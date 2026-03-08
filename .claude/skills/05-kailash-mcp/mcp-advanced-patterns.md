---
name: mcp-advanced-patterns
description: "Advanced MCP patterns: prompts, dynamic resources, auth integration, Python handlers, transport config. Use when asking 'MCP prompts', 'MCP dynamic resource', 'MCP Python', 'MCP auth integration', 'MCP transport config', 'MCP advanced'."
---

# MCP Advanced Patterns

Advanced patterns beyond basic tool registration. Covers prompts, dynamic resources, authenticated servers, transport configuration, Python API, and Nexus auto-integration.

## Prompts

MCP prompts generate parameterized message sequences. The server supports `prompts/list` and `prompts/get` protocol methods.

Source: `crates/kailash-nexus/src/mcp/server.rs`

### Rust API

```rust
use kailash_nexus::mcp::server::{McpServer, PromptArgument};
use std::collections::HashMap;

let mut server = McpServer::new("prompt-server", "1.0.0");

server.register_prompt(
    "code-review",
    Some("Generates a code review prompt for a given language"),
    vec![
        PromptArgument {
            name: "language".to_string(),
            description: Some("Programming language".to_string()),
            required: true,
        },
        PromptArgument {
            name: "style".to_string(),
            description: Some("Review style: thorough or quick".to_string()),
            required: false,
        },
    ],
    Box::new(|args: &HashMap<String, String>| {
        let lang = args.get("language").map(|s| s.as_str()).unwrap_or("unknown");
        let style = args.get("style").map(|s| s.as_str()).unwrap_or("thorough");
        Ok(vec![
            kailash_nexus::mcp::PromptMessage {
                role: "system".to_string(),
                content: format!("You are a {style} code reviewer for {lang}."),
            },
            kailash_nexus::mcp::PromptMessage {
                role: "user".to_string(),
                content: "Please review the following code.".to_string(),
            },
        ])
    }),
);

assert_eq!(server.prompt_count(), 1);

// Get prompt messages
let mut args = HashMap::new();
args.insert("language".to_string(), "Rust".to_string());
let messages = server.get_prompt("code-review", &args)?;
assert_eq!(messages.len(), 2);
assert_eq!(messages[0].role, "system");
```

Required arguments are validated -- `get_prompt` returns `NexusError::MissingParam` if a required argument is missing.

### Python API

```python
from kailash import McpServer

server = McpServer("prompt-server", "1.0.0")

def review_handler(args):
    lang = args.get("language", "unknown")
    return [
        {"role": "system", "content": f"You are a code reviewer for {lang}."},
        {"role": "user", "content": "Please review the following code."},
    ]

server.register_prompt(
    "code-review",
    handler=review_handler,
    description="Generates a code review prompt",
    arguments=[
        {"name": "language", "description": "Programming language", "required": True},
        {"name": "style", "description": "Review style", "required": False},
    ],
)

assert server.prompt_count() == 1
```

Prompt handler must return a list of dicts, each with `role` (str) and `content` (str) keys.

## Dynamic Resources

Static resources return fixed content. Dynamic resources use a handler function that receives the URI and returns content at read time.

### Rust API

```rust
use kailash_nexus::mcp::server::McpServer;

let mut server = McpServer::new("resource-server", "1.0.0");

// Static resource
server.register_resource(
    "file:///config.json",
    "Configuration",
    Some("Application config"),
    Some("application/json"),
    r#"{"port": 3000, "debug": false}"#,
);

// Dynamic resource -- handler receives URI, returns content
server.register_dynamic_resource(
    "system:///status",
    "System Status",
    Some("Current system status"),
    Some("application/json"),
    Box::new(|_uri: &str| {
        Ok(format!(r#"{{"uptime_secs": {}, "healthy": true}}"#, 42))
    }),
);

assert_eq!(server.resource_count(), 2);

// Read returns ResourceContent with uri, mime_type, text
let content = server.read_resource("system:///status")?;
assert!(content.text.unwrap().contains("uptime_secs"));
```

### Python API

```python
from kailash import McpServer

server = McpServer("resource-server", "1.0.0")

# Static resource
server.register_resource(
    "file:///readme",
    "README",
    "Welcome to the project.",
    description="Project documentation",
    mime_type="text/plain",
)

# Dynamic resource -- handler receives URI string, must return str
server.register_dynamic_resource(
    "system:///metrics",
    "Metrics",
    handler=lambda uri: '{"requests": 1234}',
    description="Live metrics",
    mime_type="application/json",
)

assert server.resource_count() == 2

# Read a resource
content = server.read_resource("file:///readme")
assert content["text"] == "Welcome to the project."

# List all resources
resources = server.list_resources()
assert len(resources) == 2

# Remove a resource
server.remove_resource("file:///readme")
assert server.resource_count() == 1
```

Python resource handler must return a `str`. The `read_resource` method returns a dict with `uri`, `mimeType`, and `text` keys.

## Transport Configuration

The MCP server supports three transports: `stdio`, `sse`, `http`. Transport and bind address are configured separately.

### Rust API

```rust
use kailash_nexus::mcp::server::{McpServer, McpTransport};

// Create with specific transport
let mut server = McpServer::with_transport("my-server", "1.0.0", McpTransport::Sse);
assert_eq!(server.transport(), McpTransport::Sse);

// Default SSE config is 127.0.0.1:3000
let config = server.transport_config();
assert_eq!(config.host, "127.0.0.1");
assert_eq!(config.port, 3000);

// Change SSE bind address
server.set_sse_config("0.0.0.0", 9000);

// Switch transport (resets config to new transport's default)
server.set_transport(McpTransport::Http);
// HTTP default is 127.0.0.1:8080
let config = server.transport_config();
assert_eq!(config.port, 8080);

// Override HTTP config
server.set_http_config("0.0.0.0", 3000);
```

### Python API

```python
from kailash import McpServer

# Default transport is stdio
server = McpServer("my-server", "1.0.0")
assert server.transport() == "stdio"

# Create with specific transport
server = McpServer("my-server", "1.0.0", transport="sse")
assert server.transport() == "sse"

# Configure SSE bind address -- separate args, NOT a dict
server.set_sse_config("0.0.0.0", 9000)

# Get current config
config = server.get_transport_config()
assert config["host"] == "0.0.0.0"
assert config["port"] == 9000

# Switch transport
server.set_transport("http")
server.set_http_config("0.0.0.0", 3000)
```

**Important**: `set_sse_config(host, port)` takes two separate arguments (string and int), not a dict.

## Authenticated MCP Server

Combine MCP tools with API key or JWT authentication.

### Rust API

```rust
use kailash_nexus::mcp::server::McpServer;
use kailash_nexus::mcp::auth::{McpAuthConfig, McpAuthMethod};

let mut server = McpServer::new("secure-server", "1.0.0");

// Enable API key auth
server.with_auth(McpAuthConfig {
    enabled: true,
    methods: vec![McpAuthMethod::ApiKey {
        valid_keys: vec!["secret-key-1".to_string()],
    }],
});

// Register tools as usual
server.register_tool(
    "protected-tool",
    Some("Requires authentication"),
    serde_json::json!({"type": "object", "properties": {}}),
    |_args: serde_json::Value| async move {
        Ok(serde_json::json!({"status": "ok"}))
    },
);

// Authenticate before dispatching
let result = server.authenticate(Some("Bearer secret-key-1"));
assert!(result.is_ok());
assert!(result.unwrap().authenticated);

// Invalid key
let result = server.authenticate(Some("Bearer wrong-key"));
assert!(result.is_err());

// Disable auth
server.disable_auth();
let result = server.authenticate(None);
assert!(result.is_ok());
```

### Python API

```python
from kailash import McpServer

server = McpServer("secure-server", "1.0.0")

# Configure auth with a dict
server.with_auth({
    "enabled": True,
    "methods": [
        {"type": "api_key", "keys": ["key-1", "key-2"]},
    ],
})

# Authenticate a request
result = server.authenticate("Bearer key-1")
assert result["authenticated"]
assert result["method"] == "api_key"

# JWT auth
server.with_auth({
    "enabled": True,
    "methods": [
        {"type": "jwt", "secret": "my-secret-at-least-32-bytes-long!", "issuer": "my-app"},
    ],
})
```

Auth config dict schema:

- `enabled` (bool): whether auth is enforced
- `methods` (list[dict]): list of auth method dicts
  - API key: `{"type": "api_key", "keys": ["key1", ...]}`
  - JWT: `{"type": "jwt", "secret": "...", "issuer": "...", "audience": "..."}`

## Python Tool Handlers

Python tool handlers receive a dict and return a dict. The PyO3 binding handles JSON conversion automatically.

```python
from kailash import McpServer

server = McpServer("py-server", "1.0.0")

# Lambda handler
server.register_tool(
    "echo",
    "Echoes input back",
    lambda params: params,
)

# Function handler with schema
def search(params):
    query = params.get("query", "")
    limit = params.get("limit", 10)
    return {"results": [], "query": query, "limit": limit}

server.register_tool(
    "search",
    "Searches documents",
    search,
    schema={
        "type": "object",
        "properties": {
            "query": {"type": "string", "description": "Search query"},
            "limit": {"type": "integer", "description": "Max results"},
        },
        "required": ["query"],
    },
)

assert server.tool_count() == 2
```

`register_tool` Python signature: `register_tool(name, description, handler, schema=None)`.

If `schema` is omitted, a default empty object schema is used: `{"type": "object", "properties": {}}`.

## Nexus Auto-Integration

When `enable_mcp` is `true` (default) in `NexusConfig`, Nexus handlers are automatically exposed as MCP tools via SSE at `/mcp/message` and `/mcp/sse`.

```rust
use kailash_nexus::Nexus;
use kailash_nexus::handler::{ClosureHandler, HandlerParam, HandlerParamType};
use kailash_value::{Value, ValueMap};

let mut nexus = Nexus::new();

let params = vec![
    HandlerParam::new("query", HandlerParamType::String)
        .with_description("Search query"),
];

nexus.handler(
    "search",
    ClosureHandler::with_params(
        |inputs: ValueMap| async move {
            let query = inputs.get("query").and_then(|v| v.as_str()).unwrap_or("");
            Ok(Value::from(format!("Results for: {query}")))
        },
        params,
    ),
);

// The handler is available as:
//   POST /api/search    (HTTP API)
//   MCP tool "search"   (via POST /mcp/message)
let router = nexus.router()?;
```

The SSE module converts `HandlerDef` to MCP tools automatically:

- Handler name becomes tool name
- Handler description becomes tool description
- `HandlerParam` types map to JSON Schema types
- Required/optional params are reflected in the `required` array

## Handling Messages Directly

For testing or embedding, call `handle_message` directly with JSON-RPC strings.

```rust
use kailash_nexus::mcp::server::McpServer;

let server = McpServer::new("test", "0.1.0");

// Initialize
let response = server.handle_message(
    r#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}"#
).await;
assert!(response.contains("protocolVersion"));

// List prompts
let response = server.handle_message(
    r#"{"jsonrpc":"2.0","id":2,"method":"prompts/list","params":{}}"#
).await;

// Get a prompt
let response = server.handle_message(
    r#"{"jsonrpc":"2.0","id":3,"method":"prompts/get","params":{"name":"code-review","arguments":{"language":"Rust"}}}"#
).await;
```

Supported methods: `initialize`, `tools/list`, `tools/call`, `resources/list`, `resources/read`, `prompts/list`, `prompts/get`.

## Source Files

- `crates/kailash-nexus/src/mcp/server.rs` -- `McpServer`, prompts, dynamic resources, transport config
- `crates/kailash-nexus/src/mcp/auth.rs` -- `McpAuthConfig`, `McpAuthMethod`, `McpAuthenticator`
- `crates/kailash-nexus/src/mcp/sse.rs` -- Nexus auto-integration, `build_mcp_router`
- `bindings/kailash-python/src/nexus.rs` -- `PyMcpServer`: Python tool/resource/prompt handlers

<!-- Trigger Keywords: MCP prompts, MCP dynamic resource, MCP Python handler, MCP auth integration, MCP transport config, MCP advanced, register_prompt, register_dynamic_resource, set_sse_config, Nexus auto-integration, handle_message -->
