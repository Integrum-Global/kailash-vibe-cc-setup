---
name: gold-custom-nodes
description: "Gold standard for custom node development in the Kailash Rust SDK. Use when asking 'create custom node', 'custom node standard', or 'node development'."
---

# Gold Standard: Custom Node Development

> **Skill Metadata**
> Category: `gold-standards`
> Priority: `MEDIUM`

## Custom Node Template

```rust
use kailash_core::{Node, NodeError, ExecutionContext};
use kailash_core::node::{ParamDef, ParamType};
use kailash_core::value::{Value, ValueMap};
use std::pin::Pin;
use std::future::Future;

/// Custom node for specific business logic.
///
/// Use this node to process input data with custom configuration.
pub struct MyCustomNode {
    input_params: Vec<ParamDef>,
    output_params: Vec<ParamDef>,
}

impl MyCustomNode {
    /// Create a new instance from workflow configuration.
    pub fn from_config(_config: &ValueMap) -> Self {
        Self {
            input_params: vec![
                ParamDef::new("input_data", ParamType::String, true),   // Required
                ParamDef::new("config", ParamType::Object, false),      // Optional
                ParamDef::new("metadata", ParamType::Object, false),    // Optional
            ],
            output_params: vec![
                ParamDef::new("result", ParamType::String, false),
                ParamDef::new("metadata", ParamType::Object, false),
            ],
        }
    }

    /// Internal processing logic.
    fn process(data: &str, _config: &ValueMap) -> String {
        data.to_uppercase()
    }
}

impl Node for MyCustomNode {
    fn type_name(&self) -> &str {
        "MyCustomNode"
    }

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
            // Extract required input
            let input_data = inputs.get("input_data")
                .and_then(|v| v.as_str())
                .ok_or_else(|| NodeError::MissingInput {
                    name: "input_data".to_string(),
                })?;

            // Extract optional config (default to empty map)
            let config = inputs.get("config")
                .and_then(|v| v.as_object())
                .cloned()
                .unwrap_or_default();

            // Extract optional metadata (pass through if present)
            let metadata = inputs.get("metadata").cloned();

            // Process the data
            let result = Self::process(input_data, &config);

            // Build output map
            let mut outputs = ValueMap::from([
                ("result".into(), Value::String(result.into())),
            ]);

            if let Some(meta) = metadata {
                outputs.insert("metadata".into(), meta);
            }

            Ok(outputs)
        })
    }
}
```

## Gold Standard Checklist

- [ ] Implements the `Node` trait
- [ ] Implements `type_name()` returning a unique identifier
- [ ] Implements `input_params()` with `ParamDef::new(name, ParamType, required)`
- [ ] Implements `output_params()` with `ParamDef::new(name, ParamType, required)`
- [ ] Implements `execute()` returning `Pin<Box<dyn Future<...> + Send + '_>>`
- [ ] Uses `Box::pin(async move { ... })` inside `execute()`
- [ ] Extracts inputs with proper error handling (no `unwrap()`)
- [ ] Returns `Result<ValueMap, NodeError>`
- [ ] Uses `NodeError::MissingInput` for required inputs that are absent
- [ ] Has `from_config(config: &ValueMap)` constructor
- [ ] Rustdoc (`///`) comments on struct and methods
- [ ] Unit tests for execute logic
- [ ] Integration test in a workflow context

## Registering Custom Nodes

```rust
use kailash_core::NodeRegistry;
use kailash_core::node::{NodeFactory, NodeMetadata, ParamDef, ParamType};

/// Factory for creating MyCustomNode instances.
struct MyCustomNodeFactory {
    metadata: NodeMetadata,
}

impl MyCustomNodeFactory {
    fn new() -> Self {
        Self {
            metadata: NodeMetadata {
                type_name: "MyCustomNode".into(),
                description: "Custom node for specific business logic".into(),
                category: "custom".into(),
                input_params: vec![
                    ParamDef::new("input_data", ParamType::String, true),
                    ParamDef::new("config", ParamType::Object, false),
                    ParamDef::new("metadata", ParamType::Object, false),
                ],
                output_params: vec![
                    ParamDef::new("result", ParamType::String, false),
                    ParamDef::new("metadata", ParamType::Object, false),
                ],
                version: "0.1.0".into(),
                author: "Kailash Authors".into(),
                tags: vec!["custom".into()],
            },
        }
    }
}

impl NodeFactory for MyCustomNodeFactory {
    fn create(&self, config: ValueMap) -> Result<Box<dyn Node>, NodeError> {
        Ok(Box::new(MyCustomNode::from_config(&config)))
    }

    fn metadata(&self) -> &NodeMetadata {
        &self.metadata
    }
}

/// Register custom nodes with the registry.
pub fn register_custom_nodes(registry: &mut NodeRegistry) {
    registry.register(Box::new(MyCustomNodeFactory::new()));
}
```

## Using the Proc-Macro (Alternative)

```rust
use kailash_macros::kailash_node;

#[kailash_node(description = "Transforms input data", category = "transform")]
pub struct MyTransformNode {
    #[input(required)]
    data: Value,
    #[input(default = "\"@\"")]
    expression: String,
    #[output]
    result: Value,
}

#[async_trait]
impl NodeExecute for MyTransformNode {
    async fn execute(
        &self,
        inputs: ValueMap,
        _ctx: &ExecutionContext,
    ) -> Result<ValueMap, NodeError> {
        let data = inputs.get("data")
            .ok_or(NodeError::MissingInput { name: "data".to_string() })?;
        // ... transform logic ...
        Ok(ValueMap::from([("result".into(), data.clone())]))
    }
}
```

## Documentation

- **Node Trait**: [`crates/kailash-core/src/node.rs`](../../../../crates/kailash-core/src/node.rs)
- **Existing Nodes**: [`crates/kailash-nodes/src/`](../../../../crates/kailash-nodes/src/)
- **Proc-Macro**: [`crates/kailash-macros/src/`](../../../../crates/kailash-macros/src/)

<!-- Trigger Keywords: create custom node, custom node standard, node development, custom node gold standard -->
