---
name: gold-testing
description: "Gold standard for testing in the Kailash Rust SDK. Use when asking 'testing standard', 'testing best practices', or 'how to test'."
---

# Gold Standard: Testing

> **Skill Metadata**
> Category: `gold-standards`
> Priority: `HIGH`

## Testing Principles

### 1. Test-First Development

```rust
use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

// ✅ Write test FIRST
#[tokio::test]
async fn test_user_workflow() {
    let mut builder = WorkflowBuilder::new();
    builder.add_node("JSONTransformNode", "create", ValueMap::from([
        ("expression".into(), Value::String("@".into())),
    ]));

    let registry = Arc::new(NodeRegistry::default());
    let workflow = builder.build(&registry).expect("workflow build failed");
    let runtime = Runtime::new(RuntimeConfig::default(), registry);

    let inputs = ValueMap::from([
        ("data".into(), Value::Object(ValueMap::from([
            ("email".into(), Value::String("test@example.com".into())),
            ("created".into(), Value::Bool(true)),
        ]))),
    ]);
    let result = runtime.execute(&workflow, inputs).await.expect("execution failed");

    assert!(result.results.contains_key("create"));
}

// Then implement the actual workflow
```

### 2. 3-Tier Testing Strategy

```rust
// Tier 1: Unit (fast, in-memory)
#[test]
fn test_workflow_build() {
    let mut builder = WorkflowBuilder::new();
    builder.add_node("LogNode", "process", ValueMap::new());

    let registry = Arc::new(NodeRegistry::default());
    let workflow = builder.build(&registry);
    assert!(workflow.is_ok());
}

// Tier 2: Integration (real infrastructure — NO MOCKING)
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

// Tier 3: E2E (full system)
#[tokio::test]
#[cfg(feature = "e2e")]
async fn test_full_pipeline() {
    let mut builder = WorkflowBuilder::new();
    // Build complete pipeline with real nodes...
    // ...

    let registry = Arc::new(NodeRegistry::default());
    let workflow = builder.build(&registry).expect("build failed");
    let runtime = Runtime::new(RuntimeConfig::default(), registry);
    let result = runtime.execute(&workflow, ValueMap::new()).await.expect("execution failed");

    assert!(result.results.contains_key("extract"));
}
```

### 3. NO MOCKING (Tiers 2-3)

```rust
// ✅ GOOD: Real infrastructure in integration tests
#[tokio::test]
#[cfg(feature = "integration")]
async fn test_database_operations() {
    dotenvy::dotenv().ok();
    let db_url = std::env::var("DATABASE_URL").expect("DATABASE_URL required");
    let pool = sqlx::PgPool::connect(&db_url).await.expect("connect failed");

    let row = sqlx::query!("SELECT * FROM users LIMIT 1")
        .fetch_optional(&pool)
        .await
        .expect("query failed");

    // Real query against real database
    assert!(row.is_some() || row.is_none()); // Valid either way
}

// ❌ BAD: Using mockall in integration tests
// #[automock]
// trait Database { fn query(&self) -> Result<Vec<Row>>; }
// fn test_database(mock: MockDatabase) { ... } // DON'T DO THIS
```

### 4. Clear Test Names

```rust
// ✅ GOOD: Descriptive names
#[test]
fn test_user_creation_with_valid_email_succeeds() { /* ... */ }

#[test]
fn test_user_creation_with_invalid_email_fails() { /* ... */ }

#[test]
fn test_workflow_execution_returns_results_and_run_id() { /* ... */ }

// ❌ BAD: Generic names
// fn test_user_1() { }
// fn test_workflow() { }
```

### 5. Test Isolation

```rust
#[cfg(test)]
mod tests {
    use super::*;

    /// Create a fresh WorkflowBuilder for each test.
    fn new_builder() -> WorkflowBuilder {
        WorkflowBuilder::new()
    }

    /// Create a Runtime with default config.
    fn new_runtime() -> (Runtime, Arc<NodeRegistry>) {
        let registry = Arc::new(NodeRegistry::default());
        let runtime = Runtime::new(RuntimeConfig::default(), registry.clone());
        (runtime, registry)
    }

    #[tokio::test]
    async fn test_one() {
        let mut builder = new_builder();
        builder.add_node("LogNode", "node", ValueMap::from([
            ("message".into(), Value::String("one".into())),
        ]));
        let (runtime, registry) = new_runtime();
        let workflow = builder.build(&registry).expect("build failed");
        let result = runtime.execute(&workflow, ValueMap::new()).await.expect("exec failed");
        assert!(result.results.contains_key("node"));
    }

    #[tokio::test]
    async fn test_two() {
        let mut builder = new_builder();
        builder.add_node("LogNode", "node", ValueMap::from([
            ("message".into(), Value::String("two".into())),
        ]));
        let (runtime, registry) = new_runtime();
        let workflow = builder.build(&registry).expect("build failed");
        let result = runtime.execute(&workflow, ValueMap::new()).await.expect("exec failed");
        assert!(result.results.contains_key("node"));
    }
}
```

## Testing Checklist

- [ ] Test written before implementation (TDD)
- [ ] All 3 tiers covered (unit, integration, E2E)
- [ ] NO MOCKING in Tiers 2-3 (use real Docker services)
- [ ] Clear, descriptive test names (snake_case)
- [ ] Test isolation with helper functions
- [ ] Tests run in CI/CD (`cargo test --workspace`)
- [ ] 80%+ code coverage (`cargo tarpaulin` or `cargo llvm-cov`)
- [ ] Error cases tested (assert `Result::is_err()`)
- [ ] Edge cases tested
- [ ] Real infrastructure via Docker (PostgreSQL, Redis)
- [ ] Tests organized by feature gate (`#[cfg(feature = "integration")]`)

## Documentation References

### Primary Sources

- [`CLAUDE.md`](../../../../CLAUDE.md) - Workspace architecture and testing commands
- [`rules/testing.md`](../../../../rules/testing.md) - Testing rules

## Related Patterns

- **Testing strategies**: [`test-3tier-strategy`](../../13-testing-strategies/test-3tier-strategy.md)
- **Testing patterns**: [`testing-patterns`](../../13-testing-strategies/testing-patterns.md)

<!-- Trigger Keywords: testing standard, testing best practices, how to test, testing gold standard, test guidelines -->
