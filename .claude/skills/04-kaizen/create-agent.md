---
name: create-agent
description: "Scaffold a Kaizen AI agent with LLM client, tools, memory, and test template. Use when asking 'create agent', 'scaffold agent', 'new agent template', or 'agent boilerplate'."
---

# Create Agent Skill

Scaffold a Kaizen AI agent with LLM client, tools, memory, and test template.

## Usage

`/create-agent <AgentName>` -- Create a new Kaizen agent with the given name

Examples:

- `/create-agent ResearchAgent`
- `/create-agent CodeReviewAgent`

## Steps

1. Read the existing agent patterns from:
   - `crates/kailash-kaizen/src/agent/concrete.rs` -- Agent struct, construction, `chat()`, `BaseAgent` impl
   - `crates/kailash-kaizen/src/agent/tools.rs` -- ToolRegistry, ToolDef, FnTool, ToolParam
   - `crates/kailash-kaizen/src/llm/client.rs` -- LlmClient, `from_env()`, `with_openai_key()`, `with_base_url()`
   - `crates/kailash-kaizen/src/orchestration/runtime.rs` -- OrchestrationRuntime for multi-agent coordination
   - `crates/kailash-kaizen/src/types.rs` -- AgentConfig, ExecutionMode, MemoryConfig, ToolAccess
   - `crates/kailash-kaizen/src/cost/` -- CostTracker, CostConfig, MonitoredAgent for LLM cost tracking
   - `crates/kailash-kaizen/src/events.rs` -- AgentEventEmitter for UI streaming of agent events

2. Create the agent module file at the appropriate location (e.g., `examples/` or a new module under `src/agents/`).

3. Implement the agent with:
   - `AgentConfig` with model read from `.env` (NEVER hardcode model names)
   - `LlmClient::from_env()` for API key resolution
   - `ToolRegistry` with at least one sample tool
   - Memory configuration (Session or None)
   - Example execution code using `agent.chat()` or `agent.run()`

4. Write tests using `wiremock` for LLM response mocking (Tier 1 unit tests only).

5. If multi-agent coordination is needed, use `OrchestrationRuntime` with a strategy (Sequential, Parallel, Hierarchical, Pipeline).

## Template

### Single Agent

```rust
use std::sync::Arc;
use kailash_kaizen::agent::concrete::Agent;
use kailash_kaizen::agent::tools::{FnTool, ToolDef, ToolParam, ToolParamType, ToolRegistry};
use kailash_kaizen::llm::client::LlmClient;
use kailash_kaizen::types::{AgentConfig, ExecutionMode, MemoryConfig, ToolAccess};
use kailash_value::Value;

/// Creates and configures the {AgentName}.
///
/// # Panics
///
/// Panics if `DEFAULT_LLM_MODEL` is not set in `.env` or if
/// no LLM API keys are configured.
fn create_{agent_name_snake}() -> Agent {
    dotenvy::dotenv().ok();

    // Read model from .env -- NEVER hardcode
    let model = std::env::var("DEFAULT_LLM_MODEL")
        .expect("DEFAULT_LLM_MODEL must be set in .env");

    let config = AgentConfig {
        model: Some(model),
        execution_mode: ExecutionMode::Autonomous,
        memory: MemoryConfig::Session,
        tool_access: ToolAccess::Constrained,
        system_prompt: Some("You are a helpful {AgentName}. Respond concisely.".to_string()),
        temperature: Some(0.7),
        max_tokens: Some(4096),
        ..AgentConfig::default()
    };

    let llm = LlmClient::from_env().expect("LLM API keys must be set in .env");

    // Build tool registry
    let mut tools = ToolRegistry::new();
    tools.register(ToolDef::new(
        "search",
        "Search for information on a topic",
        vec![
            ToolParam {
                name: Arc::from("query"),
                param_type: ToolParamType::String,
                description: Some(Arc::from("The search query")),
                required: true,
                enum_values: None,
            },
        ],
        Arc::new(FnTool::new(|inputs| {
            Box::pin(async move {
                let query = inputs
                    .get("query" as &str)
                    .and_then(|v| v.as_str())
                    .unwrap_or("unknown");
                Ok(Value::String(Arc::from(format!("Results for: {query}"))))
            })
        })),
    ));

    Agent::new(config, llm)
        .expect("agent creation should succeed")
        .with_tools(tools)
}

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt::init();

    let mut agent = create_{agent_name_snake}();

    // Single-shot chat
    let response = agent.chat("What is Kailash?").await.expect("chat should succeed");
    println!("Response: {response}");

    // Conversational follow-up
    let follow_up = agent.chat("Tell me more about it.").await.expect("follow-up should succeed");
    println!("Follow-up: {follow_up}");

    // Check conversation history
    println!("Conversation turns: {}", agent.conversation().len());
}
```

### Multi-Agent Orchestration

```rust
use std::sync::Arc;
use kailash_kaizen::agent::concrete::Agent;
use kailash_kaizen::llm::client::LlmClient;
use kailash_kaizen::orchestration::runtime::OrchestrationRuntime;
use kailash_kaizen::types::{AgentConfig, ExecutionMode, MemoryConfig, OrchestrationStrategy};

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt::init();

    let model = std::env::var("DEFAULT_LLM_MODEL")
        .expect("DEFAULT_LLM_MODEL must be set in .env");

    let llm = LlmClient::from_env().expect("LLM API keys in .env");

    // Create specialized agents
    let researcher = Agent::new(
        AgentConfig {
            model: Some(model.clone()),
            execution_mode: ExecutionMode::SingleShot,
            system_prompt: Some("You are a research specialist. Gather facts.".to_string()),
            ..AgentConfig::default()
        },
        llm.clone(),
    ).expect("researcher agent");

    let writer = Agent::new(
        AgentConfig {
            model: Some(model.clone()),
            execution_mode: ExecutionMode::SingleShot,
            system_prompt: Some("You are a writing specialist. Produce clear prose.".to_string()),
            ..AgentConfig::default()
        },
        llm.clone(),
    ).expect("writer agent");

    let reviewer = Agent::new(
        AgentConfig {
            model: Some(model),
            execution_mode: ExecutionMode::SingleShot,
            system_prompt: Some("You are a reviewer. Check for accuracy and clarity.".to_string()),
            ..AgentConfig::default()
        },
        llm,
    ).expect("reviewer agent");

    // Orchestrate: research -> write -> review
    let orchestrator = OrchestrationRuntime::new()
        .add_agent("researcher", researcher)
        .add_agent("writer", writer)
        .add_agent("reviewer", reviewer)
        .strategy(OrchestrationStrategy::Sequential);

    let result = orchestrator.run("Write a report on AI safety").await
        .expect("orchestration should succeed");

    println!("Final response: {}", result.final_response);
    println!("Total tokens: {}", result.total_tokens);
    println!("Agents used: {}", result.agent_results.len());
}
```

### Agent with Cost Tracking

```rust
use std::sync::Arc;
use kailash_kaizen::agent::concrete::Agent;
use kailash_kaizen::cost::{CostConfig, CostTracker, MonitoredAgent, ModelRate};
use kailash_kaizen::llm::client::LlmClient;
use kailash_kaizen::types::{AgentConfig, ExecutionMode, MemoryConfig};

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt::init();

    let model = std::env::var("DEFAULT_LLM_MODEL")
        .expect("DEFAULT_LLM_MODEL must be set in .env");

    let llm = LlmClient::from_env().expect("LLM API keys in .env");

    let agent = Agent::new(
        AgentConfig {
            model: Some(model.clone()),
            execution_mode: ExecutionMode::Autonomous,
            memory: MemoryConfig::Session,
            ..AgentConfig::default()
        },
        llm,
    ).expect("agent creation");

    // Configure cost tracking with per-model rates
    let cost_config = CostConfig::new()
        .add_model_rate(ModelRate {
            model: model.clone(),
            input_cost_per_1k: 0.005,
            output_cost_per_1k: 0.015,
        })
        .budget_limit(1.00); // $1.00 budget limit

    let tracker = Arc::new(CostTracker::new(cost_config));

    // Wrap agent with cost monitoring
    let mut monitored = MonitoredAgent::new(agent, tracker.clone());

    let response = monitored.chat("What is Kailash?").await.expect("chat should succeed");
    println!("Response: {response}");

    // Query cost report
    let report = tracker.report();
    println!("Total cost: ${:.6}", report.total_cost);
    println!("Input tokens: {}", report.total_input_tokens);
    println!("Output tokens: {}", report.total_output_tokens);
    println!("Budget remaining: ${:.6}", report.budget_remaining.unwrap_or(f64::INFINITY));
}
```

### Agent with Event Streaming

```rust
use std::sync::Arc;
use kailash_kaizen::agent::concrete::Agent;
use kailash_kaizen::events::AgentEventEmitter;
use kailash_kaizen::llm::client::LlmClient;
use kailash_kaizen::types::{AgentConfig, ExecutionMode};

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt::init();

    let model = std::env::var("DEFAULT_LLM_MODEL")
        .expect("DEFAULT_LLM_MODEL must be set in .env");

    let llm = LlmClient::from_env().expect("LLM API keys in .env");

    let mut agent = Agent::new(
        AgentConfig {
            model: Some(model),
            execution_mode: ExecutionMode::Autonomous,
            ..AgentConfig::default()
        },
        llm,
    ).expect("agent creation");

    // Create event emitter for UI streaming
    let emitter = AgentEventEmitter::new();
    let mut receiver = emitter.subscribe();

    // Attach emitter to agent
    agent.set_event_emitter(emitter);

    // Spawn a task to consume events (for UI streaming)
    let event_task = tokio::spawn(async move {
        while let Ok(event) = receiver.recv().await {
            println!("[EVENT] {}: {}", event.event_type, event.data);
        }
    });

    let response = agent.chat("Explain quantum computing").await.expect("chat");
    println!("Response: {response}");

    drop(agent); // Close emitter channel
    let _ = event_task.await;
}
```

### Test Template

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use kailash_kaizen::llm::client::LlmClient;
    use kailash_kaizen::types::{AgentConfig, ExecutionMode, LlmProvider, MemoryConfig};
    use wiremock::matchers::{method, path};
    use wiremock::{Mock, MockServer, ResponseTemplate};

    fn test_config(model: &str) -> AgentConfig {
        AgentConfig {
            model: Some(model.to_string()),
            execution_mode: ExecutionMode::SingleShot,
            memory: MemoryConfig::Session,
            ..AgentConfig::default()
        }
    }

    fn test_llm_client(mock_uri: &str) -> LlmClient {
        LlmClient::new()
            .with_openai_key("test-key-not-real")
            .with_base_url(LlmProvider::OpenAi, mock_uri)
            .with_max_retries(0)
    }

    fn openai_response_json(content: &str) -> serde_json::Value {
        serde_json::json!({
            "id": "chatcmpl-test",
            "object": "chat.completion",
            "created": 1700000000_u64,
            "model": "gpt-5",
            "choices": [{
                "index": 0,
                "message": { "role": "assistant", "content": content },
                "finish_reason": "stop"
            }],
            "usage": { "prompt_tokens": 10, "completion_tokens": 20, "total_tokens": 30 }
        })
    }

    #[tokio::test]
    async fn {agent_name_snake}_responds_to_chat() {
        let server = MockServer::start().await;
        Mock::given(method("POST"))
            .and(path("/chat/completions"))
            .respond_with(
                ResponseTemplate::new(200).set_body_json(openai_response_json("Test response")),
            )
            .mount(&server)
            .await;

        let config = test_config("gpt-5");
        let llm = test_llm_client(&server.uri());
        let mut agent = Agent::new(config, llm).expect("should create agent");

        let result = agent.chat("Hello").await;
        assert!(result.is_ok());
        assert_eq!(result.expect("ok"), "Test response");
    }

    #[tokio::test]
    async fn {agent_name_snake}_maintains_conversation_history() {
        let server = MockServer::start().await;
        Mock::given(method("POST"))
            .and(path("/chat/completions"))
            .respond_with(
                ResponseTemplate::new(200).set_body_json(openai_response_json("Reply")),
            )
            .expect(2)
            .mount(&server)
            .await;

        let config = AgentConfig {
            model: Some("gpt-5".to_string()),
            execution_mode: ExecutionMode::Autonomous,
            ..AgentConfig::default()
        };
        let llm = test_llm_client(&server.uri());
        let mut agent = Agent::new(config, llm).expect("should create");

        agent.chat("First").await.expect("first call");
        agent.chat("Second").await.expect("second call");

        assert_eq!(agent.conversation().len(), 4); // 2 user + 2 assistant
    }
}
```

## Verify

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo test -p kailash-kaizen && cargo clippy -p kailash-kaizen -- -D warnings
```
