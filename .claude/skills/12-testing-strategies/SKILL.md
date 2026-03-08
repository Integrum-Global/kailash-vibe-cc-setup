---
name: testing-strategies
description: "Comprehensive testing strategies for the Kailash Rust SDK including the 3-tier testing approach with NO MOCKING policy for Tiers 2-3. Use when asking about 'testing', 'test strategy', '3-tier testing', 'unit tests', 'integration tests', 'end-to-end tests', 'testing workflows', 'testing DataFlow', 'testing Nexus', 'NO MOCKING', 'real infrastructure', 'test organization', or 'testing best practices'."
---

# Kailash Testing Strategies

Comprehensive testing approach for the Kailash Rust SDK using the 3-tier testing strategy with NO MOCKING policy.

## Overview

Kailash testing philosophy:

- **3-Tier Strategy**: Unit, Integration, End-to-End
- **NO MOCKING Policy**: Tiers 2-3 use real infrastructure
- **Real Database Testing**: Actual PostgreSQL/SQLite via sqlx
- **Real API Testing**: Live HTTP calls
- **Real LLM Testing**: Actual model calls (with caching)

## Reference Documentation

### Core Strategy

- **[test-3tier-strategy](test-3tier-strategy.md)** - Complete 3-tier testing guide
  - Tier 1: Unit Tests (trait-based test doubles allowed)
  - Tier 2: Integration Tests (NO MOCKING)
  - Tier 3: End-to-End Tests (NO MOCKING)
  - Test organization
  - Helper function patterns
  - CI/CD integration

## 3-Tier Testing Strategy

### Tier 1: Unit Tests

**Scope**: Individual functions and structs
**Mocking**: ✅ Trait-based test doubles allowed
**Speed**: Fast (< 1s per test)

```rust
#[test]
fn test_workflow_builder() {
    let mut builder = WorkflowBuilder::new();
    builder.add_node("LogNode", "node1", ValueMap::new());

    let registry = Arc::new(NodeRegistry::default());
    let workflow = builder.build(&registry);
    assert!(workflow.is_ok());
}
```

### Tier 2: Integration Tests

**Scope**: Component integration (workflows, database, APIs)
**Mocking**: ❌ NO MOCKING
**Speed**: Medium (1-10s per test)

```rust
#[tokio::test]
#[cfg(feature = "integration")]
async fn test_dataflow_crud() {
    dotenvy::dotenv().ok();
    let db_url = std::env::var("DATABASE_URL").expect("DATABASE_URL required");

    let mut builder = WorkflowBuilder::new();
    builder.add_node("SQLQueryNode", "create", ValueMap::from([
        ("connection_string".into(), Value::String(db_url.into())),
        ("query".into(), Value::String("INSERT INTO users (name) VALUES ($1) RETURNING id".into())),
        ("parameters".into(), Value::Array(vec![Value::String("Test".into())])),
    ]));

    let registry = Arc::new(NodeRegistry::default());
    let workflow = builder.build(&registry).expect("build failed");
    let runtime = Runtime::new(RuntimeConfig::default(), registry);
    let result = runtime.execute(&workflow, ValueMap::new()).await.expect("execution failed");

    assert!(result.results.contains_key("create"));
}
```

### Tier 3: End-to-End Tests

**Scope**: Complete user workflows
**Mocking**: ❌ NO MOCKING
**Speed**: Slow (10s+ per test)

```rust
#[tokio::test]
#[cfg(feature = "e2e")]
async fn test_user_registration_flow() {
    // Real HTTP request to actual axum API
    let client = reqwest::Client::new();
    let response = client.post("http://localhost:3000/api/register")
        .json(&serde_json::json!({
            "email": "test@example.com",
            "name": "Test User"
        }))
        .send()
        .await
        .expect("request failed");

    assert_eq!(response.status(), 200);
    let body: serde_json::Value = response.json().await.expect("json parse failed");
    assert!(body["user_id"].is_string());
}
```

## NO MOCKING Policy

### Why No Mocking in Tiers 2-3?

**Real Issues Found**:

- Database constraint violations
- API timeout problems
- Race conditions
- Connection pool exhaustion
- Schema migration issues
- LLM token limits

**Mocking Hides**:

- Real-world latency
- Actual error conditions
- Integration bugs
- Performance issues

### What to Use Instead

**Real Infrastructure**:

- Test databases (Docker containers)
- Test API endpoints
- Test LLM accounts (with caching)
- Test file systems (temp directories via `tempfile` crate)

## Test Organization

### Directory Structure

```
crates/kailash-core/
  src/
    lib.rs           # #[cfg(test)] mod tests at bottom
  tests/
    integration/     # #[cfg(feature = "integration")]
    e2e/             # #[cfg(feature = "e2e")]

crates/kailash-dataflow/
  tests/
    concurrency_test.rs
    integration/

tests/                # Workspace-level integration tests
  docker-compose.test.yml
```

### Test Module Patterns

```rust
// In src/lib.rs or src/module.rs — Tier 1 unit tests
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_workflow_builder_creates_workflow() {
        // ...
    }
}

// In tests/integration/mod.rs — Tier 2
#[cfg(feature = "integration")]
mod integration {
    #[tokio::test]
    async fn test_with_real_database() {
        // ...
    }
}
```

## Testing Different Components

### Testing Workflows

```rust
#[tokio::test]
async fn test_workflow_execution() {
    let mut builder = WorkflowBuilder::new();
    builder.add_node("JSONTransformNode", "calc", ValueMap::from([
        ("expression".into(), Value::String("@.value".into())),
    ]));

    let registry = Arc::new(NodeRegistry::default());
    let workflow = builder.build(&registry).expect("build failed");
    let runtime = Runtime::new(RuntimeConfig::default(), registry);

    let inputs = ValueMap::from([
        ("data".into(), Value::Object(ValueMap::from([
            ("value".into(), Value::Integer(42)),
        ]))),
    ]);
    let result = runtime.execute(&workflow, inputs).await.expect("execution failed");

    assert!(result.results.contains_key("calc"));
}
```

### Testing DataFlow

```rust
#[tokio::test]
#[cfg(feature = "integration")]
async fn test_dataflow_operations() {
    dotenvy::dotenv().ok();
    let db_url = std::env::var("DATABASE_URL").expect("DATABASE_URL required");
    let pool = sqlx::PgPool::connect(&db_url).await.expect("connect failed");

    // Real database operations via sqlx
    let row = sqlx::query!("SELECT 1 as value")
        .fetch_one(&pool)
        .await
        .expect("query failed");

    assert_eq!(row.value, Some(1));
}
```

### Testing Nexus

```rust
#[tokio::test]
#[cfg(feature = "e2e")]
async fn test_nexus_api() {
    let client = reqwest::Client::new();

    let response = client.post("http://localhost:3000/api/workflow/test_workflow")
        .json(&serde_json::json!({"input": "data"}))
        .send()
        .await
        .expect("request failed");

    assert_eq!(response.status(), 200);
    let body: serde_json::Value = response.json().await.expect("json parse failed");
    assert!(body.get("result").is_some());
}
```

### Testing Kaizen Agents

```rust
#[tokio::test]
#[cfg(feature = "integration")]
async fn test_agent_execution() {
    dotenvy::dotenv().ok();

    // Real LLM call (use caching to reduce costs)
    let agent = MyAgent::new();
    let result = agent.run("Test query").await.expect("agent failed");

    assert!(!result.output.is_empty());
}
```

## Critical Rules

- ✅ Tier 1: Trait-based test doubles for external dependencies
- ✅ Tier 2-3: Use real infrastructure
- ✅ Use Docker for test databases
- ✅ Clean up resources after tests
- ✅ Cache LLM responses for cost
- ✅ Run Tier 1 in CI, Tier 2-3 optionally
- ❌ NEVER use mockall/mock frameworks in Tier 2-3
- ❌ NEVER mock database in Tier 2-3
- ❌ NEVER mock HTTP calls in Tier 2-3
- ❌ NEVER skip resource cleanup
- ❌ NEVER commit test credentials (use `.env`)

## Running Tests

### Local Development

```bash
# Run all unit tests
cargo test --workspace

# Run by tier
cargo test --workspace                        # Tier 1: Unit
cargo test --workspace --features integration # Tier 2: Integration
cargo test --workspace --features e2e         # Tier 3: E2E

# Run with coverage
cargo tarpaulin --workspace --out Html
# or
cargo llvm-cov --workspace --html
```

### CI/CD

```bash
# Fast CI (Tier 1 only)
cargo test --workspace
cargo clippy --workspace -- -D warnings

# Full CI (all tiers)
docker compose -f tests/docker-compose.test.yml up -d
cargo test --workspace --features integration,e2e
docker compose -f tests/docker-compose.test.yml down
```

## When to Use This Skill

Use this skill when you need to:

- Understand Kailash testing philosophy
- Set up test infrastructure
- Write integration tests
- Test workflows with real execution
- Test DataFlow with real databases
- Test Nexus APIs end-to-end
- Organize test suites
- Configure CI/CD testing

## Best Practices

### Test Quality

- Write descriptive test names (snake_case)
- Use AAA pattern (Arrange, Act, Assert)
- Test both success and failure cases
- Clean up resources properly
- Use helper functions for setup/teardown

### Performance

- Use test database containers
- Cache expensive operations
- Run tests in parallel (when safe) via `cargo test -- --test-threads=N`
- Feature-gate slow tests with `#[cfg(feature = "integration")]`

### Maintenance

- Keep tests close to code (`#[cfg(test)] mod tests`)
- Update tests with code changes
- Review test coverage regularly
- Remove obsolete tests

## Related Skills

- **[02-dataflow](../../02-dataflow/SKILL.md)** - DataFlow testing
- **[03-nexus](../../03-nexus/SKILL.md)** - API testing
- **[26-gold-standards](../../26-gold-standards/SKILL.md)** - Testing best practices

## Support

For testing help, invoke:

- `testing-specialist` - Testing strategies and patterns
- `tdd-implementer` - Test-driven development
- `dataflow-specialist` - DataFlow testing patterns
