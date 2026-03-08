---
name: nexus-sessions
description: "Nexus sessions: request-scoped session data via JWT claims in axum extensions, AuthUser extractor, request extension pattern, state sharing. Use when asking 'session', 'session data', 'request state', 'user context', 'AuthUser', 'request extensions', 'per-request state', 'tenant context', or 'user identity in handler'."
---

# Nexus Sessions

Request-scoped session data in Nexus is handled through axum request extensions, not a traditional session store. The primary mechanism is JWT claims injected by `JwtAuthLayer` and extracted via `AuthUser`.

## Architecture

Nexus does NOT have a dedicated session module. Instead, session-like behavior is achieved through:

1. **JWT Claims** -- Stateless sessions via signed tokens (primary pattern)
2. **Request Extensions** -- Arbitrary data injected by Tower middleware
3. **Axum State** -- Shared application state via `Router::with_state()`

```
Client sends Authorization: Bearer <JWT>
  -> JwtAuthLayer validates token
  -> JwtClaims injected into request extensions
  -> Handler extracts via AuthUser(claims)
  -> Claims contain: sub (user ID), role, tenant_id, custom claims
```

## 1. JWT-Based Sessions (Primary Pattern)

The JWT token acts as a stateless session. User identity, role, tenant, and custom claims are embedded in the token itself.

### Setting Up the Auth Layer

```rust
use kailash_nexus::auth::jwt::{JwtAuthLayer, JwtConfig};
use axum::{Router, routing::get};

dotenvy::dotenv().ok();
let secret = std::env::var("JWT_SECRET")?;

let jwt_layer = JwtAuthLayer::new(JwtConfig::new(&secret))?;

let app = Router::new()
    .route("/api/profile", get(profile_handler))
    .layer(jwt_layer);
```

### Extracting Session Data in Handlers

```rust
use kailash_nexus::auth::jwt::AuthUser;

async fn profile_handler(AuthUser(claims): AuthUser) -> String {
    // claims.sub -- user ID (always present)
    // claims.role -- user role (Option<String>)
    // claims.tenant_id -- tenant ID (Option<String>)
    // claims.iss -- issuer (Option<String>)
    // claims.aud -- audience (Option<Vec<String>>)
    // claims.exp -- expiry timestamp (u64)
    // claims.iat -- issued-at timestamp (u64)
    // claims.extra -- custom claims (BTreeMap<String, serde_json::Value>)

    format!(
        "User: {}, Role: {:?}, Tenant: {:?}",
        claims.sub,
        claims.role,
        claims.tenant_id,
    )
}
```

### Accessing Custom Claims

```rust
use kailash_nexus::auth::jwt::{AuthUser, JwtClaims};

async fn handler_with_custom_claims(AuthUser(claims): AuthUser) -> String {
    // Access custom claims stored in the JWT
    let org_id = claims.extra
        .get("org_id")
        .and_then(|v| v.as_str())
        .unwrap_or("unknown");

    let permissions: Vec<String> = claims.extra
        .get("permissions")
        .and_then(|v| v.as_array())
        .map(|arr| arr.iter().filter_map(|v| v.as_str().map(String::from)).collect())
        .unwrap_or_default();

    format!("Org: {org_id}, Permissions: {permissions:?}")
}
```

### Creating Tokens with Session Data

```rust
use kailash_nexus::auth::jwt::{JwtConfig, JwtClaims, create_jwt};

dotenvy::dotenv().ok();
let secret = std::env::var("JWT_SECRET")?;
let config = JwtConfig::new(&secret);

let claims = JwtClaims::new("user-123")       // sub = user ID
    .with_role("admin")                         // session role
    .with_tenant_id("tenant-456")               // multi-tenancy
    .with_issuer("my-app")
    .with_extra("org_id", serde_json::json!("org-1"))
    .with_extra("permissions", serde_json::json!(["read", "write"]));

let token = create_jwt(&claims, &config)?;
// Send token to client in login response
```

## 2. Request Extensions Pattern

For non-auth session data, use Tower middleware to inject values into request extensions.

### Custom Middleware for Request Context

```rust
use std::task::{Context, Poll};
use axum::{
    body::Body,
    extract::Extension,
    http::Request,
    Router,
    routing::get,
};
use tower::{Layer, Service};

/// Per-request context injected by middleware
#[derive(Debug, Clone)]
struct RequestContext {
    request_id: String,
    client_ip: Option<String>,
    user_agent: Option<String>,
}

#[derive(Debug, Clone)]
struct RequestContextLayer;

impl<S> Layer<S> for RequestContextLayer {
    type Service = RequestContextService<S>;

    fn layer(&self, inner: S) -> Self::Service {
        RequestContextService { inner }
    }
}

#[derive(Debug, Clone)]
struct RequestContextService<S> {
    inner: S,
}

impl<S> Service<Request<Body>> for RequestContextService<S>
where
    S: Service<Request<Body>>,
{
    type Response = S::Response;
    type Error = S::Error;
    type Future = S::Future;

    fn poll_ready(&mut self, cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        self.inner.poll_ready(cx)
    }

    fn call(&mut self, mut req: Request<Body>) -> Self::Future {
        let ctx = RequestContext {
            request_id: uuid::Uuid::new_v4().to_string(),
            client_ip: req.headers()
                .get("x-forwarded-for")
                .and_then(|v| v.to_str().ok())
                .map(String::from),
            user_agent: req.headers()
                .get("user-agent")
                .and_then(|v| v.to_str().ok())
                .map(String::from),
        };
        req.extensions_mut().insert(ctx);
        self.inner.call(req)
    }
}

// Extract in handler
async fn handler(Extension(ctx): Extension<RequestContext>) -> String {
    format!("Request ID: {}", ctx.request_id)
}

let app = Router::new()
    .route("/api/data", get(handler))
    .layer(RequestContextLayer);
```

## 3. Shared Application State

For data shared across all requests (database pools, caches, config), use axum's state system.

```rust
use std::sync::Arc;
use axum::{extract::State, Router, routing::get};

#[derive(Clone)]
struct AppState {
    db_pool: sqlx::PgPool,
    config: Arc<AppConfig>,
}

struct AppConfig {
    feature_flags: Vec<String>,
}

async fn handler(State(state): State<AppState>) -> String {
    let flags = &state.config.feature_flags;
    format!("Feature flags: {flags:?}")
}

let state = AppState {
    db_pool: sqlx::PgPool::connect(&std::env::var("DATABASE_URL")?).await?,
    config: Arc::new(AppConfig {
        feature_flags: vec!["dark_mode".into(), "beta_api".into()],
    }),
};

let app = Router::new()
    .route("/api/info", get(handler))
    .with_state(state);
```

## 4. Combining Auth + Context + State

```rust
use kailash_nexus::auth::jwt::{AuthUser, JwtAuthLayer, JwtConfig};
use axum::{extract::{Extension, State}, Router, routing::get};

#[derive(Clone)]
struct AppState {
    db_pool: sqlx::PgPool,
}

#[derive(Debug, Clone)]
struct RequestId(String);

async fn protected_handler(
    AuthUser(claims): AuthUser,          // from JwtAuthLayer
    Extension(req_id): Extension<RequestId>,  // from custom middleware
    State(state): State<AppState>,       // from Router::with_state
) -> String {
    format!(
        "User: {}, Request: {}, DB connected: {}",
        claims.sub,
        req_id.0,
        !state.db_pool.is_closed(),
    )
}
```

## 5. Tenant Context Pattern

For multi-tenant applications, extract tenant from JWT and use it to scope queries.

```rust
use kailash_nexus::auth::jwt::AuthUser;
use kailash_nexus::auth::AuthError;

/// Extract tenant_id from JWT claims, rejecting requests without one.
async fn tenant_handler(
    AuthUser(claims): AuthUser,
) -> Result<String, AuthError> {
    let tenant_id = claims.tenant_id
        .as_deref()
        .ok_or(AuthError::MissingTenant)?;

    // Use tenant_id to scope database queries
    Ok(format!("Tenant: {tenant_id}"))
}
```

## Why No Session Store?

Nexus follows a **stateless-first** architecture:

- **JWT tokens** carry all session data in the token itself
- **No server-side session storage** means horizontal scaling without session affinity
- **Token expiry** handles session timeout naturally
- **Custom claims** (`extra` field) allow arbitrary session-like data

For applications that need server-side sessions (shopping carts, wizard state, etc.), implement a session store using `axum::extract::State` with a shared data structure (DashMap, Redis, sqlx).

<!-- Trigger Keywords: session, session data, request state, user context, AuthUser, request extensions, per-request state, tenant context, user identity, JWT session, stateless session, request context, Extension extractor, request ID, tenant isolation, multi-tenant, shared state, AppState -->
