---
name: kaizen-tools
description: "Tool system for Kaizen agents. Use when asking about defining tools, ToolDef, ToolRegistry, ToolExecutor, tool parameters, FnTool, or MCP tools."
---

# Kaizen Tools: Agent Tool System

The Kaizen tool system allows agents to call external functions during the TAOD loop. Tools are defined with `ToolDef`, registered in a `ToolRegistry`, and executed by the `ToolExecutor`.

## Core Types

| Type            | Module                     | Purpose                                                           |
| --------------- | -------------------------- | ----------------------------------------------------------------- |
| `ToolDef`       | `agent::tools`             | Tool definition: name, description, parameters, callable function |
| `ToolParam`     | `agent::tools`             | Parameter definition with type, description, required flag        |
| `ToolParamType` | `agent::tools`             | Enum: String, Integer, Float, Bool, Object, Array                 |
| `ToolFn`        | `agent::tools`             | Async trait for callable tool functions                           |
| `FnTool`        | `agent::tools`             | Wrapper to convert closures into `ToolFn` implementations         |
| `ToolRegistry`  | `agent::tools`             | HashMap-based registry of tools by name                           |
| `ToolExecutor`  | `agent::tools_integration` | Executes tool calls from LLM responses                            |

## Creating a Tool

```rust
use std::sync::Arc;
use kailash_kaizen::agent::tools::{ToolDef, ToolParam, ToolParamType, FnTool};
use kailash_kaizen::error::AgentError;
use kailash_value::{Value, ValueMap};

let calculator = ToolDef::new(
    "calculator",
    "Performs basic arithmetic",
    vec![
        ToolParam {
            name: Arc::from("a"),
            param_type: ToolParamType::Integer,
            description: Some(Arc::from("First operand")),
            required: true,
            enum_values: None,
        },
        ToolParam {
            name: Arc::from("b"),
            param_type: ToolParamType::Integer,
            description: Some(Arc::from("Second operand")),
            required: true,
            enum_values: None,
        },
        ToolParam {
            name: Arc::from("op"),
            param_type: ToolParamType::String,
            description: Some(Arc::from("Operation to perform")),
            required: true,
            enum_values: Some(vec![
                "add".to_string(),
                "subtract".to_string(),
                "multiply".to_string(),
            ]),
        },
    ],
    Arc::new(FnTool::new(|inputs: ValueMap| {
        Box::pin(async move {
            let a = inputs
                .get("a" as &str)
                .and_then(|v| v.as_i64())
                .ok_or_else(|| AgentError::ToolError("missing 'a'".into()))?;
            let b = inputs
                .get("b" as &str)
                .and_then(|v| v.as_i64())
                .ok_or_else(|| AgentError::ToolError("missing 'b'".into()))?;
            let op = inputs
                .get("op" as &str)
                .and_then(|v| v.as_str())
                .ok_or_else(|| AgentError::ToolError("missing 'op'".into()))?;

            let result = match op {
                "add" => a + b,
                "subtract" => a - b,
                "multiply" => a * b,
                other => {
                    return Err(AgentError::ToolError(
                        format!("unknown operation: {other}")
                    ));
                },
            };
            Ok(Value::from(result))
        })
    })),
);
```

## Registering Tools

```rust
use kailash_kaizen::agent::tools::ToolRegistry;

let mut registry = ToolRegistry::new();
registry.register(calculator);
registry.register(search_tool);

// Query the registry
assert_eq!(registry.len(), 2);
assert!(registry.get("calculator").is_some());

// Get all tools as a Vec<ToolDef>
let all_tools = registry.all();
```

## ToolExecutor: Executing Tool Calls

The `ToolExecutor` wraps a `ToolRegistry` and executes tool calls from LLM responses. Errors are captured as `ToolResult` values (not propagated), so the LLM can observe and recover.

```rust
use std::sync::Arc;
use kailash_kaizen::agent::tools::ToolRegistry;
use kailash_kaizen::agent::tools_integration::ToolExecutor;
use kailash_kaizen::types::ToolCallRequest;

let registry = Arc::new(registry);
let executor = ToolExecutor::new(Arc::clone(&registry));

// Execute tool calls sequentially
let calls = vec![
    ToolCallRequest {
        id: "call_1".into(),
        tool_name: "calculator".into(),
        arguments: serde_json::json!({"a": 10, "b": 5, "op": "add"}),
    },
];

let results = executor.execute_tool_calls(&calls).await;
// results[0].content == Value::from(15)
// results[0].is_error == false

// Execute tool calls in parallel (uses tokio::spawn)
let results = executor.execute_parallel(&calls).await;
```

## Handling Tool Errors

Tool errors are captured in the result, not propagated. This allows the LLM to observe failures and adapt:

```rust
use kailash_kaizen::types::ToolResult;
use kailash_value::Value;

// When a tool is not found:
// ToolResult { call_id, tool_name, content: "tool not found: ...", is_error: true }

// When a tool execution fails:
// ToolResult { call_id, tool_name, content: "error message...", is_error: true }
```

## Building Conversation Turns from Tool Results

After executing tools, build conversation turns for the next LLM request:

```rust
use kailash_kaizen::agent::tools_integration::ToolExecutor;

let (assistant_turn, tool_turn) = ToolExecutor::build_tool_turns(
    "Let me calculate that.",  // assistant's text before tool calls
    &calls,                     // the tool call requests
    &results,                   // the tool results
);
// assistant_turn: ConversationTurn with role=Assistant, tool_calls recorded
// tool_turn: ConversationTurn with role=Tool, tool_results recorded

// Append both to conversation history before next LLM call
```

## Schema Generation

Tool definitions generate provider-specific JSON schemas automatically:

```rust
use kailash_kaizen::agent::tools_integration::{
    tool_defs_to_openai_schema,
    tool_defs_to_anthropic_schema,
};

let tools = registry.all();

// OpenAI format: {"type": "function", "function": {"name": ..., "parameters": ...}}
let openai = tool_defs_to_openai_schema(&tools);

// Anthropic format: {"name": ..., "input_schema": {"type": "object", ...}}
let anthropic = tool_defs_to_anthropic_schema(&tools);

// Per-tool methods also available:
let schema = calculator.to_openai_function_schema();
let schema = calculator.to_anthropic_tool_schema();
```

## Tools with the Agent

Register tools on a concrete `Agent`:

```rust
use kailash_kaizen::agent::concrete::Agent;
use kailash_kaizen::llm::client::LlmClient;
use kailash_kaizen::types::AgentConfig;

let config = AgentConfig {
    model: Some(std::env::var("DEFAULT_LLM_MODEL").expect("model in .env")),
    ..AgentConfig::default()
};
let llm = LlmClient::from_env()
    .map_err(|e| kailash_kaizen::error::AgentError::Config(e.to_string()))?;

let agent = Agent::new(config, llm)?
    .with_tools(registry);

// Access the registry from the agent
assert_eq!(agent.tools().len(), 2);

// Share the registry with a ToolExecutor
let executor = ToolExecutor::new(Arc::clone(agent.tools_arc()));
```

## Tools in the TAOD Loop

The `TaodRunner` integrates tools natively. Register tools and the runner will:

1. Send tool definitions to the LLM with each request
2. Parse tool call requests from LLM responses
3. Execute tools via the registry
4. Feed results back to the LLM as conversation turns
5. Loop until the LLM stops requesting tools

```rust
use std::sync::Arc;
use std::time::Duration;
use kailash_kaizen::agent::taod::{TaodConfig, TaodRunner};
use kailash_kaizen::agent::tools::ToolRegistry;
use kailash_kaizen::llm::client::LlmClient;
use kailash_kaizen::memory::SessionMemory;

let llm = Arc::new(LlmClient::from_env()
    .map_err(|e| kailash_kaizen::error::AgentError::Config(e.to_string()))?);

let mut tools = ToolRegistry::new();
tools.register(calculator);
let tools = Arc::new(tools);

let config = TaodConfig {
    max_iterations: 5,
    timeout: Duration::from_secs(120),
    system_prompt: Some("You are a math assistant.".into()),
    model: std::env::var("DEFAULT_LLM_MODEL").expect("model in .env"),
    temperature: None,
    max_tokens: None,
};

let mut runner = TaodRunner::new(llm, tools, Box::new(SessionMemory::new()), config);
let result = runner.run("What is 15 * 7?").await?;
// result.final_response: "15 * 7 = 105"
// result.tool_calls_made: ["calculator"]
```

## Implementing the ToolFn Trait Directly

For complex tools that need shared state, implement `ToolFn` on a struct:

```rust
use async_trait::async_trait;
use kailash_kaizen::agent::tools::ToolFn;
use kailash_kaizen::error::AgentError;
use kailash_value::{Value, ValueMap};
use std::sync::Arc;
use tokio::sync::RwLock;

struct DatabaseQueryTool {
    // Shared state across invocations
    cache: Arc<RwLock<std::collections::HashMap<String, Value>>>,
}

#[async_trait]
impl ToolFn for DatabaseQueryTool {
    async fn call(&self, inputs: ValueMap) -> Result<Value, AgentError> {
        let query = inputs
            .get("query" as &str)
            .and_then(|v| v.as_str())
            .ok_or_else(|| AgentError::ToolError("missing 'query'".into()))?;

        // Check cache first
        {
            let cache = self.cache.read().await;
            if let Some(cached) = cache.get(query) {
                return Ok(cached.clone());
            }
        }

        // Execute query and cache result...
        let result = Value::from(format!("query result for: {query}"));
        {
            let mut cache = self.cache.write().await;
            cache.insert(query.to_string(), result.clone());
        }
        Ok(result)
    }
}
```

<!-- Trigger Keywords: tool, ToolDef, ToolRegistry, ToolExecutor, FnTool, ToolFn, tool parameter, tool execution, function calling -->
