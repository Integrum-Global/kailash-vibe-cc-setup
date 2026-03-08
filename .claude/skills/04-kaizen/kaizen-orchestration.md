---
name: kaizen-orchestration
description: "Multi-agent orchestration for Kaizen. Use when asking about OrchestrationRuntime, orchestration strategies (Sequential, Parallel, Hierarchical, Pipeline), WorkerAgent, SupervisorAgent, MultiAgentOrchestrator, AgentExecutor, or multi-agent coordination."
---

# Kaizen Orchestration: Multi-Agent Coordination

The orchestration module provides three coordination patterns:

1. **`OrchestrationRuntime`** -- Strategy-based runtime (Sequential/Parallel/Hierarchical/Pipeline)
2. **`SupervisorAgent` + `WorkerAgent`** -- Capability-based task delegation
3. **`MultiAgentOrchestrator`** -- Conditional routing with dependency tracking

Plus **`AgentExecutor`** for unified execution with retry, timeout, and observability.

## OrchestrationRuntime

Builder-pattern runtime using `OrchestrationStrategy`. Agents are stored in insertion order.

```rust
use kailash_kaizen::orchestration::{
    OrchestrationRuntime, OrchestrationStrategy, OrchestrationConfig,
};

let runtime = OrchestrationRuntime::new()
    .add_agent("researcher", researcher_agent)
    .add_agent("writer", writer_agent)
    .strategy(OrchestrationStrategy::Sequential)
    .config(OrchestrationConfig {
        max_total_iterations: 50,
        max_agent_calls: 100,
        timeout_secs: Some(120),
        fail_fast: true,
        share_conversation_history: false,
    });

let result = runtime.run("Write about Rust").await?;
println!("Output: {}", result.final_output);
println!("Tokens: {}", result.total_tokens);
println!("Duration: {}ms", result.duration_ms);
```

### Builder Methods

```rust
// All builder methods consume and return self:
OrchestrationRuntime::new()                           // Default: Sequential strategy
    .add_agent("name", impl BaseAgent + 'static)      // Add agent by value
    .add_agent_arc("name", Arc<dyn BaseAgent>)         // Add pre-wrapped agent
    .strategy(OrchestrationStrategy::Parallel)         // Set strategy
    .shared_memory(Arc<dyn AgentMemory>)               // Set shared memory
    .config(OrchestrationConfig { ... })               // Set config

// Introspection:
runtime.agent_count() -> usize
runtime.agent_names() -> Vec<&str>
runtime.current_strategy() -> &OrchestrationStrategy
runtime.get_shared_memory() -> Option<&Arc<dyn AgentMemory>>
```

### Sequential Strategy

Agents run in insertion order. Each receives the previous agent's response as input.

```rust
let runtime = OrchestrationRuntime::new()
    .add_agent("a", agent_a)
    .add_agent("b", agent_b)
    .add_agent("c", agent_c)
    .strategy(OrchestrationStrategy::Sequential);

let result = runtime.run("input").await?;
// a("input") -> b(a_output) -> c(b_output)
// result.final_output == c's response
```

### Parallel Strategy

All agents run concurrently via `tokio::task::JoinSet` with the same input.

```rust
let config = OrchestrationConfig {
    fail_fast: true,   // Stop on first error (default)
    ..Default::default()
};
// fail_fast: false -- collects all results, omits failed agents

let runtime = OrchestrationRuntime::new()
    .add_agent("a", agent_a)
    .add_agent("b", agent_b)
    .strategy(OrchestrationStrategy::Parallel)
    .config(config);

let result = runtime.run("analyze").await?;
// Both receive "analyze" concurrently
// result.final_output concatenates with "--- name ---" headers
```

### Hierarchical Strategy

A coordinator agent runs first. Sub-agents run with the coordinator's output.

```rust
let runtime = OrchestrationRuntime::new()
    .add_agent("coordinator", coordinator)
    .add_agent("data_analyst", analyst)
    .add_agent("writer", writer)
    .strategy(OrchestrationStrategy::Hierarchical {
        coordinator_name: "coordinator".to_string(),
    });
// Error if coordinator_name not in registered agents
```

### Pipeline Strategy

Explicit step ordering with configurable input routing via `PipelineInputSource`.

```rust
use kailash_kaizen::orchestration::{PipelineStep, PipelineInputSource};

let runtime = OrchestrationRuntime::new()
    .add_agent("a", agent_a)
    .add_agent("b", agent_b)
    .strategy(OrchestrationStrategy::Pipeline {
        steps: vec![
            PipelineStep {
                agent_name: "a".to_string(),
                input_from: PipelineInputSource::Initial, // Original input
            },
            PipelineStep {
                agent_name: "b".to_string(),
                input_from: PipelineInputSource::AgentOutput("a".to_string()), // a's output
            },
        ],
    });

// Template interpolation with {{agent_name.response}} placeholders:
PipelineStep {
    agent_name: "b".to_string(),
    input_from: PipelineInputSource::Template(
        "Research: {{a.response}}\nWrite a report.".to_string()
    ),
}
```

### OrchestrationResult

```rust
pub struct OrchestrationResult {
    pub agent_results: IndexMap<String, AgentResult>,  // Per-agent results in execution order
    pub final_output: String,                          // Last agent's response or aggregation
    pub total_iterations: u32,                         // Number of agent invocations
    pub total_tokens: u64,                             // Sum of all agents' tokens
    pub duration_ms: u64,                              // Wall-clock duration
}
```

### Shared Memory

When shared memory is set, agents with `run_with_memory()` use it for inter-agent communication.

```rust
use kailash_kaizen::memory::{AgentMemory, SharedMemory};

let shared: Arc<dyn AgentMemory> = Arc::new(SharedMemory::new());
let runtime = OrchestrationRuntime::new()
    .add_agent("writer", writer)
    .add_agent("reader", reader)
    .shared_memory(shared)
    .strategy(OrchestrationStrategy::Sequential);
```

## WorkerAgent

Wraps any `BaseAgent` with capability declarations, status tracking, and progress reporting.

```rust
use kailash_kaizen::orchestration::worker::{WorkerAgent, WorkerStatus};

let worker = WorkerAgent::new("coder", inner_agent)       // name + impl BaseAgent
    .with_capabilities(vec!["python", "rust", "code"])     // case-insensitive matching
    .with_description("writes code");                       // optional override

// Capability matching
worker.accept_task("write python code");  // true (contains "python")
worker.accept_task("design a logo");      // false
// No capabilities = accepts all tasks

// Status tracking (atomic, lock-free)
worker.status() -> WorkerStatus           // Idle | Working | Failed
// Transitions: Idle -> Working (on run) -> Idle (on success) | Failed (on error)

// Progress reporting
worker.report_progress(0.5);              // Clamped to [0.0, 1.0]
worker.current_progress() -> f32          // Returns 0.0..=1.0
worker.progress_handle() -> Arc<AtomicU32> // Clone for external polling

// Heartbeat
worker.heartbeat();                       // Records timestamp
worker.last_heartbeat() -> u32            // Milliseconds since Unix epoch (u32)

// Construction from Arc
WorkerAgent::from_arc("name", Arc<dyn BaseAgent>)

// Implements BaseAgent -- delegates run() to inner agent
let result = worker.run("task").await?;
```

## SupervisorAgent

Delegates tasks to managed `WorkerAgent`s via configurable routing strategies.

```rust
use kailash_kaizen::orchestration::supervisor::{SupervisorAgent, RoutingStrategy};

let mut supervisor = SupervisorAgent::new("boss");
supervisor.add_worker(worker1);                         // WorkerAgent by value
supervisor.add_worker_arc(Arc::clone(&shared_worker));  // WorkerAgent by Arc
supervisor.set_routing_strategy(RoutingStrategy::Capability); // Default
supervisor.set_max_delegation_depth(3);                 // Default: 3
supervisor.set_description("manages the team");

// Routing strategies:
RoutingStrategy::RoundRobin     // Cycles through workers sequentially
RoutingStrategy::Capability     // Matches task keywords to worker capabilities (default)
RoutingStrategy::LlmDecision    // Falls back to Capability in current impl
RoutingStrategy::Custom(Arc<dyn Fn(&str, &[(&str, &[String])]) -> usize + Send + Sync>)

// Introspection:
supervisor.worker_count() -> usize
supervisor.worker_names() -> Vec<&str>
supervisor.worker_statuses() -> Vec<(&str, WorkerStatus)>
supervisor.routing_strategy() -> &RoutingStrategy
supervisor.max_delegation_depth() -> u32

// Implements BaseAgent -- routes task to a worker
let result = supervisor.run("Write Python code").await?;
// Error if no workers registered or delegation depth exceeded
```

## MultiAgentOrchestrator

Dynamic agent selection with conditional routing, dependency tracking, and concurrent execution.

```rust
use kailash_kaizen::orchestration::multi_agent::{MultiAgentOrchestrator, RoutingCondition};

let mut orchestrator = MultiAgentOrchestrator::new();

// Register agents
orchestrator.add_agent("researcher", researcher_agent);
orchestrator.add_agent_arc("writer", Arc::clone(&writer));

// Add routing rules (condition -> agent)
orchestrator.add_route(RoutingCondition::Always, "researcher");
orchestrator.add_route(RoutingCondition::Contains("code".to_string()), "coder");
orchestrator.add_route(RoutingCondition::Regex("^analyze".to_string()), "analyst");
orchestrator.add_route(RoutingCondition::Custom(Arc::new(|input| input.len() > 100)), "long-handler");

// Declare dependencies (topological sort, cycle detection)
orchestrator.add_dependency("writer", "researcher"); // writer waits for researcher

// Configuration
orchestrator.set_concurrency_limit(10); // Default: 10 (min: 1)
orchestrator.set_aggregator(|results| { // Custom result aggregation
    format!("Combined: {}", results.len())
});

// Introspection
orchestrator.agent_count() -> usize
orchestrator.agent_names() -> Vec<&str>

// Run
let result = orchestrator.orchestrate("Write about Rust").await?;
// Returns OrchestrationResult with agent_results, final_output, total_tokens
```

### Execution Model

1. **Route selection**: Evaluate each route's condition against input. Matching agents form the execution set.
2. **Dependency resolution**: Topological sort (Kahn's algorithm). Circular dependencies rejected.
3. **Concurrent execution**: Independent agents run concurrently (up to concurrency limit). Dependent agents receive their dependency's output.
4. **Result aggregation**: Custom aggregator or default (single agent = its output; multiple = concatenated with `--- name ---` headers).

## AgentExecutor

Unified execution with retry, timeout, and observability hooks.

```rust
use kailash_kaizen::orchestration::executor::{
    AgentExecutor, RetryPolicy, BackoffStrategy, ExecutionHooks,
};
use std::time::Duration;

let executor = AgentExecutor::new()
    .with_retry_policy(RetryPolicy {
        max_retries: 3,
        backoff: BackoffStrategy::Exponential {
            base: Duration::from_millis(100),
            max: Duration::from_secs(5),
        },
        retryable_errors: vec![],  // Empty = all errors retryable
    })
    .with_agent_timeout(Duration::from_secs(30))
    .with_global_timeout(Duration::from_secs(120))
    .with_hooks(ExecutionHooks {
        on_agent_start: Some(Arc::new(|name, input| println!("{name} started"))),
        on_agent_complete: Some(Arc::new(|name, response| println!("{name} done"))),
        on_agent_error: Some(Arc::new(|name, err| eprintln!("{name}: {err}"))),
        on_retry: Some(Arc::new(|name, attempt| println!("{name} retry {attempt}"))),
    })
    .with_observability(Arc::new(ObservabilityManager::new()));

// Single agent execution
let result = executor.execute_single(&agent, "hello").await?;

// Multi-agent execution via OrchestrationRuntime
let result = executor.execute_multi(&runtime, "hello").await?;

// BackoffStrategy variants:
BackoffStrategy::Fixed(Duration::from_millis(100))           // Same delay every retry
BackoffStrategy::Exponential { base, max }                    // 100ms, 200ms, 400ms... capped at max

// Introspection:
executor.retry_policy() -> &RetryPolicy
executor.agent_timeout() -> Option<Duration>
executor.global_timeout() -> Option<Duration>
```

## Python Binding

```python
from kailash import WorkerAgent, SupervisorAgent, MultiAgentOrchestrator, AgentExecutor, RetryPolicy

# WorkerAgent wraps a Python callable
def code_fn(input: str) -> str:
    return f"coded: {input}"

worker = WorkerAgent("coder", code_fn, capabilities=["python", "rust"])
assert worker.accept_task("write python code")
assert worker.status == "idle"
result = worker.run("hello")  # returns dict with "response", "total_tokens", etc.

# SupervisorAgent delegates to workers
supervisor = SupervisorAgent("boss", routing="capability", max_delegation_depth=3)
# routing: "round_robin" | "capability" | "llm_decision"
supervisor.add_worker(worker)
result = supervisor.run("Write Python code")

# MultiAgentOrchestrator with conditional routing
orch = MultiAgentOrchestrator()
orch.add_agent("researcher", research_fn)
orch.add_agent("writer", write_fn)
orch.add_route("always", "researcher")
orch.add_route("contains:code", "coder")
orch.add_custom_route(lambda input: len(input) > 50, "long_handler")
orch.add_dependency("writer", "researcher")
orch.set_concurrency_limit(5)
result = orch.orchestrate("Write about Rust")  # dict: final_output, agent_results, total_tokens

# AgentExecutor with retry and timeout
policy = RetryPolicy(max_retries=3, backoff="exponential", base_delay_ms=100, max_delay_ms=5000)
# backoff: "fixed" | "exponential"
executor = AgentExecutor(retry_policy=policy, agent_timeout_ms=30000, global_timeout_ms=120000)
result = executor.execute_single(worker, "hello")
```

## Source Files

- `crates/kailash-kaizen/src/orchestration/runtime.rs` -- `OrchestrationRuntime`, `OrchestrationConfig`, `OrchestrationResult`
- `crates/kailash-kaizen/src/orchestration/strategies.rs` -- `OrchestrationStrategy`, `PipelineStep`, `PipelineInputSource`
- `crates/kailash-kaizen/src/orchestration/worker.rs` -- `WorkerAgent`, `WorkerStatus`
- `crates/kailash-kaizen/src/orchestration/supervisor.rs` -- `SupervisorAgent`, `RoutingStrategy`
- `crates/kailash-kaizen/src/orchestration/multi_agent.rs` -- `MultiAgentOrchestrator`, `RoutingCondition`
- `crates/kailash-kaizen/src/orchestration/executor.rs` -- `AgentExecutor`, `RetryPolicy`, `BackoffStrategy`, `ExecutionHooks`
- `bindings/kailash-python/src/kaizen/orchestration.rs` -- Python bindings

<!-- Trigger Keywords: orchestration, OrchestrationRuntime, multi-agent, Sequential, Parallel, Hierarchical, Pipeline, PipelineStep, WorkerAgent, SupervisorAgent, MultiAgentOrchestrator, AgentExecutor, RetryPolicy, strategy, coordination, routing, delegation -->
