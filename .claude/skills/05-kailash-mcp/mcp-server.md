---
name: mcp-server
description: "MCP server patterns with kailash-nexus. Use when asking 'MCP server', 'register MCP tool', 'MCP resources', 'expose workflow as tool', 'McpServer setup'."
---

# MCP Server (kailash-nexus)

The MCP server lives in `crates/kailash-nexus/src/mcp/server.rs` behind the `mcp` feature flag. `McpServer` is transport-agnostic -- it accepts raw JSON-RPC 2.0 strings and returns response strings. Transport layers (SSE, HTTP, stdio) wrap it for I/O.

## Architecture

```
McpServer (transport-agnostic, JSON-RPC 2.0)
  |
  +-- register_tool()              -- custom handler functions
  +-- register_workflow_as_tool()  -- wraps a kailash-core Workflow
  +-- register_resource()          -- static resources
  +-- handle_message(&str) -> String  -- main dispatch entry point
  |
  +-- Transports (wrappers):
       +-- stdio::run_stdio_server()         -- stdin/stdout with Content-Length framing
       +-- http_transport::mcp_http_router() -- POST /mcp axum Router
       +-- sse::build_mcp_router()           -- POST /mcp/message + GET /mcp/sse
       +-- Nexus auto-integration            -- enable_mcp: true in NexusConfig
```

## Supported Protocol Methods

| Method           | Description                                |
| ---------------- | ------------------------------------------ |
| `initialize`     | Server capabilities and identification     |
| `tools/list`     | List all registered tools with JSON Schema |
| `tools/call`     | Execute a tool by name with arguments      |
| `resources/list` | List all registered resources              |
| `resources/read` | Read a resource by URI                     |

## Creating an MCP Server

```rust
use kailash_nexus::mcp::server::McpServer;

let mut server = McpServer::new("my-server", "1.0.0");
assert_eq!(server.tool_count(), 0);
assert_eq!(server.resource_count(), 0);
```

## Registering a Tool with a Custom Handler

`register_tool` accepts an async closure that receives `serde_json::Value` arguments and returns `Result<serde_json::Value, NexusError>`.

```rust
use kailash_nexus::mcp::server::McpServer;
use kailash_nexus::error::NexusError;

let mut server = McpServer::new("calculator-server", "1.0.0");

server.register_tool(
    "add",
    Some("Adds two numbers"),
    serde_json::json!({
        "type": "object",
        "properties": {
            "a": { "type": "number", "description": "First number" },
            "b": { "type": "number", "description": "Second number" }
        },
        "required": ["a", "b"]
    }),
    |args: serde_json::Value| async move {
        let a = args["a"].as_f64().unwrap_or(0.0);
        let b = args["b"].as_f64().unwrap_or(0.0);
        Ok(serde_json::json!({ "sum": a + b }))
    },
);

assert_eq!(server.tool_count(), 1);
```

## Registering a Workflow as a Tool

`register_workflow_as_tool` auto-generates the JSON Schema from the workflow's source nodes' input parameters. When called, the workflow executes via the provided `Runtime`.

```rust
use kailash_nexus::mcp::server::McpServer;
use kailash_core::workflow::WorkflowBuilder;
use kailash_core::node::NodeRegistry;
use kailash_core::runtime::{Runtime, RuntimeConfig};
use kailash_value::{Value, ValueMap};
use std::sync::Arc;

// Build a workflow
let registry = Arc::new(NodeRegistry::new());
let mut builder = WorkflowBuilder::new();
// ... add nodes and connections ...
let workflow = Arc::new(builder.build(&registry)?);
let runtime = Arc::new(Runtime::new(RuntimeConfig::default(), registry));

// Expose it as an MCP tool
let mut server = McpServer::new("workflow-server", "1.0.0");
server.register_workflow_as_tool(
    "process-data",
    Some("Processes data through a workflow pipeline"),
    &workflow,
    &runtime,
);
```

The tool call result includes `run_id` and per-node `results`:

```json
{
  "run_id": "abc-123",
  "results": {
    "node_id": { "output_key": "output_value" }
  }
}
```

## Registering a Static Resource

```rust
use kailash_nexus::mcp::server::McpServer;

let mut server = McpServer::new("docs-server", "1.0.0");

server.register_resource(
    "file:///config.json",
    "Configuration",
    Some("Application configuration file"),
    Some("application/json"),
    r#"{"database": "postgres://localhost/mydb", "port": 3000}"#,
);

server.register_resource(
    "file:///readme",
    "README",
    Some("Project documentation"),
    Some("text/plain"),
    "Welcome to the project.",
);

assert_eq!(server.resource_count(), 2);
```

## Handling Messages Directly

`handle_message` is the main dispatch entry point. It parses JSON-RPC, routes to the appropriate handler, and returns a JSON-RPC response string.

```rust
use kailash_nexus::mcp::server::McpServer;

let server = McpServer::new("test", "0.1.0");

let response = server.handle_message(
    r#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}"#
).await;

// response is a JSON string containing protocolVersion, capabilities, serverInfo
assert!(response.contains("protocolVersion"));
```

## Nexus Auto-Integration

When `enable_mcp` is `true` (the default) in `NexusConfig`, all registered Nexus handlers are automatically exposed as MCP tools via the SSE transport at `/mcp/message` and `/mcp/sse`.

```rust
use kailash_nexus::Nexus;
use kailash_nexus::handler::{ClosureHandler, HandlerParam, HandlerParamType};
use kailash_value::{Value, ValueMap};

let mut nexus = Nexus::new();

// This handler becomes available as both:
//   POST /api/greet      (HTTP API)
//   MCP tool "greet"     (via /mcp/message)
let params = vec![
    HandlerParam::new("name", HandlerParamType::String)
        .with_description("Name to greet"),
];
nexus.handler(
    "greet",
    ClosureHandler::with_params(
        |inputs: ValueMap| async move {
            let name = inputs
                .get("name")
                .and_then(|v| v.as_str())
                .unwrap_or("World");
            Ok(Value::from(format!("Hello, {name}!")))
        },
        params,
    ),
);

// MCP routes are automatically merged into the router
let router = nexus.router()?;
// Serves: POST /mcp/message, GET /mcp/sse, POST /api/greet, GET /health
```

## Key Types (server module)

| Type                                 | Description                                                  |
| ------------------------------------ | ------------------------------------------------------------ |
| `McpServer`                          | Transport-agnostic MCP server, registers tools and resources |
| `McpToolInfo`                        | Tool name, description, and JSON Schema (`inputSchema`)      |
| `McpResource`                        | Resource URI, name, description, MIME type                   |
| `ResourceContent`                    | Content returned by `resources/read`                         |
| `ToolHandler`                        | Trait for tool handler functions                             |
| `ServerCapabilities`                 | Advertised capabilities (`tools`, `resources`)               |
| `InitializeResult`                   | Result of the `initialize` handshake                         |
| `JsonRpcRequest` / `JsonRpcResponse` | JSON-RPC 2.0 wire types                                      |

## Feature Flag

MCP server code requires the `mcp` feature on `kailash-nexus`:

```toml
[dependencies]
kailash-nexus = { path = "../kailash-nexus", features = ["mcp"] }
```

## Source Files

- `crates/kailash-nexus/src/mcp/mod.rs` -- module root, re-exports
- `crates/kailash-nexus/src/mcp/server.rs` -- `McpServer`, tool/resource registration, dispatch
- `crates/kailash-nexus/src/mcp/sse.rs` -- SSE transport (axum routes at `/mcp/message`, `/mcp/sse`)
- `crates/kailash-nexus/src/mcp/stdio.rs` -- stdio transport (`run_stdio_server`)
- `crates/kailash-nexus/src/mcp/http_transport.rs` -- HTTP transport (`mcp_http_router`)
- `crates/kailash-nexus/src/nexus.rs` -- Nexus auto-integration (`enable_mcp`)

<!-- Trigger Keywords: MCP server, McpServer, register tool, register resource, MCP setup, expose workflow, workflow as tool, MCP nexus, JSON-RPC server -->
