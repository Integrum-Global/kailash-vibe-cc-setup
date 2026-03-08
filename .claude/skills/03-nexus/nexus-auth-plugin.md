---
name: nexus-auth-plugin
description: "Nexus auth plugin: JWT authentication, RBAC middleware, per-user rate limiting. Use when asking 'JWT auth', 'RBAC middleware', 'auth plugin', 'role-based access', 'auth extractor', 'AuthUser', 'JwtClaims', 'rate limit per user', or 'tenant isolation'."
---

# Nexus Auth Plugin

JWT authentication, RBAC enforcement, and per-user rate limiting as composable Tower layers for axum routers.

## Module Structure

```
kailash_nexus::auth
  jwt         -- JwtConfig, JwtClaims, JwtAuthLayer, AuthUser, create_jwt, decode_jwt
  rbac        -- RbacConfig, RbacLayer (route-level permission enforcement)
  rate_limit  -- AuthRateLimitConfig, AuthRateLimitLayer (per-user/per-tenant)
  error       -- AuthError (WeakSecret, JwtInvalid, MissingAuth, Forbidden, etc.)
```

## 1. JWT Authentication

### JwtConfig

Configure JWT validation. HS algorithms require a secret of at least 32 bytes.

```rust
use kailash_nexus::auth::jwt::JwtConfig;
use jsonwebtoken::Algorithm;

// Read secret from environment -- NEVER hardcode
dotenvy::dotenv().ok();
let secret = std::env::var("JWT_SECRET")
    .map_err(|_| "JWT_SECRET must be set in .env")?;

let config = JwtConfig::new(&secret)
    .with_algorithm(Algorithm::HS256)  // default
    .with_expiry_secs(3600)            // default: 1 hour
    .with_issuer("my-app")
    .with_audience(vec!["api".to_string()])
    .with_leeway_secs(60)             // clock skew tolerance
    .with_required_claim("sub");

// Validates secret strength (>= 32 bytes for HS algorithms)
config.validate()?;
```

### JwtClaims

Token payload with built-in RBAC fields (`role`, `tenant_id`).

```rust
use kailash_nexus::auth::jwt::JwtClaims;

let claims = JwtClaims::new("user-123")       // sub = user ID
    .with_role("admin")                         // RBAC role
    .with_tenant_id("tenant-456")               // multi-tenancy
    .with_issuer("my-app")
    .with_audience(vec!["api".to_string()])
    .with_extra("org_id", serde_json::json!("org-1")); // custom claims

// Create with custom expiry
let short_lived = JwtClaims::with_expiry("user-123", 900); // 15 minutes
```

### Create and Decode Tokens

```rust
use kailash_nexus::auth::jwt::{JwtConfig, JwtClaims, create_jwt, decode_jwt};

let config = JwtConfig::new(&secret);
let claims = JwtClaims::new("user-123").with_role("admin");

let token = create_jwt(&claims, &config)?;
let decoded = decode_jwt(&token, &config)?;
assert_eq!(decoded.sub, "user-123");
assert_eq!(decoded.role.as_deref(), Some("admin"));
```

### JwtAuthLayer -- Tower Middleware

Validates `Authorization: Bearer <token>` on every request. Injects `JwtClaims` into request extensions.

```rust
use kailash_nexus::auth::jwt::{JwtAuthLayer, JwtConfig};
use axum::{Router, routing::get};

let config = JwtConfig::new(&secret);
let jwt_layer = JwtAuthLayer::new(config)?; // validates config eagerly

let app = Router::new()
    .route("/protected", get(protected_handler))
    .layer(jwt_layer);
```

**Failure behavior:**

- Missing `Authorization` header: HTTP 401
- Invalid/expired token: HTTP 401

### AuthUser Extractor

Read authenticated claims in handler functions.

```rust
use kailash_nexus::auth::jwt::AuthUser;

async fn protected_handler(AuthUser(claims): AuthUser) -> String {
    format!("Hello, {}! Role: {:?}", claims.sub, claims.role)
}

async fn tenant_handler(AuthUser(claims): AuthUser) -> Result<String, kailash_nexus::auth::AuthError> {
    let tenant = claims.tenant_id
        .as_deref()
        .ok_or(kailash_nexus::auth::AuthError::MissingTenant)?;
    Ok(format!("Tenant: {tenant}"))
}
```

## 2. RBAC Middleware

Route-level role-based access control. Reads `JwtClaims` from extensions (set by `JwtAuthLayer`) and checks permissions.

### RbacConfig

```rust
use kailash_nexus::auth::rbac::RbacConfig;

let rbac_config = RbacConfig::new()
    // Define roles and their permissions
    .with_role("admin", vec!["*".to_string()])                    // wildcard: all access
    .with_role("editor", vec!["users.*".to_string()])             // resource wildcard
    .with_role("viewer", vec!["users.read".to_string()])          // exact permission
    // Map routes to required permissions ("METHOD /path" format)
    .with_route_permission("GET /api/users", "users.read")
    .with_route_permission("POST /api/users", "users.write")
    .with_route_permission("DELETE /api/users/{id}", "users.delete")
    // Default behavior for unmapped routes
    .with_deny_by_default(true)                                   // default
    .with_default_permission("base.access");                      // optional fallback
```

**Permission matching:**

- `"*"` matches any permission (admin wildcard)
- `"users.*"` matches `"users.read"`, `"users.write"`, etc.
- `"users.read"` exact match only
- Route patterns support `{param}` placeholders

### Composing JWT + RBAC

Layer order matters -- JWT must run before RBAC because RBAC reads claims from extensions.

```rust
use kailash_nexus::auth::{
    jwt::{JwtAuthLayer, JwtConfig},
    rbac::{RbacConfig, RbacLayer},
};
use axum::{Router, routing::get};

let jwt_layer = JwtAuthLayer::new(JwtConfig::new(&secret))?;
let rbac_layer = RbacLayer::new(
    RbacConfig::new()
        .with_role("admin", vec!["*".to_string()])
        .with_role("user", vec!["data.read".to_string()])
        .with_route_permission("GET /api/data", "data.read")
        .with_route_permission("POST /api/data", "data.write"),
);

// Tower layers wrap outside-in: last .layer() is outermost
// JWT runs first (outermost), then RBAC checks claims
let app = Router::new()
    .route("/api/data", get(data_handler))
    .layer(rbac_layer)   // inner: checks permissions
    .layer(jwt_layer);   // outer: validates token, sets claims
```

**Failure behavior:**

- No claims in extensions (JWT layer missing): HTTP 403
- Role lacks required permission: HTTP 403
- Response body is generic `"Forbidden"` to avoid leaking role info

## 3. Per-User Rate Limiting

Unlike the global `middleware::rate_limit`, this limits per authenticated user or per anonymous key.

```rust
use kailash_nexus::auth::rate_limit::{AuthRateLimitConfig, AuthRateLimitLayer};

let rate_config = AuthRateLimitConfig::new()
    .with_authenticated_rpm(2000)  // default: 1000/min
    .with_anonymous_rpm(30)        // default: 60/min
    .with_burst_size(100);         // default: 50 above limit

let rate_layer = AuthRateLimitLayer::new(rate_config);

// Compose with JWT for per-user identification
let app = Router::new()
    .route("/api/data", get(data_handler))
    .layer(rate_layer)  // inner: rate limit
    .layer(jwt_layer);  // outer: sets claims used for rate limit key
```

**Behavior:**

- Authenticated users keyed by `user:{sub}` from JWT claims
- Anonymous users keyed by `"anonymous"` (shared pool)
- Rate limit headers on every response: `x-ratelimit-limit`, `x-ratelimit-remaining`
- HTTP 429 with `retry-after: 60` when exceeded

## 4. Full Auth Stack Example

```rust
use kailash_nexus::auth::{
    jwt::{AuthUser, JwtAuthLayer, JwtClaims, JwtConfig},
    rbac::{RbacConfig, RbacLayer},
    rate_limit::{AuthRateLimitConfig, AuthRateLimitLayer},
};
use axum::{Router, routing::get};

dotenvy::dotenv().ok();
let secret = std::env::var("JWT_SECRET")?;

let jwt_layer = JwtAuthLayer::new(
    JwtConfig::new(&secret)
        .with_issuer("my-app")
        .with_audience(vec!["api".to_string()]),
)?;

let rbac_layer = RbacLayer::new(
    RbacConfig::new()
        .with_role("admin", vec!["*".to_string()])
        .with_role("user", vec!["users.read".to_string(), "orders.read".to_string()])
        .with_route_permission("GET /api/users", "users.read")
        .with_route_permission("GET /api/orders", "orders.read")
        .with_route_permission("POST /api/admin", "admin.access"),
);

let rate_layer = AuthRateLimitLayer::new(
    AuthRateLimitConfig::new()
        .with_authenticated_rpm(1000)
        .with_anonymous_rpm(60)
        .with_burst_size(50),
);

// Layer order (inside-out): rate limit -> RBAC -> JWT
let app = Router::new()
    .route("/api/users", get(list_users))
    .route("/api/orders", get(list_orders))
    .route("/api/admin", get(admin_panel).post(admin_action))
    .layer(rate_layer)   // innermost
    .layer(rbac_layer)   // middle
    .layer(jwt_layer);   // outermost

async fn list_users(AuthUser(claims): AuthUser) -> String {
    format!("Users for tenant: {:?}", claims.tenant_id)
}

async fn list_orders(AuthUser(claims): AuthUser) -> String {
    format!("Orders for user: {}", claims.sub)
}

async fn admin_panel(AuthUser(claims): AuthUser) -> String {
    format!("Admin: {}", claims.sub)
}

async fn admin_action(AuthUser(claims): AuthUser) -> String {
    format!("Admin action by: {}", claims.sub)
}
```

## 5. AuthError Types

| Variant             | HTTP Status | When                                   |
| ------------------- | ----------- | -------------------------------------- |
| `WeakSecret`        | 500         | Secret < 32 bytes for HS algorithms    |
| `JwtInvalid`        | 401         | Token expired, malformed, wrong secret |
| `MissingAuth`       | 401         | No Authorization header                |
| `Forbidden`         | 403         | RBAC permission denied                 |
| `MissingTenant`     | 403         | No tenant_id in token/headers          |
| `RateLimitExceeded` | 429         | Per-user rate limit exceeded           |
| `SsoError`          | 500         | SSO provider failure                   |
| `OAuthStateError`   | 400         | OAuth state mismatch or expired        |
| `ConfigError`       | 500         | Auth plugin misconfiguration           |

`AuthError` implements `IntoResponse` for direct use as axum error responses.

<!-- Trigger Keywords: JWT, RBAC, authentication, authorization, auth plugin, JwtClaims, AuthUser, rate limit, per-user rate limit, tenant isolation, role-based access, token, bearer -->
