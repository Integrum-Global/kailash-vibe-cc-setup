---
name: create-mcp-server
description: "Scaffold an MCP server using kailash-nexus with tool registration, resource registration, and SSE transport. Use when asking 'create MCP server', 'scaffold MCP', or 'MCP server template'."
---

# Create MCP Server Skill

Scaffold an MCP (Model Context Protocol) server using kailash-nexus with tool registration, resource registration, and SSE transport.

## Usage

`/create-mcp-server <name>` -- Create a new MCP server with the given name

Examples:

- `/create-mcp-server data-tools`
- `/create-mcp-server code-assistant`

## Steps

1. Read existing MCP patterns from:
   - `crates/kailash-nexus/src/mcp/server.rs` -- McpServer, register_tool, register_resource, register_workflow_as_tool
   - `crates/kailash-nexus/src/mcp/sse.rs` -- SSE transport, `build_mcp_router`
   - `crates/kailash-nexus/src/mcp/stdio.rs` -- `run_stdio_server` (LSP-style Content-Length framing over stdin/stdout)
   - `crates/kailash-nexus/src/mcp/http_transport.rs` -- `mcp_http_router` (HTTP POST-based)
   - `crates/kailash-nexus/src/handler.rs` -- HandlerDef for auto-registered handlers

2. Create the MCP server binary or example at the appropriate location.

3. Implement the server with:
   - `McpServer::new(name, version)` initialization
   - Tool registration via `register_tool()` with JSON Schema input definitions
   - Resource registration via `register_resource()` for static content
   - Optionally register kailash-core workflows as tools via `register_workflow_as_tool()`
   - SSE transport setup for AI agent connectivity

4. Write tests covering:
   - Tool listing (`tools/list`)
   - Tool execution (`tools/call`)
   - Resource listing (`resources/list`)
   - Resource reading (`resources/read`)
   - Error handling for unknown tools/resources

## Template

### Standalone MCP Server

```rust
use std::sync::Arc;
use kailash_nexus::mcp::server::McpServer;
use kailash_nexus::error::NexusError;

fn create_{name_snake}_server() -> McpServer {
    let mut server = McpServer::new("{name}", "0.1.0");

    // Register a tool with JSON Schema input
    server.register_tool(
        "greet",
        Some("Greet a user by name"),
        serde_json::json!({
            "type": "object",
            "properties": {
                "name": {
                    "type": "string",
                    "description": "The name of the person to greet"
                },
                "style": {
                    "type": "string",
                    "description": "Greeting style: formal or casual",
                    "enum": ["formal", "casual"]
                }
            },
            "required": ["name"]
        }),
        |args: serde_json::Value| async move {
            let name = args.get("name")
                .and_then(|v| v.as_str())
                .unwrap_or("World");
            let style = args.get("style")
                .and_then(|v| v.as_str())
                .unwrap_or("casual");

            let greeting = match style {
                "formal" => format!("Good day, {name}. How may I assist you?"),
                _ => format!("Hey {name}!"),
            };

            Ok(serde_json::json!({
                "greeting": greeting
            }))
        },
    );

    // Register a resource (static content)
    server.register_resource(
        "config://server-info",
        "Server Information",
        Some("Information about this MCP server"),
        Some("application/json"),
        &serde_json::json!({
            "name": "{name}",
            "version": "0.1.0",
            "capabilities": ["tools", "resources"]
        }).to_string(),
    );

    server
}

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt::init();

    let server = create_{name_snake}_server();
    println!("MCP Server '{}' ready", "{name}");
    println!("Tools: {}", server.tool_count());
    println!("Resources: {}", server.resource_count());

    // Handle a JSON-RPC message directly (for testing)
    let init_request = serde_json::json!({
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": { "name": "test-client", "version": "1.0" }
        }
    });

    let response = server.handle_message(&init_request.to_string()).await;
    println!("Init response: {response}");
}
```

### MCP Server with Workflow as Tool

```rust
use std::sync::Arc;
use kailash_core::node::NodeRegistry;
use kailash_core::nodes::system::register_system_nodes;
use kailash_core::nodes::transform::register_transform_nodes;
use kailash_core::runtime::{Runtime, RuntimeConfig};
use kailash_core::WorkflowBuilder;
use kailash_nexus::mcp::server::McpServer;
use kailash_value::{Value, ValueMap};

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt::init();

    // Build a workflow
    let mut registry = NodeRegistry::new();
    register_system_nodes(&mut registry);
    register_transform_nodes(&mut registry);
    let registry = Arc::new(registry);

    let mut builder = WorkflowBuilder::new();
    builder
        .add_node("TextTransformNode", "upper", {
            let mut config = ValueMap::new();
            config.insert(Arc::from("operation"), Value::String(Arc::from("uppercase")));
            config
        })
        .add_node("LogNode", "log", ValueMap::new())
        .connect("upper", "result", "log", "data");

    let workflow = Arc::new(builder.build(&registry).expect("workflow should build"));
    let runtime = Arc::new(Runtime::new(RuntimeConfig::default(), registry));

    // Create MCP server and register the workflow as a tool
    let mut server = McpServer::new("workflow-server", "0.1.0");
    server.register_workflow_as_tool(
        "uppercase_text",
        Some("Convert text to uppercase"),
        &workflow,
        &runtime,
    );

    println!("MCP Server ready with {} tools", server.tool_count());

    // Test: call the tool
    let call_request = serde_json::json!({
        "jsonrpc": "2.0",
        "id": 2,
        "method": "tools/call",
        "params": {
            "name": "uppercase_text",
            "arguments": {
                "upper.text": "hello world"
            }
        }
    });

    let response = server.handle_message(&call_request.to_string()).await;
    println!("Tool call response: {response}");
}
```

### Test Template

```rust
#[cfg(test)]
mod tests {
    use super::*;

    fn test_server() -> McpServer {
        let mut server = McpServer::new("test-server", "0.1.0");
        server.register_tool(
            "echo",
            Some("Echoes input"),
            serde_json::json!({
                "type": "object",
                "properties": {
                    "message": { "type": "string" }
                },
                "required": ["message"]
            }),
            |args: serde_json::Value| async move {
                Ok(args)
            },
        );
        server.register_resource(
            "test://info",
            "Test Info",
            Some("Test resource"),
            Some("text/plain"),
            "Hello from test resource",
        );
        server
    }

    #[tokio::test]
    async fn test_initialize() {
        let server = test_server();
        let request = serde_json::json!({
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": { "name": "test", "version": "1.0" }
            }
        });
        let response = server.handle_message(&request.to_string()).await;
        let parsed: serde_json::Value = serde_json::from_str(&response).expect("valid JSON");
        assert!(parsed.get("result").is_some());
    }

    #[tokio::test]
    async fn test_tools_list() {
        let server = test_server();
        let request = serde_json::json!({
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/list",
            "params": {}
        });
        let response = server.handle_message(&request.to_string()).await;
        let parsed: serde_json::Value = serde_json::from_str(&response).expect("valid JSON");
        let tools = parsed["result"]["tools"].as_array().expect("tools array");
        assert_eq!(tools.len(), 1);
        assert_eq!(tools[0]["name"], "echo");
    }

    #[tokio::test]
    async fn test_tools_call() {
        let server = test_server();
        let request = serde_json::json!({
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": {
                "name": "echo",
                "arguments": { "message": "hello" }
            }
        });
        let response = server.handle_message(&request.to_string()).await;
        let parsed: serde_json::Value = serde_json::from_str(&response).expect("valid JSON");
        assert!(parsed.get("result").is_some());
    }

    #[tokio::test]
    async fn test_resources_list() {
        let server = test_server();
        let request = serde_json::json!({
            "jsonrpc": "2.0",
            "id": 4,
            "method": "resources/list",
            "params": {}
        });
        let response = server.handle_message(&request.to_string()).await;
        let parsed: serde_json::Value = serde_json::from_str(&response).expect("valid JSON");
        let resources = parsed["result"]["resources"].as_array().expect("resources array");
        assert_eq!(resources.len(), 1);
        assert_eq!(resources[0]["uri"], "test://info");
    }

    #[tokio::test]
    async fn test_unknown_tool_returns_error() {
        let server = test_server();
        let request = serde_json::json!({
            "jsonrpc": "2.0",
            "id": 5,
            "method": "tools/call",
            "params": {
                "name": "nonexistent_tool",
                "arguments": {}
            }
        });
        let response = server.handle_message(&request.to_string()).await;
        let parsed: serde_json::Value = serde_json::from_str(&response).expect("valid JSON");
        assert!(parsed.get("error").is_some());
    }
}
```

### MCP Server with Stdio Transport (CLI-based)

Uses LSP-style Content-Length framing over stdin/stdout. Ideal for CLI tools that AI agents run as subprocesses (e.g., Claude Desktop).

```rust
use kailash_nexus::mcp::server::McpServer;
use kailash_nexus::mcp::stdio::run_stdio_server;

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();

    let mut server = McpServer::new("{name}", "0.1.0");

    server.register_tool(
        "echo",
        Some("Echoes input back"),
        serde_json::json!({
            "type": "object",
            "properties": {
                "message": { "type": "string" }
            },
            "required": ["message"]
        }),
        |args: serde_json::Value| async move {
            Ok(args)
        },
    );

    // Blocks on stdin, writes to stdout. EOF on stdin triggers clean shutdown.
    run_stdio_server(&server).await.expect("stdio server should run");
}
```

### MCP Server with HTTP Transport

Uses a simple POST endpoint for stateless HTTP-based MCP communication.

```rust
use std::sync::Arc;
use kailash_nexus::mcp::server::McpServer;
use kailash_nexus::mcp::http_transport::mcp_http_router;

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt::init();

    let mut server = McpServer::new("{name}", "0.1.0");

    server.register_tool(
        "echo",
        Some("Echoes input back"),
        serde_json::json!({
            "type": "object",
            "properties": {
                "message": { "type": "string" }
            },
            "required": ["message"]
        }),
        |args: serde_json::Value| async move {
            Ok(args)
        },
    );

    // Build HTTP POST endpoint at /mcp
    let router = mcp_http_router(Arc::new(server));

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3001").await.unwrap();
    println!("MCP HTTP transport listening on http://0.0.0.0:3001/mcp");
    axum::serve(listener, router).await.unwrap();
}
```

### Choosing a Transport

| Transport | Use Case                                    | Method                                    |
| --------- | ------------------------------------------- | ----------------------------------------- |
| SSE       | AI agent integration (long-lived streaming) | `build_mcp_router()` in axum              |
| Stdio     | CLI tools (Claude Desktop, pipes)           | `run_stdio_server(&server).await`         |
| HTTP      | Web clients (stateless POST requests)       | `mcp_http_router(Arc::new(server))` axum  |

## Verify

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo test -p kailash-nexus && cargo clippy -p kailash-nexus -- -D warnings
```
