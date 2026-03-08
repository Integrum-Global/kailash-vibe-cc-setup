---
name: mcp-transports
description: "MCP transport options: SSE, HTTP, stdio. Use when asking 'MCP transport', 'SSE transport', 'stdio transport', 'HTTP transport', 'Claude Desktop MCP', 'Content-Length framing'."
---

# MCP Transports

MCP uses JSON-RPC 2.0 as its wire protocol. The transport layer handles how messages are sent and received. Kailash provides three transport implementations for both server and client sides.

## Transport Summary

| Transport | Server (nexus)       | Client (kaizen)  | Best For                                    |
| --------- | -------------------- | ---------------- | ------------------------------------------- |
| **HTTP**  | `mcp_http_router()`  | `HttpTransport`  | Web services, remote servers                |
| **SSE**   | `build_mcp_router()` | --               | Browser/web clients, Nexus auto-integration |
| **stdio** | `run_stdio_server()` | `StdioTransport` | Local tools, Claude Desktop, editor plugins |

## HTTP Transport

The simplest transport: each request is a single HTTP POST with `Content-Type: application/json`, and the response body is the JSON-RPC response.

### Server Side (kailash-nexus)

```rust
use std::sync::Arc;
use kailash_nexus::mcp::server::McpServer;
use kailash_nexus::mcp::http_transport::mcp_http_router;

let mut server = McpServer::new("my-server", "1.0.0");
server.register_tool(
    "echo",
    Some("Echoes input"),
    serde_json::json!({"type": "object", "properties": {}}),
    |args: serde_json::Value| async move { Ok(args) },
);

// Creates an axum Router with POST /mcp
let router = mcp_http_router(Arc::new(server));

// Mount into an axum app or serve directly
let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await?;
axum::serve(listener, router).await?;
```

Routes created:

- `POST /mcp` -- accepts JSON-RPC 2.0 request body, returns JSON-RPC response

### Client Side (kailash-kaizen)

```rust
use kailash_kaizen::mcp::http_transport::HttpTransport;
use kailash_kaizen::mcp::transport::McpTransport;

// Default reqwest client
let transport = HttpTransport::new("http://localhost:3000/mcp");

// Custom client with timeout
let client = reqwest::Client::builder()
    .timeout(std::time::Duration::from_secs(30))
    .build()?;
let transport = HttpTransport::with_client("http://localhost:3000/mcp", client);

// Check the configured URL
assert_eq!(transport.endpoint_url(), "http://localhost:3000/mcp");
```

Error mapping:

- Connection refused -> `McpError::ConnectionError`
- HTTP timeout -> `McpError::Timeout`
- HTTP 4xx/5xx -> `McpError::ProtocolError` with status code

## SSE Transport

SSE (Server-Sent Events) transport provides the MCP endpoint routes that Nexus auto-integrates when `enable_mcp` is `true`.

### Server Side (kailash-nexus)

```rust
use std::sync::Arc;
use kailash_nexus::mcp::sse::build_mcp_router;
use kailash_nexus::handler::{ClosureHandler, HandlerDef, HandlerParam, HandlerParamType};
use kailash_value::{Value, ValueMap};

// Build handlers
let params = vec![
    HandlerParam::new("name", HandlerParamType::String)
        .with_description("Name to greet"),
];
let handler = ClosureHandler::with_params(
    |inputs: ValueMap| async move {
        let name = inputs
            .get("name")
            .and_then(|v| v.as_str())
            .unwrap_or("World");
        Ok(Value::from(format!("Hello, {name}!")))
    },
    params,
);
let handlers = vec![Arc::new(
    HandlerDef::new("greet", handler).with_description("Greets a user"),
)];

// Build MCP router from Nexus handlers
let mcp_router = build_mcp_router(&handlers);
```

Routes created:

- `POST /mcp/message` -- handles JSON-RPC requests (tools/list, tools/call, initialize)
- `GET /mcp/sse` -- SSE endpoint (returns connection status and tool count)

The SSE transport automatically converts `HandlerDef` instances to MCP tools:

- Handler name becomes tool name
- Handler description becomes tool description
- `HandlerParam` types are mapped to JSON Schema types via `param_type.json_schema_type()`
- Required/optional params are reflected in the `required` array

### Nexus Auto-Integration

The simplest way to use SSE -- Nexus handles everything:

```rust
use kailash_nexus::Nexus;
use kailash_nexus::config::NexusConfig;

let config = NexusConfig {
    enable_mcp: true,  // default is true
    ..NexusConfig::default()
};

let nexus = Nexus::new().with_config(config);
// All handlers registered via nexus.handler() are now MCP tools
nexus.start().await?;
// Serves: POST /mcp/message, GET /mcp/sse (plus API routes)
```

## Stdio Transport

Stdio transport uses LSP-style Content-Length framing over stdin/stdout. This is ideal for local tools and is the transport used by Claude Desktop and editor integrations.

### Framing Protocol

Each message is framed as:

```text
Content-Length: <N>\r\n
\r\n
<JSON body of exactly N bytes>
```

This is identical to the Language Server Protocol (LSP) framing format.

### Server Side (kailash-nexus)

```rust
use kailash_nexus::mcp::server::McpServer;
use kailash_nexus::mcp::stdio::run_stdio_server;

let mut server = McpServer::new("my-cli-tool", "1.0.0");
server.register_tool(
    "search",
    Some("Searches files"),
    serde_json::json!({
        "type": "object",
        "properties": {
            "query": { "type": "string", "description": "Search query" },
            "path": { "type": "string", "description": "Directory to search" }
        },
        "required": ["query"]
    }),
    |args: serde_json::Value| async move {
        let query = args["query"].as_str().unwrap_or("");
        Ok(serde_json::json!({ "matches": [], "query": query }))
    },
);

// Reads from stdin, writes to stdout until EOF
run_stdio_server(&server).await?;
```

For testing, use `run_stdio_server_with_io` with custom reader/writer:

```rust
use kailash_nexus::mcp::stdio::run_stdio_server_with_io;
use std::io::Cursor;
use tokio::io::BufReader;

let server = McpServer::new("test", "0.1.0");

// Build framed input
let request = r#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}"#;
let input = format!("Content-Length: {}\r\n\r\n{}", request.len(), request);

let reader = BufReader::new(Cursor::new(input.into_bytes()));
let mut output = Vec::new();

run_stdio_server_with_io(&server, reader, &mut output).await?;
// output contains the framed response
```

### Client Side (kailash-kaizen)

```rust
use kailash_kaizen::mcp::stdio::StdioTransport;
use kailash_kaizen::mcp::client::McpClient;

// Spawn a subprocess and connect via stdin/stdout
let transport = StdioTransport::spawn("my-mcp-server", &["--mode", "mcp"]).await?;
let client = McpClient::new(transport);

let info = client.initialize().await?;
println!("Connected to {} via stdio", info.name);
```

You can also wrap an already-spawned child process:

```rust
use kailash_kaizen::mcp::stdio::StdioTransport;
use tokio::process::Command;

let child = Command::new("my-mcp-server")
    .stdin(std::process::Stdio::piped())
    .stdout(std::process::Stdio::piped())
    .stderr(std::process::Stdio::null())
    .spawn()?;

let transport = StdioTransport::from_child(child)?;
```

## Claude Desktop Integration

To make a Kailash MCP server available in Claude Desktop, build a binary that runs the stdio server and configure it in `claude_desktop_config.json`.

### Binary (main.rs)

```rust
use kailash_nexus::mcp::server::McpServer;
use kailash_nexus::mcp::stdio::run_stdio_server;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut server = McpServer::new("my-kailash-tools", "1.0.0");

    server.register_tool(
        "analyze",
        Some("Analyzes data using a Kailash workflow"),
        serde_json::json!({
            "type": "object",
            "properties": {
                "data": { "type": "string", "description": "Data to analyze" }
            },
            "required": ["data"]
        }),
        |args: serde_json::Value| async move {
            let data = args["data"].as_str().unwrap_or("");
            // Run analysis workflow...
            Ok(serde_json::json!({ "analysis": format!("Processed: {data}") }))
        },
    );

    run_stdio_server(&server).await?;
    Ok(())
}
```

### Claude Desktop Config

```json
{
  "mcpServers": {
    "kailash-tools": {
      "command": "/path/to/my-kailash-tools",
      "args": []
    }
  }
}
```

## McpTransport Trait

All client transports implement this trait:

```rust
pub trait McpTransport: Send + Sync + 'static {
    fn send(
        &self,
        request: &str,
    ) -> Pin<Box<dyn Future<Output = Result<String, McpError>> + Send + '_>>;
}
```

To create a custom transport, implement `McpTransport` for your type.

## Source Files

- `crates/kailash-nexus/src/mcp/sse.rs` -- SSE transport (server)
- `crates/kailash-nexus/src/mcp/stdio.rs` -- stdio transport (server)
- `crates/kailash-nexus/src/mcp/http_transport.rs` -- HTTP transport (server)
- `crates/kailash-kaizen/src/mcp/transport.rs` -- `McpTransport` trait, `InMemoryTransport`
- `crates/kailash-kaizen/src/mcp/stdio.rs` -- `StdioTransport` (client)
- `crates/kailash-kaizen/src/mcp/http_transport.rs` -- `HttpTransport` (client)

<!-- Trigger Keywords: MCP transport, SSE transport, stdio transport, HTTP transport, Content-Length framing, Claude Desktop, MCP config, McpTransport trait, custom transport -->
