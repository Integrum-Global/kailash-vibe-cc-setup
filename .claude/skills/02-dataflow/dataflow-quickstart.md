---
name: dataflow-quickstart
description: "DataFlow in 5 minutes: connect to a database, define models, register nodes, run CRUD workflows or use DataFlowExpress for direct operations. Use when asking 'dataflow quickstart', 'dataflow getting started', 'first dataflow model', 'DataFlowExpress', or 'dataflow without workflow'."
---

# DataFlow Quickstart Skill

DataFlow in 5 minutes: connect, define models, run CRUD via workflows or DataFlowExpress.

## Usage

`/dataflow-quickstart` -- Fastest path to database-backed workflows with kailash-dataflow

## What DataFlow Does

DataFlow is NOT an ORM. It takes `ModelDefinition` objects (runtime builder API) and
generates 11 workflow node types per model. Those nodes are registered into `NodeRegistry`
and used exactly like any other workflow node. Alternatively, `DataFlowExpress` provides
direct CRUD without building workflows.

## Step 1: Connect to a Database

```rust
use kailash_dataflow::connection::{DataFlow, DataFlowConfig};

// From a URL (auto-detects dialect: SQLite, PostgreSQL, MySQL)
let mut df = DataFlow::new("sqlite::memory:").await?;

// From the DATABASE_URL environment variable (loads .env via dotenvy)
let mut df = DataFlow::from_env().await?;

// From a config (pool tuning, auto-migrate, test mode)
let config = DataFlowConfig::new("postgres://user:pass@localhost/mydb")
    .with_max_connections(20)
    .with_min_connections(5)
    .with_auto_migrate(true);
let mut df = DataFlow::from_config(config).await?;
```

**Supported URL formats:**

| Database   | URL Format                          |
| ---------- | ----------------------------------- |
| SQLite     | `sqlite::memory:`, `sqlite:data.db` |
| PostgreSQL | `postgres://user:pass@host/db`      |
| MySQL      | `mysql://user:pass@host/db`         |
| MariaDB    | `mariadb://user:pass@host/db`       |

Dialect is auto-detected via `QueryDialect::from_url()`.

## Step 2: Define a Model (Runtime Builder API)

Models are defined at runtime using `ModelDefinition`, not a compile-time proc-macro.

```rust
use kailash_dataflow::model::{ModelDefinition, FieldType};

let model = ModelDefinition::new("User", "users")
    .field("id", FieldType::Integer, |f| f.primary_key())
    .field("name", FieldType::Text, |f| f.required())
    .field("email", FieldType::Text, |f| f.required().unique())
    .field("age", FieldType::Integer, |f| f.nullable())
    .field("deleted_at", FieldType::Timestamp, |f| f.nullable().soft_delete())
    .auto_timestamps(); // adds created_at, updated_at (auto-managed)

// Register the model (validates it)
df.register_model(model)?;
```

## Step 3: Create the Table

```rust
// Option A: Execute DDL manually
df.execute_raw(
    "CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        age INTEGER,
        deleted_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    )"
).await?;

// Option B: Use DataFlowConfig::with_auto_migrate(true) + DataFlowExpress
// (auto-creates tables on model registration)

// Option C: Use MigrationManager for production schema versioning
use kailash_dataflow::migration::MigrationManager;
let mgr = MigrationManager::new();
let migration = mgr.generate_migration(df.models(), &df).await?;
mgr.apply(&migration, &df).await?;
```

## Step 4: Register Nodes and Build a Workflow

```rust
use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig, NodeRegistry};
use kailash_value::{Value, ValueMap};
use std::{collections::BTreeMap, sync::Arc};

// Register all 11 node types per model into a NodeRegistry
let mut registry = NodeRegistry::default();
df.register_nodes(&mut registry);
let registry = Arc::new(registry);

// Build a workflow: create a user then read it back
let mut builder = WorkflowBuilder::new();
builder.add_node("CreateUser", "create", ValueMap::new());
builder.add_node("ReadUser", "verify", ValueMap::new());
builder.connect("create", "id", "verify", "id");

let workflow = builder.build(&registry)?;
let runtime = Runtime::new(RuntimeConfig::default(), Arc::clone(&registry));

// CreateUser takes flat params matching model writable fields
let mut inputs = BTreeMap::new();
inputs.insert(Arc::from("name"), Value::String(Arc::from("Alice")));
inputs.insert(Arc::from("email"), Value::String(Arc::from("alice@example.com")));

let result = runtime.execute(&workflow, inputs).await?;
let created = &result.results["create"];
// created["record"] = Value::Object({ id, name, email, age, created_at, updated_at })
// created["id"] = Value::Integer(1)
```

## Alternative: DataFlowExpress (Direct CRUD Without Workflows)

`DataFlowExpress` provides `create`, `read`, `update`, `delete`, `list`, `count`,
and `bulk_create` methods directly -- no `WorkflowBuilder` needed.

```rust
use kailash_dataflow::express::DataFlowExpress;
use kailash_dataflow::model::{ModelDefinition, FieldType};
use kailash_value::{Value, value_map};
use std::sync::Arc;

// Create with auto_migrate=true (tables created automatically)
let mut express = DataFlowExpress::new("sqlite::memory:", true).await?;

let model = ModelDefinition::new("User", "users")
    .field("id", FieldType::Integer, |f| f.primary_key())
    .field("name", FieldType::Text, |f| f.required())
    .field("email", FieldType::Text, |f| f.required())
    .auto_timestamps();

express.register_model(model)?;
express.create_tables().await?;

// Create
let data = value_map! { "name" => "Alice", "email" => "alice@example.com" };
let created = express.create("User", data).await?;
// created is HashMap<String, Value> with all columns including auto-generated id

// Read by primary key
let user = express.read("User", Value::Integer(1)).await?;
// user is Option<HashMap<String, Value>>

// Update by primary key
let fields = value_map! { "name" => "Alice Smith" };
let updated = express.update("User", Value::Integer(1), fields).await?;

// Delete by primary key (soft-delete if model has soft_delete field)
let deleted = express.delete("User", Value::Integer(1)).await?;
// deleted is bool -- true if a row was affected

// List with optional filters
use kailash_dataflow::filter::{FilterCondition, FilterOp};
let filters = vec![FilterCondition {
    column: "name".to_string(),
    operator: FilterOp::Like,
    values: vec![Value::from("%Alice%")],
}];
let rows = express.list("User", Some(&filters)).await?;

// Count
let total = express.count("User", None).await?;

// Bulk create
let items = vec![
    value_map! { "name" => "Bob", "email" => "bob@example.com" },
    value_map! { "name" => "Carol", "email" => "carol@example.com" },
];
let created_rows = express.bulk_create("User", items).await?;
```

## Schema Inspection (DataFlowInspector)

Inspect the live database schema at runtime:

```rust
use kailash_dataflow::inspector::DataFlowInspector;

// List all tables
let tables = DataFlowInspector::tables(&df).await?;

// Get table metadata (columns, row count)
let info = DataFlowInspector::table_info(&df, "users").await?;
for col in &info.columns {
    println!("{}: {} (nullable: {}, pk: {})",
        col.name, col.data_type, col.is_nullable, col.is_primary_key);
}

// Get indexes
let indexes = DataFlowInspector::indexes(&df, "users").await?;

// Count rows
let count = DataFlowInspector::row_count(&df, "users").await?;

// Sample data
let sample = DataFlowInspector::sample(&df, "users", 5).await?;
```

## StrictMode Validation

Enable strict validation for type checking, required field enforcement, and
read-only field protection:

```rust
use kailash_dataflow::strict::StrictMode;

// Enable globally
StrictMode::enable();

// Validate before insert
let data = value_map! { "name" => "Alice", "email" => "alice@example.com" };
StrictMode::validate_insert(&model, &data)?;

// Validate before update
let update_data = value_map! { "name" => "Alice Smith" };
StrictMode::validate_update(&model, &update_data)?;

// Disable when done
StrictMode::disable();
```

## Python Binding

The Python binding exposes `DataFlow`, `ModelDefinition`, `FieldType`, `FilterCondition`,
`DataFlowTransaction`, and `DataFlowInspector` as native Python classes.

```python
from kailash import DataFlow, ModelDefinition, FieldType, FilterCondition

# Connect
df = DataFlow("sqlite::memory:")

# Define model
model = ModelDefinition("User", "users")
model.field("id", FieldType.integer(), primary_key=True)
model.field("name", FieldType.text(), required=True)
model.field("email", FieldType.text(), required=True)
model.auto_timestamps()

# Register and create table
df.register_model(model)
df.execute_raw("CREATE TABLE users (...)")

# Register nodes into a NodeRegistry
registry = NodeRegistry()
df.register_nodes(registry)

# Use FilterCondition for queries
f = FilterCondition("name", "eq", "Alice")
f = FilterCondition("age", "gte", 18)
f = FilterCondition("status", "in", ["active", "pending"])
f = FilterCondition("deleted_at", "is_null")

# Shorthand static methods
f = FilterCondition.eq("name", "Alice")
f = FilterCondition.gt("age", 18)
f = FilterCondition.like("name", "%smith%")
```

**Python decorator approach** (`@db.model`): The Python compatibility layer in
`bindings/kailash-python/python/kailash/dataflow.py` provides a `@db.model`
decorator that wraps this builder API. See the Python binding docs for details.

## Critical Rules

1. NEVER manually set `created_at` or `updated_at` -- they are auto-managed
2. `CreateUser` uses FLAT params (not nested objects)
3. Primary key field must use `.primary_key()` in the builder
4. `soft_delete` marks records deleted AND filters them from READ/LIST
5. DataFlow is NOT an ORM -- it generates workflow nodes
6. All queries use parameterized `?` placeholders (never string interpolation)

## Verify

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" \
  SDKROOT=$(xcrun --show-sdk-path) \
  cargo test -p kailash-dataflow -- --nocapture 2>&1
```
