---
name: mcp-tools
description: "MCP tool and resource patterns. Use when asking 'MCP tool schema', 'tool handler', 'workflow as tool', 'tool testing', 'MCP error handling', 'JSON Schema MCP'."
---

# MCP Tool Patterns

Patterns for defining, registering, and testing MCP tools in the Kailash SDK. Tools are the primary way AI agents interact with your application through MCP.

## Tool Schema Definition

MCP tools use JSON Schema to describe their input parameters. The schema is passed to `register_tool` and advertised to clients via `tools/list`.

### Basic Schema

```rust
use kailash_nexus::mcp::server::McpServer;

let mut server = McpServer::new("tools-server", "1.0.0");

server.register_tool(
    "search",
    Some("Searches documents by query"),
    serde_json::json!({
        "type": "object",
        "properties": {
            "query": {
                "type": "string",
                "description": "The search query"
            },
            "limit": {
                "type": "integer",
                "description": "Maximum number of results (default: 10)"
            },
            "include_metadata": {
                "type": "boolean",
                "description": "Whether to include document metadata"
            }
        },
        "required": ["query"]
    }),
    |args: serde_json::Value| async move {
        let query = args["query"].as_str().unwrap_or("");
        let limit = args["limit"].as_i64().unwrap_or(10);
        let include_meta = args["include_metadata"].as_bool().unwrap_or(false);

        Ok(serde_json::json!({
            "results": [],
            "query": query,
            "limit": limit,
            "metadata_included": include_meta
        }))
    },
);
```

### Schema with Enums

```rust
server.register_tool(
    "format",
    Some("Formats text in a specified style"),
    serde_json::json!({
        "type": "object",
        "properties": {
            "text": {
                "type": "string",
                "description": "Text to format"
            },
            "style": {
                "type": "string",
                "enum": ["uppercase", "lowercase", "title_case", "snake_case"],
                "description": "Formatting style to apply"
            }
        },
        "required": ["text", "style"]
    }),
    |args: serde_json::Value| async move {
        let text = args["text"].as_str().unwrap_or("");
        let style = args["style"].as_str().unwrap_or("uppercase");
        let result = match style {
            "uppercase" => text.to_uppercase(),
            "lowercase" => text.to_lowercase(),
            _ => text.to_string(),
        };
        Ok(serde_json::json!({ "formatted": result }))
    },
);
```

### Schema with Nested Objects

```rust
server.register_tool(
    "create_user",
    Some("Creates a new user account"),
    serde_json::json!({
        "type": "object",
        "properties": {
            "name": { "type": "string", "description": "Full name" },
            "email": { "type": "string", "description": "Email address" },
            "preferences": {
                "type": "object",
                "properties": {
                    "theme": { "type": "string", "enum": ["light", "dark"] },
                    "notifications": { "type": "boolean" }
                },
                "description": "User preferences"
            }
        },
        "required": ["name", "email"]
    }),
    |args: serde_json::Value| async move {
        let name = args["name"].as_str().unwrap_or("");
        let email = args["email"].as_str().unwrap_or("");
        Ok(serde_json::json!({
            "id": "usr_123",
            "name": name,
            "email": email,
            "created": true
        }))
    },
);
```

## Tool Handler Implementation

### Handler Signature

Tool handlers are async closures with the signature:

```rust
Fn(serde_json::Value) -> Future<Output = Result<serde_json::Value, NexusError>>
```

The `serde_json::Value` argument contains the `arguments` field from the `tools/call` request.

### Error Handling in Handlers

Return `NexusError` from handlers to signal failures. The server translates these to JSON-RPC error responses with code `-32603` (internal error).

```rust
use kailash_nexus::error::NexusError;

server.register_tool(
    "divide",
    Some("Divides two numbers"),
    serde_json::json!({
        "type": "object",
        "properties": {
            "numerator": { "type": "number" },
            "denominator": { "type": "number" }
        },
        "required": ["numerator", "denominator"]
    }),
    |args: serde_json::Value| async move {
        let num = args["numerator"].as_f64()
            .ok_or_else(|| NexusError::InvalidInput(
                "numerator must be a number".to_string()
            ))?;
        let den = args["denominator"].as_f64()
            .ok_or_else(|| NexusError::InvalidInput(
                "denominator must be a number".to_string()
            ))?;

        if den == 0.0 {
            return Err(NexusError::InvalidInput(
                "division by zero".to_string()
            ));
        }

        Ok(serde_json::json!({ "result": num / den }))
    },
);
```

### Handler with Shared State

Use `Arc` to share state across tool handlers:

```rust
use std::sync::Arc;
use std::collections::HashMap;
use tokio::sync::RwLock;
use kailash_nexus::mcp::server::McpServer;

let db: Arc<RwLock<HashMap<String, String>>> = Arc::new(RwLock::new(HashMap::new()));

let mut server = McpServer::new("stateful-server", "1.0.0");

// Write tool
let db_write = db.clone();
server.register_tool(
    "set_value",
    Some("Stores a key-value pair"),
    serde_json::json!({
        "type": "object",
        "properties": {
            "key": { "type": "string" },
            "value": { "type": "string" }
        },
        "required": ["key", "value"]
    }),
    move |args: serde_json::Value| {
        let db = db_write.clone();
        async move {
            let key = args["key"].as_str().unwrap_or("").to_string();
            let value = args["value"].as_str().unwrap_or("").to_string();
            db.write().await.insert(key.clone(), value);
            Ok(serde_json::json!({ "stored": key }))
        }
    },
);

// Read tool
let db_read = db.clone();
server.register_tool(
    "get_value",
    Some("Retrieves a value by key"),
    serde_json::json!({
        "type": "object",
        "properties": {
            "key": { "type": "string" }
        },
        "required": ["key"]
    }),
    move |args: serde_json::Value| {
        let db = db_read.clone();
        async move {
            let key = args["key"].as_str().unwrap_or("");
            let value = db.read().await.get(key).cloned();
            Ok(serde_json::json!({ "key": key, "value": value }))
        }
    },
);
```

## Workflow-as-Tool Pattern

Wrap a kailash-core `Workflow` as an MCP tool. The JSON Schema is auto-generated from the workflow's source nodes' input parameters.

```rust
use std::sync::Arc;
use kailash_nexus::mcp::server::McpServer;
use kailash_core::workflow::WorkflowBuilder;
use kailash_core::node::NodeRegistry;
use kailash_core::nodes::transform::register_transform_nodes;
use kailash_core::runtime::{Runtime, RuntimeConfig};
use kailash_value::{Value, ValueMap};

// Build a workflow
let mut node_registry = NodeRegistry::new();
register_transform_nodes(&mut node_registry);
let registry = Arc::new(node_registry);

let mut builder = WorkflowBuilder::new();
builder
    .add_node("TextTransformNode", "upper", {
        let mut config = ValueMap::new();
        config.insert(
            Arc::from("operation"),
            Value::String(Arc::from("uppercase")),
        );
        config
    });

let workflow = Arc::new(builder.build(&registry)?);
let runtime = Arc::new(Runtime::new(RuntimeConfig::default(), registry));

// Register the workflow as an MCP tool
let mut server = McpServer::new("workflow-server", "1.0.0");
server.register_workflow_as_tool(
    "uppercase",
    Some("Converts text to uppercase via workflow"),
    &workflow,
    &runtime,
);
```

When the tool is called:

1. Arguments are converted from JSON to `ValueMap`
2. The workflow executes via `runtime.execute(&workflow, inputs)`
3. Results are returned as `{ "run_id": "...", "results": { "node_id": { ... } } }`

## MCP Response Format

Tool call results use the MCP content format:

```json
{
  "content": [
    {
      "type": "text",
      "text": "{\"sum\": 42}"
    }
  ]
}
```

The handler's `Ok(serde_json::Value)` return value is serialized to a string and wrapped in a text content block.

## Testing Tools

### Unit Testing with Direct Dispatch

```rust
use kailash_nexus::mcp::server::McpServer;

#[tokio::test]
async fn test_add_tool() {
    let mut server = McpServer::new("test", "0.1.0");
    server.register_tool(
        "add",
        Some("Adds numbers"),
        serde_json::json!({
            "type": "object",
            "properties": {
                "a": { "type": "number" },
                "b": { "type": "number" }
            },
            "required": ["a", "b"]
        }),
        |args: serde_json::Value| async move {
            let a = args["a"].as_f64().unwrap_or(0.0);
            let b = args["b"].as_f64().unwrap_or(0.0);
            Ok(serde_json::json!({ "sum": a + b }))
        },
    );

    // Dispatch a tools/call message directly
    let response = server.handle_message(
        &serde_json::json!({
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {
                "name": "add",
                "arguments": { "a": 10, "b": 32 }
            }
        }).to_string()
    ).await;

    let parsed: serde_json::Value = serde_json::from_str(&response)?;
    assert!(parsed["result"]["content"][0]["text"]
        .as_str()
        .is_some_and(|t| t.contains("42")));
}
```

### Testing with HTTP Router (axum test utilities)

```rust
use std::sync::Arc;
use axum::{body::Body, http::Request};
use tower::ServiceExt;
use kailash_nexus::mcp::http_transport::mcp_http_router;
use kailash_nexus::mcp::server::McpServer;

#[tokio::test]
async fn test_tool_via_http() {
    let mut server = McpServer::new("test", "0.1.0");
    server.register_tool(
        "echo",
        Some("Echoes input"),
        serde_json::json!({"type": "object", "properties": {}}),
        |args: serde_json::Value| async move { Ok(args) },
    );

    let router = mcp_http_router(Arc::new(server));

    let request = Request::builder()
        .uri("/mcp")
        .method("POST")
        .header("content-type", "application/json")
        .body(Body::from(serde_json::json!({
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/list",
            "params": {}
        }).to_string()))
        .expect("should build request");

    let response = router.oneshot(request).await.expect("should respond");
    assert_eq!(response.status(), 200);
}
```

### Testing with Stdio (in-memory buffers)

```rust
use kailash_nexus::mcp::server::McpServer;
use kailash_nexus::mcp::stdio::run_stdio_server_with_io;
use std::io::Cursor;
use tokio::io::BufReader;

#[tokio::test]
async fn test_tool_via_stdio() {
    let mut server = McpServer::new("test", "0.1.0");
    server.register_tool(
        "ping",
        Some("Returns pong"),
        serde_json::json!({"type": "object", "properties": {}}),
        |_args: serde_json::Value| async move {
            Ok(serde_json::json!({ "message": "pong" }))
        },
    );

    let request = r#"{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}"#;
    let input = format!("Content-Length: {}\r\n\r\n{}", request.len(), request);

    let reader = BufReader::new(Cursor::new(input.into_bytes()));
    let mut output = Vec::new();

    let result = run_stdio_server_with_io(&server, reader, &mut output).await;
    assert!(result.is_ok());

    let output_str = String::from_utf8(output).unwrap_or_default();
    assert!(output_str.contains("ping"));
}
```

### Testing Client-Side Tool Discovery

```rust
use kailash_kaizen::mcp::client::McpClient;
use kailash_kaizen::mcp::transport::InMemoryTransport;
use kailash_kaizen::agent::tools::ToolRegistry;

#[tokio::test]
async fn test_discover_tools() {
    let transport = InMemoryTransport::new();

    transport.push_response(&serde_json::json!({
        "jsonrpc": "2.0",
        "id": 1,
        "result": {
            "tools": [{
                "name": "calculator",
                "description": "Does math",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "expression": {
                            "type": "string",
                            "description": "Math expression"
                        }
                    },
                    "required": ["expression"]
                }
            }]
        }
    }).to_string());

    let client = McpClient::new(transport);
    let mut registry = ToolRegistry::new();
    let count = client.discover_and_register(&mut registry).await?;

    assert_eq!(count, 1);

    let tool = registry.get("calculator").expect("should exist");
    assert_eq!(tool.name.as_ref(), "calculator");
    assert_eq!(tool.parameters.len(), 1);
    assert_eq!(tool.parameters[0].name.as_ref(), "expression");
    assert!(tool.parameters[0].required);
}
```

## JSON-RPC Error Codes

Standard JSON-RPC 2.0 error codes used by the MCP server:

| Code     | Constant           | Meaning                       |
| -------- | ------------------ | ----------------------------- |
| `-32700` | `PARSE_ERROR`      | Invalid JSON                  |
| `-32601` | `METHOD_NOT_FOUND` | Unknown method name           |
| `-32602` | `INVALID_PARAMS`   | Missing or invalid parameters |
| `-32603` | `INTERNAL_ERROR`   | Handler execution failure     |

## Source Files

- `crates/kailash-nexus/src/mcp/server.rs` -- `McpServer`, `ToolHandler`, `register_tool`, `register_workflow_as_tool`
- `crates/kailash-nexus/src/mcp/sse.rs` -- `handler_to_mcp_tool` (auto-converts `HandlerDef` to MCP tool)
- `crates/kailash-kaizen/src/mcp/client.rs` -- `mcp_tool_to_tool_def`, `extract_params_from_schema`
- `crates/kailash-kaizen/src/agent/tools.rs` -- `ToolRegistry`, `ToolDef`, `ToolParam`, `ToolParamType`

<!-- Trigger Keywords: MCP tool, tool schema, JSON Schema, tool handler, workflow as tool, tool testing, tool registration, MCP error handling, JSON-RPC error, ToolHandler trait -->
