# Nexus Skills Index

Skills for `kailash-nexus` -- the multi-channel deployment platform built on axum + tower.

Source: `crates/kailash-nexus/src/`

---

## Skill Files

| File                     | Description                                                                                   | Use When                                                               |
| ------------------------ | --------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `nexus-quickstart.md`    | Getting started with Nexus: handler registration, presets, starting servers                   | First-time setup, basic API creation                                   |
| `nexus-preset-system.md` | Preset system overview and Nexus configuration                                                | Choosing presets, configuring Nexus                                    |
| `nexus-auth-plugin.md`   | JWT authentication, RBAC middleware, per-user rate limiting, AuthError types                  | Adding auth, role-based access, JWT tokens, tenant isolation           |
| `nexus-middleware.md`    | Tower middleware composition: CORS, rate limit, body limit, security headers, logging, custom | Configuring middleware stack, creating custom middleware               |
| `nexus-mcp-channel.md`   | MCP SSE/HTTP/stdio transports, McpServer, tool/resource registration                          | AI agent integration, Claude Desktop, MCP protocol                     |
| `nexus-sessions.md`      | Request-scoped session data via JWT claims and axum extensions                                | User identity in handlers, request context, tenant context             |
| `nexus-agentui.md`       | SSE-based real-time agent event streaming, AgentEvent, broadcast channel                      | Agent-to-UI streaming, live agent monitoring, frontend SSE integration |
| `create-mcp-server.md`   | Step-by-step MCP server creation guide                                                        | Building an MCP server from scratch                                    |

## Quick Navigation

- **"How do I create an API?"** -> `nexus-quickstart.md`
- **"Which preset should I use?"** -> `nexus-preset-system.md` or `nexus-middleware.md` (Preset Matrix)
- **"How do I add JWT auth?"** -> `nexus-auth-plugin.md`
- **"How do I add RBAC?"** -> `nexus-auth-plugin.md`
- **"How do I configure CORS?"** -> `nexus-middleware.md`
- **"How do I rate limit?"** -> `nexus-middleware.md` (global) or `nexus-auth-plugin.md` (per-user)
- **"How do I add security headers?"** -> `nexus-middleware.md`
- **"How do I create custom middleware?"** -> `nexus-middleware.md` (Section 7)
- **"How do I expose handlers as MCP tools?"** -> `nexus-mcp-channel.md`
- **"How do I run an MCP stdio server?"** -> `nexus-mcp-channel.md` or `create-mcp-server.md`
- **"How do I integrate with Claude Desktop?"** -> `nexus-mcp-channel.md` (Section 7)
- **"How do I get user identity in a handler?"** -> `nexus-sessions.md`
- **"How do I stream agent events to a UI?"** -> `nexus-agentui.md`
- **"What AgentEvent types exist?"** -> `nexus-agentui.md` (Section 3)
- **"How do I connect a React frontend to SSE?"** -> `nexus-agentui.md` (Section 7)

## Key Concepts

- **Handler pattern**: Register async functions via `ClosureHandler::new()` or `ClosureHandler::with_params()`
- **Three channels**: HTTP API (`/api/{name}`), CLI (auto-generated via clap), MCP (JSON-RPC 2.0)
- **Preset system**: `Preset::None` through `Preset::Enterprise` for one-line middleware configuration
- **Auth is separate from middleware**: JWT/RBAC layers are applied independently from the middleware stack
- **No dedicated session store**: Stateless sessions via JWT claims in request extensions
- **AgentUI**: Broadcast-based SSE streaming with late-client buffering
