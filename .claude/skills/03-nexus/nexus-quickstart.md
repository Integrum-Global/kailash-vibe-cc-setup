---
name: nexus-quickstart
description: "Nexus in 5 minutes: deploy workflows as API + CLI + MCP simultaneously. Use when asking 'nexus quickstart', 'nexus getting started', 'first nexus server', or 'multi-channel deployment'."
---

# Nexus Quickstart Skill

Nexus in 5 minutes: deploy workflows as API + CLI + MCP simultaneously.

## Usage

`/nexus-quickstart` -- Fastest path to a running Nexus API server with authentication

## What Nexus Does

Nexus is a multi-channel deployment platform built on axum + tower. Register a handler once; it becomes available as:

- HTTP API endpoint (`POST /api/{handler_name}`)
- CLI command (`nexus {handler_name} --arg value`)
- MCP tool (via `/mcp/sse` for AI agent integration)

## Minimal Server

```rust
use kailash_nexus::prelude::*;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenvy::dotenv().ok();

    let mut nexus = Nexus::new();

    // Handlers receive ValueMap and return Result<Value, NexusError>
    nexus.handler("greet", ClosureHandler::with_params(
        |inputs: ValueMap| async move {
            let name = inputs
                .get("name")
                .and_then(|v| v.as_str())
                .unwrap_or("World");
            Ok(Value::from(format!("Hello, {name}!")))
        },
        vec![HandlerParam::new("name", HandlerParamType::String)],
    ));

    nexus.start().await?;
    // API:  POST /api/greet     {"name": "Alice"}
    // CLI:  nexus greet --name Alice
    // MCP:  GET  /mcp/sse
    Ok(())
}
```

## Handler Pattern

Handlers always receive `ValueMap` and return `Result<Value, NexusError>`. Parameter metadata is declared via `HandlerParam` for schema generation (CLI args, MCP tool schema, API docs).

```rust
use kailash_nexus::handler::{ClosureHandler, HandlerParam, HandlerParamType};
use kailash_value::{Value, ValueMap};
use std::sync::Arc;

// Define parameters for schema generation
let params = vec![
    HandlerParam::new("text", HandlerParamType::String)
        .with_description("Text to process"),
    HandlerParam::new("max_len", HandlerParamType::Integer)
        .required(false)
        .with_default(Value::Integer(256)),
    HandlerParam::new("enabled", HandlerParamType::Bool)
        .required(false)
        .with_default(Value::Bool(true)),
];

nexus.handler("process", ClosureHandler::with_params(
    |inputs: ValueMap| async move {
        let text = inputs.get("text")
            .and_then(|v| v.as_str())
            .unwrap_or("");
        let max_len = inputs.get("max_len")
            .and_then(|v| v.as_i64())
            .unwrap_or(256) as usize;
        let enabled = inputs.get("enabled")
            .and_then(|v| v.as_bool())
            .unwrap_or(true);

        if !enabled {
            return Ok(Value::from("processing disabled"));
        }

        let truncated = text.len() > max_len;
        let result = &text[..max_len.min(text.len())];
        Ok(Value::from(format!("result={result}, truncated={truncated}")))
    },
    params,
));
```

## Handler with Workflow

```rust
use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig};
use kailash_core::node::NodeRegistry;
use kailash_value::{Value, ValueMap};
use kailash_nexus::handler::{ClosureHandler, HandlerParam, HandlerParamType};
use kailash_nexus::error::NexusError;
use std::sync::Arc;

let mut node_reg = NodeRegistry::new();
kailash_core::nodes::register_system_nodes(&mut node_reg);
let node_reg = Arc::new(node_reg);

// Build workflow once
let mut builder = WorkflowBuilder::new();
builder
    .add_node("TextTransformNode", "upper", {
        let mut c = ValueMap::new();
        c.insert(Arc::from("operation"), Value::String(Arc::from("uppercase")));
        c
    })
    .add_node("LogNode", "log", ValueMap::new())
    .connect("upper", "result", "log", "data");

let workflow = Arc::new(builder.build(&node_reg)?);
let runtime = Arc::new(Runtime::new(RuntimeConfig::default(), Arc::clone(&node_reg)));

// Capture in handler closure
let params = vec![
    HandlerParam::new("text", HandlerParamType::String)
        .with_description("Text to transform"),
];
nexus.handler("transform", ClosureHandler::with_params(
    move |inputs: ValueMap| {
        let workflow = Arc::clone(&workflow);
        let runtime = Arc::clone(&runtime);
        async move {
            let result = runtime.execute(&workflow, inputs).await
                .map_err(|e| NexusError::Internal(e.to_string()))?;

            let output = result.results.get("upper")
                .and_then(|m| m.get("result"))
                .and_then(|v| v.as_str())
                .unwrap_or("");

            Ok(Value::from(output))
        }
    },
    params,
));
```

## Preset Middleware

One-line middleware configuration:

```rust
use kailash_nexus::Nexus;
use kailash_nexus::middleware::Preset;

// None: No middleware (raw axum, development only)
let nexus = Nexus::new().preset(Preset::None);

// Lightweight: Permissive CORS + request logging
let nexus = Nexus::new().preset(Preset::Lightweight);

// Standard: Strict CORS + rate limiting + logging + body limit
let nexus = Nexus::new().preset(Preset::Standard);

// SaaS: Standard + security response headers
let nexus = Nexus::new().preset(Preset::SaaS);

// Enterprise: SaaS + stricter rate limits, body limits, headers
let nexus = Nexus::new().preset(Preset::Enterprise);
```

## Adding Auth

JWT authentication is a separate Tower layer applied to the axum Router. Nexus does not have a built-in `jwt_secret()` method. Instead, build the JWT layer and apply it when composing the router.

```rust
use kailash_nexus::auth::jwt::{JwtAuthLayer, JwtConfig, AuthUser, JwtClaims, create_jwt};
use axum::{Router, routing::get};

dotenvy::dotenv().ok();
let secret = std::env::var("JWT_SECRET")
    .expect("JWT_SECRET must be set in .env");

let jwt_layer = JwtAuthLayer::new(JwtConfig::new(&secret))?;

// Build your router with the JWT layer
let app = Router::new()
    .route("/api/protected", get(protected_handler))
    .layer(jwt_layer);

async fn protected_handler(AuthUser(claims): AuthUser) -> String {
    // AuthUser wraps JwtClaims, extracted from validated JWT
    format!(
        "user_id: {}, role: {:?}, tenant: {:?}",
        claims.sub, claims.role, claims.tenant_id
    )
}
```

## Custom Middleware Configuration

```rust
use kailash_nexus::Nexus;
use kailash_nexus::middleware::MiddlewareConfig;

let config = MiddlewareConfig::builder()
    .logging(true)
    .build();

let nexus = Nexus::new().middleware(config);
```

## MCP Integration

When `enable_mcp` is `true` (the default) in `NexusConfig`, all registered handlers are automatically exposed as MCP tools via SSE at `/mcp/message` and `/mcp/sse`.

For Claude Desktop, add to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "my-service": {
      "url": "http://localhost:3000/mcp/sse"
    }
  }
}
```

## Custom Port and Config

```rust
use kailash_nexus::Nexus;
use kailash_nexus::config::NexusConfig;

// Default: 0.0.0.0:3000
nexus.start().await?;

// Custom port via NexusConfig
let nexus = Nexus::new().with_config(NexusConfig {
    host: "127.0.0.1".to_string(),
    port: 8080,
    ..NexusConfig::default()
});
nexus.start().await?;

// Or mutate config
let mut nexus = Nexus::new();
nexus.set_config(NexusConfig {
    port: 9000,
    ..NexusConfig::default()
});

// With graceful shutdown
nexus.start_with_shutdown(async {
    tokio::signal::ctrl_c().await.expect("ctrl-c listener");
}).await?;
```

## Method Aliases

Nexus provides aliases for common conventions:

```rust
// All equivalent to nexus.handler(name, func):
nexus.register("name", handler);
nexus.register_handler("name", handler);

// All equivalent to nexus.start():
nexus.run().await?;
nexus.serve().await?;
```

## Verify

```bash
cargo test -p kailash-nexus -- --nocapture 2>&1
```

<!-- Trigger Keywords: nexus quickstart, getting started, first nexus server, multi-channel, Nexus::new, handler registration, ClosureHandler, HandlerParam, ValueMap handler, preset middleware, Nexus start, Nexus serve, NexusConfig -->
