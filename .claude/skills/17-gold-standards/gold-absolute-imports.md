---
name: gold-absolute-imports
description: "Import and module organization standard for the Kailash Rust SDK requiring proper use paths and crate dependencies. Use when asking 'import standards', 'use paths', 'module organization', 'crate imports', or 'import gold standard'."
---

# Gold Standard: Import and Module Organization

Gold standard for `use` declarations, crate dependencies, and module organization in the Kailash Rust SDK.

> **Skill Metadata**
> Category: `gold-standards`
> Priority: `HIGH`

## Quick Reference

- **Primary Use**: Gold Standard: Import and Module Organization
- **Category**: gold-standards
- **Priority**: HIGH
- **Trigger Keywords**: import standards, use paths, module organization, crate imports

## Core Pattern

```rust
// ✅ CORRECT: Use absolute crate paths
use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use kailash_core::{Node, ParamDef, NodeError, ExecutionContext};
use std::sync::Arc;
use std::pin::Pin;
use std::future::Future;
```

## Import Rules

### 1. Use Absolute Crate Paths

```rust
// ✅ CORRECT: Absolute crate path
use kailash_core::WorkflowBuilder;
use kailash_dataflow::ModelDefinition;
use kailash_nexus::NexusApp;
use kailash_kaizen::BaseAgent;

// ❌ WRONG: Relative paths in non-submodule context
// use super::super::core::WorkflowBuilder;
```

### 2. Group Imports by Origin

```rust
// ✅ CORRECT: Standard library, then external crates, then workspace crates
use std::sync::Arc;
use std::collections::HashMap;

use serde::{Serialize, Deserialize};
use tokio::sync::Mutex;

use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig};
use kailash_core::value::{Value, ValueMap};
```

### 3. Use `self` and `super` Only Within a Crate

```rust
// ✅ CORRECT: super within the same crate's module tree
mod submodule {
    use super::ParentStruct; // OK within same crate
}

// ✅ CORRECT: crate:: for same-crate absolute paths
use crate::error::AppError;
use crate::config::Settings;
```

### 4. Re-export Through Prelude Modules

```rust
// ✅ CORRECT: Crate preludes for common items
use kailash_core::prelude::*;

// For crate authors: define a prelude
pub mod prelude {
    pub use crate::WorkflowBuilder;
    pub use crate::Runtime;
    pub use crate::value::{Value, ValueMap};
}
```

### 5. Feature-Gated Imports

```rust
// ✅ CORRECT: Guard imports behind feature flags
#[cfg(feature = "yaml")]
use kailash_core::WorkflowDefinition;

#[cfg(feature = "integration")]
use sqlx::PgPool;
```

## Cargo.toml Dependency Patterns

```toml
# ✅ CORRECT: Workspace crate dependencies
[dependencies]
kailash-core = { path = "../kailash-core" }
kailash-value = { path = "../kailash-value" }

# ✅ CORRECT: External dependencies with version
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }

# ✅ CORRECT: Optional dependencies behind feature flags
[features]
default = []
yaml = ["kailash-core/yaml"]
integration = ["sqlx", "dotenvy"]
```

## Common Use Cases

- **Workflow building**: `use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig, NodeRegistry};`
- **Value manipulation**: `use kailash_core::value::{Value, ValueMap};`
- **Custom nodes**: `use kailash_core::{Node, ParamDef, NodeError, ExecutionContext};`
- **DataFlow models**: `use kailash_dataflow::{ModelDefinition, DataFlowConfig};`
- **Nexus handlers**: `use kailash_nexus::{NexusApp, HandlerConfig};`
- **Kaizen agents**: `use kailash_kaizen::{BaseAgent, AgentConfig};`
- **Enterprise RBAC**: `use kailash_enterprise::{RbacEvaluator, Permission};`

## Anti-Patterns

```rust
// ❌ BAD: Wildcard imports in production code (except preludes)
use kailash_core::*;

// ❌ BAD: Unused imports
use kailash_core::Runtime; // Never used — cargo clippy will catch this

// ❌ BAD: Importing internal/private modules from other crates
use kailash_core::internal::scheduler; // Not part of public API
```

## Related Patterns

- **For crate architecture**: See [`CLAUDE.md`](../../../../CLAUDE.md) (Crate Dependency Graph)
- **For feature flags**: See Cargo.toml workspace configuration

## Quick Tips

- 💡 **Tip 1**: Run `cargo clippy -- -D warnings` to catch unused imports
- 💡 **Tip 2**: Use `cargo fmt` to auto-sort and group imports
- 💡 **Tip 3**: Check `CLAUDE.md` Crate Dependency Graph for valid dependency directions

## Keywords for Auto-Trigger

<!-- Trigger Keywords: import standards, use paths, module organization, crate imports, import gold standard, use declarations -->
