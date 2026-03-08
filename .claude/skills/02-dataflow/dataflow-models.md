---
name: dataflow-models
description: "Complete reference for ModelDefinition runtime builder API, FieldType, FieldBuilder, field constraints, validation, and all 11 generated node types. Use when asking 'dataflow model', 'generated nodes', 'model definition', 'ModelDefinition', 'FieldType', 'field constraints', 'unique', 'index', or 'foreign key'."
---

# DataFlow Models Skill

Complete reference for the `ModelDefinition` runtime builder API and all 11 generated node types.

## Usage

`/dataflow-models` -- Reference for model definition, field types, builder options, and generated nodes

## ModelDefinition -- Runtime Builder API

Models are defined at runtime using `ModelDefinition::new()` with a fluent builder.
There is no compile-time proc-macro for DataFlow models.

```rust
use kailash_dataflow::model::{ModelDefinition, FieldType};

let model = ModelDefinition::new("User", "users")        // (model_name, table_name)
    .field("id", FieldType::Integer, |f| f.primary_key())
    .field("name", FieldType::Text, |f| f.required())
    .field("email", FieldType::Text, |f| f.required().unique())
    .field("age", FieldType::Integer, |f| f.nullable())
    .field("bio", FieldType::Text, |f| f.nullable().default(Value::from("No bio")))
    .field("deleted_at", FieldType::Timestamp, |f| f.nullable().soft_delete())
    .auto_timestamps(); // adds created_at and updated_at (auto-managed)
```

**Source:** `crates/kailash-dataflow/src/model.rs`

## FieldType -- SQL Column Types

| FieldType              | SQLite  | PostgreSQL       | MySQL      |
| ---------------------- | ------- | ---------------- | ---------- |
| `FieldType::Integer`   | INTEGER | BIGINT           | BIGINT     |
| `FieldType::Float`     | REAL    | DOUBLE PRECISION | DOUBLE     |
| `FieldType::Text`      | TEXT    | TEXT             | TEXT       |
| `FieldType::Boolean`   | INTEGER | BOOLEAN          | TINYINT(1) |
| `FieldType::Timestamp` | TEXT    | TIMESTAMPTZ      | DATETIME   |
| `FieldType::Json`      | TEXT    | JSONB            | JSON       |
| `FieldType::Uuid`      | TEXT    | UUID             | CHAR(36)   |

**Source:** `crates/kailash-dataflow/src/model.rs` -- `FieldType::sqlite_type()`, `postgres_type()`, `mysql_type()`

## FieldBuilder -- Field Configuration Options

Each `.field()` call receives a closure with a `FieldBuilder`. Chain methods:

| Method                       | Effect                                                   |
| ---------------------------- | -------------------------------------------------------- |
| `.primary_key()`             | Marks as PK. Also sets `required`. Must be exactly one.  |
| `.required()`                | NOT NULL. Must be provided on Create.                    |
| `.nullable()`                | Allows NULL. Clears `required`.                          |
| `.soft_delete()`             | DELETE sets this field to NOW() instead of removing row. |
| `.auto_managed()`            | Field is system-managed (e.g., custom timestamps).       |
| `.default(value)`            | Default value when field is absent on insert.            |
| `.unique()`                  | UNIQUE constraint on the column.                         |
| `.index()`                   | Creates a database index (CREATE INDEX).                 |
| `.references(table, column)` | Foreign key: REFERENCES table(column).                   |

### Examples

```rust
use kailash_dataflow::model::{ModelDefinition, FieldType};
use kailash_value::Value;

// Required text field
.field("name", FieldType::Text, |f| f.required())

// Nullable integer with default
.field("priority", FieldType::Integer, |f| f.nullable().default(Value::Integer(0)))

// Unique, indexed email
.field("email", FieldType::Text, |f| f.required().unique().index())

// Foreign key reference
.field("user_id", FieldType::Integer, |f| f.required().references("users", "id"))

// Multiple constraints combined
.field("org_id", FieldType::Integer, |f| {
    f.required().unique().index().references("organizations", "id")
})
```

## Model Validation Rules

`ModelDefinition::validate()` enforces:

1. **At least one field** -- "model has no fields"
2. **Exactly one primary key** -- "model must have a primary key field" / "exactly one primary key"
3. **At most one soft-delete** -- "model must have at most one soft-delete column"
4. **Valid SQL identifiers** -- model name, table name, and field names must match `[a-zA-Z_][a-zA-Z0-9_]*`
5. **Valid FK references** -- foreign key table and column names must be valid identifiers

Validation happens automatically on `DataFlow::register_model(model)`.

```rust
// Rejected: SQL injection in table name
let bad = ModelDefinition::new("User", "users; DROP TABLE users")
    .field("id", FieldType::Integer, |f| f.primary_key());
assert!(bad.validate().is_err());

// Rejected: field name starting with digit
let bad = ModelDefinition::new("User", "users")
    .field("id", FieldType::Integer, |f| f.primary_key())
    .field("1name", FieldType::Text, |f| f.required());
assert!(bad.validate().is_err());
```

## Auto-Timestamps

`.auto_timestamps()` adds two auto-managed fields:

- `created_at` (FieldType::Timestamp, NOT NULL, auto-managed) -- set on INSERT only
- `updated_at` (FieldType::Timestamp, NOT NULL, auto-managed) -- set on INSERT and UPDATE

These fields are:

- Excluded from `writable_fields()` (cannot be set manually)
- Bound as RFC 3339 strings (`chrono::Utc::now().to_rfc3339()`) for cross-database compatibility
- Idempotent: calling `.auto_timestamps()` twice does not duplicate fields

```rust
let model = ModelDefinition::new("User", "users")
    .field("id", FieldType::Integer, |f| f.primary_key())
    .field("name", FieldType::Text, |f| f.required())
    .auto_timestamps();

// writable_fields() returns only ["name"]
let writable: Vec<&str> = model.writable_fields().iter().map(|f| f.name()).collect();
assert_eq!(writable, vec!["name"]);

// All column names: id, name, created_at, updated_at
assert_eq!(model.fields().len(), 4);
```

## Model Accessor Methods

| Method                   | Returns                                       |
| ------------------------ | --------------------------------------------- |
| `.name()`                | Model name (e.g., "User")                     |
| `.table()`               | Table name (e.g., "users")                    |
| `.primary_key()`         | PK column name (defaults to "id")             |
| `.fields()`              | `&[FieldDef]` -- all field definitions        |
| `.field_by_name(name)`   | `Option<&FieldDef>` -- lookup by column name  |
| `.writable_fields()`     | `Vec<&FieldDef>` -- excluding PK, auto, soft  |
| `.column_names()`        | `Vec<&str>` -- all column names               |
| `.has_soft_delete()`     | `bool`                                        |
| `.soft_delete_column()`  | `Option<&str>` -- the soft-delete column name |
| `.has_auto_timestamps()` | `bool`                                        |
| `.dialect()`             | `QueryDialect` -- set by DataFlow on register |
| `.validate()`            | `Result<(), DataFlowError>`                   |

## Generated Node Types (11 per model)

When a model named "User" is registered, these 11 node types are created:

| Node Type        | Operation                                         |
| ---------------- | ------------------------------------------------- |
| `CreateUser`     | INSERT one record (flat writable fields as input) |
| `ReadUser`       | SELECT one by primary key                         |
| `UpdateUser`     | UPDATE with `filter` + `fields` inputs            |
| `DeleteUser`     | DELETE (or soft-delete) by primary key            |
| `ListUser`       | SELECT with filters, ordering, pagination         |
| `UpsertUser`     | INSERT or UPDATE on conflict                      |
| `CountUser`      | SELECT COUNT with optional filter                 |
| `BulkCreateUser` | Batch INSERT (input: `items` array)               |
| `BulkUpdateUser` | Batch UPDATE (input: array of `{filter, fields}`) |
| `BulkDeleteUser` | Batch DELETE (input: `ids` array or `filter`)     |
| `BulkUpsertUser` | Batch INSERT or UPDATE                            |

For input/output shapes, see `dataflow-crud-patterns.md`.

## Python Binding

```python
from kailash import ModelDefinition, FieldType

# Create model
model = ModelDefinition("User", "users")
model.field("id", FieldType.integer(), primary_key=True)
model.field("name", FieldType.text(), required=True)
model.field("email", FieldType.text(), required=True, unique=True)
model.field("age", FieldType.integer(), nullable=True)
model.field("user_id", FieldType.integer(), required=True, references=("users", "id"))
model.auto_timestamps()

# Accessors
model.name           # "User"
model.table_name     # "users"
model.primary_key    # "id"
model.has_soft_delete       # False
model.has_auto_timestamps   # True
model.fields                # list of FieldDef objects

# Validate
model.validate()     # raises RuntimeError on failure
```

**FieldType static methods in Python:**
`FieldType.integer()`, `FieldType.float()`, `FieldType.real()` (alias for float),
`FieldType.text()`, `FieldType.boolean()`, `FieldType.timestamp()`,
`FieldType.json()`, `FieldType.uuid()`

**FieldDef properties in Python:**
`name`, `field_type`, `is_primary_key`, `is_nullable`, `is_required`,
`is_soft_delete`, `is_auto_managed`, `is_unique`, `is_indexed`,
`references` (returns `{"table": ..., "column": ...}` dict or `None`)

## Verify

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" \
  SDKROOT=$(xcrun --show-sdk-path) \
  cargo test -p kailash-dataflow -- --nocapture 2>&1
```
