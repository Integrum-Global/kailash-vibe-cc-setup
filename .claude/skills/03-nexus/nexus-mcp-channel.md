---
name: nexus-mcp-channel
description: "Nexus MCP channel: Model Context Protocol SSE/HTTP/stdio transports, McpServer, tool registration, resource exposure, handler-to-tool conversion, Claude Desktop integration. Use when asking 'MCP', 'Model Context Protocol', 'McpServer', 'MCP tool', 'MCP resource', 'MCP SSE', 'MCP stdio', 'MCP HTTP', 'Claude Desktop', 'AI agent integration', 'JSON-RPC', or 'tool registration'."
---

# Nexus MCP Channel

Model Context Protocol (MCP) server implementation with three transports: SSE, HTTP, and stdio. Exposes Nexus handlers and kailash-core workflows as MCP tools for AI agent integration.

**Feature flag**: All MCP modules require `feature = "mcp"` (enabled by default).

## Module Structure

```
kailash_nexus::mcp
  server           -- McpServer, McpToolInfo, McpResource, ToolHandler, register_tool, register_resource, register_workflow_as_tool, handle_message
  sse              -- build_mcp_router (POST /mcp/message + GET /mcp/sse), McpMessage, McpResponse, McpError, McpTool
  stdio            -- run_stdio_server, run_stdio_server_with_io (LSP-style Content-Length framing)
  http_transport   -- mcp_http_router (POST /mcp)
```

## 1. Standalone McpServer

The `McpServer` is transport-agnostic. It accepts raw JSON strings and returns raw JSON strings. Transports (SSE, stdio, HTTP) wrap it with I/O.

### Creating a Server

```rust
use kailash_nexus::mcp::server::McpServer;

let mut server = McpServer::new("my-app", "1.0.0");
assert_eq!(server.tool_count(), 0);
assert_eq!(server.resource_count(), 0);
```

### Registering Tools

```rust
use kailash_nexus::mcp::server::McpServer;

let mut server = McpServer::new("my-app", "1.0.0");

// Register a tool with an async handler
server.register_tool(
    "add",                             // tool name
    Some("Adds two numbers"),          // description (Option<&str>)
    serde_json::json!({                // JSON Schema for input
        "type": "object",
        "properties": {
            "a": {"type": "number"},
            "b": {"type": "number"}
        },
        "required": ["a", "b"]
    }),
    |args: serde_json::Value| async move {
        let a = args["a"].as_f64().unwrap_or(0.0);
        let b = args["b"].as_f64().unwrap_or(0.0);
        Ok(serde_json::json!({"sum": a + b}))
    },
);

assert_eq!(server.tool_count(), 1);
```

The handler signature is:

```rust
// F: Fn(serde_json::Value) -> Fut + Send + Sync + 'static
// Fut: Future<Output = Result<serde_json::Value, NexusError>> + Send + 'static
```

### Registering Resources

```rust
use kailash_nexus::mcp::server::McpServer;

let mut server = McpServer::new("my-app", "1.0.0");

server.register_resource(
    "docs://api/reference",            // URI
    "API Reference",                   // name
    Some("API documentation"),         // description
    Some("text/markdown"),             // MIME type
    "# API Reference\n\n...".to_string(),  // content
);

assert_eq!(server.resource_count(), 1);
```

### Registering Workflows as Tools

Automatically converts kailash-core workflows into MCP tools with generated JSON Schemas from source node input parameters.

```rust
use std::sync::Arc;
use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig, NodeRegistry};
use kailash_nexus::mcp::server::McpServer;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();
// ... build your workflow ...
let workflow = builder.build(&registry)?;

let mut server = McpServer::new("my-app", "1.0.0");
let runtime = Arc::new(Runtime::new(RuntimeConfig::default(), registry));

server.register_workflow_as_tool(
    "process_data",
    Some("Processes input data through the workflow"),
    &Arc::new(workflow),
    &runtime,
);
```

### Handling Messages Directly

```rust
use kailash_nexus::mcp::server::McpServer;

let mut server = McpServer::new("my-app", "1.0.0");
server.register_tool(
    "echo",
    Some("Echoes input"),
    serde_json::json!({"type": "object"}),
    |args| async move { Ok(args) },
);

// handle_message accepts a JSON string and returns a JSON string
let request = r#"{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}"#;
let response = server.handle_message(request).await;
// response is a JSON-RPC 2.0 response string
```

## 2. Protocol Methods

MCP uses JSON-RPC 2.0. The server handles these methods:

| Method           | Description                   | Response                                        |
| ---------------- | ----------------------------- | ----------------------------------------------- |
| `initialize`     | Server capabilities and info  | `protocolVersion`, `capabilities`, `serverInfo` |
| `tools/list`     | List all registered tools     | `{"tools": [...]}`                              |
| `tools/call`     | Execute a tool by name        | `{"content": [{"type":"text","text":"..."}]}`   |
| `resources/list` | List all registered resources | `{"resources": [...]}`                          |
| `resources/read` | Read a resource by URI        | `{"contents": [{"uri":"...","text":"..."}]}`    |

### Error Codes

| Code   | Meaning          |
| ------ | ---------------- |
| -32700 | Parse error      |
| -32601 | Method not found |
| -32602 | Invalid params   |
| -32603 | Internal error   |

## 3. SSE Transport

Creates axum routes for MCP over Server-Sent Events. Handlers are automatically converted to MCP tools with JSON Schema derived from `HandlerParam` definitions.

```rust
use std::sync::Arc;
use kailash_nexus::mcp::sse::build_mcp_router;
use kailash_nexus::handler::{ClosureHandler, HandlerDef, HandlerParam, HandlerParamType};
use kailash_value::ValueMap;
use kailash_value::Value;
use axum::Router;

// Define handlers with typed parameters
let params = vec![
    HandlerParam::new("name", HandlerParamType::String)
        .with_description("Name to greet"),
];
let handler = ClosureHandler::with_params(
    |inputs: ValueMap| async move {
        let name = inputs.get("name").and_then(|v| v.as_str()).unwrap_or("World");
        Ok(Value::from(format!("Hello, {name}!")))
    },
    params,
);
let handlers = vec![Arc::new(
    HandlerDef::new("greet", handler).with_description("Greets a user"),
)];

// Build MCP router
let mcp_router = build_mcp_router(&handlers);

// Merge into your app
let app = Router::new()
    .merge(mcp_router);
// Routes: POST /mcp/message, GET /mcp/sse
```

### Handler-to-Tool Schema Conversion

Each `HandlerDef` is converted to an MCP tool with a JSON Schema generated from its `HandlerParam` list:

```rust
// HandlerParamType maps to JSON Schema types:
// HandlerParamType::String  -> {"type": "string"}
// HandlerParamType::Integer -> {"type": "integer"}
// HandlerParamType::Float   -> {"type": "number"}
// HandlerParamType::Bool    -> {"type": "boolean"}
// HandlerParamType::Object  -> {"type": "object"}
// HandlerParamType::Array   -> {"type": "array"}
// HandlerParamType::Any     -> {"type": "string"}

// Parameters with `required: true` are added to the JSON Schema `required` array.
```

### SSE Endpoint Behavior

- `POST /mcp/message` -- Accepts a JSON-RPC request, dispatches to the handler, returns a JSON-RPC response
- `GET /mcp/sse` -- Returns connection status JSON (tool count, status)

## 4. HTTP Transport

Simple POST endpoint for HTTP-based MCP communication.

```rust
use std::sync::Arc;
use kailash_nexus::mcp::server::McpServer;
use kailash_nexus::mcp::http_transport::mcp_http_router;
use axum::Router;

let mut server = McpServer::new("my-app", "1.0.0");
server.register_tool(
    "echo",
    Some("Echoes input"),
    serde_json::json!({"type": "object"}),
    |args| async move { Ok(args) },
);

let router = mcp_http_router(Arc::new(server));
// Route: POST /mcp
// Content-Type: application/json
// Empty body -> 400 Bad Request
```

## 5. Stdio Transport

Reads JSON-RPC from stdin and writes responses to stdout using LSP-style Content-Length framing. Ideal for CLI tools that AI agents run as subprocesses.

```rust
use kailash_nexus::mcp::server::McpServer;
use kailash_nexus::mcp::stdio::run_stdio_server;

let mut server = McpServer::new("my-app", "1.0.0");
server.register_tool(
    "echo",
    Some("Echoes input"),
    serde_json::json!({"type": "object"}),
    |args| async move { Ok(args) },
);

// Blocks on stdin, writes to stdout
run_stdio_server(&server).await?;
// EOF on stdin triggers clean shutdown (returns Ok(()))
```

### Framing Protocol

```
Content-Length: 42\r\n
\r\n
{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}
```

Each message is prefixed with a `Content-Length` header specifying the body size in bytes, followed by `\r\n\r\n`, then the JSON body.

### Testing with Custom I/O

```rust
use kailash_nexus::mcp::stdio::run_stdio_server_with_io;
use tokio::io::BufReader;
use std::io::Cursor;

let server = McpServer::new("test", "0.1.0");

let request = r#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}"#;
let input = format!("Content-Length: {}\r\n\r\n{}", request.len(), request);

let reader = BufReader::new(Cursor::new(input.into_bytes()));
let mut output = Vec::new();

run_stdio_server_with_io(&server, reader, &mut output).await?;
// Parse output to verify response
```

## 6. Nexus Integration (Automatic MCP)

When using `Nexus`, the MCP channel is automatically configured from registered handlers.

```rust
use kailash_nexus::prelude::*;

let mut nexus = Nexus::new();
nexus.handler("greet", ClosureHandler::with_params(
    |inputs: ValueMap| async move {
        let name = inputs.get("name").and_then(|v| v.as_str()).unwrap_or("World");
        Ok(Value::from(format!("Hello, {name}!")))
    },
    vec![HandlerParam::new("name", HandlerParamType::String)],
));

// Nexus automatically exposes handlers as MCP tools at /mcp/message and /mcp/sse
// Default bind address: 0.0.0.0:3000 (from NexusConfig::default())
nexus.start().await?;
```

## 7. Claude Desktop Integration

### claude_desktop_config.json

For stdio transport (recommended for local development):

```json
{
  "mcpServers": {
    "my-app": {
      "command": "/path/to/my-app",
      "args": ["--mcp-stdio"]
    }
  }
}
```

For SSE transport (recommended for remote servers):

```json
{
  "mcpServers": {
    "my-app": {
      "url": "http://localhost:3000/mcp/sse"
    }
  }
}
```

## 8. MCP Types Reference

### McpToolInfo

```rust
pub struct McpToolInfo {
    pub name: String,
    pub description: Option<String>,
    pub input_schema: serde_json::Value,  // JSON Schema
}
```

### McpResource

```rust
pub struct McpResource {
    pub uri: String,           // e.g., "docs://api/reference"
    pub name: String,
    pub description: Option<String>,
    pub mime_type: Option<String>,  // serialized as "mimeType"
}
```

### McpMessage (SSE transport)

```rust
pub struct McpMessage {
    pub jsonrpc: String,                  // "2.0"
    pub id: Option<serde_json::Value>,
    pub method: String,
    pub params: serde_json::Value,
}
```

### McpResponse (SSE transport)

```rust
pub struct McpResponse {
    pub jsonrpc: String,                  // "2.0"
    pub id: Option<serde_json::Value>,    // echoed from request
    pub result: Option<serde_json::Value>,
    pub error: Option<McpError>,
}
```

<!-- Trigger Keywords: MCP, Model Context Protocol, McpServer, MCP tool, MCP resource, MCP SSE, MCP stdio, MCP HTTP, Claude Desktop, AI agent integration, JSON-RPC, tool registration, register_tool, register_resource, register_workflow_as_tool, handle_message, build_mcp_router, run_stdio_server, mcp_http_router, McpToolInfo, McpResource, McpMessage, McpResponse -->
