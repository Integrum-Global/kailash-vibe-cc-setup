---
name: dataflow-crud-patterns
description: "Complete CRUD operation patterns for kailash-dataflow. Use when asking 'how to create records', 'how to update with filters', 'how to delete', 'how to list with pagination', 'how to upsert', 'how to count', 'bulk operations', 'DataFlow node inputs', or 'DataFlow node outputs'."
---

# DataFlow CRUD Patterns

Comprehensive reference for all 11 generated node types per model, with exact input/output
`ValueMap` shapes derived from the actual source code in `crates/kailash-dataflow/src/`.

## Model Definition (Runtime Builder API)

Models are defined at runtime using `ModelDefinition`, not a compile-time proc-macro.
Each model generates 11 nodes: 7 CRUD + 4 Bulk.

```rust
use kailash_dataflow::prelude::*;

let model = ModelDefinition::new("User", "users")
    .field("id", FieldType::Integer, |f| f.primary_key())
    .field("name", FieldType::Text, |f| f.required())
    .field("email", FieldType::Text, |f| f.required())
    .field("age", FieldType::Integer, |f| f.nullable())
    .field("deleted_at", FieldType::Timestamp, |f| f.nullable().soft_delete())
    .auto_timestamps(); // adds created_at, updated_at (auto-managed)
```

## Node Summary Table

| Node                | Input Key(s)                                         | Output Key(s)                                           |
| ------------------- | ---------------------------------------------------- | ------------------------------------------------------- |
| `Create{Model}`     | flat writable fields                                 | `record` (Object), `id` (Integer)                       |
| `Read{Model}`       | `id`                                                 | `record` (Object), `found` (Bool)                       |
| `Update{Model}`     | `filter` (Object), `fields` (Object)                 | `updated_count` (Integer)                               |
| `Delete{Model}`     | `id`                                                 | `deleted_count` (Integer), `soft_deleted` (Bool)        |
| `List{Model}`       | `filter`, `order_by`, `order_dir`, `limit`, `offset` | `records` (Array), `count` (Integer), `total` (Integer) |
| `Upsert{Model}`     | `id` + flat writable fields                          | `record` (Object), `created` (Bool)                     |
| `Count{Model}`      | `filter` (Object)                                    | `count` (Integer)                                       |
| `BulkCreate{Model}` | `items` (Array of Objects)                           | `created_count` (Integer), `records` (Array)            |
| `BulkUpdate{Model}` | `items` (Array of `{filter, fields}`)                | `updated_count` (Integer)                               |
| `BulkDelete{Model}` | `ids` (Array) or `filter` (Object)                   | `deleted_count` (Integer)                               |
| `BulkUpsert{Model}` | `items` (Array of Objects)                           | `created_count`, `updated_count`, `records`             |

---

## CRUD Operations

### CreateUser -- Insert a Single Row

Inputs are **flat** writable field values. The primary key (`id`) is excluded (auto-generated).
Timestamps `created_at`/`updated_at` are auto-managed -- never provide them.

```rust
use std::{collections::BTreeMap, sync::Arc};
use kailash_value::{Value, ValueMap};

// Input ValueMap: flat field values
let mut inputs = BTreeMap::new();
inputs.insert(Arc::from("name"), Value::String(Arc::from("Alice")));
inputs.insert(Arc::from("email"), Value::String(Arc::from("alice@example.com")));
inputs.insert(Arc::from("age"), Value::Integer(30));
// DO NOT include "id", "created_at", or "updated_at"

// Output ValueMap after execution:
// {
//   "record": Value::Object({
//     "id": Value::Integer(1),
//     "name": Value::String("Alice"),
//     "email": Value::String("alice@example.com"),
//     "age": Value::Integer(30),
//     "created_at": Value::String("2026-03-07T12:00:00+00:00"),
//     "updated_at": Value::String("2026-03-07T12:00:00+00:00"),
//   }),
//   "id": Value::Integer(1),
// }
```

**Error cases:**

- Missing required field -> `NodeError::ExecutionFailed` with "missing required field: {name}"

### ReadUser -- Select by Primary Key

```rust
use std::{collections::BTreeMap, sync::Arc};
use kailash_value::{Value, ValueMap};

let mut inputs = BTreeMap::new();
inputs.insert(Arc::from("id"), Value::Integer(42));

// Output when found:
// {
//   "record": Value::Object({ full row }),
//   "found": Value::Bool(true),
// }

// Output when NOT found:
// {
//   "record": Value::Null,
//   "found": Value::Bool(false),
// }
```

For soft-delete models, `ReadUser` automatically adds `AND deleted_at IS NULL` to the query.

### UpdateUser -- Update with Filter + Fields

**Critical:** Update uses TWO separate objects: `filter` (WHERE clause) and `fields` (SET clause).
This is NOT the same as Create, which uses flat params.

```rust
use std::{collections::BTreeMap, sync::Arc};
use kailash_value::{Value, ValueMap};

// Filter: which rows to update (Value::Object format)
let mut filter = BTreeMap::new();
filter.insert(Arc::from("id"), Value::Integer(1));

// Fields: what to change (Value::Object format)
let mut fields = BTreeMap::new();
fields.insert(Arc::from("name"), Value::String(Arc::from("Alice Smith")));
fields.insert(Arc::from("email"), Value::String(Arc::from("alice.smith@example.com")));

let mut inputs = BTreeMap::new();
inputs.insert(Arc::from("filter"), Value::Object(filter));
inputs.insert(Arc::from("fields"), Value::Object(fields));

// Output:
// {
//   "updated_count": Value::Integer(1),
// }
```

**Error cases:**

- Empty `fields` object -> "no fields provided to update"
- Unknown column in `fields` -> "unknown column in update fields: {col}"
- Non-writable column (pk, auto-managed, soft-delete) -> "column '{col}' is not writable"
- `updated_at` is auto-set -- never include it in `fields`

### DeleteUser -- Delete by Primary Key

```rust
use std::{collections::BTreeMap, sync::Arc};
use kailash_value::{Value, ValueMap};

let mut inputs = BTreeMap::new();
inputs.insert(Arc::from("id"), Value::Integer(1));

// Output for hard delete (no soft_delete column):
// {
//   "deleted_count": Value::Integer(1),
//   "soft_deleted": Value::Bool(false),
// }

// Output for soft delete (model has soft_delete column):
// The row is NOT removed. Instead: UPDATE SET deleted_at = NOW(), updated_at = NOW()
// {
//   "deleted_count": Value::Integer(1),
//   "soft_deleted": Value::Bool(true),
// }
```

### ListUser -- Query with Filters, Pagination, Ordering

```rust
use std::{collections::BTreeMap, sync::Arc};
use kailash_value::{Value, ValueMap};

let mut inputs = BTreeMap::new();

// Optional filter (Value::Object, see Filter section below)
let mut filter = BTreeMap::new();
filter.insert(Arc::from("name"), Value::String(Arc::from("Alice")));
inputs.insert(Arc::from("filter"), Value::Object(filter));

// Optional ordering
inputs.insert(Arc::from("order_by"), Value::String(Arc::from("name")));
inputs.insert(Arc::from("order_dir"), Value::String(Arc::from("ASC"))); // or "DESC"

// Optional pagination (defaults: limit=100, offset=0, max limit=1000)
inputs.insert(Arc::from("limit"), Value::Integer(50));
inputs.insert(Arc::from("offset"), Value::Integer(10));

// Output:
// {
//   "records": Value::Array([ Value::Object({row1}), Value::Object({row2}), ... ]),
//   "count": Value::Integer(2),    // count of records in this page
//   "total": Value::Integer(150),  // total matching rows (ignoring limit/offset)
// }
```

For soft-delete models, `ListUser` automatically adds `WHERE deleted_at IS NULL`.

### UpsertUser -- Insert or Update on Conflict

Input shape is like `CreateUser` (flat writable fields) plus optional `id`.
Uses `ON CONFLICT(id) DO UPDATE SET ...` (SQLite/PostgreSQL) or
`ON DUPLICATE KEY UPDATE ...` (MySQL).

```rust
use std::{collections::BTreeMap, sync::Arc};
use kailash_value::{Value, ValueMap};

let mut inputs = BTreeMap::new();
inputs.insert(Arc::from("id"), Value::Integer(1)); // optional: include for upsert
inputs.insert(Arc::from("name"), Value::String(Arc::from("Alice")));
inputs.insert(Arc::from("email"), Value::String(Arc::from("alice@example.com")));

// Output:
// {
//   "record": Value::Object({ full row after insert-or-update }),
//   "created": Value::Bool(true),  // true if new row, false if updated existing
// }
```

### CountUser -- Count Matching Rows

```rust
use std::{collections::BTreeMap, sync::Arc};
use kailash_value::{Value, ValueMap};

let mut inputs = BTreeMap::new();

// Optional filter
let mut filter = BTreeMap::new();
filter.insert(Arc::from("name"), Value::String(Arc::from("Alice")));
inputs.insert(Arc::from("filter"), Value::Object(filter));

// Output:
// {
//   "count": Value::Integer(5),
// }
```

---

## Filter Format

Filters are `Value::Object` where keys are column names. The value specifies the comparison.

### Equality (shorthand)

```rust
use std::{collections::BTreeMap, sync::Arc};
use kailash_value::Value;

// {"name": "Alice"} -> WHERE name = ?
let mut filter = BTreeMap::new();
filter.insert(Arc::from("name"), Value::String(Arc::from("Alice")));
```

### Comparison Operators

Wrap the value in an object with an operator key:

```rust
use std::{collections::BTreeMap, sync::Arc};
use kailash_value::Value;

// {"age": {"$gt": 18, "$lt": 65}} -> WHERE age > ? AND age < ?
let mut ops = BTreeMap::new();
ops.insert(Arc::from("$gt"), Value::Integer(18));
ops.insert(Arc::from("$lt"), Value::Integer(65));

let mut filter = BTreeMap::new();
filter.insert(Arc::from("age"), Value::Object(ops));
```

### All Supported Operators

| Operator | SQL                       | Value Type                                     |
| -------- | ------------------------- | ---------------------------------------------- |
| `$eq`    | `column = ?`              | Any scalar                                     |
| `$ne`    | `column != ?`             | Any scalar                                     |
| `$gt`    | `column > ?`              | Any scalar                                     |
| `$gte`   | `column >= ?`             | Any scalar                                     |
| `$lt`    | `column < ?`              | Any scalar                                     |
| `$lte`   | `column <= ?`             | Any scalar                                     |
| `$like`  | `column LIKE ?`           | String (use `%` wildcards)                     |
| `$in`    | `column IN (?, ?, ...)`   | Array of values                                |
| `$null`  | `IS NULL` / `IS NOT NULL` | Bool (`true` = IS NULL, `false` = IS NOT NULL) |

### Filter Examples

```rust
use std::{collections::BTreeMap, sync::Arc};
use kailash_value::Value;

// LIKE pattern matching
let mut ops = BTreeMap::new();
ops.insert(Arc::from("$like"), Value::String(Arc::from("%smith%")));
let mut filter = BTreeMap::new();
filter.insert(Arc::from("name"), Value::Object(ops));
// -> WHERE name LIKE '%smith%'

// IN set membership
let mut ops = BTreeMap::new();
ops.insert(Arc::from("$in"), Value::Array(vec![
    Value::String(Arc::from("active")),
    Value::String(Arc::from("pending")),
]));
let mut filter = BTreeMap::new();
filter.insert(Arc::from("status"), Value::Object(ops));
// -> WHERE status IN ('active', 'pending')

// NULL check
let mut ops = BTreeMap::new();
ops.insert(Arc::from("$null"), Value::Bool(true));
let mut filter = BTreeMap::new();
filter.insert(Arc::from("deleted_at"), Value::Object(ops));
// -> WHERE deleted_at IS NULL

// Combined: multiple columns in one filter
let mut filter = BTreeMap::new();
filter.insert(Arc::from("name"), Value::String(Arc::from("Alice")));
let mut age_ops = BTreeMap::new();
age_ops.insert(Arc::from("$gte"), Value::Integer(18));
filter.insert(Arc::from("age"), Value::Object(age_ops));
// -> WHERE name = 'Alice' AND age >= 18
```

---

## Bulk Operations

### BulkCreateUser -- Insert Multiple Rows

```rust
use std::{collections::BTreeMap, sync::Arc};
use kailash_value::{Value, ValueMap};

let item1 = {
    let mut m = BTreeMap::new();
    m.insert(Arc::from("name"), Value::String(Arc::from("Alice")));
    m.insert(Arc::from("email"), Value::String(Arc::from("alice@example.com")));
    Value::Object(m)
};
let item2 = {
    let mut m = BTreeMap::new();
    m.insert(Arc::from("name"), Value::String(Arc::from("Bob")));
    m.insert(Arc::from("email"), Value::String(Arc::from("bob@example.com")));
    Value::Object(m)
};

let mut inputs = BTreeMap::new();
inputs.insert(Arc::from("items"), Value::Array(vec![item1, item2]));

// Output:
// {
//   "created_count": Value::Integer(2),
//   "records": Value::Array([ ...created rows... ]),
// }
```

Processes in chunks of 1000 rows for large batches.

### BulkUpdateUser -- Update Multiple Rows

Each item in `items` must have `filter` and `fields` sub-objects:

```rust
use std::{collections::BTreeMap, sync::Arc};
use kailash_value::{Value, ValueMap};

let update1 = {
    let mut m = BTreeMap::new();
    let mut filter = BTreeMap::new();
    filter.insert(Arc::from("id"), Value::Integer(1));
    m.insert(Arc::from("filter"), Value::Object(filter));
    let mut fields = BTreeMap::new();
    fields.insert(Arc::from("name"), Value::String(Arc::from("Alice Updated")));
    m.insert(Arc::from("fields"), Value::Object(fields));
    Value::Object(m)
};

let mut inputs = BTreeMap::new();
inputs.insert(Arc::from("items"), Value::Array(vec![update1]));

// Output:
// {
//   "updated_count": Value::Integer(1),
// }
```

### BulkDeleteUser -- Delete Multiple Rows

Accepts either `ids` (array of primary key values) or `filter` (object):

```rust
use std::{collections::BTreeMap, sync::Arc};
use kailash_value::{Value, ValueMap};

// Option A: delete by IDs
let mut inputs = BTreeMap::new();
inputs.insert(
    Arc::from("ids"),
    Value::Array(vec![Value::Integer(1), Value::Integer(2), Value::Integer(3)]),
);

// Option B: delete by filter
let mut inputs_b = BTreeMap::new();
let mut filter = BTreeMap::new();
filter.insert(Arc::from("name"), Value::String(Arc::from("old_user")));
inputs_b.insert(Arc::from("filter"), Value::Object(filter));

// Output:
// {
//   "deleted_count": Value::Integer(3),
// }
```

For soft-delete models, generates `UPDATE SET deleted_at = NOW()` instead of `DELETE`.

### BulkUpsertUser -- Bulk Insert-or-Update

```rust
use std::{collections::BTreeMap, sync::Arc};
use kailash_value::{Value, ValueMap};

let item1 = {
    let mut m = BTreeMap::new();
    m.insert(Arc::from("id"), Value::Integer(1));
    m.insert(Arc::from("name"), Value::String(Arc::from("Alice")));
    m.insert(Arc::from("email"), Value::String(Arc::from("alice@example.com")));
    Value::Object(m)
};

let mut inputs = BTreeMap::new();
inputs.insert(Arc::from("items"), Value::Array(vec![item1]));

// Output:
// {
//   "created_count": Value::Integer(0),
//   "updated_count": Value::Integer(1),
//   "records": Value::Array([ ...resulting rows... ]),
// }
```

---

## Workflow Example: Create-then-Read Pipeline

```rust
use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig, NodeRegistry};
use kailash_dataflow::prelude::*;
use kailash_value::{Value, ValueMap};
use std::{collections::BTreeMap, sync::Arc};

async fn example() -> Result<(), Box<dyn std::error::Error>> {
    // 1. Connect and register model
    let mut df = DataFlow::new("sqlite::memory:").await?;
    let model = ModelDefinition::new("User", "users")
        .field("id", FieldType::Integer, |f| f.primary_key())
        .field("name", FieldType::Text, |f| f.required())
        .field("email", FieldType::Text, |f| f.required())
        .auto_timestamps();
    df.register_model(model)?;

    // 2. Create table (in production, use migrations)
    df.execute_raw(
        "CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )"
    ).await?;

    // 3. Register nodes and build workflow
    let mut registry = NodeRegistry::default();
    df.register_nodes(&mut registry);
    let registry = Arc::new(registry);

    let mut builder = WorkflowBuilder::new();
    builder.add_node("CreateUser", "create", ValueMap::new());
    builder.add_node("ReadUser", "verify", ValueMap::new());
    builder.connect("create", "id", "verify", "id");

    let workflow = builder.build(&registry)?;
    let runtime = Runtime::new(RuntimeConfig::default(), Arc::clone(&registry));

    // 4. Execute
    let mut inputs = BTreeMap::new();
    inputs.insert(Arc::from("name"), Value::String(Arc::from("Alice")));
    inputs.insert(Arc::from("email"), Value::String(Arc::from("alice@example.com")));

    let result = runtime.execute(&workflow, inputs).await?;
    let verified = &result.results["verify"];
    // verified["record"] contains the full User row
    // verified["found"] = Value::Bool(true)

    Ok(())
}
```

<!-- Trigger Keywords: CRUD, create record, read record, update record, delete record, list records, upsert, count, bulk create, bulk update, bulk delete, bulk upsert, DataFlow inputs, DataFlow outputs, filter, ValueMap shape, node parameters -->
