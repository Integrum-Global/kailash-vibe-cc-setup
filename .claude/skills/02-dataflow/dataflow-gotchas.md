---
name: dataflow-gotchas
description: "Common DataFlow pitfalls and mistakes quick reference. Use when asking 'DataFlow gotcha', 'common mistake', 'why is my create failing', 'why is update not working', 'primary key error', 'created_at error', 'soft delete behavior', 'DataFlow is not ORM', or 'sqlx compile-time'."
---

# DataFlow Gotchas

Quick-reference of common kailash-dataflow pitfalls, all verified against
the actual source in `crates/kailash-dataflow/src/`.

---

## 1. Primary Key MUST Be Named `id`

The `ModelDefinition` defaults to `"id"` as the primary key column. If no field
has `.primary_key()` set, the system assumes `"id"`. Validation rejects models
with no primary key.

```rust
use kailash_dataflow::model::{ModelDefinition, FieldType};

// CORRECT
let model = ModelDefinition::new("User", "users")
    .field("id", FieldType::Integer, |f| f.primary_key())
    .field("name", FieldType::Text, |f| f.required());

// WRONG: validation fails -- "model must have a primary key field"
let bad = ModelDefinition::new("User", "users")
    .field("name", FieldType::Text, |f| f.required());
assert!(bad.validate().is_err());

// WRONG: multiple primary keys -- "model must have exactly one primary key"
let bad2 = ModelDefinition::new("User", "users")
    .field("id", FieldType::Integer, |f| f.primary_key())
    .field("code", FieldType::Text, |f| f.primary_key());
assert!(bad2.validate().is_err());
```

---

## 2. NEVER Manually Set `created_at` / `updated_at`

These fields are auto-managed when `.auto_timestamps()` is called. They are
excluded from writable fields, so the query builder will reject them.

```rust
use kailash_dataflow::model::{ModelDefinition, FieldType};

let model = ModelDefinition::new("User", "users")
    .field("id", FieldType::Integer, |f| f.primary_key())
    .field("name", FieldType::Text, |f| f.required())
    .auto_timestamps();

// writable_fields() returns only ["name"] -- NOT id, created_at, updated_at
let writable: Vec<&str> = model.writable_fields().iter().map(|f| f.name()).collect();
assert_eq!(writable, vec!["name"]);
```

If you try to UPDATE `created_at` or `updated_at`, you get:
`"column 'created_at' is not writable (primary key, auto-managed, or soft-delete)"`

Timestamps are bound as RFC 3339 string parameters (`chrono::Utc::now().to_rfc3339()`),
not SQL expressions. This ensures cross-database compatibility.

---

## 3. CreateModel Uses FLAT Params; UpdateModel Uses filter+fields

This is the most common source of confusion.

**Create** -- inputs are flat field values at the top level:

```rust
use std::{collections::BTreeMap, sync::Arc};
use kailash_value::Value;

// CORRECT for CreateUser
let mut inputs = BTreeMap::new();
inputs.insert(Arc::from("name"), Value::String(Arc::from("Alice")));
inputs.insert(Arc::from("email"), Value::String(Arc::from("alice@example.com")));
// NOT nested under any key -- flat at the top level
```

**Update** -- inputs are TWO nested objects: `filter` and `fields`:

```rust
use std::{collections::BTreeMap, sync::Arc};
use kailash_value::Value;

// CORRECT for UpdateUser
let mut filter = BTreeMap::new();
filter.insert(Arc::from("id"), Value::Integer(1));

let mut fields = BTreeMap::new();
fields.insert(Arc::from("name"), Value::String(Arc::from("Alice Smith")));

let mut inputs = BTreeMap::new();
inputs.insert(Arc::from("filter"), Value::Object(filter));
inputs.insert(Arc::from("fields"), Value::Object(fields));

// WRONG: passing flat params to Update
// inputs.insert(Arc::from("name"), Value::String(Arc::from("Alice Smith")));
// -> This will NOT work. Update requires filter+fields structure.
```

---

## 4. soft_delete Only Affects DELETE, But Also Filters SELECT/LIST

When a model has a `soft_delete` field:

- **DELETE** generates `UPDATE SET deleted_at = NOW()` instead of `DELETE FROM`
- **READ** (by id) adds `AND deleted_at IS NULL` to the WHERE clause
- **LIST** adds `WHERE deleted_at IS NULL` to exclude soft-deleted records

This means soft-deleted records are automatically excluded from reads and lists,
but they remain in the database.

```rust
use kailash_dataflow::model::{ModelDefinition, FieldType};

let model = ModelDefinition::new("Post", "posts")
    .field("id", FieldType::Integer, |f| f.primary_key())
    .field("title", FieldType::Text, |f| f.required())
    .field("deleted_at", FieldType::Timestamp, |f| f.nullable().soft_delete())
    .auto_timestamps();

assert!(model.has_soft_delete());
assert_eq!(model.soft_delete_column(), Some("deleted_at"));

// You cannot have more than one soft-delete column
// -> "model must have at most one soft-delete column"
```

---

## 5. DataFlow Is NOT an ORM

DataFlow generates workflow **nodes** that wrap sqlx queries. It does not:

- Map Rust structs to database rows (no `#[derive(FromRow)]`)
- Provide a query builder with method chaining (use `Value::Object` filters)
- Handle migrations automatically (use `execute_raw()` or external tools)
- Support lazy loading, eager loading, or relationships
- Manage schema changes

Each registered model produces 11 workflow nodes. Those nodes are used like
any other node in a `WorkflowBuilder` pipeline.

```rust
use kailash_dataflow::prelude::*;
use kailash_core::NodeRegistry;

// DataFlow registers NODE FACTORIES, not ORM entities
let mut df = DataFlow::new("sqlite::memory:").await?;
df.register_model(model)?;

let mut registry = NodeRegistry::default();
df.register_nodes(&mut registry);
// registry now has: CreateUser, ReadUser, UpdateUser, DeleteUser,
//                   ListUser, UpsertUser, CountUser,
//                   BulkCreateUser, BulkUpdateUser, BulkDeleteUser, BulkUpsertUser
```

---

## 6. SQL Identifier Validation

Model names, table names, and field names are validated as safe SQL identifiers.
They must match `[a-zA-Z_][a-zA-Z0-9_]*`. This prevents SQL injection through
identifier names.

```rust
use kailash_dataflow::model::{ModelDefinition, FieldType};

// REJECTED: SQL injection in table name
let bad = ModelDefinition::new("User", "users; DROP TABLE users")
    .field("id", FieldType::Integer, |f| f.primary_key());
assert!(bad.validate().is_err());
// -> "invalid table name"

// REJECTED: spaces in field name
let bad = ModelDefinition::new("User", "users")
    .field("id", FieldType::Integer, |f| f.primary_key())
    .field("full name", FieldType::Text, |f| f.required());
assert!(bad.validate().is_err());
// -> "invalid field name"

// REJECTED: Unicode characters
let bad = ModelDefinition::new("User", "users")
    .field("id", FieldType::Integer, |f| f.primary_key())
    .field("name", FieldType::Text, |f| f.required());
// Model names like "User--" or table names like "cafe" are also rejected
```

---

## 7. Filter Column Validation

Filters validate that column names exist in the model. Unknown columns are
rejected immediately, not silently ignored.

```rust
use std::{collections::BTreeMap, sync::Arc};
use kailash_dataflow::filter::parse_filter;
use kailash_dataflow::model::{ModelDefinition, FieldType};
use kailash_value::Value;

let model = ModelDefinition::new("User", "users")
    .field("id", FieldType::Integer, |f| f.primary_key())
    .field("name", FieldType::Text, |f| f.required());

// REJECTED: "nonexistent" is not a column in the model
let mut filter = BTreeMap::new();
filter.insert(Arc::from("nonexistent"), Value::Integer(1));
let result = parse_filter(&Value::Object(filter), &model);
assert!(result.is_err());
// -> "unknown column: nonexistent"
```

---

## 8. Update Field Validation

The `build_update` function validates that field keys in the `fields` object:

1. Exist as columns in the model
2. Are writable (not primary key, auto-managed, or soft-delete)

```rust
// These are REJECTED in UpdateUser fields:
// "id"         -> "column 'id' is not writable (primary key, auto-managed, or soft-delete)"
// "created_at" -> not writable (auto-managed)
// "updated_at" -> not writable (auto-managed)
// "deleted_at" -> not writable (soft-delete)
// "unknown"    -> "unknown column in update fields: unknown"
```

---

## 9. ORDER BY Validation

The `ListUser` node validates that `order_by` refers to a real column.
Unknown column names are rejected, not silently ignored.

```rust
// This will FAIL:
// inputs.insert(Arc::from("order_by"), Value::String(Arc::from("nonexistent")));
// -> "unknown column in ORDER BY: nonexistent"

// SQL injection attempts in ORDER BY are also caught by identifier validation:
// "name; DROP TABLE users" -> "invalid identifier in ORDER BY"
```

---

## 10. LIMIT/OFFSET Are Parameterized

LIMIT and OFFSET values are bound as `?` parameters, never interpolated into
the SQL string. This prevents SQL injection through pagination values.

Default values: `limit = 100` (capped at 1000), `offset = 0`.
Negative values are rejected: `"LIMIT must be non-negative"`.

---

## 11. Dialect-Specific Behavior

DataFlow auto-detects the SQL dialect from the connection URL and adjusts
query generation accordingly:

| Feature            | SQLite                      | PostgreSQL                      | MySQL                     |
| ------------------ | --------------------------- | ------------------------------- | ------------------------- |
| Placeholders       | `?`                         | `$1, $2, ...` (auto-translated) | `?`                       |
| Upsert             | `ON CONFLICT ... DO UPDATE` | `ON CONFLICT ... DO UPDATE`     | `ON DUPLICATE KEY UPDATE` |
| Timestamps         | `?`                         | `?::TIMESTAMPTZ`                | `?`                       |
| PK Retrieval       | `last_insert_rowid()`       | `RETURNING id`                  | `LAST_INSERT_ID()`        |
| Auto Increment     | `AUTOINCREMENT`             | `SERIAL`                        | `AUTO_INCREMENT`          |
| Identifier Quoting | `"name"`                    | `"name"`                        | `` `name` ``              |

You do not need to handle dialect differences manually -- the `QueryDialect`
enum dispatches automatically.

---

## 12. `auto_timestamps()` Is Idempotent

Calling `.auto_timestamps()` multiple times does not duplicate the
`created_at`/`updated_at` fields. It checks for existing fields before adding.

```rust
use kailash_dataflow::model::{ModelDefinition, FieldType};

let model = ModelDefinition::new("User", "users")
    .field("id", FieldType::Integer, |f| f.primary_key())
    .auto_timestamps()
    .auto_timestamps(); // safe -- no duplication

let ts_count = model.fields().iter()
    .filter(|f| f.name() == "created_at" || f.name() == "updated_at")
    .count();
assert_eq!(ts_count, 2); // exactly 2, not 4
```

---

## 13. Empty Bulk Operations Are Rejected

Bulk operations require at least one item/id. Empty inputs return an error:

- `build_bulk_insert(&model, &[])` -> "bulk insert requires at least one item"
- `build_bulk_delete(&model, &[])` -> "bulk delete requires at least one id"

`BulkCreateNode` handles empty items gracefully by returning
`{ created_count: 0, records: [] }` without hitting the database.

---

## 14. Null Filter Returns Empty Conditions

Passing `Value::Null` as a filter is valid and returns zero conditions
(effectively no WHERE clause). Passing a non-object, non-null value is
rejected: `"filter must be an object"`.

---

## 15. $in Requires Array, $null Requires Bool

```rust
// WRONG: $in with non-array
// {"name": {"$in": "alice"}} -> "$in requires an array value"

// WRONG: $null with non-bool
// {"age": {"$null": "yes"}} -> "$null requires a boolean value"
```

<!-- Trigger Keywords: gotcha, pitfall, common mistake, primary key, created_at, updated_at, flat params, filter fields, soft delete, not ORM, SQL injection, identifier validation, ORDER BY validation, LIMIT OFFSET, dialect, auto_timestamps, bulk empty, null filter -->
