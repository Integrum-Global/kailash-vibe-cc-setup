---
name: kaizen-quickstart
description: "First AI agent in 5 minutes with kailash-kaizen. Use when asking 'kaizen quickstart', 'kaizen getting started', 'first agent', or 'agent hello world'."
---

# Kaizen Quickstart Skill

First AI agent in 5 minutes with kailash-kaizen.

## Usage

`/kaizen-quickstart` -- Fastest path to a working AI agent: .env setup, LlmClient, Agent::new(), run()

## Prerequisites: .env Setup

All model names and API keys MUST come from `.env`. Never hardcode them.

```bash
# .env
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
GOOGLE_API_KEY=AIza...

# Model names (choose one as default)
DEFAULT_LLM_MODEL=gpt-5
OPENAI_PROD_MODEL=gpt-5
ANTHROPIC_PROD_MODEL=claude-opus-4-6
```

## Minimal Agent

```rust
use kailash_kaizen::agent::concrete::Agent;
use kailash_kaizen::llm::client::LlmClient;
use kailash_kaizen::types::{AgentConfig, ExecutionMode};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenvy::dotenv().ok();  // MUST be first

    // Read model from .env -- NEVER hardcode
    let model = std::env::var("DEFAULT_LLM_MODEL")
        .or_else(|_| std::env::var("OPENAI_PROD_MODEL"))
        .expect("No LLM model configured in .env");

    let config = AgentConfig {
        model: Some(model),
        execution_mode: ExecutionMode::SingleShot,  // One response, no TAOD loop
        ..AgentConfig::default()
    };

    let llm = LlmClient::from_env()?;

    let mut agent = Agent::new(config, llm)?;

    let response = agent.chat("What is 2 + 2?").await?;
    println!("Response: {response}");
    Ok(())
}
```

## LlmClient::from_env()

The preferred way to create an LLM client (reads model and key from .env automatically):

```rust
use kailash_kaizen::LlmClient;

dotenv().ok();

// Reads DEFAULT_LLM_MODEL (or OPENAI_PROD_MODEL) + matching API key
let client = LlmClient::from_env()?;

// Or specify a specific .env variable name
let client = LlmClient::from_env_var("ANTHROPIC_PROD_MODEL")?;
```

## ExecutionMode

```rust
pub enum ExecutionMode {
    /// One LLM call, return response (no tool use, no iterations)
    SingleShot,

    /// TAOD loop: Think-Act-Observe-Decide until convergence
    /// Uses tools iteratively until goal is achieved
    Autonomous,

    /// Like Autonomous but waits for human approval before each action
    HumanInLoop,
}
```

## Agent with Tools

Tools are Rust functions the agent can call to take actions.

```rust
use std::sync::Arc;
use kailash_kaizen::agent::concrete::Agent;
use kailash_kaizen::agent::tools::{FnTool, ToolDef, ToolParam, ToolParamType, ToolRegistry};
use kailash_kaizen::llm::client::LlmClient;
use kailash_kaizen::types::{AgentConfig, ExecutionMode};
use kailash_value::Value;

dotenvy::dotenv().ok();
let model = std::env::var("DEFAULT_LLM_MODEL").expect("DEFAULT_LLM_MODEL in .env");

let llm = LlmClient::from_env()?;

// Define a tool using ToolDef + FnTool
let mut tools = ToolRegistry::new();
tools.register(ToolDef::new(
    "search_web",
    "Search the web for information",
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

let config = AgentConfig {
    model: Some(model),
    execution_mode: ExecutionMode::Autonomous,
    ..AgentConfig::default()
};

let mut agent = Agent::new(config, llm)?
    .with_tools(tools);

let response = agent.chat("What is the latest news about Rust 2.0?").await?;
println!("Response: {response}");
```

## Memory Types

```rust
pub enum MemoryConfig {
    /// No memory -- each run is stateless
    None,

    /// Session memory -- remembers within a single agent lifetime (HashMap)
    Session,
}

let config = AgentConfig {
    model: Some(model),
    execution_mode: ExecutionMode::Autonomous,
    memory: MemoryConfig::Session,  // Remember conversation history
    ..AgentConfig::default()
};

let llm = LlmClient::from_env()?;
let mut agent = Agent::new(config, llm)?;

// Subsequent calls remember previous context
agent.chat("My name is Alice").await?;
let response = agent.chat("What is my name?").await?;
// response: "Your name is Alice"
```

## Multi-Agent Orchestration

```rust
use kailash_kaizen::agent::concrete::Agent;
use kailash_kaizen::llm::client::LlmClient;
use kailash_kaizen::orchestration::runtime::OrchestrationRuntime;
use kailash_kaizen::types::{AgentConfig, ExecutionMode, OrchestrationStrategy};

dotenvy::dotenv().ok();
let model = std::env::var("DEFAULT_LLM_MODEL").expect("No model in .env");
let llm = LlmClient::from_env()?;

let researcher = Agent::new(
    AgentConfig {
        model: Some(model.clone()),
        system_prompt: Some("You are a research expert. Find facts.".to_string()),
        execution_mode: ExecutionMode::Autonomous,
        ..AgentConfig::default()
    },
    llm.clone(),
).expect("researcher agent");

let writer = Agent::new(
    AgentConfig {
        model: Some(model),
        system_prompt: Some("You are a writer. Turn facts into clear prose.".to_string()),
        execution_mode: ExecutionMode::SingleShot,
        ..AgentConfig::default()
    },
    llm,
).expect("writer agent");

let orchestrator = OrchestrationRuntime::new()
    .add_agent("researcher", researcher)
    .add_agent("writer", writer)
    .strategy(OrchestrationStrategy::Sequential);  // researcher → writer

let result = orchestrator.run("Write a short article about Rust performance").await?;
println!("{}", result.final_output);
```

## Cost Tracking

```rust
use std::sync::Arc;
use kailash_kaizen::agent::concrete::Agent;
use kailash_kaizen::cost::{CostConfig, CostTracker, MonitoredAgent, ModelRate};
use kailash_kaizen::llm::client::LlmClient;
use kailash_kaizen::types::{AgentConfig, ExecutionMode, MemoryConfig};

dotenvy::dotenv().ok();
let model = std::env::var("DEFAULT_LLM_MODEL").expect("DEFAULT_LLM_MODEL in .env");
let llm = LlmClient::from_env()?;

let agent = Agent::new(
    AgentConfig {
        model: Some(model.clone()),
        execution_mode: ExecutionMode::Autonomous,
        memory: MemoryConfig::Session,
        ..AgentConfig::default()
    },
    llm,
)?;

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

let response = monitored.chat("Explain quantum computing").await?;
println!("Response: {response}");

let report = tracker.report();
println!("Total cost: ${:.6}", report.total_cost);
println!("Input tokens: {}", report.total_input_tokens);
println!("Output tokens: {}", report.total_output_tokens);
```

## AgentResult Fields

```rust
pub struct AgentResult {
    /// Final text response from the agent
    pub response: String,

    /// Session identifier for conversation continuity
    pub session_id: Option<String>,

    /// Number of TAOD iterations performed
    pub iterations: u32,

    /// Number of tool calls made during this run
    pub tool_calls_made: u32,

    /// Total tokens consumed (prompt + completion)
    pub total_tokens: u64,

    /// Prompt/input tokens consumed
    pub prompt_tokens: u64,

    /// Completion/output tokens consumed
    pub completion_tokens: u64,

    /// Execution duration in milliseconds
    pub duration_ms: u64,
}
```

## Verify

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo test -p kailash-kaizen -- --nocapture 2>&1
```
