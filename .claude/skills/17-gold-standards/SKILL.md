---
name: gold-standards
description: "Mandatory best practices and gold standards for Kailash Rust SDK development including import organization, parameter passing, error handling, testing policies (NO MOCKING in Tiers 2-3), workflow design, custom node development, security, documentation, and test creation. Use when asking about 'best practices', 'standards', 'gold standards', 'mandatory rules', 'required patterns', 'import organization', 'NO MOCKING', 'testing policy', 'error handling standards', 'security best practices', 'documentation standards', or 'workflow design standards'."
---

# Kailash Gold Standards - Mandatory Best Practices

Mandatory best practices and standards for all Kailash Rust SDK development. These are **required** patterns that must be followed.

## Overview

Gold standards are **mandatory** practices for:

- Import and module organization
- Parameter passing patterns
- Error handling strategies
- Testing policies (NO MOCKING in Tiers 2-3)
- Workflow design principles
- Custom node development
- Security requirements
- Documentation standards
- Test creation guidelines

**IMPORTANT**: These are not suggestions - they are **required standards** that prevent bugs, ensure consistency, and maintain code quality.

## Reference Documentation

### Code Organization

#### Import Organization (MANDATORY)

- **[gold-absolute-imports](gold-absolute-imports.md)** - Import and module organization
  - **Rule**: Use absolute crate paths (`use kailash_core::...`)
  - **Rule**: Group imports: std, external crates, workspace crates
  - **Pattern**: `use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig};`
  - **Never**: Wildcard imports in production code (except preludes)

#### Parameter Passing (MANDATORY)

- **[gold-parameter-passing](gold-parameter-passing.md)** - Parameter standards
  - **Rule**: Use 4-parameter connection format
  - **Pattern**: `builder.connect(source_id, source_param, target_id, target_param)`
  - **Rule**: Access results via `result.results["node_id"]["field"]`
  - **Rule**: Declare params via `input_params()` / `output_params()` in Node trait

### Testing Standards

#### NO MOCKING Policy (MANDATORY)

- **[gold-mocking-policy](gold-mocking-policy.md)** - NO MOCKING in Tiers 2-3
  - **Rule**: NO mocking/mockall in integration (Tier 2) or E2E (Tier 3) tests
  - **Reason**: Mocking hides real-world issues
  - **Required**: Use real databases, APIs, infrastructure
  - **Allowed**: Trait-based test doubles ONLY in Tier 1 unit tests

#### Testing Standards (MANDATORY)

- **[gold-testing](gold-testing.md)** - Testing requirements
  - **Rule**: Follow 3-tier strategy (Unit, Integration, E2E)
  - **Rule**: Tiers 2-3 use real infrastructure
  - **Rule**: Feature-gate tests (`#[cfg(feature = "integration")]`)
  - **Rule**: Tests must be deterministic

#### Test Creation (MANDATORY)

- **[gold-test-creation](gold-test-creation.md)** - Test creation standards
  - **Rule**: Write tests BEFORE implementation (TDD)
  - **Rule**: One assertion focus per test
  - **Rule**: Use AAA pattern (Arrange, Act, Assert)
  - **Rule**: Descriptive snake_case test names

### Error Handling

#### Error Handling (MANDATORY)

- **[gold-error-handling](gold-error-handling.md)** - Error handling requirements
  - **Rule**: Always return `Result<T, E>` for fallible operations
  - **Rule**: Use `?` operator, never `unwrap()` in production code
  - **Rule**: Define domain errors with `thiserror`
  - **Rule**: Log errors with `tracing` and context
  - **Rule**: No silent error swallowing

### Workflow & Node Design

#### Workflow Design (MANDATORY)

- **[gold-workflow-design](gold-workflow-design.md)** - Workflow standards
  - **Rule**: Always call `builder.build(&registry)?` before execution
  - **Pattern**: `let workflow = builder.build(&registry)?;`
  - **Rule**: Use 4-parameter `connect()` calls
  - **Rule**: Single responsibility per workflow

#### Custom Node Development (MANDATORY)

- **[gold-custom-nodes](gold-custom-nodes.md)** - Custom node standards
  - **Rule**: Implement the `Node` trait
  - **Rule**: Declare params via `input_params()` / `output_params()`
  - **Rule**: Return `Pin<Box<dyn Future<...> + Send + '_>>` from execute
  - **Rule**: Use `NodeError` for error reporting

### Security & Documentation

#### Security (MANDATORY)

- **[gold-security](gold-security.md)** - Security requirements
  - **Rule**: NEVER hardcode secrets (use `dotenvy` + `std::env::var()`)
  - **Rule**: Use `sqlx::query!` for compile-time SQL checking
  - **Rule**: `unsafe` blocks require `// SAFETY:` comments
  - **Rule**: `cargo audit` must pass
  - **Rule**: No `Command::new` with user input

#### Documentation (MANDATORY)

- **[gold-documentation](gold-documentation.md)** - Documentation standards
  - **Rule**: Rustdoc (`///`) for all public APIs
  - **Rule**: Include `# Examples` with runnable doc tests
  - **Rule**: `cargo test --doc` must pass
  - **Rule**: Explain WHY, not just WHAT

## Critical Gold Standards

### 1. Proper Imports

```rust
// ✅ CORRECT (Gold Standard)
use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

// ❌ WRONG (Violates Gold Standard)
use kailash_core::*; // Wildcard import
```

### 2. NO MOCKING in Tiers 2-3

```rust
// ✅ CORRECT (Gold Standard - Tier 2)
#[tokio::test]
#[cfg(feature = "integration")]
async fn test_dataflow_crud() {
    dotenvy::dotenv().ok();
    let db_url = std::env::var("DATABASE_URL").expect("DATABASE_URL required");
    let pool = sqlx::PgPool::connect(&db_url).await.expect("connect failed");
    // Real database operations...
}

// ❌ WRONG (Violates Gold Standard)
// use mockall::automock;
// #[automock] trait Database { ... } // NO mockall in Tier 2!
```

### 3. 4-Parameter Connections

```rust
// ✅ CORRECT (Gold Standard)
builder.connect("node1", "result", "node2", "input_data");

// ❌ WRONG (Violates Gold Standard)
// builder.connect("node1", "node2"); // Missing output/input params
```

### 4. Always build() Before Execute

```rust
// ✅ CORRECT (Gold Standard)
let workflow = builder.build(&registry)?;
let result = runtime.execute(&workflow, inputs).await?;

// ❌ WRONG (Violates Gold Standard)
// runtime.execute(&builder, inputs) // Must call build() first!
```

### 5. Result-Based Error Handling

```rust
// ✅ CORRECT (Gold Standard)
let value = inputs.get("key")
    .ok_or(NodeError::MissingInput { name: "key".to_string() })?;

// ❌ WRONG (Violates Gold Standard)
let value = inputs.get("key").unwrap(); // Panics in production!
```

### 6. Environment Variables for Secrets

```rust
// ✅ CORRECT (Gold Standard)
dotenvy::dotenv().ok();
let api_key = std::env::var("API_KEY")
    .map_err(|_| NodeError::ExecutionFailed {
        message: "API_KEY not set".to_string(),
        source: None,
    })?;

// ❌ WRONG (Violates Gold Standard)
// let api_key = "sk-1234567890abcdef"; // Hardcoded!
```

### 7. TDD (Test-First Development)

```rust
// ✅ CORRECT (Gold Standard)
// 1. Write test first
#[test]
fn test_user_creation() {
    let user = create_user("test@example.com").expect("creation failed");
    assert_eq!(user.email, "test@example.com");
}

// 2. Then implement
fn create_user(email: &str) -> Result<User, AppError> {
    Ok(User { email: email.to_string() })
}

// ❌ WRONG: Write implementation first, then add tests
```

### 8. Explicit Error Handling

```rust
// ✅ CORRECT (Gold Standard)
match runtime.execute(&workflow, inputs).await {
    Ok(result) => {
        tracing::info!(run_id = %result.run_id, "workflow completed");
        Ok(result)
    }
    Err(e) => {
        tracing::error!(error = %e, "workflow failed");
        Err(e)
    }
}

// ❌ WRONG (Violates Gold Standard)
// let _ = runtime.execute(&workflow, inputs).await; // Silently discards result!
```

## Compliance Checklist

### Before Every Commit

- [ ] All imports use absolute crate paths
- [ ] All connections use 4 parameters
- [ ] `builder.build(&registry)?` called before execute
- [ ] No hardcoded secrets
- [ ] Error handling with `Result` and `?`
- [ ] Tests written (TDD)
- [ ] No mocking in Tier 2-3 tests
- [ ] Rustdoc on public APIs

### Before Every PR

- [ ] `cargo test --workspace` passes
- [ ] `cargo clippy --workspace -- -D warnings` clean
- [ ] `cargo fmt --all --check` passes
- [ ] `cargo audit` clean
- [ ] Security review completed (`security-reviewer`)
- [ ] Code review completed (`intermediate-reviewer`)

### Before Every Release

- [ ] Full gold standards audit
- [ ] `cargo test --doc --workspace` passes
- [ ] All patterns compliant
- [ ] Security audit complete

## Enforcement

### Automated Validation

```bash
# Run all checks
cargo test --workspace
cargo clippy --workspace -- -D warnings
cargo fmt --all --check
cargo audit
cargo test --doc --workspace

# With integration tests
cargo test --workspace --features integration
```

### Code Review Focus

- Check import organization
- Verify NO MOCKING policy
- Validate 4-parameter connections
- Check error handling (no unwrap in production)
- Verify TDD approach
- Review security patterns

## Why Gold Standards Matter

### Problems They Prevent

**Import Organization**: Prevent dependency confusion and circular imports

**NO MOCKING**: Catch real database issues, API timeouts, race conditions

**4-Parameter Connections**: Prevent wrong data routing

**build() Requirement**: Validate workflow DAG before execution

**Error Handling**: Prevent panics in async code (tears down tokio runtime)

**TDD**: Prevent bugs before they exist

**Security Standards**: Prevent credential leaks, SQL injection, command injection

## When to Use This Skill

Use this skill:

- **Before writing code** - Know the standards
- **During code review** - Validate compliance
- **When in doubt** - Check gold standards
- **Before deployment** - Ensure compliance
- **When onboarding** - Learn required patterns

## Related Skills

- **[13-testing-strategies](../13-testing-strategies/SKILL.md)** - Testing strategies
- **[01-core](../01-core/SKILL.md)** - Core SDK patterns (if exists)
- **[02-dataflow](../02-dataflow/SKILL.md)** - DataFlow patterns
- **[03-nexus](../03-nexus/SKILL.md)** - Nexus patterns

## Support

For gold standards compliance, invoke:

- `intermediate-reviewer` - Code review after changes
- `security-reviewer` - Security audit before commits
- `testing-specialist` - Testing compliance
- `rust-architect` - Architecture decisions
