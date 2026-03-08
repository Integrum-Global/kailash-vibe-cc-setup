---
name: dataflow-transactions
description: "Transaction management and connection pool patterns for kailash-dataflow. Use when asking 'how to use transactions', 'begin commit rollback', 'RAII auto-rollback', 'connection pool configuration', 'DataFlowTransaction', 'SqlConnection', 'begin_immediate', or 'transaction with tenant'."
---

# DataFlow Transactions

Transaction management in kailash-dataflow, covering `DataFlowTransaction`,
`SqlConnection`, connection pool configuration, and RAII rollback semantics.

Source: `crates/kailash-dataflow/src/transaction.rs` and `crates/kailash-dataflow/src/connection.rs`

---

## DataFlowTransaction

A wrapper around a sqlx transaction with RAII drop semantics.
Created via `DataFlow::begin()`, `DataFlow::begin_immediate()`, or
`DataFlow::begin_with_tenant()`.

### Basic Begin / Commit

```rust
use kailash_dataflow::connection::DataFlow;

async fn example() -> Result<(), kailash_dataflow::error::DataFlowError> {
    let df = DataFlow::new("sqlite::memory:").await?;

    // Setup
    df.execute_raw("CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL)").await?;

    // Begin a transaction
    let mut tx = df.begin().await?;

    // Execute raw SQL within the transaction
    tx.execute_raw("INSERT INTO items (name) VALUES ('test')").await?;
    tx.execute_raw("INSERT INTO items (name) VALUES ('another')").await?;

    // Commit -- persists both inserts
    tx.commit().await?;

    Ok(())
}
```

### Explicit Rollback

```rust
use kailash_dataflow::connection::DataFlow;

async fn example() -> Result<(), kailash_dataflow::error::DataFlowError> {
    let df = DataFlow::new("sqlite::memory:").await?;
    df.execute_raw("CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL)").await?;

    let mut tx = df.begin().await?;
    tx.execute_raw("INSERT INTO items (name) VALUES ('will be discarded')").await?;

    // Explicit rollback -- discards all changes
    tx.rollback().await?;

    // tx.is_finished() == true after rollback
    Ok(())
}
```

### RAII Auto-Rollback on Drop

If `DataFlowTransaction` is dropped without calling `commit()` or `rollback()`:

1. A warning is logged via `tracing::warn!`
2. The underlying sqlx transaction performs an **implicit rollback** on drop
3. For raw-connection transactions (`begin_immediate`), a `ROLLBACK` is spawned
   on the current tokio runtime to clean up the connection before it returns to the pool

```rust
use kailash_dataflow::connection::DataFlow;

async fn risky_operation(df: &DataFlow) -> Result<(), kailash_dataflow::error::DataFlowError> {
    let mut tx = df.begin().await?;
    tx.execute_raw("INSERT INTO items (name) VALUES ('risky')").await?;

    // Simulate an error: tx is dropped without commit
    // -> WARNING logged, implicit rollback occurs
    // -> "risky" row is NOT persisted
    Err(kailash_dataflow::error::DataFlowError::Config("simulated error".into()))
    // tx dropped here -- auto-rollback
}
```

**Important:** After `commit()` or `rollback()`, calling either again returns
`DataFlowError::TransactionFinished`.

### begin_immediate() -- SQLite Write Lock

For SQLite read-modify-write patterns, use `begin_immediate()` to acquire a
write lock immediately. This prevents `SQLITE_BUSY` errors when concurrent
writers are active.

```rust
use kailash_dataflow::connection::DataFlow;

async fn read_modify_write(df: &DataFlow) -> Result<(), kailash_dataflow::error::DataFlowError> {
    // Acquires a write lock immediately (SQLite only).
    // For PostgreSQL/MySQL, behaves identically to begin().
    let mut tx = df.begin_immediate().await?;

    // Read
    let rows = tx.fetch_all("SELECT balance FROM accounts WHERE id = 1").await?;

    // Modify + Write (no SQLITE_BUSY because we hold the write lock)
    tx.execute_raw("UPDATE accounts SET balance = balance - 100 WHERE id = 1").await?;

    tx.commit().await?;
    Ok(())
}
```

### begin_with_tenant() -- Tenant-Scoped Transactions

```rust
use kailash_dataflow::connection::DataFlow;

async fn tenant_tx(df: &DataFlow) -> Result<(), kailash_dataflow::error::DataFlowError> {
    let mut tx = df.begin_with_tenant("org-123").await?;

    // The tenant ID is stored on the transaction
    assert_eq!(tx.tenant_id(), Some("org-123"));

    tx.execute_raw("INSERT INTO items (name, tenant_id) VALUES ('scoped', 'org-123')").await?;
    tx.commit().await?;
    Ok(())
}
```

### Transaction Query Methods

`DataFlowTransaction` provides three query methods:

| Method                | Returns               | Use Case                       |
| --------------------- | --------------------- | ------------------------------ |
| `execute_raw(sql)`    | `u64` (rows affected) | INSERT, UPDATE, DELETE         |
| `fetch_all(sql)`      | `Vec<AnyRow>`         | SELECT returning multiple rows |
| `fetch_optional(sql)` | `Option<AnyRow>`      | SELECT returning 0 or 1 row    |

All three return `DataFlowError::TransactionFinished` if the transaction has
already been committed or rolled back.

---

## SqlConnection -- Pool or Transaction Abstraction

`SqlConnection` is an enum that unifies pool-based and transaction-based execution,
allowing CRUD functions to work with either.

```rust
use kailash_dataflow::connection::DataFlow;
use kailash_dataflow::transaction::SqlConnection;

async fn example(df: &DataFlow) -> Result<(), kailash_dataflow::error::DataFlowError> {
    // Use pool directly (auto-commit per statement)
    let mut conn = SqlConnection::Pool(df.pool().clone());
    conn.execute_raw("SELECT 1").await?;
    assert!(conn.is_pool());

    // Use transaction (manual commit/rollback)
    let tx = df.begin().await?;
    let mut conn = SqlConnection::Transaction(tx);
    conn.execute_raw("SELECT 1").await?;
    assert!(conn.is_transaction());

    Ok(())
}
```

---

## Connection Pool Configuration

`DataFlowConfig` controls the connection pool via `AnyPoolOptions` (sqlx).

### Default Configuration

```rust
use kailash_dataflow::connection::DataFlowConfig;

let config = DataFlowConfig::new("sqlite::memory:");
// config.max_connections = 10
// config.min_connections = 1
// config.connect_timeout_secs = 30
// config.idle_timeout_secs = None
// config.max_lifetime_secs = Some(1800) (30 minutes)
```

### Custom Configuration

```rust
use kailash_dataflow::connection::{DataFlow, DataFlowConfig};

async fn example() -> Result<(), kailash_dataflow::error::DataFlowError> {
    let config = DataFlowConfig::new("postgres://user:pass@localhost/db")
        .with_max_connections(20)
        .with_min_connections(5);

    let df = DataFlow::from_config(config).await?;
    Ok(())
}
```

### SQLite Connection Hooks

For SQLite connections, DataFlow automatically configures:

- **WAL journal mode** -- concurrent readers + single writer
- **5-second busy_timeout** -- retry on lock instead of immediate failure
- **NORMAL synchronous mode** -- safe with WAL, better throughput
- **Foreign key enforcement** enabled

### From Environment Variable

```rust
use kailash_dataflow::connection::DataFlow;

async fn example() -> Result<(), kailash_dataflow::error::DataFlowError> {
    // Reads DATABASE_URL from .env via dotenvy
    let df = DataFlow::from_env().await?;
    Ok(())
}
```

---

## DataFlow -- Primary Entry Point

The complete lifecycle of a `DataFlow` instance:

```rust
use kailash_dataflow::prelude::*;
use kailash_core::NodeRegistry;
use std::sync::Arc;

async fn full_lifecycle() -> Result<(), DataFlowError> {
    // 1. Connect
    let mut df = DataFlow::new("sqlite::memory:").await?;

    // 2. Register models
    let model = ModelDefinition::new("User", "users")
        .field("id", FieldType::Integer, |f| f.primary_key())
        .field("name", FieldType::Text, |f| f.required())
        .auto_timestamps();
    df.register_model(model)?; // validates the model

    // 3. Access pool for direct sqlx usage
    let _pool = df.pool();

    // 4. Check dialect
    let _dialect = df.dialect(); // QueryDialect::Sqlite

    // 5. Register 11 nodes per model into a NodeRegistry
    let mut registry = NodeRegistry::default();
    df.register_nodes(&mut registry);

    // 6. Begin transactions
    let mut tx = df.begin().await?;
    tx.commit().await?;

    // 7. Close when done
    df.close().await;

    Ok(())
}
```

---

## Error Types

| Error                                        | When                                                      |
| -------------------------------------------- | --------------------------------------------------------- |
| `DataFlowError::TransactionFinished`         | Calling commit/rollback/execute on a finished transaction |
| `DataFlowError::TransactionBeginFailed(msg)` | Pool exhausted or connection failure during begin         |
| `DataFlowError::Database(sqlx::Error)`       | SQL execution failure                                     |
| `DataFlowError::MissingEnvVar { var }`       | `DATABASE_URL` not set when using `from_env()`            |

---

## Best Practices

1. **Always commit or rollback explicitly.** RAII rollback is a safety net, not a workflow pattern.

2. **Use `begin_immediate()` for SQLite write transactions.** Prevents `SQLITE_BUSY` when
   multiple connections exist in the pool.

3. **Use `begin_with_tenant()` when multi-tenancy is active.** The tenant ID is stored
   on the transaction for query interception.

4. **Do NOT hold transactions across await points longer than necessary.** Each open
   transaction holds a connection from the pool. Long transactions can exhaust the pool.

5. **Use `SqlConnection` when writing functions that should work with either pools or
   transactions.** This avoids duplicating code for both paths.

<!-- Trigger Keywords: transaction, begin, commit, rollback, RAII, auto-rollback, DataFlowTransaction, SqlConnection, connection pool, begin_immediate, begin_with_tenant, pool configuration, max_connections, DataFlowConfig -->
