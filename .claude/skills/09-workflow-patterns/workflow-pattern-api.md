---
name: workflow-pattern-api
description: "API integration workflow patterns (REST, GraphQL, webhooks). Use when asking 'API workflow', 'REST integration', 'API orchestration', 'webhook', or 'API automation'."
---

# API Integration Workflow Patterns

Patterns for integrating and orchestrating APIs in workflows.

> **Skill Metadata**
> Category: `workflow-patterns`
> Priority: `HIGH`
> SDK Version: `0.9.25+`
> Related Skills: [`nodes-api-reference`](../nodes/nodes-api-reference.md), [`nexus-specialist`](../../03-nexus/nexus-specialist.md)
> Related Subagents: `nexus-specialist` (API platform), `pattern-expert` (API workflows)

## Quick Reference

API patterns enable:

- **REST APIs** - GET, POST, PUT, DELETE operations
- **GraphQL** - Query and mutation execution
- **Webhooks** - Event-driven integrations
- **Authentication** - OAuth, API keys, JWT
- **Rate limiting** - Backoff and throttling
- **Error handling** - Retries and fallbacks

## Pattern 1: REST API Orchestration

```rust
use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. Authenticate
builder.add_node("HTTPRequestNode", "auth", ValueMap::from([
    ("url".into(), Value::String("https://api.example.com/auth/token".into())),
    ("method".into(), Value::String("POST".into())),
    ("body".into(), Value::Object(ValueMap::from([
        ("client_id".into(), Value::String(
            std::env::var("CLIENT_ID").expect("CLIENT_ID in .env").into()
        )),
        ("client_secret".into(), Value::String(
            std::env::var("CLIENT_SECRET").expect("CLIENT_SECRET in .env").into()
        )),
    ]))),
]));

// 2. Get user data
builder.add_node("HTTPRequestNode", "get_user", ValueMap::from([
    ("url".into(), Value::String("https://api.example.com/users/{{input.user_id}}".into())),
    ("method".into(), Value::String("GET".into())),
    ("headers".into(), Value::Object(ValueMap::from([
        ("Authorization".into(), Value::String("Bearer {{auth.access_token}}".into())),
    ]))),
]));

// 3. Update user profile
builder.add_node("HTTPRequestNode", "update_profile", ValueMap::from([
    ("url".into(), Value::String("https://api.example.com/users/{{input.user_id}}/profile".into())),
    ("method".into(), Value::String("PUT".into())),
    ("headers".into(), Value::Object(ValueMap::from([
        ("Authorization".into(), Value::String("Bearer {{auth.access_token}}".into())),
    ]))),
    ("body".into(), Value::String("{{input.profile_data}}".into())),
]));

// 4. Trigger webhook
builder.add_node("HTTPRequestNode", "notify_webhook", ValueMap::from([
    ("url".into(), Value::String("{{input.webhook_url}}".into())),
    ("method".into(), Value::String("POST".into())),
    ("body".into(), Value::Object(ValueMap::from([
        ("event".into(), Value::String("profile_updated".into())),
        ("user_id".into(), Value::String("{{input.user_id}}".into())),
        ("timestamp".into(), Value::String("{{now}}".into())),
    ]))),
]));

builder.connect("auth", "access_token", "get_user", "token");
builder.connect("get_user", "data", "update_profile", "user_data");
builder.connect("update_profile", "result", "notify_webhook", "body");

let workflow = builder.build(&registry)?;
let runtime = Runtime::new(RuntimeConfig::default(), registry);
let result = runtime.execute(&workflow, ValueMap::from([
    ("user_id".into(), Value::String("12345".into())),
    ("profile_data".into(), Value::Object(ValueMap::from([
        ("name".into(), Value::String("John Doe".into())),
    ]))),
    ("webhook_url".into(), Value::String("https://webhook.site/...".into())),
])).await?;
```

## Pattern 2: Parallel API Calls

```rust
use kailash_core::{WorkflowBuilder, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// Fetch data from multiple APIs in parallel
builder.add_node("HTTPRequestNode", "api_weather", ValueMap::from([
    ("url".into(), Value::String("https://api.weather.com/current/{{input.city}}".into())),
    ("method".into(), Value::String("GET".into())),
]));

builder.add_node("HTTPRequestNode", "api_news", ValueMap::from([
    ("url".into(), Value::String("https://api.news.com/headlines/{{input.city}}".into())),
    ("method".into(), Value::String("GET".into())),
]));

builder.add_node("HTTPRequestNode", "api_events", ValueMap::from([
    ("url".into(), Value::String("https://api.events.com/search?location={{input.city}}".into())),
    ("method".into(), Value::String("GET".into())),
]));

// Merge results
builder.add_node("MergeNode", "merge_results", ValueMap::from([
    ("strategy".into(), Value::String("combine".into())),
]));

// No connections between parallel nodes - they run simultaneously
builder.connect("api_weather", "data", "merge_results", "weather_data");
builder.connect("api_news", "data", "merge_results", "news_data");
builder.connect("api_events", "data", "merge_results", "events_data");
```

## Pattern 3: API with Retry and Backoff

```rust
use kailash_core::{WorkflowBuilder, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. Initialize retry state
builder.add_node("SetVariableNode", "init_retry", ValueMap::from([
    ("retry_count".into(), Value::Integer(0)),
    ("max_retries".into(), Value::Integer(3)),
]));

// 2. Make API call
builder.add_node("HTTPRequestNode", "api_call", ValueMap::from([
    ("url".into(), Value::String("https://api.example.com/operation".into())),
    ("method".into(), Value::String("POST".into())),
    ("body".into(), Value::String("{{input.data}}".into())),
    ("timeout".into(), Value::Integer(30)),
]));

// 3. Check response status
builder.add_node("ConditionalNode", "check_status", ValueMap::from([
    ("condition".into(), Value::String("{{api_call.status_code}} >= 200 AND {{api_call.status_code}} < 300".into())),
    ("true_branch".into(), Value::String("success".into())),
    ("false_branch".into(), Value::String("check_retry".into())),
]));

// 4. Check if should retry
builder.add_node("ConditionalNode", "check_retry", ValueMap::from([
    ("condition".into(), Value::String("{{init_retry.retry_count}} < {{init_retry.max_retries}}".into())),
    ("true_branch".into(), Value::String("backoff".into())),
    ("false_branch".into(), Value::String("failed".into())),
]));

// 5. Exponential backoff
builder.add_node("TransformNode", "calculate_delay", ValueMap::from([
    ("input".into(), Value::String("{{init_retry.retry_count}}".into())),
    ("transformation".into(), Value::String("2 ** value".into())), // 1, 2, 4 seconds
]));

builder.add_node("DelayNode", "backoff", ValueMap::from([
    ("duration_seconds".into(), Value::String("{{calculate_delay.result}}".into())),
]));

// 6. Increment retry counter
builder.add_node("TransformNode", "increment", ValueMap::from([
    ("input".into(), Value::String("{{init_retry.retry_count}}".into())),
    ("transformation".into(), Value::String("value + 1".into())),
]));

// Loop back
builder.connect("init_retry", "retry_count", "api_call", "retry");
builder.connect("api_call", "status_code", "check_status", "condition");
builder.connect("check_status", "output_false", "check_retry", "condition");
builder.connect("check_retry", "output_true", "calculate_delay", "input");
builder.connect("calculate_delay", "result", "backoff", "duration_seconds");
builder.connect("backoff", "done", "increment", "input");
builder.connect("increment", "result", "api_call", "retry"); // Retry
```

## Pattern 4: GraphQL API Integration

```rust
use kailash_core::{WorkflowBuilder, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. GraphQL query
builder.add_node("HTTPRequestNode", "graphql_query", ValueMap::from([
    ("url".into(), Value::String("https://api.example.com/graphql".into())),
    ("method".into(), Value::String("POST".into())),
    ("headers".into(), Value::Object(ValueMap::from([
        ("Content-Type".into(), Value::String("application/json".into())),
        ("Authorization".into(), Value::String(
            format!("Bearer {}", std::env::var("API_TOKEN").expect("API_TOKEN in .env")).into()
        )),
    ]))),
    ("body".into(), Value::Object(ValueMap::from([
        ("query".into(), Value::String(r#"
            query GetUser($id: ID!) {
                user(id: $id) {
                    id
                    name
                    email
                    posts {
                        id
                        title
                        createdAt
                    }
                }
            }
        "#.into())),
        ("variables".into(), Value::Object(ValueMap::from([
            ("id".into(), Value::String("{{input.user_id}}".into())),
        ]))),
    ]))),
]));

// 2. Extract nested data
builder.add_node("TransformNode", "extract_posts", ValueMap::from([
    ("input".into(), Value::String("{{graphql_query.data.user.posts}}".into())),
    ("transformation".into(), Value::String("map(|p| { id: p.id, title: p.title })".into())),
]));

// 3. GraphQL mutation
builder.add_node("HTTPRequestNode", "graphql_mutation", ValueMap::from([
    ("url".into(), Value::String("https://api.example.com/graphql".into())),
    ("method".into(), Value::String("POST".into())),
    ("headers".into(), Value::Object(ValueMap::from([
        ("Content-Type".into(), Value::String("application/json".into())),
        ("Authorization".into(), Value::String(
            format!("Bearer {}", std::env::var("API_TOKEN").expect("API_TOKEN in .env")).into()
        )),
    ]))),
    ("body".into(), Value::Object(ValueMap::from([
        ("query".into(), Value::String(r#"
            mutation UpdateUser($id: ID!, $input: UserInput!) {
                updateUser(id: $id, input: $input) {
                    id
                    name
                    updatedAt
                }
            }
        "#.into())),
        ("variables".into(), Value::Object(ValueMap::from([
            ("id".into(), Value::String("{{input.user_id}}".into())),
            ("input".into(), Value::String("{{input.updates}}".into())),
        ]))),
    ]))),
]));

builder.connect("graphql_query", "data", "extract_posts", "input");
builder.connect("extract_posts", "result", "graphql_mutation", "posts_data");
```

## Pattern 5: Webhook Receiver Workflow

```rust
use kailash_core::{WorkflowBuilder, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use kailash_nexus::{NexusApp, Preset};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. Validate webhook signature
builder.add_node("TransformNode", "validate_signature", ValueMap::from([
    ("input".into(), Value::String("{{input.signature}}".into())),
    ("expected".into(), Value::String(
        std::env::var("WEBHOOK_SECRET").expect("WEBHOOK_SECRET in .env").into()
    )),
    ("transformation".into(), Value::String("hmac_sha256(input.body, expected)".into())),
]));

builder.add_node("ConditionalNode", "check_signature", ValueMap::from([
    ("condition".into(), Value::String("{{validate_signature.result}} == {{input.signature}}".into())),
    ("true_branch".into(), Value::String("process".into())),
    ("false_branch".into(), Value::String("reject".into())),
]));

// 2. Parse webhook payload
builder.add_node("TransformNode", "parse_payload", ValueMap::from([
    ("input".into(), Value::String("{{input.body}}".into())),
    ("transformation".into(), Value::String("json_parse(value)".into())),
]));

// 3. Route by event type
builder.add_node("ConditionalNode", "route_event", ValueMap::from([
    ("condition".into(), Value::String("{{parse_payload.event_type}}".into())),
    ("branches".into(), Value::Object(ValueMap::from([
        ("user.created".into(), Value::String("create_user".into())),
        ("user.updated".into(), Value::String("update_user".into())),
        ("user.deleted".into(), Value::String("delete_user".into())),
    ]))),
]));

// 4. Process each event type
builder.add_node("DatabaseExecuteNode", "create_user", ValueMap::from([
    ("query".into(), Value::String("INSERT INTO users (id, name, email) VALUES (?, ?, ?)".into())),
    ("parameters".into(), Value::String("{{parse_payload.data}}".into())),
]));

builder.add_node("DatabaseExecuteNode", "update_user", ValueMap::from([
    ("query".into(), Value::String("UPDATE users SET name = ?, email = ? WHERE id = ?".into())),
    ("parameters".into(), Value::String("{{parse_payload.data}}".into())),
]));

builder.add_node("DatabaseExecuteNode", "delete_user", ValueMap::from([
    ("query".into(), Value::String("DELETE FROM users WHERE id = ?".into())),
    ("parameters".into(), Value::Array(vec![
        Value::String("{{parse_payload.data.id}}".into()),
    ])),
]));

builder.connect("validate_signature", "result", "check_signature", "condition");
builder.connect("check_signature", "output_true", "parse_payload", "input");
builder.connect("parse_payload", "event_type", "route_event", "condition");

// Deploy as API endpoint
let workflow = builder.build(&registry)?;
let app = NexusApp::new().preset(Preset::Standard);
// Register workflow as handler on port 3000 — POST /execute receives webhooks
```

## Best Practices

1. **Authentication** - Store credentials in secrets
2. **Timeouts** - Set reasonable timeout values
3. **Retry logic** - Implement exponential backoff
4. **Rate limiting** - Respect API limits
5. **Error handling** - Graceful degradation
6. **Logging** - Track all API calls
7. **Validation** - Verify responses
8. **Parallel calls** - Use for independent APIs

## Common Pitfalls

- **No retry logic** - Transient failures kill workflows
- **Missing timeouts** - Hanging requests
- **Hard-coded credentials** - Security risks
- **No rate limiting** - API bans
- **Blocking parallel calls** - Slow execution
- **Poor error messages** - Hard to debug

## Related Skills

- **API Nodes**: [`nodes-api-reference`](../nodes/nodes-api-reference.md)
- **Nexus Platform**: [`nexus-specialist`](../../03-nexus/nexus-specialist.md)
- **Error Handling**: [`gold-error-handling`](../../17-gold-standards/gold-error-handling.md)

<!-- Trigger Keywords: API workflow, REST integration, API orchestration, webhook, API automation, GraphQL -->
