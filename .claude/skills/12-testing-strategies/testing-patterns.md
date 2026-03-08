---
name: testing-patterns
description: "Test implementation patterns for the 3-tier testing strategy including unit, integration, and E2E tests with NO MOCKING policy. Use for 'test patterns', 'unit test example', 'integration test example', or 'E2E test example'."
---

# Testing Implementation Patterns

> **Skill Metadata**
> Category: `testing`
> Priority: `HIGH`
> Policy: NO MOCKING in Tiers 2-3

## Tier 1: Unit Test Pattern

```rust
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

#[test]
fn test_analysis_node_basic_functionality() {
    let node = CustomAnalysisNode::from_config(&ValueMap::new());

    let inputs = ValueMap::from([
        ("input_data".into(), Value::Array(vec![
            Value::Integer(1), Value::Integer(2), Value::Integer(3),
            Value::Integer(4), Value::Integer(5),
        ])),
        ("analysis_type".into(), Value::String("mean".into())),
    ]);

    let result = tokio_test::block_on(node.execute(inputs, &ExecutionContext::default()));
    let outputs = result.expect("execution should succeed");

    assert_eq!(outputs["result"], Value::Float(3.0));
    assert_eq!(outputs["status"], Value::String("success".into()));
}

#[test]
fn test_analysis_node_error_handling() {
    let node = CustomAnalysisNode::from_config(&ValueMap::new());

    let inputs = ValueMap::from([
        ("input_data".into(), Value::Object(ValueMap::new())),
        ("analysis_type".into(), Value::String("mean".into())),
    ]);

    let result = tokio_test::block_on(node.execute(inputs, &ExecutionContext::default()));
    assert!(result.is_err(), "empty data should produce an error");
}
```

## Tier 2: Integration Test Pattern

```rust
use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

#[tokio::test]
#[cfg(feature = "integration")]
async fn test_workflow_database_integration() {
    dotenvy::dotenv().ok();
    let db_url = std::env::var("DATABASE_URL").expect("DATABASE_URL required");

    let mut builder = WorkflowBuilder::new();

    builder.add_node("SQLQueryNode", "create_user", ValueMap::from([
        ("connection_string".into(), Value::String(db_url.clone().into())),
        ("query".into(), Value::String(
            "INSERT INTO users (name, email) VALUES ($1, $2) RETURNING id".into()
        )),
        ("parameters".into(), Value::Array(vec![
            Value::String("Integration Test User".into()),
            Value::String("integration@test.com".into()),
        ])),
    ]));

    builder.add_node("SQLQueryNode", "find_user", ValueMap::from([
        ("connection_string".into(), Value::String(db_url.into())),
        ("query".into(), Value::String(
            "SELECT * FROM users WHERE email = $1".into()
        )),
        ("parameters".into(), Value::Array(vec![
            Value::String("integration@test.com".into()),
        ])),
    ]));

    builder.connect("create_user", "result", "find_user", "criteria");

    let registry = Arc::new(NodeRegistry::default());
    let workflow = builder.build(&registry).expect("workflow build failed");
    let runtime = Runtime::new(RuntimeConfig::default(), registry);
    let result = runtime.execute(&workflow, ValueMap::new()).await.expect("execution failed");

    assert!(result.results.contains_key("create_user"));
    assert!(result.results.contains_key("find_user"));
}
```

## Tier 3: E2E Test Pattern

```rust
use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

#[tokio::test]
#[cfg(feature = "e2e")]
async fn test_complete_data_processing_pipeline() {
    let mut builder = WorkflowBuilder::new();

    // Data pipeline
    builder.add_node("CSVReaderNode", "ingest", ValueMap::from([
        ("file_path".into(), Value::String("tests/fixtures/real_data.csv".into())),
    ]));
    builder.add_node("SchemaValidatorNode", "validate", ValueMap::from([
        ("schema".into(), Value::Object(ValueMap::from([
            ("name".into(), Value::String("str".into())),
            ("age".into(), Value::String("int".into())),
        ]))),
    ]));
    builder.add_node("DataMapperNode", "transform", ValueMap::from([
        ("operations".into(), Value::Array(vec![
            Value::String("clean_names".into()),
        ])),
    ]));

    // Connect pipeline
    builder.connect("ingest", "data", "validate", "input_data");
    builder.connect("validate", "validated", "transform", "raw_data");

    let registry = Arc::new(NodeRegistry::default());
    let workflow = builder.build(&registry).expect("workflow build failed");
    let runtime = Runtime::new(RuntimeConfig::default(), registry);
    let result = runtime.execute(&workflow, ValueMap::new()).await.expect("execution failed");

    assert!(result.results["ingest"].contains_key("data"));
}
```

## Helper Functions (Replacing Fixtures)

```rust
/// Create sample user data for tests.
fn sample_user_data() -> ValueMap {
    ValueMap::from([
        ("name".into(), Value::String("Test User".into())),
        ("email".into(), Value::String("test@example.com".into())),
        ("age".into(), Value::Integer(30)),
        ("preferences".into(), Value::Object(ValueMap::from([
            ("theme".into(), Value::String("dark".into())),
        ]))),
    ])
}

/// Path to real CSV fixture data for E2E tests.
fn real_csv_data() -> &'static str {
    "tests/fixtures/users.csv" // Actual file, not mocked
}

/// Set up and tear down test database tables.
#[cfg(feature = "integration")]
async fn with_clean_database<F, Fut>(test_fn: F)
where
    F: FnOnce(sqlx::PgPool) -> Fut,
    Fut: std::future::Future<Output = ()>,
{
    dotenvy::dotenv().ok();
    let db_url = std::env::var("DATABASE_URL").expect("DATABASE_URL required");
    let pool = sqlx::PgPool::connect(&db_url).await.expect("connect failed");
    sqlx::query("TRUNCATE TABLE users CASCADE").execute(&pool).await.ok();
    test_fn(pool.clone()).await;
    sqlx::query("TRUNCATE TABLE users CASCADE").execute(&pool).await.ok();
}
```

## Timeout Enforcement

```rust
// Unit tests (Tier 1) - use tokio timeout
#[tokio::test]
async fn test_fast_unit_operation() {
    let result = tokio::time::timeout(
        std::time::Duration::from_secs(1),
        async { /* unit test logic */ }
    ).await;
    assert!(result.is_ok(), "unit test exceeded 1s timeout");
}

// Integration tests (Tier 2) - 5 seconds max
#[tokio::test]
#[cfg(feature = "integration")]
async fn test_database_integration_with_timeout() {
    let result = tokio::time::timeout(
        std::time::Duration::from_secs(5),
        async { /* integration test logic */ }
    ).await;
    assert!(result.is_ok(), "integration test exceeded 5s timeout");
}

// E2E tests (Tier 3) - 10 seconds max
#[tokio::test]
#[cfg(feature = "e2e")]
async fn test_complete_workflow_with_timeout() {
    let result = tokio::time::timeout(
        std::time::Duration::from_secs(10),
        async { /* e2e test logic */ }
    ).await;
    assert!(result.is_ok(), "e2e test exceeded 10s timeout");
}
```

## Allowed vs Forbidden Patterns

### Allowed in All Tiers

```rust
// Time-based testing (use a fixed timestamp)
let fixed_time = chrono::NaiveDate::from_ymd_opt(2023, 1, 1)
    .unwrap()
    .and_hms_opt(0, 0, 0)
    .unwrap();

// Deterministic random with seed
use rand::SeedableRng;
let mut rng = rand::rngs::StdRng::seed_from_u64(42);

// Environment variable testing
std::env::set_var("TEST_MODE", "true");
let result = environment_aware_function();
std::env::remove_var("TEST_MODE");
```

### Allowed in Tier 1 Only

```rust
// Trait-based test doubles are acceptable in unit tests
struct FakeHttpClient;
impl HttpClient for FakeHttpClient {
    fn get(&self, _url: &str) -> Result<Response, Error> {
        Ok(Response { status: 200, body: r#"{"status":"success"}"#.into() })
    }
}

#[test]
fn test_unit_with_fake_client() {
    let client = FakeHttpClient;
    let result = my_function(&client);
    assert!(result.is_ok());
}
```

### Forbidden in Tiers 2-3

```rust
// ❌ Don't use fake database implementations
// struct FakeDatabase; // WRONG in integration tests

// ❌ Don't use mockall for SDK components
// #[automock] trait NodeExecutor { ... } // WRONG in integration tests

// ❌ Don't use fake file system implementations
// struct InMemoryFs; // WRONG in integration tests - use real temp files
```

## Test Execution Commands

```bash
# Unit tests only (fast feedback)
cargo test --workspace

# Integration tests (requires Docker services)
docker compose -f tests/docker-compose.test.yml up -d
cargo test --workspace --features integration

# E2E tests
cargo test --workspace --features e2e

# Full test suite
cargo test --workspace --features integration,e2e

# With coverage (requires cargo-tarpaulin or cargo-llvm-cov)
cargo tarpaulin --workspace --out Html
# or
cargo llvm-cov --workspace --html
```

## Docker Infrastructure

```bash
# Start test services
docker compose -f tests/docker-compose.test.yml up -d

# Expected services:
# ✅ PostgreSQL: localhost:5433
# ✅ Redis: localhost:6380
# ✅ MinIO: localhost:9001
# ✅ Elasticsearch: localhost:9201
```

```rust
// Test configuration via environment variables
// Set in .env or export before running integration tests:
// DATABASE_URL=postgresql://test:test@localhost:5433/test_db
// REDIS_URL=redis://localhost:6380/0
// MINIO_URL=http://localhost:9001
```

<!-- Trigger Keywords: test patterns, unit test example, integration test example, E2E test example, cargo test patterns, testing helpers, test timeout, NO MOCKING -->
