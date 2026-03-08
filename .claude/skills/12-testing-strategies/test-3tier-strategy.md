---
name: test-3tier-strategy
description: "3-tier testing strategy overview for the Kailash Rust SDK. Use when asking '3-tier testing', 'testing strategy', or 'test tiers'."
---

# 3-Tier Testing Strategy

> **Skill Metadata**
> Category: `testing`
> Priority: `HIGH`

## Testing Pyramid

### Tier 1: Unit Tests (Fast, In-Memory)

```rust
#[test]
fn test_workflow_build() {
    let mut builder = WorkflowBuilder::new();
    builder.add_node("LLMNode", "llm", ValueMap::from([
        ("prompt".into(), Value::String("test".into())),
    ]));
    let registry = Arc::new(NodeRegistry::default());
    let workflow = builder.build(&registry);
    assert!(workflow.is_ok());
}
```

### Tier 2: Integration Tests (Real Infrastructure)

```rust
#[tokio::test]
#[cfg(feature = "integration")]
async fn test_llm_integration() {
    dotenvy::dotenv().ok();
    let mut builder = WorkflowBuilder::new();
    builder.add_node("LLMNode", "llm", ValueMap::from([
        ("provider".into(), Value::String("openai".into())),
        ("model".into(), Value::String(std::env::var("OPENAI_MODEL").unwrap().into())),
        ("prompt".into(), Value::String("Say hello".into())),
    ]));

    let registry = Arc::new(NodeRegistry::default());
    let workflow = builder.build(&registry).expect("workflow build failed");
    let runtime = Runtime::new(RuntimeConfig::default(), registry);
    let result = runtime.execute(&workflow, ValueMap::new()).await.expect("execution failed");

    let response = result.results["llm"]["response"].as_str().unwrap();
    assert!(response.to_lowercase().contains("hello"));
}
```

### Tier 3: End-to-End Tests (Full System)

```rust
#[tokio::test]
#[cfg(feature = "e2e")]
async fn test_full_application() {
    // Test API endpoint with real axum server
    // Test database persistence with real sqlx pool
    // Test external integrations with real services
}
```

## Test Distribution

- **Tier 1 (Unit)**: 70% - Fast feedback
- **Tier 2 (Integration)**: 25% - Real dependencies
- **Tier 3 (E2E)**: 5% - Critical paths

## NO MOCKING Policy

✅ **Use real infrastructure** in Tiers 2-3:

- Real OpenAI API calls
- Real databases (SQLite/PostgreSQL via sqlx)
- Real file systems

❌ **No mocks** for:

- LLM providers
- Databases
- External APIs (in integration tests)

## Test Execution

```bash
# Tier 1: Unit tests (fast feedback)
cargo test --workspace

# Tier 2: Integration tests (real DBs, real APIs)
cargo test --workspace --features integration

# Tier 3: E2E tests (real everything)
cargo test --workspace --features e2e

# Lint (no warnings allowed)
cargo clippy --workspace -- -D warnings
```

## Documentation

- **Testing Rules**: [`rules/testing.md`](../../../../rules/testing.md)
- **Workspace Root**: [`CLAUDE.md`](../../../../CLAUDE.md)

<!-- Trigger Keywords: 3-tier testing, testing strategy, test tiers, testing pyramid, unit tests, integration tests -->
