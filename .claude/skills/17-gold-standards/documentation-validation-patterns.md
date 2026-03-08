---
name: documentation-validation-patterns
description: "Documentation validation patterns for the Kailash Rust SDK including doc test execution, example verification, and validation reporting. Use for 'doc validation', 'example testing', 'documentation verification'."
---

# Documentation Validation Patterns

> **Skill Metadata**
> Category: `documentation`
> Priority: `MEDIUM`
> Use Cases: Validating code examples, testing documentation

## Validation Process

### Phase 1: Doc Test Extraction

Rust documentation examples are automatically testable via `cargo test --doc`:

````rust
/// Process input data and return a result.
///
/// # Examples
///
/// ```
/// use kailash_core::value::{Value, ValueMap};
///
/// let input = ValueMap::from([
///     ("key".into(), Value::String("hello".into())),
/// ]);
/// assert_eq!(input.len(), 1);
/// ```
pub fn process(input: ValueMap) -> Result<ValueMap, NodeError> {
    // ...
}
````

### Phase 2: Run Doc Tests

```bash
# Run all doc tests across the workspace
cargo test --doc --workspace

# Run doc tests for a specific crate
cargo test --doc -p kailash-core

# Run with verbose output to see each test
cargo test --doc --workspace -- --nocapture
```

### Phase 3: Infrastructure Setup (for Integration Examples)

```bash
# For examples that require real services
docker compose -f tests/docker-compose.test.yml up -d

# Verify services are ready:
# ✅ PostgreSQL: Ready (localhost:5433)
# ✅ Redis: Ready (localhost:6380)
```

### Phase 4: Generate and Review Documentation

```bash
# Generate docs and check for warnings
cargo doc --workspace --no-deps 2>&1 | grep -i warning

# Open generated docs in browser
cargo doc --workspace --no-deps --open

# Verify all public items are documented
cargo clippy --workspace -- -W missing_docs
```

## Validation Report Template

```markdown
## Documentation Validation: [crate_name]

### Summary

- Total doc tests: 12
- Passed: 11
- Fixed: 1
- Blocked: 0

### Validation Details

1. **Example: Value creation** (src/value.rs:23-35)
   - Test: cargo test --doc -p kailash-value
   - Result: PASSED
   - Execution time: 0.34s

2. **Example: Workflow building** (src/builder.rs:67-89)
   - Test: cargo test --doc -p kailash-core
   - Result: FAILED -> FIXED
   - Issue: Used deprecated API
   - Fix: Updated to current WorkflowBuilder API

### Infrastructure Requirements

- Docker services: PostgreSQL, Redis (for integration doc tests)
- Environment variables: DATABASE_URL (for sqlx examples)

### Verification Commands

- Doc tests: `cargo test --doc --workspace`
- Doc generation: `cargo doc --workspace --no-deps`
- Lint for missing docs: `cargo clippy -- -W missing_docs`
```

## Common Documentation Issues

### 1. Outdated API Examples

````rust
// ❌ OUTDATED: Old API
/// ```
/// let wf = Workflow::new();
/// wf.add("CSVReader", config);
/// ```

// ✅ CORRECT: Current API
/// ```
/// use kailash_core::WorkflowBuilder;
/// use kailash_core::value::ValueMap;
///
/// let mut builder = WorkflowBuilder::new();
/// builder.add_node("CSVReaderNode", "reader", ValueMap::new());
/// ```
````

### 2. Missing use Statements in Doc Tests

````rust
// ❌ INCOMPLETE: Won't compile
/// ```
/// let value = Value::String("hello".into());
/// ```

// ✅ COMPLETE: All imports present
/// ```
/// use kailash_core::value::Value;
///
/// let value = Value::String("hello".into());
/// ```
````

### 3. Examples That Should Not Run

````rust
// ✅ Use no_run for examples that require external services
/// ```no_run
/// use sqlx::PgPool;
///
/// let pool = PgPool::connect("postgresql://localhost/db").await?;
/// ```

// ✅ Use ignore for examples that need special setup
/// ```ignore
/// // Requires running Docker services
/// let result = test_with_real_database().await;
/// ```
````

### 4. Compile-Only Examples

````rust
// ✅ Use compile_fail for examples that should NOT compile
/// ```compile_fail
/// use kailash_core::value::Value;
///
/// let v: Value = "hello"; // Should fail: no implicit conversion
/// ```
````

## Documentation Directories

```
crates/
  kailash-core/src/     - Core SDK source with rustdoc
  kailash-nodes/src/    - Node implementations with rustdoc
  kailash-dataflow/src/ - DataFlow with rustdoc
  kailash-nexus/src/    - Nexus with rustdoc
  kailash-kaizen/src/   - Kaizen with rustdoc
docs/                   - Architecture and design documents
examples/               - Runnable example programs
.claude/skills/         - Agent skill documentation
```

## Update Guidelines

1. **Rustdoc first**: All public APIs must have `///` doc comments
2. **Doc tests required**: Every `# Examples` section must contain runnable code
3. **Verify with cargo**: `cargo test --doc` must pass before commit
4. **Cross-reference validation**: Ensure examples use actual crate types
5. **Version awareness**: Update examples when APIs change

<!-- Trigger Keywords: doc validation, example testing, documentation verification, documentation update, validate docs, test examples, cargo doc, doc tests -->
