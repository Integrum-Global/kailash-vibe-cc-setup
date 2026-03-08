---
name: gold-mocking-policy
description: "Testing policy requiring real infrastructure, no mocking for Tier 2-3 tests in the Kailash Rust SDK. Use when asking 'mocking policy', 'NO MOCKING', 'real infrastructure', 'test policy', 'mock guidelines', or 'testing standards'."
---

# Gold Standard: NO MOCKING Policy

NO MOCKING policy for integration and E2E tests -- use real infrastructure with the unified Kailash Runtime.

> **Skill Metadata**
> Category: `gold-standards`
> Priority: `CRITICAL`

## Core Policy

### NO MOCKING in Tiers 2-3

**Tier 1 (Unit Tests)**: Trait-based test doubles ALLOWED for external dependencies
**Tier 2 (Integration Tests)**: NO MOCKING - Use real Docker services
**Tier 3 (E2E Tests)**: NO MOCKING - Use real infrastructure

## Why NO MOCKING?

1. **Mocks hide real integration issues** - Type mismatches, connection errors, timing issues
2. **Real infrastructure catches actual bugs** - Validates actual behavior, not assumptions
3. **Production-like testing prevents surprises** - Discovers deployment issues early
4. **Runtime validation** - Tests the unified Runtime with real services
5. **Better confidence** - Tests prove the code works with real systems

## What to Use Instead

### Tier 1: Unit Tests (Test Doubles Allowed)

```rust
// ✅ ALLOWED in unit tests: trait-based test doubles
trait HttpClient: Send + Sync {
    fn get(&self, url: &str) -> Result<Response, Error>;
}

struct FakeHttpClient;
impl HttpClient for FakeHttpClient {
    fn get(&self, _url: &str) -> Result<Response, Error> {
        Ok(Response { status: 200, body: r#"{"status":"success"}"#.into() })
    }
}

#[test]
fn test_node_logic_with_fake_client() {
    let client = FakeHttpClient;
    let result = process_with_client(&client, "test input");
    assert!(result.is_ok());
}
```

### Tier 2: Integration Tests (NO MOCKING)

```rust
use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

// ✅ CORRECT: Use real Docker PostgreSQL
#[tokio::test]
#[cfg(feature = "integration")]
async fn test_database_integration() {
    dotenvy::dotenv().ok();
    let db_url = std::env::var("DATABASE_URL").expect("DATABASE_URL required");

    let mut builder = WorkflowBuilder::new();
    builder.add_node("SQLQueryNode", "db", ValueMap::from([
        ("connection_string".into(), Value::String(db_url.into())),
        ("query".into(), Value::String("SELECT 1 as value".into())),
        ("operation".into(), Value::String("select".into())),
    ]));

    let registry = Arc::new(NodeRegistry::default());
    let workflow = builder.build(&registry).expect("build failed");
    let runtime = Runtime::new(RuntimeConfig::default(), registry);
    let result = runtime.execute(&workflow, ValueMap::new()).await.expect("execution failed");

    assert!(result.results.contains_key("db"));
}


// ❌ WRONG: Using mockall in integration tests
// use mockall::automock;
// #[automock]
// trait Database { fn query(&self) -> Result<Vec<Row>>; }
// fn test_database_integration(mock: MockDatabase) { ... }
```

### Tier 3: E2E Tests (NO MOCKING)

```rust
// ✅ CORRECT: Use real services for E2E
#[tokio::test]
#[cfg(feature = "e2e")]
async fn test_complete_pipeline() {
    let mut builder = WorkflowBuilder::new();
    // Build complete ETL pipeline with real nodes...

    let registry = Arc::new(NodeRegistry::default());
    let workflow = builder.build(&registry).expect("build failed");
    let runtime = Runtime::new(RuntimeConfig::default(), registry);
    let result = runtime.execute(&workflow, ValueMap::new()).await.expect("execution failed");

    // All stages use real services
    assert!(result.results.contains_key("extract"));
    assert!(result.results.contains_key("transform"));
    assert!(result.results.contains_key("load"));
}
```

## Real Infrastructure Examples

### Real PostgreSQL Database

```rust
#[tokio::test]
#[cfg(feature = "integration")]
async fn test_with_real_postgres() {
    dotenvy::dotenv().ok();
    let db_url = std::env::var("DATABASE_URL").expect("DATABASE_URL required");
    let pool = sqlx::PgPool::connect(&db_url).await.expect("connect failed");

    let row = sqlx::query!("SELECT 1 as value")
        .fetch_one(&pool)
        .await
        .expect("query failed");

    assert_eq!(row.value, Some(1));
}
```

### Real Redis Cache

```rust
#[tokio::test]
#[cfg(feature = "integration")]
async fn test_with_real_redis() {
    dotenvy::dotenv().ok();
    let redis_url = std::env::var("REDIS_URL").expect("REDIS_URL required");
    let client = redis::Client::open(redis_url).expect("redis client failed");
    let mut conn = client.get_multiplexed_async_connection().await.expect("connect failed");

    redis::cmd("SET").arg("test_key").arg("test_value")
        .exec_async(&mut conn).await.expect("set failed");

    let value: String = redis::cmd("GET").arg("test_key")
        .query_async(&mut conn).await.expect("get failed");

    assert_eq!(value, "test_value");
}
```

### Real HTTP API

```rust
#[tokio::test]
#[cfg(feature = "e2e")]
async fn test_with_real_api() {
    let mut builder = WorkflowBuilder::new();
    builder.add_node("HTTPRequestNode", "api", ValueMap::from([
        ("url".into(), Value::String("http://localhost:8888/v1/users".into())),
        ("method".into(), Value::String("GET".into())),
    ]));

    let registry = Arc::new(NodeRegistry::default());
    let workflow = builder.build(&registry).expect("build failed");
    let runtime = Runtime::new(RuntimeConfig::default(), registry);
    let result = runtime.execute(&workflow, ValueMap::new()).await.expect("execution failed");

    assert!(result.results.contains_key("api"));
}
```

## Available Docker Services

### Test Infrastructure

```bash
# Start all test services
docker compose -f tests/docker-compose.test.yml up -d

# Available services:
# - PostgreSQL: localhost:5433
# - Redis: localhost:6380
# - Elasticsearch: localhost:9201
```

### Environment Configuration

```bash
# Set in .env for integration tests:
DATABASE_URL=postgresql://test:test@localhost:5433/test_db
REDIS_URL=redis://localhost:6380/0
```

## Common Violations and Fixes

### Violation 1: Using mockall in Integration Tests

```rust
// ❌ WRONG: mockall in integration test
// use mockall::automock;
// #[automock] trait Database { ... }

// ✅ CORRECT: Use real database
#[tokio::test]
#[cfg(feature = "integration")]
async fn test_database_query() {
    dotenvy::dotenv().ok();
    let db_url = std::env::var("DATABASE_URL").expect("DATABASE_URL required");
    let pool = sqlx::PgPool::connect(&db_url).await.expect("connect failed");
    // Use real PostgreSQL connection
}
```

### Violation 2: Fake HTTP Clients in Integration Tests

```rust
// ❌ WRONG: fake HTTP client in integration test
// struct FakeClient; // WRONG in Tier 2-3

// ✅ CORRECT: Use real HTTP client
#[tokio::test]
#[cfg(feature = "integration")]
async fn test_api_call() {
    let client = reqwest::Client::new();
    let response = client.get("http://localhost:8888/v1/users")
        .send()
        .await
        .expect("request failed");
    assert_eq!(response.status(), 200);
}
```

### Violation 3: Faking Runtime Behavior

```rust
// ❌ WRONG: Not testing real runtime behavior
// let fake_result = ExecutionResult { ... }; // WRONG

// ✅ CORRECT: Use real runtime
#[tokio::test]
async fn test_workflow() {
    let mut builder = WorkflowBuilder::new();
    builder.add_node("LogNode", "node", ValueMap::from([
        ("message".into(), Value::String("test".into())),
    ]));

    let registry = Arc::new(NodeRegistry::default());
    let workflow = builder.build(&registry).expect("build failed");
    let runtime = Runtime::new(RuntimeConfig::default(), registry);
    let result = runtime.execute(&workflow, ValueMap::new()).await.expect("execution failed");

    assert!(result.results.contains_key("node"));
}
```

## Policy Summary

| Test Tier               | Mocking Policy                      | Infrastructure       | Execution                                            |
| ----------------------- | ----------------------------------- | -------------------- | ---------------------------------------------------- |
| **Tier 1: Unit**        | ✅ Trait-based test doubles ALLOWED | In-memory            | `#[test]` / `#[tokio::test]`                         |
| **Tier 2: Integration** | ❌ NO MOCKING                       | Real Docker services | `#[tokio::test]` + `#[cfg(feature = "integration")]` |
| **Tier 3: E2E**         | ❌ NO MOCKING                       | Real infrastructure  | `#[tokio::test]` + `#[cfg(feature = "e2e")]`         |

## Documentation References

### Primary Sources

- [`rules/testing.md`](../../../../rules/testing.md) - Testing rules
- [`CLAUDE.md`](../../../../CLAUDE.md) - Development quick reference

## Related Patterns

- **Gold testing standard**: [`gold-testing`](gold-testing.md)
- **Testing strategies**: [`test-3tier-strategy`](../../13-testing-strategies/test-3tier-strategy.md)

<!-- Trigger Keywords: mocking policy, NO MOCKING, real infrastructure, test policy, mock guidelines, testing standards, mockall -->
