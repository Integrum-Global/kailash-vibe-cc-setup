# Workflow Quickstart Skill

The fastest path to a running Kailash workflow.

## Usage

`/workflow-quickstart` -- Generate a complete working workflow with NodeRegistry, WorkflowBuilder, and Runtime

## The Essential Pattern

```rust
use kailash_core::{WorkflowBuilder, NodeRegistry, Runtime, RuntimeConfig};
use kailash_core::nodes::system::register_system_nodes;
use kailash_core::nodes::transform::register_transform_nodes;
use kailash_value::{Value, ValueMap};
use std::sync::Arc;

dotenvy::dotenv().ok();

// 1. Build a NodeRegistry with the nodes you need
let mut registry = NodeRegistry::new();
register_system_nodes(&mut registry);     // NoOpNode, LogNode, HandlerNode
register_transform_nodes(&mut registry);  // TextTransformNode, JSONTransformNode, etc.
// Add more: register_http_nodes, register_ai_nodes, etc.
let registry = Arc::new(registry);

// 2. Build your workflow (validation happens at build() time)
let mut builder = WorkflowBuilder::new();
builder
    .add_node("TextTransformNode", "uppercase", {
        let mut config = ValueMap::new();
        config.insert(Arc::from("operation"), Value::String(Arc::from("uppercase")));
        config
    })
    .add_node("LogNode", "log", ValueMap::new())
    .connect("uppercase", "result", "log", "data");  // source_node, source_output, target_node, target_input

let workflow = builder.build(&registry)?;  // Validates types, resolves connections

// 3. Execute (async -- primary path)
let runtime = Runtime::new(RuntimeConfig::default(), Arc::clone(&registry));

let mut inputs = ValueMap::new();
inputs.insert(Arc::from("text"), Value::String(Arc::from("hello world")));

let result = runtime.execute(&workflow, inputs).await?;
// result.run_id: String  -- unique run identifier
// result.results: HashMap<String, ValueMap>  -- per-node outputs

let uppercase_output = &result.results["uppercase"];
println!("Result: {:?}", uppercase_output.get("result"));
```

## Sync Execution (CLI/scripts)

```rust
// When you don't have an async context (e.g., in main() without #[tokio::main])
let result = runtime.execute_sync(&workflow, inputs)?;
// Same ExecutionResult -- just runs synchronously via internal tokio runtime
```

## Quick Template: 2-Node Pipeline

```rust
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenvy::dotenv().ok();

    let mut registry = NodeRegistry::new();
    register_system_nodes(&mut registry);
    register_transform_nodes(&mut registry);
    let registry = Arc::new(registry);

    let mut builder = WorkflowBuilder::new();
    builder
        .add_node("TextTransformNode", "step1", {
            let mut c = ValueMap::new();
            c.insert(Arc::from("operation"), Value::String(Arc::from("uppercase")));
            c
        })
        .add_node("LogNode", "step2", ValueMap::new())
        .connect("step1", "result", "step2", "data");

    let workflow = builder.build(&registry)?;
    let runtime = Runtime::new(RuntimeConfig::default(), registry);

    let mut inputs = ValueMap::new();
    inputs.insert(Arc::from("text"), Value::String(Arc::from("hello")));

    let result = runtime.execute(&workflow, inputs).await?;
    println!("Run ID: {}", result.run_id);
    println!("Outputs: {:?}", result.results);
    Ok(())
}
```

## Accessing Results

```rust
let result = runtime.execute(&workflow, inputs).await?;

// Access output from a specific node
if let Some(node_output) = result.results.get("my_node_id") {
    if let Some(value) = node_output.get("output_key") {
        println!("Got: {:?}", value);
    }
}

// Iterate all node results
for (node_id, outputs) in &result.results {
    println!("Node '{}' produced {:?}", node_id, outputs.keys().collect::<Vec<_>>());
}
```

## RuntimeConfig Options

```rust
let config = RuntimeConfig {
    debug: true,                                          // Enable debug logging
    enable_cycles: false,                                 // Allow cyclic workflows
    max_concurrent_nodes: 8,                              // Semaphore-controlled parallelism
    conditional_execution: ConditionalMode::SkipBranches, // Skip unmet branches
    connection_validation: ValidationMode::Strict,         // Strict connection checking
    ..RuntimeConfig::default()
};
```

## Common Node Types (Quick Reference)

| Node Type           | Inputs                                   | Outputs                       | Notes                         |
| ------------------- | ---------------------------------------- | ----------------------------- | ----------------------------- |
| `NoOpNode`          | `data`                                   | `data`                        | Pass-through                  |
| `LogNode`           | `data`, `level?`                         | `data`                        | Logs and passes through       |
| `TextTransformNode` | `text`, `operation`                      | `result`                      | uppercase/lowercase/trim/etc. |
| `JSONTransformNode` | `data`, `expression`                     | `result`                      | JMESPath transforms           |
| `ConditionalNode`   | `condition`, `true_data?`, `false_data?` | `true_output`, `false_output` | Branch                        |
| `SwitchNode`        | `value`, `cases`                         | `case_*`                      | Multi-branch                  |
| `MergeNode`         | `inputs` (array)                         | `merged`                      | Combine streams               |

## Verify

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo test -p kailash-core -- --nocapture 2>&1
```
