---
name: track-costs
description: "Configure LLM cost tracking for Kaizen agents with per-model rates, budget limits, and cost reporting. Use when asking 'cost tracking', 'LLM costs', 'agent budget', 'CostTracker', or 'token usage'."
---

# Track Costs Skill

Configure LLM cost tracking for Kaizen agents with per-model rates, budget limits, and cost reporting.

## Usage

`/track-costs` -- Set up cost tracking for Kaizen agents with CostConfig, CostTracker, and MonitoredAgent

## Steps

1. Read existing cost tracking patterns from:
   - `crates/kailash-kaizen/src/cost/mod.rs` -- CostTracker, CostConfig, CostReport
   - `crates/kailash-kaizen/src/cost/rates.rs` -- ModelRate, per-model pricing
   - `crates/kailash-kaizen/src/cost/monitored.rs` -- MonitoredAgent wrapper

2. Configure `CostConfig` with per-model rates for each LLM provider in use. Read model names from `.env` (NEVER hardcode).

3. Create a `CostTracker` with the config and optional budget limit.

4. Wrap agents with `MonitoredAgent` to automatically track token usage and costs.

5. Query `CostTracker::report()` for cost breakdowns, budget remaining, and per-model usage.

## Template

### Basic Cost Tracking

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

    // Read model from .env -- NEVER hardcode
    let model = std::env::var("DEFAULT_LLM_MODEL")
        .expect("DEFAULT_LLM_MODEL must be set in .env");

    let llm = LlmClient::from_env().expect("LLM API keys must be set in .env");

    // 1. Configure per-model rates (cost per 1K tokens)
    let cost_config = CostConfig::new()
        .add_model_rate(ModelRate {
            model: model.clone(),
            input_cost_per_1k: 0.005,   // $0.005 per 1K input tokens
            output_cost_per_1k: 0.015,  // $0.015 per 1K output tokens
        })
        // Add rates for other models you may use
        .add_model_rate(ModelRate {
            model: "claude-3-5-sonnet-20241022".to_string(),
            input_cost_per_1k: 0.003,
            output_cost_per_1k: 0.015,
        });

    // 2. Create tracker with budget limit
    let tracker = Arc::new(CostTracker::new(cost_config));

    // 3. Create agent
    let agent = Agent::new(
        AgentConfig {
            model: Some(model),
            execution_mode: ExecutionMode::Autonomous,
            memory: MemoryConfig::Session,
            ..AgentConfig::default()
        },
        llm,
    ).expect("agent creation should succeed");

    // 4. Wrap with cost monitoring
    let mut monitored = MonitoredAgent::new(agent, tracker.clone());

    // 5. Use the agent normally -- costs are tracked automatically
    let response = monitored.chat("Explain quantum computing in 3 sentences")
        .await
        .expect("chat should succeed");
    println!("Response: {response}");

    // 6. Query cost report
    let report = tracker.report();
    println!("\n--- Cost Report ---");
    println!("Total cost:        ${:.6}", report.total_cost);
    println!("Input tokens:      {}", report.total_input_tokens);
    println!("Output tokens:     {}", report.total_output_tokens);
    println!("Total requests:    {}", report.total_requests);
}
```

### Cost Tracking with Budget Limits

```rust
use std::sync::Arc;
use kailash_kaizen::agent::concrete::Agent;
use kailash_kaizen::cost::{CostConfig, CostTracker, MonitoredAgent, ModelRate, BudgetExceeded};
use kailash_kaizen::llm::client::LlmClient;
use kailash_kaizen::types::{AgentConfig, ExecutionMode, MemoryConfig};

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt::init();

    let model = std::env::var("DEFAULT_LLM_MODEL")
        .expect("DEFAULT_LLM_MODEL must be set in .env");

    let llm = LlmClient::from_env().expect("LLM API keys in .env");

    // Set a strict budget limit
    let cost_config = CostConfig::new()
        .add_model_rate(ModelRate {
            model: model.clone(),
            input_cost_per_1k: 0.005,
            output_cost_per_1k: 0.015,
        })
        .budget_limit(0.50); // $0.50 budget limit

    let tracker = Arc::new(CostTracker::new(cost_config));

    let agent = Agent::new(
        AgentConfig {
            model: Some(model),
            execution_mode: ExecutionMode::Autonomous,
            memory: MemoryConfig::Session,
            ..AgentConfig::default()
        },
        llm,
    ).expect("agent creation");

    let mut monitored = MonitoredAgent::new(agent, tracker.clone());

    // Run multiple requests -- budget is enforced
    for i in 1..=10 {
        match monitored.chat(&format!("Question {i}: Tell me a fact.")).await {
            Ok(response) => {
                let report = tracker.report();
                println!("[{i}] Cost so far: ${:.6} / ${:.6}",
                    report.total_cost,
                    report.budget_remaining.map(|r| r + report.total_cost).unwrap_or(0.0)
                );
            }
            Err(e) => {
                // Budget exceeded -- MonitoredAgent returns error before calling LLM
                println!("[{i}] Budget exceeded: {e}");
                break;
            }
        }
    }

    // Final report
    let report = tracker.report();
    println!("\n--- Final Cost Report ---");
    println!("Total cost:         ${:.6}", report.total_cost);
    println!("Budget remaining:   ${:.6}", report.budget_remaining.unwrap_or(f64::INFINITY));
    println!("Total requests:     {}", report.total_requests);
}
```

### Multi-Agent Cost Tracking

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

    // Shared cost tracker across multiple agents
    let cost_config = CostConfig::new()
        .add_model_rate(ModelRate {
            model: model.clone(),
            input_cost_per_1k: 0.005,
            output_cost_per_1k: 0.015,
        })
        .budget_limit(5.00); // $5.00 shared budget

    let tracker = Arc::new(CostTracker::new(cost_config));

    // Create multiple agents sharing the same tracker
    let researcher = Agent::new(
        AgentConfig {
            model: Some(model.clone()),
            execution_mode: ExecutionMode::SingleShot,
            system_prompt: Some("You are a researcher.".to_string()),
            ..AgentConfig::default()
        },
        llm.clone(),
    ).expect("researcher agent");

    let writer = Agent::new(
        AgentConfig {
            model: Some(model),
            execution_mode: ExecutionMode::SingleShot,
            system_prompt: Some("You are a writer.".to_string()),
            ..AgentConfig::default()
        },
        llm,
    ).expect("writer agent");

    let mut monitored_researcher = MonitoredAgent::new(researcher, tracker.clone());
    let mut monitored_writer = MonitoredAgent::new(writer, tracker.clone());

    // Both agents contribute to the same cost tracker
    let research = monitored_researcher.chat("Research AI safety trends")
        .await
        .expect("research should succeed");
    println!("Research: {research}");

    let article = monitored_writer.chat(&format!("Write an article based on: {research}"))
        .await
        .expect("writing should succeed");
    println!("Article: {article}");

    // Unified cost report
    let report = tracker.report();
    println!("\n--- Shared Cost Report ---");
    println!("Total cost:         ${:.6}", report.total_cost);
    println!("Total requests:     {}", report.total_requests);
    println!("Budget remaining:   ${:.6}", report.budget_remaining.unwrap_or(f64::INFINITY));

    // Per-model breakdown (if multiple models used)
    for (model_name, model_report) in &report.per_model {
        println!("  {}: ${:.6} ({} requests)",
            model_name, model_report.cost, model_report.requests);
    }
}
```

### Test Template

```rust
#[cfg(test)]
mod tests {
    use std::sync::Arc;
    use kailash_kaizen::cost::{CostConfig, CostTracker, ModelRate};

    #[test]
    fn tracks_token_costs() {
        let config = CostConfig::new()
            .add_model_rate(ModelRate {
                model: "test-model".to_string(),
                input_cost_per_1k: 0.01,
                output_cost_per_1k: 0.03,
            });

        let tracker = CostTracker::new(config);

        // Record usage: 1000 input tokens, 500 output tokens
        tracker.record_usage("test-model", 1000, 500);

        let report = tracker.report();
        // Input: 1000/1000 * 0.01 = 0.01
        // Output: 500/1000 * 0.03 = 0.015
        // Total: 0.025
        assert!((report.total_cost - 0.025).abs() < 1e-10);
        assert_eq!(report.total_input_tokens, 1000);
        assert_eq!(report.total_output_tokens, 500);
        assert_eq!(report.total_requests, 1);
    }

    #[test]
    fn enforces_budget_limit() {
        let config = CostConfig::new()
            .add_model_rate(ModelRate {
                model: "test-model".to_string(),
                input_cost_per_1k: 1.0, // $1 per 1K tokens
                output_cost_per_1k: 1.0,
            })
            .budget_limit(0.50); // $0.50 limit

        let tracker = CostTracker::new(config);

        // First request: 250 input + 250 output = $0.50 -- at limit
        tracker.record_usage("test-model", 250, 250);
        assert!(tracker.is_within_budget());

        // Check budget before next request
        assert!(!tracker.can_afford("test-model", 100, 100));

        let report = tracker.report();
        assert!((report.budget_remaining.unwrap()).abs() < 1e-10);
    }

    #[test]
    fn unknown_model_uses_zero_rate() {
        let config = CostConfig::new(); // No model rates configured
        let tracker = CostTracker::new(config);

        tracker.record_usage("unknown-model", 1000, 1000);

        let report = tracker.report();
        assert_eq!(report.total_cost, 0.0); // No rate = no cost
        assert_eq!(report.total_input_tokens, 1000);
        assert_eq!(report.total_output_tokens, 1000);
    }
}
```

## Verify

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo test -p kailash-kaizen -- cost && cargo clippy -p kailash-kaizen -- -D warnings
```
