# Serialize Workflow Skill

Demonstrate workflow serialization, deserialization, and template-based parameterization using kailash-core's `WorkflowDefinition` and `WorkflowTemplate`.

## Usage

`/serialize-workflow` -- Generate workflow serialization code with definition round-trip and template parameters

## Steps

1. Read the serialization and template patterns from:
   - `crates/kailash-core/src/definition.rs` -- WorkflowDefinition, NodeDefinition, ConnectionDefinition, `to_json()`, `from_json()`, `to_yaml()`, `from_yaml()`, `from_file()`, `to_builder()`
   - `crates/kailash-core/src/template.rs` -- WorkflowTemplate, `{{variable}}` placeholders, `instantiate()`, defaults
   - `crates/kailash-core/src/workflow.rs` -- WorkflowBuilder, `to_definition()`, `build()`

2. Choose the appropriate pattern:
   - **Definition round-trip**: Build workflow -> serialize to JSON -> deserialize -> rebuild
   - **YAML round-trip**: Build workflow -> serialize to YAML -> deserialize -> rebuild (requires `yaml` feature)
   - **Auto-detect from file**: Load from `.json` or `.yaml`/`.yml` file with `from_file()`
   - **Template with parameters**: Create workflow with `{{placeholders}}` -> instantiate with values
   - **Workflow export/import**: Extract definition from built workflow -> save/load

3. Implement the serialization flow with proper error handling.

4. Write tests covering:
   - JSON serialization round-trip
   - Definition to builder to workflow
   - Workflow to definition extraction
   - Template parameter substitution (exact match, partial string, nested objects)
   - Missing parameter errors
   - Default value fallbacks

## Template

### WorkflowDefinition Round-Trip

```rust
use kailash_core::definition::{WorkflowDefinition, NodeDefinition, ConnectionDefinition};
use kailash_core::node::NodeRegistry;
use kailash_core::nodes::system::register_system_nodes;
use kailash_core::nodes::transform::register_transform_nodes;
use kailash_value::{Value, ValueMap};
use std::sync::Arc;

fn main() {
    // 1. Create a workflow definition manually
    let mut config = ValueMap::new();
    config.insert(Arc::from("operation"), Value::String(Arc::from("uppercase")));

    let def = WorkflowDefinition {
        version: "1.0".to_string(),
        nodes: vec![
            NodeDefinition {
                type_name: "TextTransformNode".to_string(),
                node_id: "upper".to_string(),
                config,
            },
            NodeDefinition {
                type_name: "LogNode".to_string(),
                node_id: "log".to_string(),
                config: ValueMap::new(),
            },
        ],
        connections: vec![ConnectionDefinition {
            source_node: "upper".to_string(),
            source_output: "result".to_string(),
            target_node: "log".to_string(),
            target_input: "data".to_string(),
        }],
        enable_cycles: false,
    };

    // 2. Serialize to JSON
    let json = def.to_json().expect("serialization should succeed");
    println!("Serialized:\n{json}");

    // 3. Deserialize from JSON
    let restored = WorkflowDefinition::from_json(&json)
        .expect("deserialization should succeed");
    assert_eq!(def, restored);
    println!("Round-trip: OK");

    // 4. Convert to builder and build
    let mut registry = NodeRegistry::new();
    register_system_nodes(&mut registry);
    register_transform_nodes(&mut registry);

    let builder = restored.to_builder();
    let workflow = builder.build(&registry).expect("should build from definition");
    println!("Built workflow: {} nodes, {} connections",
        workflow.node_count(), workflow.connection_count());

    // 5. Extract definition back from built workflow
    let extracted = workflow.to_definition();
    assert_eq!(extracted.nodes.len(), def.nodes.len());
    assert_eq!(extracted.connections.len(), def.connections.len());
    println!("Extraction: OK");
}
```

### WorkflowTemplate with Parameters

```rust
use kailash_core::template::WorkflowTemplate;
use kailash_core::definition::{WorkflowDefinition, NodeDefinition, ConnectionDefinition};
use kailash_core::node::NodeRegistry;
use kailash_core::nodes::system::register_system_nodes;
use kailash_core::nodes::transform::register_transform_nodes;
use kailash_value::{Value, ValueMap, value_map};
use std::sync::Arc;

fn main() {
    // 1. Create a template with {{placeholders}}
    let def = WorkflowDefinition {
        version: "1.0".to_string(),
        nodes: vec![
            NodeDefinition {
                type_name: "TextTransformNode".to_string(),
                node_id: "transform".to_string(),
                config: value_map! {
                    "operation" => "{{operation}}",
                    "prefix" => "{{prefix}}"
                },
            },
            NodeDefinition {
                type_name: "LogNode".to_string(),
                node_id: "log".to_string(),
                config: value_map! {
                    "message" => "Processing: {{description}}"
                },
            },
        ],
        connections: vec![ConnectionDefinition {
            source_node: "transform".to_string(),
            source_output: "result".to_string(),
            target_node: "log".to_string(),
            target_input: "data".to_string(),
        }],
        enable_cycles: false,
    };

    let template = WorkflowTemplate::new(def)
        .with_name("text-processor")
        .with_description("Configurable text processing pipeline")
        .with_defaults(value_map! {
            "operation" => "uppercase",
            "prefix" => ""
        });

    // 2. List required parameters
    let params = template.parameters();
    println!("Parameters: {params:?}");
    // -> ["description", "operation", "prefix"]

    // 3. Instantiate with specific values (overrides defaults)
    let instance = template.instantiate(&value_map! {
        "operation" => "lowercase",
        "prefix" => "[OUT] ",
        "description" => "lowercase conversion"
    }).expect("instantiation should succeed");

    // 4. Verify substitution
    let transform_config = &instance.nodes[0].config;
    assert_eq!(
        transform_config.get(&Arc::from("operation") as &Arc<str>),
        Some(&Value::String(Arc::from("lowercase")))
    );

    let log_config = &instance.nodes[1].config;
    assert_eq!(
        log_config.get(&Arc::from("message") as &Arc<str>),
        Some(&Value::String(Arc::from("Processing: lowercase conversion")))
    );

    println!("Template instantiation: OK");

    // 5. Build the instantiated workflow
    let mut registry = NodeRegistry::new();
    register_system_nodes(&mut registry);
    register_transform_nodes(&mut registry);

    let workflow = instance.to_builder()
        .build(&registry)
        .expect("should build from instantiated template");
    println!("Built from template: {} nodes", workflow.node_count());

    // 6. Templates are also serializable
    let template_json = serde_json::to_string_pretty(&template)
        .expect("template serialization should succeed");
    println!("Template JSON:\n{template_json}");

    let restored: WorkflowTemplate = serde_json::from_str(&template_json)
        .expect("template deserialization should succeed");
    assert_eq!(template, restored);
    println!("Template round-trip: OK");
}
```

### YAML Serialization (requires `yaml` feature)

Enable the `yaml` feature in `Cargo.toml`:

```toml
[dependencies]
kailash-core = { path = "../kailash-core", features = ["yaml"] }
```

```rust
use kailash_core::definition::{WorkflowDefinition, NodeDefinition, ConnectionDefinition};
use kailash_value::{Value, ValueMap};
use std::sync::Arc;

fn main() {
    // 1. Create a workflow definition
    let mut config = ValueMap::new();
    config.insert(Arc::from("operation"), Value::String(Arc::from("uppercase")));

    let def = WorkflowDefinition {
        version: "1.0".to_string(),
        nodes: vec![
            NodeDefinition {
                type_name: "TextTransformNode".to_string(),
                node_id: "upper".to_string(),
                config,
            },
            NodeDefinition {
                type_name: "LogNode".to_string(),
                node_id: "log".to_string(),
                config: ValueMap::new(),
            },
        ],
        connections: vec![ConnectionDefinition {
            source_node: "upper".to_string(),
            source_output: "result".to_string(),
            target_node: "log".to_string(),
            target_input: "data".to_string(),
        }],
        enable_cycles: false,
    };

    // 2. Serialize to YAML
    let yaml = def.to_yaml().expect("YAML serialization should succeed");
    println!("YAML:\n{yaml}");

    // 3. Deserialize from YAML
    let restored = WorkflowDefinition::from_yaml(&yaml)
        .expect("YAML deserialization should succeed");
    assert_eq!(def, restored);
    println!("YAML round-trip: OK");

    // 4. Auto-detect format from file extension
    // Supports .json, .yaml, .yml
    std::fs::write("workflow.yaml", &yaml).expect("write file");
    let from_file = WorkflowDefinition::from_file("workflow.yaml")
        .expect("from_file should auto-detect YAML");
    assert_eq!(def, from_file);
    println!("Auto-detect from file: OK");

    std::fs::remove_file("workflow.yaml").ok();
}
```

### Test Template

```rust
#[cfg(test)]
mod tests {
    use kailash_core::definition::{WorkflowDefinition, NodeDefinition, ConnectionDefinition};
    use kailash_core::template::{WorkflowTemplate, TemplateError};
    use kailash_core::WorkflowBuilder;
    use kailash_core::node::NodeRegistry;
    use kailash_value::{Value, ValueMap, value_map};
    use std::sync::Arc;

    #[test]
    fn definition_json_roundtrip() {
        let def = WorkflowDefinition {
            version: "1.0".to_string(),
            nodes: vec![NodeDefinition {
                type_name: "NoOpNode".to_string(),
                node_id: "n1".to_string(),
                config: ValueMap::new(),
            }],
            connections: vec![],
            enable_cycles: false,
        };

        let json = def.to_json().expect("serialize");
        let restored = WorkflowDefinition::from_json(&json).expect("deserialize");
        assert_eq!(def, restored);
    }

    #[test]
    fn builder_to_definition_roundtrip() {
        let mut builder = WorkflowBuilder::new();
        builder
            .add_node("NoOpNode", "a", ValueMap::new())
            .add_node("NoOpNode", "b", ValueMap::new())
            .connect("a", "data", "b", "data");

        let def = builder.to_definition();
        assert_eq!(def.nodes.len(), 2);
        assert_eq!(def.connections.len(), 1);
    }

    #[test]
    fn template_exact_substitution() {
        let def = WorkflowDefinition {
            version: "1.0".to_string(),
            nodes: vec![NodeDefinition {
                type_name: "NoOpNode".to_string(),
                node_id: "n1".to_string(),
                config: value_map! { "count" => "{{count}}" },
            }],
            connections: vec![],
            enable_cycles: false,
        };

        let template = WorkflowTemplate::new(def);
        let result = template.instantiate(&value_map! { "count" => 42 }).unwrap();

        assert_eq!(
            result.nodes[0].config.get(&Arc::from("count") as &Arc<str>),
            Some(&Value::Integer(42))
        );
    }

    #[test]
    fn template_partial_string_substitution() {
        let def = WorkflowDefinition {
            version: "1.0".to_string(),
            nodes: vec![NodeDefinition {
                type_name: "NoOpNode".to_string(),
                node_id: "n1".to_string(),
                config: value_map! { "url" => "{{base}}/api/{{path}}" },
            }],
            connections: vec![],
            enable_cycles: false,
        };

        let template = WorkflowTemplate::new(def);
        let result = template.instantiate(&value_map! {
            "base" => "https://example.com",
            "path" => "users"
        }).unwrap();

        assert_eq!(
            result.nodes[0].config.get(&Arc::from("url") as &Arc<str>),
            Some(&Value::String(Arc::from("https://example.com/api/users")))
        );
    }

    #[test]
    fn template_missing_parameter_error() {
        let def = WorkflowDefinition {
            version: "1.0".to_string(),
            nodes: vec![NodeDefinition {
                type_name: "NoOpNode".to_string(),
                node_id: "n1".to_string(),
                config: value_map! { "url" => "{{missing}}" },
            }],
            connections: vec![],
            enable_cycles: false,
        };

        let template = WorkflowTemplate::new(def);
        let result = template.instantiate(&ValueMap::new());
        assert!(result.is_err());
        assert!(matches!(result.unwrap_err(), TemplateError::MissingParameter { .. }));
    }

    #[test]
    fn template_defaults_used_when_param_not_provided() {
        let def = WorkflowDefinition {
            version: "1.0".to_string(),
            nodes: vec![NodeDefinition {
                type_name: "NoOpNode".to_string(),
                node_id: "n1".to_string(),
                config: value_map! { "timeout" => "{{timeout}}" },
            }],
            connections: vec![],
            enable_cycles: false,
        };

        let template = WorkflowTemplate::new(def)
            .with_defaults(value_map! { "timeout" => 30 });

        let result = template.instantiate(&ValueMap::new()).unwrap();
        assert_eq!(
            result.nodes[0].config.get(&Arc::from("timeout") as &Arc<str>),
            Some(&Value::Integer(30))
        );
    }
}
```

## Verify

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo test -p kailash-core -- definition template && cargo clippy -p kailash-core -- -D warnings
```
