# Add Node Skill

Scaffold a new node implementation for the Kailash workflow engine.

## Usage

`/add-node <NodeName> <category>` -- Create a new node with the given name in the given category

Example: `/add-node HTTPRequestNode http`

## Node Categories and Locations

### kailash-core nodes (crate: `kailash-core`)

| Category       | Module Path                                     | Registration Function         |
| -------------- | ----------------------------------------------- | ----------------------------- |
| `system`       | `crates/kailash-core/src/nodes/system/mod.rs`   | `register_system_nodes`       |
| `control_flow` | `crates/kailash-core/src/nodes/control_flow.rs` | `register_control_flow_nodes` |
| `transform`    | `crates/kailash-core/src/nodes/transform.rs`    | `register_transform_nodes`    |

### kailash-nodes nodes (crate: `kailash-nodes`)

| Category      | Module Path                                   | Registration Function        |
| ------------- | --------------------------------------------- | ---------------------------- |
| `http`        | `crates/kailash-nodes/src/http/mod.rs`        | `register_http_nodes`        |
| `sql`         | `crates/kailash-nodes/src/sql/mod.rs`         | `register_sql_nodes`         |
| `file`        | `crates/kailash-nodes/src/file/mod.rs`        | `register_file_nodes`        |
| `ai`          | `crates/kailash-nodes/src/ai/mod.rs`          | `register_ai_nodes`          |
| `auth`        | `crates/kailash-nodes/src/auth/mod.rs`        | `register_auth_nodes`        |
| `security`    | `crates/kailash-nodes/src/security/mod.rs`    | `register_security_nodes`    |
| `monitoring`  | `crates/kailash-nodes/src/monitoring/mod.rs`  | `register_monitoring_nodes`  |
| `admin`       | `crates/kailash-nodes/src/admin/mod.rs`       | `register_admin_nodes`       |
| `edge`        | `crates/kailash-nodes/src/edge/mod.rs`        | `register_edge_nodes`        |
| `transaction` | `crates/kailash-nodes/src/transaction/mod.rs` | `register_transaction_nodes` |
| `enterprise`  | `crates/kailash-nodes/src/enterprise/mod.rs`  | `register_enterprise_nodes`  |
| `code`        | `crates/kailash-nodes/src/code/mod.rs`        | `register_code_nodes`        |
| `rag`         | `crates/kailash-nodes/src/rag/mod.rs`         | `register_rag_nodes`         |
| `cache`       | `crates/kailash-nodes/src/cache/mod.rs`       | `register_cache_nodes`       |
| `streaming`   | `crates/kailash-nodes/src/streaming/mod.rs`   | `register_streaming_nodes`   |
| `redis`       | `crates/kailash-nodes/src/redis/mod.rs`       | `register_redis_nodes`       |
| `vector`      | `crates/kailash-nodes/src/vector/mod.rs`      | `register_vector_nodes`      |
| `alerts`      | `crates/kailash-nodes/src/alerts/mod.rs`      | `register_alert_nodes`       |
| `transform`   | `crates/kailash-nodes/src/transform/mod.rs`   | `register_transform_nodes`   |

## Steps

1. Read existing node patterns from the target category module (see table above). If the category is in `kailash-core`, look at `crates/kailash-core/src/nodes/`. If in `kailash-nodes`, look at `crates/kailash-nodes/src/<category>/`.

2. If adding a node to an existing category, add the new file to the category module (e.g., `crates/kailash-nodes/src/<category>/<node_name>.rs`). If the category uses a single file (like `control_flow.rs`), add to that file.

3. Create the node struct, implementing:
   - `pub struct {NodeName}` with `input_params`, `output_params`, and config fields
   - `impl {NodeName}` with `pub fn new(...)` and `pub fn from_config(config: &ValueMap)` constructors
   - `impl Node for {NodeName}` with all 4 methods (`type_name`, `input_params`, `output_params`, `execute`)
   - `pub struct {NodeName}Factory` with `metadata: NodeMetadata`
   - `impl NodeFactory for {NodeName}Factory`

4. Add the node to the `register_{category}_nodes` function in the category's `mod.rs`

5. Export from `nodes/mod.rs` and `lib.rs` (if in `kailash-nodes`, also update `register_all_nodes` in `lib.rs`)

6. Write unit tests covering:
   - Each operation/mode
   - Missing required inputs
   - Invalid input types
   - Edge cases
   - Factory creation from config
   - `from_config(&ValueMap)` constructor

## Template

### For kailash-core nodes

```rust
use std::future::Future;
use std::pin::Pin;
use std::sync::Arc;
use kailash_value::{Value, ValueMap};
use crate::error::NodeError;
use crate::node::{Node, NodeFactory, NodeMetadata, ParamDef, ParamType, ExecutionContext};

/// Description of what the node does.
pub struct {NodeName} {
    input_params: Vec<ParamDef>,
    output_params: Vec<ParamDef>,
}

impl {NodeName} {
    /// Creates a new `{NodeName}`.
    pub fn new() -> Self {
        Self {
            input_params: vec![
                ParamDef::new("data", ParamType::Any, true)
                    .with_description("Input data"),
            ],
            output_params: vec![
                ParamDef::new("result", ParamType::Any, false)
                    .with_description("Output result"),
            ],
        }
    }

    /// Creates a `{NodeName}` from a configuration map.
    pub fn from_config(_config: &ValueMap) -> Self {
        Self::new()
    }
}

impl Node for {NodeName} {
    fn type_name(&self) -> &str { "{NodeName}" }
    fn input_params(&self) -> &[ParamDef] { &self.input_params }
    fn output_params(&self) -> &[ParamDef] { &self.output_params }
    fn execute(&self, inputs: ValueMap, _ctx: &ExecutionContext)
        -> Pin<Box<dyn Future<Output = Result<ValueMap, NodeError>> + Send + '_>> {
        Box::pin(async move {
            let data = inputs.get("data" as &str)
                .ok_or_else(|| NodeError::MissingInput { name: "data".into() })?;
            let mut output = ValueMap::new();
            output.insert(Arc::from("result"), data.clone());
            Ok(output)
        })
    }
}

/// Factory for creating `{NodeName}` instances.
pub struct {NodeName}Factory {
    metadata: NodeMetadata,
}

impl {NodeName}Factory {
    /// Creates a new factory.
    pub fn new() -> Self {
        Self {
            metadata: NodeMetadata {
                type_name: "{NodeName}".to_string(),
                description: "Description of {NodeName}".to_string(),
                category: "{category}".to_string(),
                input_params: vec![
                    ParamDef::new("data", ParamType::Any, true)
                        .with_description("Input data"),
                ],
                output_params: vec![
                    ParamDef::new("result", ParamType::Any, false)
                        .with_description("Output result"),
                ],
                version: "0.1.0".to_string(),
                author: "Kailash".to_string(),
                tags: vec!["{category}".to_string()],
            },
        }
    }
}

impl NodeFactory for {NodeName}Factory {
    fn create(&self, config: ValueMap) -> Result<Box<dyn Node>, NodeError> {
        Ok(Box::new({NodeName}::from_config(&config)))
    }

    fn metadata(&self) -> &NodeMetadata {
        &self.metadata
    }
}
```

### For kailash-nodes nodes

```rust
use std::future::Future;
use std::pin::Pin;
use std::sync::Arc;
use kailash_value::{Value, ValueMap};
use kailash_core::error::NodeError;
use kailash_core::node::{Node, NodeFactory, NodeMetadata, ParamDef, ParamType, ExecutionContext};

/// Description of what the node does.
pub struct {NodeName} {
    input_params: Vec<ParamDef>,
    output_params: Vec<ParamDef>,
}

impl {NodeName} {
    /// Creates a new `{NodeName}`.
    pub fn new() -> Self {
        Self {
            input_params: vec![
                ParamDef::new("data", ParamType::Any, true)
                    .with_description("Input data"),
            ],
            output_params: vec![
                ParamDef::new("result", ParamType::Any, false)
                    .with_description("Output result"),
            ],
        }
    }

    /// Creates a `{NodeName}` from a configuration map.
    pub fn from_config(_config: &ValueMap) -> Self {
        Self::new()
    }
}

impl Node for {NodeName} {
    fn type_name(&self) -> &str { "{NodeName}" }
    fn input_params(&self) -> &[ParamDef] { &self.input_params }
    fn output_params(&self) -> &[ParamDef] { &self.output_params }
    fn execute(&self, inputs: ValueMap, _ctx: &ExecutionContext)
        -> Pin<Box<dyn Future<Output = Result<ValueMap, NodeError>> + Send + '_>> {
        Box::pin(async move {
            let data = inputs.get("data" as &str)
                .ok_or_else(|| NodeError::MissingInput { name: "data".into() })?;
            let mut output = ValueMap::new();
            output.insert(Arc::from("result"), data.clone());
            Ok(output)
        })
    }
}

/// Factory for creating `{NodeName}` instances.
pub struct {NodeName}Factory {
    metadata: NodeMetadata,
}

impl {NodeName}Factory {
    /// Creates a new factory.
    pub fn new() -> Self {
        Self {
            metadata: NodeMetadata {
                type_name: "{NodeName}".to_string(),
                description: "Description of {NodeName}".to_string(),
                category: "{category}".to_string(),
                input_params: vec![
                    ParamDef::new("data", ParamType::Any, true)
                        .with_description("Input data"),
                ],
                output_params: vec![
                    ParamDef::new("result", ParamType::Any, false)
                        .with_description("Output result"),
                ],
                version: "0.1.0".to_string(),
                author: "Kailash".to_string(),
                tags: vec!["{category}".to_string()],
            },
        }
    }
}

impl NodeFactory for {NodeName}Factory {
    fn create(&self, config: ValueMap) -> Result<Box<dyn Node>, NodeError> {
        Ok(Box::new({NodeName}::from_config(&config)))
    }

    fn metadata(&self) -> &NodeMetadata {
        &self.metadata
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
