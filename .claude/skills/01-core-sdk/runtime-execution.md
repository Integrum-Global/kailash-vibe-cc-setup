# Runtime Execution Skill

Configuration and execution patterns for the Kailash Runtime.

## Usage

`/runtime-execution` -- Reference for RuntimeConfig, execute() vs execute_sync(), and reading results

## The Runtime

```rust
use kailash_core::{Runtime, RuntimeConfig, NodeRegistry};
use kailash_value::ValueMap;
use std::sync::Arc;

// Runtime is created once and reused across workflow executions
let runtime = Runtime::new(RuntimeConfig::default(), Arc::new(registry));

// Async execution (preferred for services)
let result = runtime.execute(&workflow, inputs).await?;

// Sync execution (for CLI, scripts, tests without async context)
let result = runtime.execute_sync(&workflow, inputs)?;
```

## RuntimeConfig

```rust
use kailash_core::RuntimeConfig;

let config = RuntimeConfig {
    // Enable debug logging for node execution (very verbose)
    debug: false,

    // Allow workflows with cycles (default: false, DAG only)
    enable_cycles: false,

    // What to do when a conditional branch is not taken
    // SkipBranches: skip nodes on unmet branches (default)
    // EvaluateAll: evaluate all branches regardless of condition
    conditional_execution: ConditionalMode::SkipBranches,

    // Connection validation strictness at execution time
    // Strict: fail on any connection issues (default)
    // Warn: log warnings but continue
    // Off: skip validation
    connection_validation: ValidationMode::Strict,

    // Enable runtime monitoring/metrics collection
    enable_monitoring: false,

    // Enable resource limit enforcement
    enable_resource_limits: false,

    // Maximum nodes executing concurrently (semaphore-controlled)
    // Level-based parallelism: nodes in the same DAG level run in parallel
    max_concurrent_nodes: 16,

    // Enable security checks during execution
    enable_security: false,

    // Enable audit logging during execution
    enable_audit: false,

    // Per-node execution timeout (None = no timeout)
    node_timeout: None,

    // Total workflow execution timeout (None = no timeout)
    workflow_timeout: None,
};

let runtime = Runtime::new(config, registry);
```

## ExecutionResult

```rust
pub struct ExecutionResult {
    /// Unique identifier for this execution run
    pub run_id: String,

    /// Per-node output maps: node_id -> output ValueMap
    pub results: HashMap<String, ValueMap>,

    /// Execution metadata (timing, node counts, etc.)
    pub metadata: ExecutionMetadata,
}
```

## Accessing Results

```rust
let result = runtime.execute(&workflow, inputs).await?;

// Check the unique run ID
println!("Run: {}", result.run_id);

// Access output from a specific node by ID
let node_output = result.results.get("my_transform_node");
if let Some(outputs) = node_output {
    // Access a specific output field
    if let Some(value) = outputs.get("result") {
        println!("Result: {:?}", value);
    }
}

// Pattern: get or error
let output = result.results
    .get("final_node")
    .ok_or("node 'final_node' not in results")?;

// Pattern: get string value
let text = result.results
    .get("text_node")
    .and_then(|o| o.get("text"))
    .and_then(|v| v.as_str())
    .unwrap_or("default");

// Iterate all node results
for (node_id, outputs) in &result.results {
    println!("Node '{}': {} outputs", node_id, outputs.len());
    for (key, val) in outputs {
        println!("  {}: {:?}", key, val);
    }
}
```

## Execution Model (Level-Based Parallelism)

```
Workflow DAG:
  A → B → D
  A → C → D

Level 0: [A]        -- runs first (no dependencies)
Level 1: [B, C]     -- runs in parallel (both depend only on A)
Level 2: [D]        -- runs last (depends on B and C)
```

The Runtime pre-computes execution levels at `builder.build()` time and uses `tokio::spawn` + a semaphore to run nodes at the same level concurrently.

## Passing Inputs to Workflows

```rust
use kailash_value::{Value, ValueMap};
use std::sync::Arc;

// Build input ValueMap
let mut inputs = ValueMap::new();
inputs.insert(Arc::from("text"), Value::String(Arc::from("hello world")));
inputs.insert(Arc::from("count"), Value::Integer(10));
inputs.insert(Arc::from("enabled"), Value::Bool(true));
inputs.insert(Arc::from("config"), Value::Object({
    let mut m = std::collections::BTreeMap::new();
    m.insert(Arc::from("timeout"), Value::Integer(30));
    m
}));

// Pass to execute
let result = runtime.execute(&workflow, inputs).await?;
```

## Common Patterns

### Re-using Runtime for Multiple Executions

```rust
// Create once, execute many times
let runtime = Arc::new(Runtime::new(RuntimeConfig::default(), registry));
let workflow = Arc::new(builder.build(&registry)?);

// Multiple concurrent executions (each with different inputs)
let handles: Vec<_> = (0..10).map(|i| {
    let runtime = Arc::clone(&runtime);
    let workflow = Arc::clone(&workflow);
    tokio::spawn(async move {
        let mut inputs = ValueMap::new();
        inputs.insert(Arc::from("id"), Value::Integer(i));
        runtime.execute(&workflow, inputs).await
    })
}).collect();

for handle in handles {
    let result = handle.await??;
    println!("Run ID: {}", result.run_id);
}
```

### Debug Mode for Development

```rust
let config = RuntimeConfig {
    debug: true,  // Logs each node before and after execution
    ..RuntimeConfig::default()
};
let runtime = Runtime::new(config, registry);
```

### Strict Connection Validation

```rust
// Default is Strict -- always prefer this in production
let config = RuntimeConfig {
    connection_validation: ValidationMode::Strict,
    ..RuntimeConfig::default()
};
```

### High-Concurrency Configuration

```rust
let config = RuntimeConfig {
    max_concurrent_nodes: 32,  // Allow more parallel node execution
    enable_resource_limits: true,
    ..RuntimeConfig::default()
};
```

## Testing with Runtime

```rust
#[tokio::test]
async fn test_workflow_produces_correct_output() {
    dotenvy::dotenv().ok();

    let mut registry = NodeRegistry::new();
    register_system_nodes(&mut registry);
    register_transform_nodes(&mut registry);
    let registry = Arc::new(registry);

    let mut builder = WorkflowBuilder::new();
    builder
        .add_node("TextTransformNode", "upper", {
            let mut c = ValueMap::new();
            c.insert(Arc::from("operation"), Value::String(Arc::from("uppercase")));
            c
        });

    let workflow = builder.build(&registry).expect("should build");
    let runtime = Runtime::new(RuntimeConfig::default(), registry);

    let mut inputs = ValueMap::new();
    inputs.insert(Arc::from("text"), Value::String(Arc::from("hello")));

    let result = runtime.execute(&workflow, inputs).await.expect("should execute");

    let output = &result.results["upper"];
    assert_eq!(
        output.get("result").and_then(|v| v.as_str()),
        Some("HELLO")
    );
}
```

## Verify

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo test -p kailash-core -- runtime --nocapture 2>&1
```
