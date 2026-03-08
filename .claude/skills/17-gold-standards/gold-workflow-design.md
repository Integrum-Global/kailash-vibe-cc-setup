---
name: gold-workflow-design
description: "Gold standard for workflow design in the Kailash Rust SDK. Use when asking 'workflow design standard', 'workflow best practices', or 'design workflow'."
---

# Gold Standard: Workflow Design

> **Skill Metadata**
> Category: `gold-standards`
> Priority: `HIGH`

## Design Principles

### 1. Single Responsibility

```rust
// ✅ GOOD: Each workflow does one thing
let mut registration_builder = WorkflowBuilder::new();
let mut welcome_email_builder = WorkflowBuilder::new();

// ❌ BAD: One workflow does too much
// let mut everything_builder = WorkflowBuilder::new(); // Registration + email + billing...
```

### 2. Composability

```rust
use kailash_core::{WorkflowBuilder, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

// ✅ GOOD: Reusable workflow construction functions
fn build_validation_workflow(builder: &mut WorkflowBuilder) {
    builder.add_node("SchemaValidatorNode", "validate", ValueMap::from([
        ("strict".into(), Value::Bool(true)),
    ]));
}

// Compose into larger workflows
fn build_user_pipeline() -> WorkflowBuilder {
    let mut builder = WorkflowBuilder::new();

    // Add validation sub-section
    build_validation_workflow(&mut builder);

    // Add processing after validation
    builder.add_node("JSONTransformNode", "process", ValueMap::from([
        ("expression".into(), Value::String("@.validated".into())),
    ]));
    builder.connect("validate", "result", "process", "data");

    builder
}
```

### 3. Error Handling

```rust
// ✅ GOOD: Use Result types and handle errors at execution boundaries
let registry = Arc::new(NodeRegistry::default());
let workflow = builder.build(&registry)?; // Validation at build time
let runtime = Runtime::new(RuntimeConfig::default(), registry);

match runtime.execute(&workflow, inputs).await {
    Ok(result) => {
        for (node_id, outputs) in &result.results {
            tracing::info!(node_id, ?outputs, "node completed");
        }
    }
    Err(e) => {
        tracing::error!(error = %e, "workflow execution failed");
        // Handle error: log, retry, notify
    }
}
```

### 4. Clear Naming

```rust
// ✅ GOOD: Descriptive node IDs
builder.add_node("LLMNode", "generate_product_description", ValueMap::from([
    ("prompt".into(), Value::String("Describe the product".into())),
]));

// ❌ BAD: Generic names
// builder.add_node("LLMNode", "node1", ValueMap::new());
```

### 5. Validate Before Execute

```rust
// ✅ GOOD: Build returns Result — catches errors at compile/build time
let registry = Arc::new(NodeRegistry::default());
let workflow = builder.build(&registry)?; // Validates DAG, connections, node types

// The workflow is guaranteed valid at this point
let result = runtime.execute(&workflow, inputs).await?;
```

### 6. Use 4-Parameter Connections

```rust
// ✅ GOOD: Explicit source output -> target input
builder.connect("reader", "data", "transform", "input_data");
builder.connect("transform", "result", "writer", "data");

// Clear data flow through the pipeline
```

## Gold Standard Checklist

- [ ] Single responsibility per workflow
- [ ] Descriptive node IDs (snake_case, describes purpose)
- [ ] `builder.build(&registry)?` called before execution (validation boundary)
- [ ] Error handling with `Result` and `?` operator
- [ ] 4-parameter `connect()` calls
- [ ] No circular dependencies (validated by `build()`)
- [ ] Composable via helper functions
- [ ] Unit tests for workflow construction logic

<!-- Trigger Keywords: workflow design standard, workflow best practices, design workflow, workflow gold standard -->
