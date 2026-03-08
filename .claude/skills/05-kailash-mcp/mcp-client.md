---
name: mcp-client
description: "MCP client patterns with kailash-kaizen. Use when asking 'MCP client', 'connect to MCP server', 'discover tools', 'call MCP tool', 'McpClient', 'agent MCP integration'."
---

# MCP Client (kailash-kaizen)

The MCP client lives in `crates/kailash-kaizen/src/mcp/client.rs`. `McpClient<T>` connects to an MCP server via a pluggable `McpTransport` and provides typed methods for the core MCP protocol operations.

## Architecture

```
McpClient<T: McpTransport>
  |
  +-- initialize()             -> ServerInfo
  +-- list_tools()             -> Vec<McpToolInfo>
  +-- call_tool(name, args)    -> serde_json::Value
  +-- list_resources()         -> Vec<McpResourceInfo>
  +-- read_resource(uri)       -> String
  +-- discover_and_register()  -> usize (registers into ToolRegistry)
  |
  Transports (T):
    +-- InMemoryTransport     -- testing
    +-- StdioTransport        -- subprocess via stdin/stdout
    +-- HttpTransport         -- HTTP POST to endpoint
```

## Creating a Client

`McpClient` is generic over `McpTransport`. Choose the transport based on how you connect to the server.

```rust
use kailash_kaizen::mcp::client::McpClient;
use kailash_kaizen::mcp::http_transport::HttpTransport;

// HTTP transport -- connects to a running MCP server
let transport = HttpTransport::new("http://localhost:3000/mcp");
let client = McpClient::new(transport);
```

```rust
use kailash_kaizen::mcp::client::McpClient;
use kailash_kaizen::mcp::stdio::StdioTransport;

// Stdio transport -- spawns a subprocess
let transport = StdioTransport::spawn("my-mcp-server", &["--mode", "mcp"]).await?;
let client = McpClient::new(transport);
```

## Initialize Handshake

The first operation must always be `initialize`. It performs the MCP handshake and returns `ServerInfo` with server name, version, and capabilities.

```rust
use kailash_kaizen::mcp::client::McpClient;
use kailash_kaizen::mcp::http_transport::HttpTransport;

let transport = HttpTransport::new("http://localhost:3000/mcp");
let client = McpClient::new(transport);

let server_info = client.initialize().await?;
println!("Server: {} v{}", server_info.name, server_info.version);
println!("Supports tools: {}", server_info.capabilities.tools);
println!("Supports resources: {}", server_info.capabilities.resources);
```

The client handles both MCP response layouts:

- Nested (standard): `{ "protocolVersion": ..., "serverInfo": { "name": ..., "version": ... }, "capabilities": ... }`
- Flat (simple): `{ "name": ..., "version": ..., "capabilities": ... }`

## Listing Tools

```rust
let tools = client.list_tools().await?;

for tool in &tools {
    println!("Tool: {} - {}", tool.name, tool.description);
    println!("  Schema: {}", tool.input_schema);
}
```

Each `McpToolInfo` contains:

- `name: String` -- tool identifier
- `description: String` -- human-readable description
- `input_schema: serde_json::Value` -- JSON Schema for input parameters

## Calling a Tool

```rust
let result = client.call_tool(
    "add",
    serde_json::json!({ "a": 10, "b": 32 }),
).await?;

println!("Result: {result}");
// Result contains MCP content format:
// { "content": [{ "type": "text", "text": "42" }] }
```

If the server reports the tool call as an error (`isError: true`), the client returns `McpError::ToolExecutionError` with the error text.

## Listing and Reading Resources

```rust
let resources = client.list_resources().await?;

for resource in &resources {
    println!("{}: {} ({})", resource.uri, resource.name, resource.description);
    if let Some(ref mime) = resource.mime_type {
        println!("  MIME: {mime}");
    }
}

// Read a specific resource
let content = client.read_resource("file:///config.json").await?;
println!("Content: {content}");
```

## Auto-Discover and Register Tools

`discover_and_register` lists all tools from the MCP server and registers them in a `ToolRegistry` for use by kaizen agents.

```rust
use kailash_kaizen::mcp::client::McpClient;
use kailash_kaizen::mcp::http_transport::HttpTransport;
use kailash_kaizen::agent::tools::ToolRegistry;

let transport = HttpTransport::new("http://localhost:3000/mcp");
let client = McpClient::new(transport);

let _server_info = client.initialize().await?;

let mut registry = ToolRegistry::new();
let count = client.discover_and_register(&mut registry).await?;
println!("Registered {count} MCP tools");

// Tools are registered by their MCP name
if let Some(tool) = registry.get("add") {
    println!("Tool: {} -- {}", tool.name, tool.description);
    for param in &tool.parameters {
        println!("  Param: {} ({:?}, required: {})",
            param.name, param.param_type, param.required);
    }
}
```

JSON Schema types are mapped to `ToolParamType`:

| JSON Schema `type` | `ToolParamType`    |
| ------------------ | ------------------ |
| `"string"`         | `String`           |
| `"integer"`        | `Integer`          |
| `"number"`         | `Float`            |
| `"boolean"`        | `Bool`             |
| `"object"`         | `Object`           |
| `"array"`          | `Array`            |
| unknown/missing    | `String` (default) |

## Error Handling

All client operations return `Result<T, McpError>`. Error variants:

| Variant                        | Cause                                                  |
| ------------------------------ | ------------------------------------------------------ |
| `McpError::ConnectionError`    | Transport failure (pipe broken, server unreachable)    |
| `McpError::ProtocolError`      | Invalid or unexpected JSON-RPC response                |
| `McpError::ToolNotFound`       | Requested tool does not exist on server                |
| `McpError::Timeout`            | Operation exceeded time limit                          |
| `McpError::ToolExecutionError` | Server reported the tool call failed (`isError: true`) |
| `McpError::SerializationError` | JSON serialization/deserialization failure             |

## Testing with InMemoryTransport

For unit tests, use `InMemoryTransport` to pre-program responses without a real server.

```rust
use kailash_kaizen::mcp::client::McpClient;
use kailash_kaizen::mcp::transport::InMemoryTransport;

let transport = InMemoryTransport::new();

// Queue responses in the order they will be consumed
transport.push_response(&serde_json::json!({
    "jsonrpc": "2.0",
    "id": 1,
    "result": {
        "protocolVersion": "2024-11-05",
        "serverInfo": { "name": "test", "version": "0.1.0" },
        "capabilities": { "tools": {} }
    }
}).to_string());

transport.push_response(&serde_json::json!({
    "jsonrpc": "2.0",
    "id": 2,
    "result": {
        "tools": [{
            "name": "echo",
            "description": "Echoes input",
            "inputSchema": { "type": "object", "properties": {} }
        }]
    }
}).to_string());

let client = McpClient::new(transport);
let info = client.initialize().await?;
assert_eq!(info.name, "test");

let tools = client.list_tools().await?;
assert_eq!(tools.len(), 1);
assert_eq!(tools[0].name, "echo");
```

You can also push errors to simulate failures:

```rust
use kailash_kaizen::mcp::{McpError, transport::InMemoryTransport};

let transport = InMemoryTransport::new();
transport.push_error(McpError::Timeout(5000));

// The next call to client.initialize() will return Err(Timeout(5000))
```

## Key Types (client module)

| Type                 | Description                                          |
| -------------------- | ---------------------------------------------------- |
| `McpClient<T>`       | Generic MCP client over a transport                  |
| `ServerInfo`         | Server name, version, capabilities from `initialize` |
| `ServerCapabilities` | Booleans: `tools`, `resources`, `prompts`            |
| `McpToolInfo`        | Tool name, description, `input_schema`               |
| `McpResourceInfo`    | Resource URI, name, description, MIME type           |
| `McpError`           | Error enum for all client operations                 |

## Source Files

- `crates/kailash-kaizen/src/mcp/mod.rs` -- module root, error type, protocol types
- `crates/kailash-kaizen/src/mcp/client.rs` -- `McpClient`, `discover_and_register`
- `crates/kailash-kaizen/src/mcp/transport.rs` -- `McpTransport` trait, `InMemoryTransport`
- `crates/kailash-kaizen/src/mcp/stdio.rs` -- `StdioTransport`
- `crates/kailash-kaizen/src/mcp/http_transport.rs` -- `HttpTransport`
- `crates/kailash-kaizen/examples/mcp_client.rs` -- full example

<!-- Trigger Keywords: MCP client, McpClient, connect MCP, discover tools, call tool, MCP agent, tool registry, MCP kaizen, InMemoryTransport -->
