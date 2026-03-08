---
name: gold-test-creation
description: "Test creation standards for the Kailash Rust SDK with 3-tier strategy, helper functions, and real infrastructure requirements. Use when asking 'test standards', 'test creation', 'test guidelines', '3-tier testing', 'test requirements', or 'testing gold standard'."
---

# Gold Standard: Test Creation

Test creation guide with patterns, examples, and best practices for the Kailash Rust SDK.

> **Skill Metadata**
> Category: `gold-standards`
> Priority: `HIGH`

## Test Creation Pattern

### Basic Test Structure

```rust
use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

#[tokio::test]
async fn test_workflow_execution() {
    // Arrange: Build workflow
    let mut builder = WorkflowBuilder::new();
    builder.add_node("JSONTransformNode", "process", ValueMap::from([
        ("expression".into(), Value::String("@".into())),
    ]));

    let registry = Arc::new(NodeRegistry::default());
    let workflow = builder.build(&registry).expect("build failed");
    let runtime = Runtime::new(RuntimeConfig::default(), registry);

    // Act: Execute workflow
    let inputs = ValueMap::from([
        ("data".into(), Value::Object(ValueMap::from([
            ("status".into(), Value::String("success".into())),
            ("value".into(), Value::Integer(42)),
        ]))),
    ]);
    let result = runtime.execute(&workflow, inputs).await.expect("execution failed");

    // Assert: Verify results
    assert!(result.results.contains_key("process"));
    assert!(!result.run_id.is_empty());
}
```

### Sync Test Pattern

```rust
#[test]
fn test_workflow_build_validation() {
    let mut builder = WorkflowBuilder::new();
    builder.add_node("LogNode", "process", ValueMap::from([
        ("message".into(), Value::String("test".into())),
    ]));

    let registry = Arc::new(NodeRegistry::default());
    let workflow = builder.build(&registry);

    assert!(workflow.is_ok());
}
```

## 3-Tier Test Creation

### Tier 1: Unit Tests

```rust
// crates/kailash-core/src/builder.rs (inline test module)
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_workflow_builder_creates_workflow() {
        let mut builder = WorkflowBuilder::new();
        builder.add_node("LogNode", "node", ValueMap::new());

        let registry = Arc::new(NodeRegistry::default());
        let workflow = builder.build(&registry);
        assert!(workflow.is_ok());
    }

    #[test]
    fn test_workflow_builder_adds_connection() {
        let mut builder = WorkflowBuilder::new();
        builder.add_node("LogNode", "source", ValueMap::new());
        builder.add_node("LogNode", "target", ValueMap::new());
        builder.connect("source", "output", "target", "input");

        let registry = Arc::new(NodeRegistry::default());
        let workflow = builder.build(&registry);
        assert!(workflow.is_ok());
    }
}
```

### Tier 2: Integration Tests (NO MOCKING)

```rust
// crates/kailash-dataflow/tests/integration/database_workflows.rs
#[tokio::test]
#[cfg(feature = "integration")]
async fn test_database_query_workflow() {
    dotenvy::dotenv().ok();
    let db_url = std::env::var("DATABASE_URL").expect("DATABASE_URL required");

    let mut builder = WorkflowBuilder::new();
    builder.add_node("SQLQueryNode", "db", ValueMap::from([
        ("connection_string".into(), Value::String(db_url.into())),
        ("query".into(), Value::String("SELECT 1 as id, 'test' as name".into())),
        ("operation".into(), Value::String("select".into())),
    ]));

    let registry = Arc::new(NodeRegistry::default());
    let workflow = builder.build(&registry).expect("build failed");
    let runtime = Runtime::new(RuntimeConfig::default(), registry);
    let result = runtime.execute(&workflow, ValueMap::new()).await.expect("execution failed");

    assert!(result.results.contains_key("db"));
}
```

### Tier 3: E2E Tests

```rust
// tests/e2e/test_complete_pipeline.rs
#[tokio::test]
#[cfg(feature = "e2e")]
async fn test_complete_etl_pipeline() {
    let workflow = build_etl_pipeline();

    let registry = Arc::new(NodeRegistry::default());
    let built = workflow.build(&registry).expect("build failed");
    let runtime = Runtime::new(RuntimeConfig::default(), registry);
    let result = runtime.execute(&built, ValueMap::new()).await.expect("execution failed");

    // Verify all stages completed
    assert!(result.results.contains_key("extract"));
    assert!(result.results.contains_key("transform"));
    assert!(result.results.contains_key("load"));
}
```

## Test Helper Functions

### Workflow Helpers

```rust
// tests/common/mod.rs (shared test utilities)

/// Create a fresh WorkflowBuilder.
pub fn new_builder() -> WorkflowBuilder {
    WorkflowBuilder::new()
}

/// Create a Runtime with default config.
pub fn new_runtime() -> (Runtime, Arc<NodeRegistry>) {
    let registry = Arc::new(NodeRegistry::default());
    let runtime = Runtime::new(RuntimeConfig::default(), registry.clone());
    (runtime, registry)
}
```

### Infrastructure Helpers

```rust
// tests/common/db.rs
use once_cell::sync::Lazy;

/// Shared database pool for integration tests (session-scoped).
#[cfg(feature = "integration")]
pub static TEST_POOL: Lazy<sqlx::PgPool> = Lazy::new(|| {
    dotenvy::dotenv().ok();
    let db_url = std::env::var("DATABASE_URL").expect("DATABASE_URL required");
    tokio::runtime::Runtime::new()
        .unwrap()
        .block_on(sqlx::PgPool::connect(&db_url))
        .expect("failed to connect to test database")
});
```

## Parametrized Testing

### Testing Multiple Scenarios

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_value_doubling() {
        let cases = vec![
            (Value::Integer(10), Value::Integer(20)),
            (Value::Integer(5), Value::Integer(10)),
            (Value::Integer(0), Value::Integer(0)),
            (Value::Integer(-5), Value::Integer(-10)),
        ];

        for (input, expected) in cases {
            let result = double_value(&input);
            assert_eq!(result, expected, "doubling {input:?} should give {expected:?}");
        }
    }
}
```

### Using rstest for Parametrized Tests

```rust
use rstest::rstest;

#[rstest]
#[case(10, 20)]
#[case(5, 10)]
#[case(0, 0)]
#[case(-5, -10)]
fn test_double_value(#[case] input: i64, #[case] expected: i64) {
    let result = double_value(&Value::Integer(input));
    assert_eq!(result, Value::Integer(expected));
}
```

## Error Testing

### Testing Error Handling

```rust
use kailash_core::NodeError;

#[test]
fn test_missing_required_input_returns_error() {
    let node = MyCustomNode::from_config(&ValueMap::new());

    let result = tokio_test::block_on(
        node.execute(ValueMap::new(), &ExecutionContext::default())
    );

    assert!(result.is_err());
    match result.unwrap_err() {
        NodeError::MissingInput { name } => {
            assert_eq!(name, "input_data");
        }
        other => panic!("expected MissingInput, got {other:?}"),
    }
}

#[test]
fn test_invalid_workflow_returns_build_error() {
    let mut builder = WorkflowBuilder::new();
    builder.add_node("NonExistentNode", "bad", ValueMap::new());

    let registry = Arc::new(NodeRegistry::default());
    let result = builder.build(&registry);

    assert!(result.is_err(), "building with unknown node type should fail");
}
```

## Test Organization Standards

### File Naming

```
crates/kailash-core/
  src/
    lib.rs                    # #[cfg(test)] mod tests { ... }
    builder.rs                # #[cfg(test)] mod tests { ... }
  tests/
    integration_test.rs       # #[cfg(feature = "integration")]
    e2e_test.rs               # #[cfg(feature = "e2e")]

tests/                        # Workspace-level tests
  common/
    mod.rs                    # Shared helpers
  e2e/
    test_full_pipeline.rs
```

### Test Naming

```rust
// ✅ GOOD: Descriptive test names (snake_case)
#[test]
fn test_workflow_execution_with_valid_parameters_returns_success() { }

#[test]
fn test_database_connection_with_invalid_credentials_returns_error() { }

// ❌ BAD: Generic test names
// fn test_workflow() { }
// fn test_db() { }
```

## Test Standards Checklist

- [ ] Test uses `#[test]` or `#[tokio::test]`
- [ ] Test organized with correct feature gate (`#[cfg(feature = "integration")]`)
- [ ] NO MOCKING in integration/e2e tests (use real Docker services)
- [ ] Clear, descriptive test name (snake_case)
- [ ] Proper helper functions for test isolation
- [ ] Error cases tested (`assert!(result.is_err())`)
- [ ] Edge cases covered
- [ ] Parametrized for multiple scenarios (where applicable)
- [ ] Proper feature gates (`#[cfg(feature = "integration")]`, `#[cfg(feature = "e2e")]`)

## Documentation References

### Primary Sources

- [`CLAUDE.md`](../../../../CLAUDE.md) - Development quick reference and test commands
- [`rules/testing.md`](../../../../rules/testing.md) - Testing rules

## Related Patterns

- **Gold testing standard**: [`gold-testing`](gold-testing.md)
- **Testing strategies**: [`test-3tier-strategy`](../../13-testing-strategies/test-3tier-strategy.md)
- **Testing patterns**: [`testing-patterns`](../../13-testing-strategies/testing-patterns.md)

## When to Escalate

Use `testing-specialist` subagent when:

- Complex test infrastructure needed
- Custom helper functions required
- CI/CD integration issues
- Performance testing strategy

<!-- Trigger Keywords: test standards, test creation, test guidelines, 3-tier testing, test requirements, testing gold standard -->
