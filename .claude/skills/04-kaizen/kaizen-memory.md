---
name: kaizen-memory
description: "Agent memory system for Kaizen. Use when asking about agent memory, SessionMemory, SharedMemory, NoMemory, memory backends, or persistent storage."
---

# Kaizen Memory: Agent Memory System

The memory system provides key-value storage for agents during TAOD loop iterations and across multi-agent orchestrations.

## Memory Types

| Type            | Backing                        | Thread Safety | Use Case                      |
| --------------- | ------------------------------ | ------------- | ----------------------------- |
| `SessionMemory` | `Mutex<HashMap>`               | `Send + Sync` | Single-agent session storage  |
| `SharedMemory`  | `tokio::sync::RwLock<HashMap>` | `Send + Sync` | Multi-agent concurrent access |
| `NoMemory`      | None (no-op)                   | `Send + Sync` | Stateless agents              |

## The AgentMemory Trait

All memory backends implement this async trait:

```rust
use async_trait::async_trait;
use kailash_kaizen::error::AgentError;
use kailash_value::Value;

#[async_trait]
pub trait AgentMemory: Send + Sync {
    /// Store a value under a key.
    async fn store(&self, key: &str, value: Value) -> Result<(), AgentError>;

    /// Retrieve a value by key. Returns None if not found.
    async fn retrieve(&self, key: &str) -> Result<Option<Value>, AgentError>;

    /// Remove a value by key.
    async fn remove(&self, key: &str) -> Result<(), AgentError>;

    /// List all keys in memory.
    async fn keys(&self) -> Result<Vec<String>, AgentError>;

    /// Clear all data.
    async fn clear(&self) -> Result<(), AgentError>;
}
```

## SessionMemory

In-memory session-scoped storage. Data is lost when the memory instance is dropped. Thread-safe via `std::sync::Mutex`.

```rust
use kailash_kaizen::memory::{AgentMemory, SessionMemory};
use kailash_value::Value;

let mem = SessionMemory::new();

// Store values
mem.store("user_name", Value::from("Alice")).await?;
mem.store("context", Value::from("researching Rust")).await?;

// Retrieve values
let name = mem.retrieve("user_name").await?;
// name == Some(Value::String("Alice"))

let missing = mem.retrieve("nonexistent").await?;
// missing == None

// List keys
let keys = mem.keys().await?;
// keys: ["user_name", "context"]

// Remove a key
mem.remove("context").await?;

// Clear all
mem.clear().await?;
```

## NoMemory

No-op implementation that stores nothing. Use when agents need no memory:

```rust
use kailash_kaizen::memory::{AgentMemory, NoMemory};
use kailash_value::Value;

let mem = NoMemory::new();

// Store silently succeeds but stores nothing
mem.store("key", Value::from("value")).await?;

// Retrieve always returns None
let val = mem.retrieve("key").await?;
assert!(val.is_none());

// Keys always returns empty
let keys = mem.keys().await?;
assert!(keys.is_empty());
```

## SharedMemory

Thread-safe shared memory for multi-agent orchestration. Uses `tokio::sync::RwLock` for concurrent read access with exclusive writes.

```rust
use std::sync::Arc;
use kailash_kaizen::memory::{AgentMemory, SharedMemory};
use kailash_value::Value;

let shared = Arc::new(SharedMemory::new());

// Multiple agents can read concurrently
let mem1 = Arc::clone(&shared);
let mem2 = Arc::clone(&shared);

// Agent 1 writes research findings
mem1.store("research", Value::from("key findings...")).await?;

// Agent 2 reads them
let findings = mem2.retrieve("research").await?;
assert!(findings.is_some());
```

### Concurrent Access Pattern

```rust
use std::sync::Arc;
use kailash_kaizen::memory::{AgentMemory, SharedMemory};
use kailash_value::Value;

let mem = Arc::new(SharedMemory::new());
let mut handles = Vec::new();

// Spawn 10 concurrent writers
for i in 0..10u32 {
    let mem_clone = Arc::clone(&mem);
    handles.push(tokio::spawn(async move {
        mem_clone
            .store(&format!("key_{i}"), Value::from(i as i64))
            .await
            .expect("store should succeed");
    }));
}

for handle in handles {
    handle.await?;
}

let keys = mem.keys().await?;
assert_eq!(keys.len(), 10);
```

## Memory Configuration in AgentConfig

The `MemoryConfig` enum controls which backend an `Agent` uses:

```rust
use kailash_kaizen::types::{AgentConfig, MemoryConfig};

// Session memory (default) -- HashMap-backed, cleared on drop
let config = AgentConfig {
    memory: MemoryConfig::Session,
    ..AgentConfig::default()
};

// No memory -- stateless agent
let config = AgentConfig {
    memory: MemoryConfig::None,
    ..AgentConfig::default()
};
```

## Memory with Concrete Agents

```rust
use kailash_kaizen::agent::concrete::Agent;
use kailash_kaizen::llm::client::LlmClient;
use kailash_kaizen::memory::SharedMemory;
use kailash_kaizen::types::AgentConfig;
use kailash_value::Value;

let config = AgentConfig {
    model: Some(std::env::var("DEFAULT_LLM_MODEL").expect("model in .env")),
    ..AgentConfig::default()
};

let llm = LlmClient::from_env()
    .map_err(|e| kailash_kaizen::error::AgentError::Config(e.to_string()))?;

// Default: SessionMemory
let agent = Agent::new(config, llm)?;

// Or replace with SharedMemory for cross-agent sharing
let agent = agent.with_memory(Box::new(SharedMemory::new()));

// Access memory via the agent
agent.memory().store("key", Value::from("value")).await?;
let val = agent.memory().retrieve("key").await?;
```

## Memory in the TAOD Loop

The `TaodRunner` stores the goal and last response in memory automatically:

```rust
use std::sync::Arc;
use std::time::Duration;
use kailash_kaizen::agent::taod::{TaodConfig, TaodRunner};
use kailash_kaizen::agent::tools::ToolRegistry;
use kailash_kaizen::llm::client::LlmClient;
use kailash_kaizen::memory::SessionMemory;

let memory = Box::new(SessionMemory::new());

let config = TaodConfig {
    max_iterations: 5,
    timeout: Duration::from_secs(120),
    system_prompt: None,
    model: std::env::var("DEFAULT_LLM_MODEL").expect("model in .env"),
    temperature: None,
    max_tokens: None,
};

let llm = Arc::new(LlmClient::from_env()
    .map_err(|e| kailash_kaizen::error::AgentError::Config(e.to_string()))?);
let tools = Arc::new(ToolRegistry::new());

let mut runner = TaodRunner::new(llm, tools, memory, config);
let result = runner.run("Research quantum computing").await?;
// Memory now contains:
//   "goal" -> "Research quantum computing"
//   "last_response" -> result.final_response
```

## Memory in Multi-Agent Orchestration

Use `SharedMemory` with `OrchestrationRuntime` for inter-agent communication:

```rust
use std::sync::Arc;
use kailash_kaizen::memory::{AgentMemory, SharedMemory};
use kailash_kaizen::orchestration::{OrchestrationRuntime, OrchestrationStrategy};

let shared: Arc<dyn AgentMemory> = Arc::new(SharedMemory::new());

let runtime = OrchestrationRuntime::new()
    .add_agent("researcher", researcher_agent)
    .add_agent("writer", writer_agent)
    .shared_memory(shared)
    .strategy(OrchestrationStrategy::Sequential);

// The researcher stores findings in shared memory.
// The writer reads them via run_with_memory().
let result = runtime.run("Write about Rust performance").await?;
```

Agents access shared memory by overriding `BaseAgent::run_with_memory`:

```rust
use std::sync::Arc;
use async_trait::async_trait;
use kailash_kaizen::agent::BaseAgent;
use kailash_kaizen::error::AgentError;
use kailash_kaizen::memory::AgentMemory;
use kailash_kaizen::types::AgentResult;
use kailash_value::Value;

struct ResearchAgent;

#[async_trait]
impl BaseAgent for ResearchAgent {
    fn name(&self) -> &str { "researcher" }
    fn description(&self) -> &str { "Researches topics" }

    async fn run(&self, input: &str) -> Result<AgentResult, AgentError> {
        // Default implementation without shared memory
        Ok(AgentResult {
            response: format!("Researched: {input}"),
            session_id: uuid::Uuid::new_v4(),
            iterations: 1,
            tool_calls_made: 0,
            total_tokens: 0,
            prompt_tokens: 0,
            completion_tokens: 0,
            duration_ms: 0,
        })
    }

    async fn run_with_memory(
        &self,
        input: &str,
        shared_memory: Arc<dyn AgentMemory>,
    ) -> Result<AgentResult, AgentError> {
        // Store findings in shared memory for other agents
        shared_memory
            .store("research_findings", Value::from("key findings..."))
            .await?;

        self.run(input).await
    }
}
```

## Implementing a Custom Memory Backend

```rust
use async_trait::async_trait;
use kailash_kaizen::error::AgentError;
use kailash_kaizen::memory::AgentMemory;
use kailash_value::Value;

struct RedisMemory {
    // redis client handle
}

#[async_trait]
impl AgentMemory for RedisMemory {
    async fn store(&self, key: &str, value: Value) -> Result<(), AgentError> {
        // Serialize value and store in Redis
        let json = serde_json::to_string(&value)
            .map_err(|e| AgentError::MemoryError(e.to_string()))?;
        // redis_client.set(key, json).await...
        Ok(())
    }

    async fn retrieve(&self, key: &str) -> Result<Option<Value>, AgentError> {
        // Get from Redis and deserialize
        // let json = redis_client.get(key).await...
        Ok(None)
    }

    async fn remove(&self, key: &str) -> Result<(), AgentError> {
        // redis_client.del(key).await...
        Ok(())
    }

    async fn keys(&self) -> Result<Vec<String>, AgentError> {
        // redis_client.keys("*").await...
        Ok(Vec::new())
    }

    async fn clear(&self) -> Result<(), AgentError> {
        // redis_client.flushdb().await...
        Ok(())
    }
}
```

<!-- Trigger Keywords: memory, AgentMemory, SessionMemory, SharedMemory, NoMemory, MemoryConfig, agent storage, shared memory, multi-agent memory -->
