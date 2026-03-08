---
name: core-events-visualization
description: "Execution event streaming, Mermaid visualization, and SubworkflowNode for workflow composition. Use when asking 'workflow events', 'execution events', 'mermaid diagram', 'visualization', 'subworkflow', 'nested workflow', or 'workflow composition'."
---

# Core Advanced: Events, Visualization, and Subworkflows

Three powerful features for monitoring, debugging, and composing workflows.

## 1. Execution Event Streaming

Stream real-time events during workflow execution for monitoring and UI integration.

### Event Types

```rust
use kailash_core::events::ExecutionEvent;

// 5 event variants in lifecycle order:
// 1. WorkflowStarted { run_id, node_count }
// 2. NodeStarted { node_id, type_name }
// 3. NodeCompleted { node_id, type_name, duration }
// 4. NodeFailed { node_id, type_name, error }
// 5. WorkflowCompleted { run_id, duration, nodes_executed }
```

### Async Event Streaming

```rust
use kailash_core::{Runtime, RuntimeConfig, WorkflowBuilder};
use kailash_core::node::NodeRegistry;
use kailash_core::events::ExecutionEvent;
use kailash_value::ValueMap;
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();
builder
    .add_node("NoOpNode", "start", ValueMap::new())
    .add_node("LogNode", "process", ValueMap::new())
    .connect("start", "data", "process", "data");
let workflow = builder.build(&registry)?;

let runtime = Runtime::new(RuntimeConfig::default(), Arc::clone(&registry));

// execute_with_events returns (ExecutionResult, mpsc::Receiver<ExecutionEvent>)
let (result, mut rx) = runtime
    .execute_with_events(&workflow, ValueMap::new())
    .await?;

// Consume events (already buffered — read after execution completes)
while let Some(event) = rx.recv().await {
    match &event {
        ExecutionEvent::WorkflowStarted { run_id, node_count } => {
            println!("[{run_id}] Workflow started with {node_count} nodes");
        }
        ExecutionEvent::NodeStarted { node_id, type_name } => {
            println!("  Node {node_id} ({type_name}) started");
        }
        ExecutionEvent::NodeCompleted { node_id, duration, .. } => {
            println!("  Node {node_id} completed in {duration:?}");
        }
        ExecutionEvent::NodeFailed { node_id, error, .. } => {
            eprintln!("  Node {node_id} FAILED: {error}");
        }
        ExecutionEvent::WorkflowCompleted { duration, nodes_executed, .. } => {
            println!("Workflow done: {nodes_executed} nodes in {duration:?}");
        }
    }
}
```

### Sync Event Collection

```rust
// execute_sync_with_events returns (ExecutionResult, Vec<ExecutionEvent>)
let (result, events) = runtime
    .execute_sync_with_events(&workflow, ValueMap::new())?;

for event in &events {
    println!("{event}"); // ExecutionEvent implements Display
}
```

### Event Ordering Guarantees

- `WorkflowStarted` is always the first event
- `WorkflowCompleted` is always the last event (on success)
- For each node: `NodeStarted` always precedes `NodeCompleted` or `NodeFailed`
- Connected nodes: upstream `NodeCompleted` precedes downstream `NodeStarted`

## 2. Mermaid Visualization

Generate Mermaid flowchart diagrams from built workflows.

### Basic Usage

```rust
use kailash_core::workflow::WorkflowBuilder;
use kailash_core::node::NodeRegistry;
use kailash_core::nodes::system::register_system_nodes;
use kailash_value::ValueMap;

let mut registry = NodeRegistry::new();
register_system_nodes(&mut registry);

let mut builder = WorkflowBuilder::new();
builder
    .add_node("NoOpNode", "start", ValueMap::new())
    .add_node("NoOpNode", "end", ValueMap::new())
    .connect("start", "data", "end", "data");
let workflow = builder.build(&registry)?;

let mermaid = workflow.to_mermaid();
println!("{mermaid}");
// Output:
// graph TD
//     start("start<br/>NoOpNode")
//     end("end<br/>NoOpNode")
//     start -->|"data -> data"| end
```

### Node Shape Rules

| Node Type                                        | Shape     | Mermaid Syntax |
| ------------------------------------------------ | --------- | -------------- |
| `ConditionalNode`, `SwitchNode`                  | Diamond   | `id{"label"}`  |
| `NoOpNode`, `LogNode`, `HandlerNode`, `*System*` | Rounded   | `id("label")`  |
| All others                                       | Rectangle | `id["label"]`  |

### Edge Labels

Connections display as `source_output -> target_input` on edges.

### Use Cases

- **Debugging**: Visualize workflow DAG to spot missing connections
- **Documentation**: Embed diagrams in docs with `mermaid` code blocks
- **Validation**: Compare visual structure against requirements

## 3. SubworkflowNode (Nested Workflows)

Compose workflows by nesting one workflow inside another as a single node.

### How It Works

```rust
use kailash_core::node::NodeRegistry;
use kailash_core::nodes::system::{register_system_nodes, register_subworkflow_node};
use kailash_core::workflow::WorkflowBuilder;
use kailash_core::definition::WorkflowDefinition;
use kailash_value::{Value, ValueMap};
use std::sync::Arc;

// 1. Build the registry with all node types
let mut registry = NodeRegistry::new();
register_system_nodes(&mut registry);
let registry_snapshot = Arc::new(registry);

// 2. Register SubworkflowNode (requires registry snapshot)
let mut registry = NodeRegistry::new();
register_system_nodes(&mut registry);
register_subworkflow_node(&mut registry, Arc::clone(&registry_snapshot));
let registry = Arc::new(registry);

// 3. Define the inner workflow as JSON
let inner_def = serde_json::json!({
    "version": "1.0",
    "nodes": [
        { "type_name": "NoOpNode", "node_id": "step1", "config": {} },
        { "type_name": "NoOpNode", "node_id": "step2", "config": {} }
    ],
    "connections": [
        { "source_node": "step1", "source_output": "data",
          "target_node": "step2", "target_input": "data" }
    ],
    "enable_cycles": false
});

// 4. Use SubworkflowNode in a parent workflow
let mut builder = WorkflowBuilder::new();
builder.add_node("SubworkflowNode", "sub", ValueMap::from([
    ("definition".into(), Value::String(inner_def.to_string().into())),
]));
let workflow = builder.build(&registry)?;
```

### Key Behaviors

- **Fail-fast**: Invalid sub-workflow definitions fail at `builder.build()` time, not at execution
- **Input forwarding**: All inputs to SubworkflowNode are forwarded as workflow-level inputs
- **Output flattening**: Inner node outputs are flattened with prefixed keys: `"{node_id}.{output_key}"`
- **Isolation**: Each execution creates a fresh Runtime for the inner workflow

### Registration Pattern

`SubworkflowNode` requires a snapshot of the registry because it needs to resolve inner node types. Register it **after** all other node types:

```rust
let mut registry = NodeRegistry::new();
register_system_nodes(&mut registry);
// ... register all other nodes ...
let snapshot = Arc::new(registry);

let mut final_registry = NodeRegistry::new();
register_system_nodes(&mut final_registry);
register_subworkflow_node(&mut final_registry, snapshot);
```

## Source Files

- Events: `crates/kailash-core/src/events.rs`
- Visualization: `crates/kailash-core/src/visualization.rs`
- Subworkflows: `crates/kailash-core/src/nodes/system/subworkflow.rs`
