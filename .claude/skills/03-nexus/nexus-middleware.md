---
name: nexus-middleware
description: "Nexus middleware: Tower middleware composition, presets, CORS, rate limiting, body limits, security headers, logging, custom middleware. Use when asking 'middleware', 'Tower layer', 'CORS', 'rate limit', 'body limit', 'security headers', 'ServiceBuilder', 'middleware stack', 'Preset', 'Lightweight', 'Standard', 'SaaS', 'Enterprise', or 'middleware ordering'."
---

# Nexus Middleware

Tower middleware composition for axum routers: presets, CORS, rate limiting, body limits, security headers, and logging.

## Module Structure

```
kailash_nexus::middleware
  stack            -- MiddlewareConfig, MiddlewareConfigBuilder, build_middleware_router
  presets          -- Preset (None, Lightweight, Standard, SaaS, Enterprise)
  cors             -- CorsConfig (permissive, strict, with_origins, with_credentials)
  rate_limit       -- RateLimitConfig, RateLimitLayer (fixed-window, atomic counter)
  body_limit       -- BodyLimitConfig (standard=2MiB, strict=256KiB)
  security_headers -- SecurityHeadersConfig (standard, strict), build_security_header_layers
  logging          -- build_trace_layer (tower_http::trace::TraceLayer)
```

## 1. Presets -- One-Line Configuration

Pick a preset to get a complete middleware stack with sensible defaults.

```rust
use kailash_nexus::middleware::{Preset, MiddlewareConfig};

// Pick a preset matching your deployment scenario
let config = MiddlewareConfig::from_preset(Preset::Standard);
```

### Preset Matrix

| Preset        | CORS             | Logging | Rate Limit   | Body Limit | Security Headers |
| ------------- | ---------------- | ------- | ------------ | ---------- | ---------------- |
| `None`        | --               | --      | --           | --         | --               |
| `Lightweight` | permissive (`*`) | yes     | --           | --         | --               |
| `Standard`    | strict           | yes     | 1000 req/60s | 2 MiB      | --               |
| `SaaS`        | strict           | yes     | 1000 req/60s | 2 MiB      | standard         |
| `Enterprise`  | strict           | yes     | 100 req/60s  | 256 KiB    | strict           |

```rust
use kailash_nexus::middleware::Preset;

// Preset is Serialize/Deserialize for config files
let preset = Preset::SaaS;
let json = serde_json::to_string(&preset)?;
let parsed: Preset = serde_json::from_str(&json)?;

// Convert to config
let config = preset.into_config();
```

## 2. Custom Configuration via Builder

Use the builder for fine-grained control when presets are not enough.

```rust
use kailash_nexus::middleware::stack::MiddlewareConfig;
use kailash_nexus::middleware::cors::CorsConfig;
use kailash_nexus::middleware::rate_limit::RateLimitConfig;
use kailash_nexus::middleware::body_limit::BodyLimitConfig;
use kailash_nexus::middleware::security_headers::SecurityHeadersConfig;

let config = MiddlewareConfig::builder()
    .cors(CorsConfig::strict().with_origins(vec![
        "https://app.example.com".to_string(),
        "https://admin.example.com".to_string(),
    ]))
    .logging(true)
    .rate_limit(RateLimitConfig::new(500, 60))   // 500 req per 60s
    .body_limit(BodyLimitConfig::new(1024 * 1024))  // 1 MiB
    .security_headers(SecurityHeadersConfig::standard())
    .build();
```

Any field not set on the builder is disabled (None).

## 3. Applying Middleware to a Router

```rust
use kailash_nexus::middleware::stack::{MiddlewareConfig, build_middleware_router};
use kailash_nexus::middleware::Preset;
use axum::{Router, routing::get};

let router = Router::new()
    .route("/api/data", get(|| async { "hello" }));

let config = MiddlewareConfig::from_preset(Preset::SaaS);
let wrapped = build_middleware_router(router, &config)?;

// `wrapped` is ready to serve
```

### Layer Application Order

`build_middleware_router` applies layers inside-out. In Tower, the last `.layer()` call is the outermost layer (runs first).

```
Request
  -> Logging        (outermost -- applied last, sees raw request)
  -> Security Headers
  -> CORS
  -> Rate Limiting
  -> Body Limit     (innermost -- applied first, closest to handler)
  -> Handler
```

## 4. Individual Middleware Configs

### CORS

```rust
use kailash_nexus::middleware::cors::CorsConfig;

// Development: allow everything (NEVER use in production with auth)
let dev = CorsConfig::permissive();
// -> allow_any_origin: true, allow_credentials: false, max_age: 3600s

// Production: explicit origins
let prod = CorsConfig::strict()
    .with_origins(vec!["https://app.example.com".to_string()])
    .with_credentials(true);
// -> allow_any_origin: false, max_age: 600s

// Convert to tower_http CorsLayer
let layer = prod.into_layer()?;
```

**Security note**: `CorsConfig::permissive()` uses `Access-Control-Allow-Origin: *`. Do not combine with credential-bearing endpoints.

### Rate Limiting (Global)

Fixed-window counter with atomic operations. Applies globally to all requests.

```rust
use kailash_nexus::middleware::rate_limit::RateLimitConfig;

let standard = RateLimitConfig::standard();  // 1000 req / 60s
let strict   = RateLimitConfig::strict();    // 100 req / 60s
let custom   = RateLimitConfig::new(200, 30); // 200 req / 30s
```

**Failure behavior**:

- HTTP 429 with `retry-after: 60` header
- JSON body: `{"error":"rate limit exceeded","code":"RATE_LIMIT_EXCEEDED"}`

**Note**: For per-user rate limiting, use `kailash_nexus::auth::rate_limit::AuthRateLimitLayer` instead (see nexus-auth-plugin skill).

### Body Limit

Prevents oversized request bodies from exhausting memory.

```rust
use kailash_nexus::middleware::body_limit::BodyLimitConfig;

let standard = BodyLimitConfig::standard();  // 2 MiB (2 * 1024 * 1024)
let strict   = BodyLimitConfig::strict();    // 256 KiB (256 * 1024)
let custom   = BodyLimitConfig::new(10 * 1024 * 1024); // 10 MiB
```

Uses `tower_http::limit::RequestBodyLimitLayer` under the hood.

### Security Headers

Adds standard HTTP security response headers.

```rust
use kailash_nexus::middleware::security_headers::SecurityHeadersConfig;

let standard = SecurityHeadersConfig::standard();
let strict   = SecurityHeadersConfig::strict();
```

| Header                    | Standard                          | Strict                                  |
| ------------------------- | --------------------------------- | --------------------------------------- |
| `X-Content-Type-Options`  | `nosniff`                         | `nosniff`                               |
| `X-Frame-Options`         | `SAMEORIGIN`                      | `DENY`                                  |
| `X-XSS-Protection`        | `1; mode=block`                   | `1; mode=block`                         |
| `Referrer-Policy`         | `strict-origin-when-cross-origin` | `no-referrer`                           |
| `Content-Security-Policy` | `default-src 'self'`              | `default-src 'none'; script-src 'self'` |

### Logging

Uses `tower_http::trace::TraceLayer` for structured request/response logging.

```rust
use kailash_nexus::middleware::logging::build_trace_layer;

let layer = build_trace_layer();
// Logs at DEBUG level. Set RUST_LOG=tower_http=debug to see output.
```

## 5. Composing with Auth Middleware

When using both the middleware stack and auth layers, apply auth layers separately. Auth layers (JWT, RBAC) are NOT part of `MiddlewareConfig`; they are standalone Tower layers.

```rust
use kailash_nexus::middleware::stack::{MiddlewareConfig, build_middleware_router};
use kailash_nexus::middleware::Preset;
use kailash_nexus::auth::{
    jwt::{JwtAuthLayer, JwtConfig},
    rbac::{RbacConfig, RbacLayer},
};
use axum::{Router, routing::get};

dotenvy::dotenv().ok();
let secret = std::env::var("JWT_SECRET")?;

// Build base router
let router = Router::new()
    .route("/api/data", get(|| async { "protected" }));

// Apply middleware stack (CORS, rate limit, logging, etc.)
let config = MiddlewareConfig::from_preset(Preset::SaaS);
let router = build_middleware_router(router, &config)?;

// Add auth layers on top
let jwt_layer = JwtAuthLayer::new(JwtConfig::new(&secret))?;
let rbac_layer = RbacLayer::new(
    RbacConfig::new()
        .with_role("admin", vec!["*".to_string()])
        .with_route_permission("GET /api/data", "data.read"),
);

let app = router
    .layer(rbac_layer)   // inner: checks permissions
    .layer(jwt_layer);   // outer: validates token
```

## 6. Full Nexus Integration

The `Nexus` struct uses `MiddlewareConfig` internally via `.preset()` and `.middleware()`.

```rust
use kailash_nexus::prelude::*;
use kailash_nexus::middleware::Preset;

let mut nexus = Nexus::new()
    .preset(Preset::SaaS);                         // use a preset

nexus.handler("greet", ClosureHandler::new(|inputs: ValueMap| async move {
    let name = inputs.get("name").and_then(|v| v.as_str()).unwrap_or("World");
    Ok(Value::from(format!("Hello, {name}!")))
}));

nexus.start().await?;
// Default bind address: 0.0.0.0:3000 (from NexusConfig::default())
```

Or use custom middleware config:

```rust
use kailash_nexus::prelude::*;
use kailash_nexus::middleware::stack::MiddlewareConfig;
use kailash_nexus::middleware::cors::CorsConfig;

let config = MiddlewareConfig::builder()
    .cors(CorsConfig::permissive())
    .logging(true)
    .build();

let mut nexus = Nexus::new()
    .middleware(config);

nexus.handler("ping", ClosureHandler::new(|_: ValueMap| async {
    Ok(Value::from("pong"))
}));
```

## 7. Custom Middleware (Tower Layer + Service)

Create custom middleware using the Tower `Layer` + `Service` pattern.

```rust
use std::task::{Context, Poll};
use axum::{body::Body, http::Request, Router};
use tower::{Layer, Service};

#[derive(Debug, Clone)]
struct TimingLayer;

impl<S> Layer<S> for TimingLayer {
    type Service = TimingService<S>;

    fn layer(&self, inner: S) -> Self::Service {
        TimingService { inner }
    }
}

#[derive(Debug, Clone)]
struct TimingService<S> {
    inner: S,
}

impl<S> Service<Request<Body>> for TimingService<S>
where
    S: Service<Request<Body>> + Clone + Send + 'static,
    S::Future: Send + 'static,
{
    type Response = S::Response;
    type Error = S::Error;
    type Future = std::pin::Pin<
        Box<dyn std::future::Future<Output = Result<Self::Response, Self::Error>> + Send>,
    >;

    fn poll_ready(&mut self, cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        self.inner.poll_ready(cx)
    }

    fn call(&mut self, req: Request<Body>) -> Self::Future {
        let start = std::time::Instant::now();
        let future = self.inner.call(req);
        Box::pin(async move {
            let response = future.await;
            tracing::info!(duration_ms = start.elapsed().as_millis(), "request handled");
            response
        })
    }
}

// Apply to router
let app = Router::new()
    .route("/api/data", axum::routing::get(|| async { "ok" }))
    .layer(TimingLayer);
```

<!-- Trigger Keywords: middleware, Tower layer, ServiceBuilder, CORS, rate limit, rate limiting, body limit, security headers, request logging, trace layer, middleware stack, middleware ordering, Preset, Lightweight, Standard, SaaS, Enterprise, MiddlewareConfig, build_middleware_router, CorsConfig, RateLimitConfig, BodyLimitConfig, SecurityHeadersConfig, custom middleware -->
