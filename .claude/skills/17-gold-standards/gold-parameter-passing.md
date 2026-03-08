---
name: gold-parameter-passing
description: "Parameter passing standard for the Kailash Rust SDK with three methods: node configuration, workflow connections, and runtime inputs. Use when asking 'parameter standard', 'parameter gold', 'parameter validation', 'parameter security', or 'parameter compliance'."
---

# Gold Standard: Parameter Passing

Parameter passing compliance standard with three methods for the Kailash Rust SDK.

> **Skill Metadata**
> Category: `gold-standards`
> Priority: `CRITICAL`

## Quick Reference

- **Primary Use**: Parameter Passing Compliance Standard
- **Category**: gold-standards
- **Priority**: CRITICAL
- **Trigger Keywords**: parameter standard, parameter gold, parameter validation, parameter security, parameter scoping

## Three Methods of Parameter Passing

### Method 1: Node Configuration (Most Reliable)

```rust
use kailash_core::WorkflowBuilder;
use kailash_core::value::{Value, ValueMap};

let mut builder = WorkflowBuilder::new();
builder.add_node("CSVReaderNode", "reader", ValueMap::from([
    ("file_path".into(), Value::String("data.csv".into())),
    ("delimiter".into(), Value::String(",".into())),
    ("has_header".into(), Value::Bool(true)),
]));
```

**Use when**: Static values, test fixtures, default settings

### Method 2: Workflow Connections (Dynamic Data Flow)

```rust
builder.add_node("CSVReaderNode", "reader", ValueMap::from([
    ("file_path".into(), Value::String("data.csv".into())),
]));
builder.add_node("DataMapperNode", "transformer", ValueMap::new());

// Pass data between nodes (4-parameter syntax)
builder.connect("reader", "data", "transformer", "input_data");
```

**Use when**: Dynamic data flow, pipelines, transformations

### Method 3: Runtime Inputs (User Input)

```rust
use kailash_core::{Runtime, RuntimeConfig, NodeRegistry};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let workflow = builder.build(&registry)?;
let runtime = Runtime::new(RuntimeConfig::default(), registry);

// Pass inputs at execution time
let inputs = ValueMap::from([
    ("file_path".into(), Value::String("custom.csv".into())),
    ("operation".into(), Value::String("normalize".into())),
]);

let result = runtime.execute(&workflow, inputs).await?;
```

**Use when**: User input, environment overrides, dynamic values

## Explicit Parameter Declaration (Node Trait)

Custom nodes must declare parameters explicitly via `input_params()` and `output_params()`:

```rust
use kailash_core::{Node, NodeError, ExecutionContext};
use kailash_core::node::{ParamDef, ParamType};
use kailash_core::value::{Value, ValueMap};
use std::pin::Pin;
use std::future::Future;

pub struct CustomNode {
    input_params: Vec<ParamDef>,
    output_params: Vec<ParamDef>,
}

impl CustomNode {
    pub fn new() -> Self {
        Self {
            input_params: vec![
                ParamDef::new("file_path", ParamType::String, true),   // Required
                ParamDef::new("delimiter", ParamType::String, false),   // Optional
            ],
            output_params: vec![ParamDef::new("data", ParamType::Any, false)],
        }
    }
}

impl Node for CustomNode {
    fn type_name(&self) -> &str { "CustomNode" }

    fn input_params(&self) -> &[ParamDef] {
        &self.input_params
    }

    fn output_params(&self) -> &[ParamDef] {
        &self.output_params
    }

    fn execute(
        &self,
        inputs: ValueMap,
        _ctx: &ExecutionContext,
    ) -> Pin<Box<dyn Future<Output = Result<ValueMap, NodeError>> + Send + '_>> {
        Box::pin(async move {
            let file_path = inputs.get("file_path")
                .and_then(|v| v.as_str())
                .ok_or(NodeError::MissingInput { name: "file_path".to_string() })?;

            let delimiter = inputs.get("delimiter")
                .and_then(|v| v.as_str())
                .unwrap_or(",");

            let data = process_file(file_path, delimiter)?;
            Ok(ValueMap::from([("data".into(), data)]))
        })
    }
}
```

**Why explicit declaration?**

- **Security**: Prevents parameter injection attacks
- **Compliance**: Enables parameter tracking and auditing
- **Debugging**: Clear parameter expectations via `input_params()`
- **Testing**: Testable parameter contracts
- **Validation**: `builder.build(&registry)?` validates connections against declared params

## Common Pitfalls

### Pitfall 1: Missing Required Input Handling

```rust
// ❌ WRONG - panics on missing input
fn execute(&self, inputs: ValueMap, _ctx: &ExecutionContext) -> ... {
    Box::pin(async move {
        let value = inputs["key"].clone(); // Panics if key missing!
        Ok(ValueMap::from([("result".into(), value)]))
    })
}

// ✅ CORRECT - use .get() with proper error
fn execute(&self, inputs: ValueMap, _ctx: &ExecutionContext) -> ... {
    Box::pin(async move {
        let value = inputs.get("key")
            .ok_or(NodeError::MissingInput { name: "key".to_string() })?;
        Ok(ValueMap::from([("result".into(), value.clone())]))
    })
}
```

### Pitfall 2: Type Mismatches

```rust
// ❌ WRONG - assumes type without checking
let count = inputs.get("count").unwrap().as_i64().unwrap();

// ✅ CORRECT - check type and provide error context
let count = inputs.get("count")
    .and_then(|v| v.as_i64())
    .ok_or_else(|| NodeError::ExecutionFailed {
        message: "count must be an integer".to_string(),
        source: None,
    })?;
```

## Build-Time Validation

```rust
// build() validates the workflow DAG, connections, and node types
let registry = Arc::new(NodeRegistry::default());
match builder.build(&registry) {
    Ok(workflow) => {
        // Workflow is valid — safe to execute
        let result = runtime.execute(&workflow, inputs).await?;
    }
    Err(e) => {
        // Build errors: missing nodes, invalid connections, cycles
        tracing::error!(error = %e, "workflow validation failed");
        return Err(e.into());
    }
}
```

## Related Patterns

- **For workflow basics**: See [`CLAUDE.md`](../../../../CLAUDE.md) (Essential Patterns section)
- **For custom nodes**: See [`gold-custom-nodes`](gold-custom-nodes.md)
- **For error handling**: See [`gold-error-handling`](gold-error-handling.md)

## Quick Tips

- Use Method 1 (node configuration) for tests - most reliable
- Use Method 2 (connections) for dynamic data flow between nodes
- Use Method 3 (runtime inputs) for user input and overrides
- Always declare parameters explicitly in custom nodes via `input_params()`
- Use `?` operator for error propagation, never `unwrap()` in production
- `builder.build(&registry)?` is the validation boundary

## Keywords for Auto-Trigger

<!-- Trigger Keywords: parameter standard, parameter gold, parameter validation, parameter security, parameter scoping, parameter compliance, parameter isolation, ValueMap parameters -->
