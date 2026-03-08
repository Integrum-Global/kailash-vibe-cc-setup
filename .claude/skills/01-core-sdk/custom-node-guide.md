# Custom Node Guide Skill

Full implementation guide for custom Kailash nodes.

## Usage

`/custom-node-guide` -- Complete reference for Node trait, ParamDef, ParamType, NodeError variants, and Factory pattern

## Node Trait (Full Signature)

```rust
pub trait Node: Send + Sync + 'static {
    /// Returns the type name used to look this node up in the NodeRegistry.
    fn type_name(&self) -> &str;

    /// Returns the list of accepted input parameters.
    fn input_params(&self) -> &[ParamDef];

    /// Returns the list of output parameters this node emits.
    fn output_params(&self) -> &[ParamDef];

    /// Executes the node logic with the given inputs and execution context.
    fn execute(
        &self,
        inputs: ValueMap,
        ctx: &ExecutionContext,
    ) -> Pin<Box<dyn Future<Output = Result<ValueMap, NodeError>> + Send + '_>>;
}
```

## ParamDef

```rust
use kailash_core::node::{ParamDef, ParamType};

// Required input
ParamDef::new("text", ParamType::String, true)
    .with_description("The text to transform");

// Optional input with description
ParamDef::new("max_length", ParamType::Integer, false)
    .with_description("Maximum output length (default: 256)");

// Required output
ParamDef::new("result", ParamType::String, false)
    .with_description("Transformed text");
```

## ParamType Variants

```rust
pub enum ParamType {
    String,                 // Value::String
    Integer,                // Value::Integer (i64)
    Float,                  // Value::Float (f64)
    Bool,                   // Value::Bool
    Bytes,                  // Value::Bytes
    Array(Box<ParamType>),  // Value::Array with element type
    Object,                 // Value::Object (BTreeMap)
    Any,                    // Accepts any Value variant
}
```

Use `ParamType::Any` when the node is generic or the exact type is determined at runtime.
Use `ParamType::Array(Box::new(ParamType::String))` for typed arrays.

## NodeError Variants

```rust
use kailash_core::error::NodeError;

// Missing required input
NodeError::MissingInput { name: "text".into() }

// Wrong type for input
NodeError::InvalidInput {
    name: "count".into(),
    expected: "integer".into(),
    got: "string".into(),
}

// General execution failure
NodeError::ExecutionFailed {
    message: "HTTP request failed with status 404".into(),
    source: None,  // or Some(Box::new(underlying_error))
}

// Node timed out
NodeError::Timeout {
    duration: std::time::Duration::from_secs(30),
}

// Resource limit exceeded
NodeError::ResourceLimit {
    resource: "memory".into(),
    limit: "256 MB".into(),
}

// Internal error (bugs / invariant violations)
NodeError::Internal {
    message: "unexpected state in node logic".into(),
}
```

## Complete Node Implementation

```rust
use std::future::Future;
use std::pin::Pin;
use std::sync::Arc;
use kailash_value::{Value, ValueMap};
use kailash_core::error::NodeError;
use kailash_core::node::{Node, NodeFactory, NodeMetadata, ParamDef, ParamType, ExecutionContext};

/// Transforms text with configurable operations.
pub struct TextTransformNode {
    input_params: Vec<ParamDef>,
    output_params: Vec<ParamDef>,
    // Config fields captured from from_config()
    default_operation: String,
}

impl TextTransformNode {
    /// Creates a `TextTransformNode` with a default operation.
    pub fn new(default_operation: &str) -> Self {
        Self {
            input_params: vec![
                ParamDef::new("text", ParamType::String, true)
                    .with_description("Input text to transform"),
                ParamDef::new("operation", ParamType::String, false)
                    .with_description("Transform operation: uppercase, lowercase, trim"),
            ],
            output_params: vec![
                ParamDef::new("result", ParamType::String, false)
                    .with_description("Transformed text"),
                ParamDef::new("length", ParamType::Integer, false)
                    .with_description("Length of transformed text"),
            ],
            default_operation: default_operation.to_string(),
        }
    }

    /// Creates a `TextTransformNode` from a configuration ValueMap.
    /// This is the canonical constructor for factory-created nodes.
    pub fn from_config(config: &ValueMap) -> Self {
        let default_op = config
            .get("operation" as &str)
            .and_then(|v| v.as_str())
            .unwrap_or("uppercase")
            .to_string();
        Self::new(&default_op)
    }
}

impl Node for TextTransformNode {
    fn type_name(&self) -> &str {
        "TextTransformNode"
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
        let default_op = self.default_operation.clone();

        Box::pin(async move {
            // Extract required input
            let text = inputs
                .get("text" as &str)
                .and_then(|v| v.as_str())
                .ok_or_else(|| NodeError::MissingInput { name: "text".into() })?
                .to_string();

            // Extract optional input with fallback to config default
            let operation = inputs
                .get("operation" as &str)
                .and_then(|v| v.as_str())
                .unwrap_or(&default_op)
                .to_string();

            // Apply operation
            let result = match operation.as_str() {
                "uppercase" => text.to_uppercase(),
                "lowercase" => text.to_lowercase(),
                "trim" => text.trim().to_string(),
                other => return Err(NodeError::ExecutionFailed {
                    message: format!("unknown operation '{}': expected uppercase, lowercase, or trim", other),
                    source: None,
                }),
            };

            let length = result.len() as i64;

            // Build output ValueMap
            let mut output = ValueMap::new();
            output.insert(Arc::from("result"), Value::String(Arc::from(result.as_str())));
            output.insert(Arc::from("length"), Value::Integer(length));
            Ok(output)
        })
    }
}

/// Factory for creating `TextTransformNode` instances from the registry.
pub struct TextTransformNodeFactory {
    metadata: NodeMetadata,
}

impl TextTransformNodeFactory {
    pub fn new() -> Self {
        Self {
            metadata: NodeMetadata {
                type_name: "TextTransformNode".to_string(),
                description: "Transforms text with configurable operations".to_string(),
                category: "transform".to_string(),
                input_params: vec![
                    ParamDef::new("text", ParamType::String, true)
                        .with_description("Input text to transform"),
                    ParamDef::new("operation", ParamType::String, false)
                        .with_description("Transform operation: uppercase, lowercase, trim"),
                ],
                output_params: vec![
                    ParamDef::new("result", ParamType::String, false)
                        .with_description("Transformed text"),
                    ParamDef::new("length", ParamType::Integer, false)
                        .with_description("Length of transformed text"),
                ],
                version: "0.1.0".to_string(),
                author: "Kailash".to_string(),
                tags: vec!["transform".to_string(), "text".to_string()],
            },
        }
    }
}

impl NodeFactory for TextTransformNodeFactory {
    fn create(&self, config: ValueMap) -> Result<Box<dyn Node>, NodeError> {
        Ok(Box::new(TextTransformNode::from_config(&config)))
    }

    fn metadata(&self) -> &NodeMetadata {
        &self.metadata
    }
}
```

## Registering Custom Nodes

```rust
use kailash_core::NodeRegistry;

pub fn register_transform_nodes(registry: &mut NodeRegistry) {
    registry.register(Box::new(TextTransformNodeFactory::new()));
    // Add more factories here
}
```

Then at runtime:

```rust
let mut registry = NodeRegistry::new();
register_transform_nodes(&mut registry);
let registry = Arc::new(registry);

let mut builder = WorkflowBuilder::new();
builder.add_node("TextTransformNode", "upper", {
    let mut c = ValueMap::new();
    c.insert(Arc::from("operation"), Value::String(Arc::from("uppercase")));
    c
});

let workflow = builder.build(&registry)?;
```

## ExecutionContext

The `_ctx: &ExecutionContext` parameter provides access to:

```rust
pub struct ExecutionContext {
    /// Unique run ID for this execution
    pub run_id: String,
    /// The ID of the node currently being executed
    pub node_id: String,
    /// Whether debug mode is enabled
    pub debug: bool,
    /// Global workflow inputs passed to runtime.execute()
    pub workflow_inputs: ValueMap,
    /// Cancellation token for cooperative cancellation
    pub cancellation_token: CancellationToken,
    /// Tracing span for structured logging
    pub span: tracing::Span,
}

// Usage in execute():
fn execute(&self, inputs: ValueMap, ctx: &ExecutionContext)
    -> Pin<Box<dyn Future<Output = Result<ValueMap, NodeError>> + Send + '_>>
{
    let run_id = ctx.run_id.clone();
    let node_id = ctx.node_id.clone();
    Box::pin(async move {
        tracing::info!(run_id = %run_id, node_id = %node_id, "Executing node");
        // Check for cancellation:
        if ctx.is_cancelled() {
            return Err(NodeError::ExecutionFailed {
                message: "cancelled".into(), source: None,
            });
        }
        // ...
    })
}
```

## Async Node with External I/O

For nodes that call external services (HTTP, database, etc.):

```rust
use reqwest::Client;

pub struct HTTPRequestNode {
    input_params: Vec<ParamDef>,
    output_params: Vec<ParamDef>,
    client: Client,  // Shared HTTP client (Clone is O(1) -- arc-backed)
}

impl HTTPRequestNode {
    pub fn new() -> Self {
        Self {
            input_params: vec![
                ParamDef::new("url", ParamType::String, true)
                    .with_description("Target URL"),
                ParamDef::new("method", ParamType::String, false)
                    .with_description("HTTP method (default: GET)"),
            ],
            output_params: vec![
                ParamDef::new("response", ParamType::Object, false)
                    .with_description("Parsed JSON response body"),
                ParamDef::new("status", ParamType::Integer, false)
                    .with_description("HTTP status code"),
            ],
            client: Client::new(),
        }
    }

    pub fn from_config(_config: &ValueMap) -> Self {
        Self::new()
    }
}

impl Node for HTTPRequestNode {
    fn type_name(&self) -> &str { "HTTPRequestNode" }
    fn input_params(&self) -> &[ParamDef] { &self.input_params }
    fn output_params(&self) -> &[ParamDef] { &self.output_params }

    fn execute(&self, inputs: ValueMap, _ctx: &ExecutionContext)
        -> Pin<Box<dyn Future<Output = Result<ValueMap, NodeError>> + Send + '_>>
    {
        let client = self.client.clone();

        Box::pin(async move {
            let url = inputs.get("url" as &str)
                .and_then(|v| v.as_str())
                .ok_or_else(|| NodeError::MissingInput { name: "url".into() })?
                .to_string();

            let method = inputs.get("method" as &str)
                .and_then(|v| v.as_str())
                .unwrap_or("GET")
                .to_string();

            let response = client
                .request(
                    method.parse().map_err(|e| NodeError::ExecutionFailed {
                        message: format!("invalid method '{}': {}", method, e),
                        source: None,
                    })?,
                    &url,
                )
                .send()
                .await
                .map_err(|e| NodeError::ExecutionFailed {
                    message: format!("HTTP request failed: {}", e),
                    source: Some(Box::new(e)),
                })?;

            let status = response.status().as_u16() as i64;

            let json: serde_json::Value = response.json().await.map_err(|e| NodeError::ExecutionFailed {
                message: format!("failed to parse JSON response: {}", e),
                source: Some(Box::new(e)),
            })?;

            let value: Value = json.into();  // serde_json::Value → kailash_value::Value

            let mut output = ValueMap::new();
            output.insert(Arc::from("response"), value);
            output.insert(Arc::from("status"), Value::Integer(status));
            Ok(output)
        })
    }
}
```

## Unit Tests for Custom Nodes

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use kailash_core::node::{Node, ExecutionContext};

    fn make_ctx() -> ExecutionContext {
        ExecutionContext::new("test-run", "test-node")
    }

    #[tokio::test]
    async fn test_uppercase_transforms_text() {
        let node = TextTransformNode::new("uppercase");
        let ctx = make_ctx();

        let mut inputs = ValueMap::new();
        inputs.insert(Arc::from("text"), Value::String(Arc::from("hello")));

        let result = node.execute(inputs, &ctx).await.unwrap();
        assert_eq!(
            result.get("result").and_then(|v| v.as_str()),
            Some("HELLO")
        );
        assert_eq!(
            result.get("length").and_then(|v| v.as_i64()),
            Some(5)
        );
    }

    #[tokio::test]
    async fn test_missing_required_input_returns_error() {
        let node = TextTransformNode::new("uppercase");
        let ctx = make_ctx();

        let result = node.execute(ValueMap::new(), &ctx).await;
        assert!(result.is_err());

        match result.unwrap_err() {
            NodeError::MissingInput { name } => assert_eq!(name, "text"),
            other => panic!("expected MissingInput, got {:?}", other),
        }
    }

    #[tokio::test]
    async fn test_from_config_reads_operation() {
        let mut config = ValueMap::new();
        config.insert(Arc::from("operation"), Value::String(Arc::from("lowercase")));
        let node = TextTransformNode::from_config(&config);

        let ctx = make_ctx();
        let mut inputs = ValueMap::new();
        inputs.insert(Arc::from("text"), Value::String(Arc::from("HELLO")));

        let result = node.execute(inputs, &ctx).await.unwrap();
        assert_eq!(
            result.get("result").and_then(|v| v.as_str()),
            Some("hello")
        );
    }

    #[test]
    fn test_factory_creates_node() {
        let factory = TextTransformNodeFactory::new();
        let config = ValueMap::new();
        let node = factory.create(config);
        assert!(node.is_ok());
        assert_eq!(node.unwrap().type_name(), "TextTransformNode");
    }
}
```

## Verify

For kailash-core nodes:

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo test -p kailash-core && cargo clippy -p kailash-core -- -D warnings
```

For kailash-nodes nodes:

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo test -p kailash-nodes && cargo clippy -p kailash-nodes -- -D warnings
```
