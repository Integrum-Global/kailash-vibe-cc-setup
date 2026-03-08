---
name: nexus-preset-system
description: "Reference for Nexus Preset middleware stacks (None, Lightweight, Standard, SaaS, Enterprise). Use when asking 'nexus presets', 'middleware presets', 'which preset', or 'preset comparison'."
---

# Nexus Preset System Skill

Reference for Nexus Preset middleware stacks and what each one enables.

## Usage

`/nexus-preset-system` -- Preset configurations, what middleware each enables, and custom tower configuration

## Preset Overview

Presets are one-line middleware stacks. Each preset configures CORS, logging, rate limiting, body limits, and security headers.

```rust
use kailash_nexus::prelude::*;
use kailash_nexus::middleware::Preset;

let nexus = Nexus::new().preset(Preset::SaaS);
```

## Preset Matrix

| Preset        | CORS             | Logging | Rate Limit   | Body Limit | Security Headers |
| ------------- | ---------------- | ------- | ------------ | ---------- | ---------------- |
| `None`        | --               | --      | --           | --         | --               |
| `Lightweight` | permissive (`*`) | yes     | --           | --         | --               |
| `Standard`    | strict           | yes     | 1000 req/60s | 2 MiB      | --               |
| `SaaS`        | strict           | yes     | 1000 req/60s | 2 MiB      | standard         |
| `Enterprise`  | strict           | yes     | 100 req/60s  | 256 KiB    | strict           |

## Preset::None

No middleware. Raw axum router. For development and testing only.

```rust
let nexus = Nexus::new().preset(Preset::None);
// - No CORS headers
// - No rate limiting
// - No logging
// - No body limits
// - No security headers
```

## Preset::Lightweight

Adds permissive CORS and request logging. Suitable for internal microservices and development.

```rust
let nexus = Nexus::new().preset(Preset::Lightweight);

// Enables:
// - CORS: Access-Control-Allow-Origin: * (permissive)
// - Request/response logging via tower_http::trace::TraceLayer
```

## Preset::Standard

Strict CORS, logging, rate limiting, and body limits. Suitable for public APIs.

```rust
let nexus = Nexus::new().preset(Preset::Standard);

// Enables:
// - CORS: strict (no wildcard origin, explicit origins only)
// - Request/response logging
// - Rate limiting: 1000 requests per 60 seconds (global)
// - Body size limit: 2 MiB
```

## Preset::SaaS

Standard plus security response headers. Suitable for multi-tenant SaaS APIs.

```rust
let nexus = Nexus::new().preset(Preset::SaaS);

// Enables all Standard features plus:
// - Security headers (standard): X-Content-Type-Options, X-Frame-Options,
//   X-XSS-Protection, Referrer-Policy, Content-Security-Policy
```

## Preset::Enterprise

SaaS with stricter rate limits, smaller body limits, and strict security headers.

```rust
let nexus = Nexus::new().preset(Preset::Enterprise);

// Enables all SaaS features with stricter settings:
// - Rate limiting: 100 requests per 60 seconds
// - Body limit: 256 KiB
// - Security headers (strict): X-Frame-Options: DENY,
//   Referrer-Policy: no-referrer, stricter CSP
```

## Adding Authentication

JWT authentication and RBAC are NOT part of presets. They are separate Tower layers applied independently to the axum router. See `nexus-auth-plugin.md` for details.

```rust
use kailash_nexus::prelude::*;
use kailash_nexus::middleware::Preset;
use kailash_nexus::auth::jwt::{JwtAuthLayer, JwtConfig};
use kailash_nexus::auth::rbac::{RbacConfig, RbacLayer};
use axum::Router;

// Step 1: Build Nexus with a preset
let mut nexus = Nexus::new().preset(Preset::SaaS);
nexus.handler("data", ClosureHandler::new(|_: ValueMap| async {
    Ok(Value::from("protected data"))
}));

// Step 2: Get the router and add auth layers
dotenvy::dotenv().ok();
let secret = std::env::var("JWT_SECRET")?;

let jwt_layer = JwtAuthLayer::new(JwtConfig::new(&secret))?;
let rbac_layer = RbacLayer::new(
    RbacConfig::new()
        .with_role("admin", vec!["*".to_string()])
        .with_route_permission("GET /api/data", "data.read"),
);

// Build router with middleware and auth layers
let router = nexus.router()?;
let app = router
    .layer(rbac_layer)   // inner: checks permissions
    .layer(jwt_layer);   // outer: validates token

// Step 3: Start manually with axum::serve
let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await?;
axum::serve(listener, app).await?;
```

## Custom Middleware Configuration

For cases where presets don't fit, use `MiddlewareConfig::builder()`:

```rust
use kailash_nexus::middleware::stack::MiddlewareConfig;
use kailash_nexus::middleware::cors::CorsConfig;
use kailash_nexus::middleware::rate_limit::RateLimitConfig;
use kailash_nexus::middleware::body_limit::BodyLimitConfig;
use kailash_nexus::middleware::security_headers::SecurityHeadersConfig;

let config = MiddlewareConfig::builder()
    .cors(CorsConfig::strict().with_origins(vec![
        "https://app.example.com".to_string(),
    ]))
    .logging(true)
    .rate_limit(RateLimitConfig::new(500, 60))       // 500 req per 60s
    .body_limit(BodyLimitConfig::new(1024 * 1024))   // 1 MiB
    .security_headers(SecurityHeadersConfig::standard())
    .build();

let nexus = Nexus::new().middleware(config);
```

## Security Defaults

| Setting                   | Default                            |
| ------------------------- | ---------------------------------- |
| JWT minimum secret length | 32 bytes for HS256/HS384/HS512     |
| RBAC error messages       | Generic "Forbidden" (no role leak) |
| Rate limit response       | HTTP 429 with retry-after header   |
| Default port              | 3000                               |
| Default host              | 0.0.0.0                            |

## Choosing the Right Preset

| Use Case                        | Preset        |
| ------------------------------- | ------------- |
| Development / local testing     | `None`        |
| Internal microservice           | `Lightweight` |
| Public API (single-tenant)      | `Standard`    |
| Multi-tenant SaaS API           | `SaaS`        |
| Enterprise with strict security | `Enterprise`  |

## Verify

```bash
cargo test -p kailash-nexus -- preset --nocapture 2>&1
```
