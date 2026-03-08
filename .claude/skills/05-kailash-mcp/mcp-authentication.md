---
name: mcp-authentication
description: "MCP server authentication: API key and JWT. Use when asking 'MCP auth', 'MCP authentication', 'MCP API key', 'MCP JWT', 'McpAuthenticator', 'MCP bearer token', 'secure MCP server'."
---

# MCP Authentication

MCP servers support optional authentication via API key or JWT bearer tokens. Authentication is disabled by default for development.

## Rust API

Source: `crates/kailash-nexus/src/mcp/auth.rs`

### Auth Configuration

```rust
use kailash_nexus::mcp::auth::{McpAuthConfig, McpAuthMethod, McpAuthenticator};

let config = McpAuthConfig {
    enabled: true,
    methods: vec![
        McpAuthMethod::ApiKey {
            valid_keys: vec!["my-api-key-1".to_string(), "my-api-key-2".to_string()],
        },
        McpAuthMethod::Jwt {
            secret: "jwt-secret-at-least-32-bytes-long!".to_string(),
            issuer: Some("my-app".to_string()),
            audience: None,
        },
    ],
};

let auth = McpAuthenticator::new(config);
assert!(auth.is_enabled());
```

### Authenticating Requests

```rust
// Validates the Authorization header
let result = auth.authenticate(Some("Bearer my-api-key-1"))?;
assert!(result.authenticated);
assert_eq!(result.method.as_deref(), Some("api_key"));

// JWT authentication returns the subject claim as identity
let result = auth.authenticate(Some("Bearer eyJ..."))?;
assert_eq!(result.identity.as_deref(), Some("user-123"));
assert_eq!(result.method.as_deref(), Some("jwt"));

// No header when auth is enabled
let err = auth.authenticate(None);  // Err(McpAuthError::Missing)
```

### Integrating with McpServer

```rust
use kailash_nexus::mcp::server::McpServer;
use kailash_nexus::mcp::auth::{McpAuthConfig, McpAuthMethod};

let mut server = McpServer::new("secure-server", "1.0.0");

// Enable authentication
server.with_auth(McpAuthConfig {
    enabled: true,
    methods: vec![McpAuthMethod::ApiKey {
        valid_keys: vec!["secret-key".to_string()],
    }],
});

// Disable later if needed
server.disable_auth();
```

### Security Properties

- API key comparison uses **constant-time equality** (prevents timing attacks)
- JWT validation uses the `jsonwebtoken` crate with HS256 algorithm
- Error messages are intentionally generic -- `McpAuthError::Display` always shows "Authentication failed"
- Debug output redacts secrets: `Jwt { issuer: Some("app"), audience: None, secret: "[REDACTED]" }`

## Python API

Source: `bindings/kailash-python/src/nexus.rs` (`PyMcpServer`)

### Configuring Auth

```python
from kailash import McpServer

server = McpServer("my-server", "1.0.0")

# Configure authentication with a dict
server.with_auth({
    "enabled": True,
    "methods": [
        {"type": "api_key", "keys": ["key-1", "key-2"]},
        {"type": "jwt", "secret": "jwt-secret-at-least-32-bytes!", "issuer": "my-app"},
    ],
})
```

Auth config dict schema:

- `enabled` (bool): whether auth is enforced
- `methods` (list[dict]): authentication methods, each with:
  - API key: `{"type": "api_key", "keys": ["key1", "key2"]}`
  - JWT: `{"type": "jwt", "secret": "...", "issuer": "...", "audience": "..."}`

### Authenticating Requests

```python
# Returns a dict: {"authenticated": True, "identity": "...", "method": "api_key"}
result = server.authenticate("Bearer key-1")
assert result["authenticated"]

# No header
result = server.authenticate()  # raises ValueError if auth enabled
```

### Disabling Auth

```python
server.disable_auth()
result = server.authenticate()  # succeeds without header
```

## Auth Methods

| Method    | Header Format        | Identity Returned              |
| --------- | -------------------- | ------------------------------ |
| `api_key` | `Bearer <key>`       | None (key matched)             |
| `jwt`     | `Bearer <jwt-token>` | JWT `sub` claim (or "anonymous") |

Methods are tried in order. The first successful match is used. If all methods fail, the error is returned.

## Error Types

| Error            | When                              |
| ---------------- | --------------------------------- |
| `Missing`        | No `Authorization` header         |
| `InvalidFormat`  | Not `Bearer <token>` format       |
| `InvalidKey`     | API key not recognized            |
| `InvalidToken`   | JWT validation failed             |
| `Expired`        | JWT `exp` claim is in the past    |

All errors display as "Authentication failed" to prevent enumeration.

## Source Files

- `crates/kailash-nexus/src/mcp/auth.rs` -- `McpAuthConfig`, `McpAuthMethod`, `McpAuthenticator`, `McpAuthError`
- `crates/kailash-nexus/src/mcp/server.rs` -- `McpServer::with_auth()`, `McpServer::authenticate()`
- `bindings/kailash-python/src/nexus.rs` -- `PyMcpServer::with_auth()`, `PyMcpServer::authenticate()`

<!-- Trigger Keywords: MCP auth, MCP authentication, MCP API key, MCP JWT, McpAuthenticator, bearer token, secure MCP, MCP security, with_auth, disable_auth -->
