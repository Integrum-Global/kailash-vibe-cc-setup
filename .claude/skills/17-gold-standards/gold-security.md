---
name: gold-security
description: "Gold standard for security practices in the Kailash Rust SDK. Use when asking 'security standard', 'security best practices', or 'secure coding'."
---

# Gold Standard: Security

> **Skill Metadata**
> Category: `gold-standards`
> Priority: `HIGH`

## Security Principles

### 1. Secrets Management

```rust
// ✅ GOOD: Environment variables via dotenvy
dotenvy::dotenv().ok();

let api_key = std::env::var("API_KEY")
    .map_err(|_| NodeError::ExecutionFailed {
        message: "API_KEY not set in .env".to_string(),
        source: None,
    })?;

let mut builder = WorkflowBuilder::new();
builder.add_node("HTTPRequestNode", "api", ValueMap::from([
    ("url".into(), Value::String("https://api.example.com".into())),
    ("authorization".into(), Value::String(format!("Bearer {api_key}").into())),
]));

// ❌ BAD: Hard-coded secrets
// ("authorization".into(), Value::String("Bearer sk-abc123...".into()))
```

### 2. SQL Injection Prevention (sqlx)

```rust
// ✅ GOOD: Compile-time checked queries with sqlx
let user = sqlx::query_as!(
    User,
    "SELECT * FROM users WHERE id = $1",
    user_id
)
.fetch_one(&pool)
.await?;

// ✅ GOOD: Runtime query with bound parameters
let user = sqlx::query_as::<_, User>("SELECT * FROM users WHERE id = $1")
    .bind(user_id)
    .fetch_one(&pool)
    .await?;

// ❌ BAD: String interpolation in SQL (SQL injection risk!)
// let query = format!("SELECT * FROM users WHERE id = {user_id}");
// sqlx::query(&query).fetch_one(&pool).await?;
```

### 3. Input Validation

```rust
use validator::Validate;

// ✅ GOOD: Validate all inputs with the validator crate
#[derive(Debug, serde::Deserialize, Validate)]
pub struct CreateUserRequest {
    #[validate(length(min = 1, max = 255))]
    pub name: String,
    #[validate(email)]
    pub email: String,
    #[validate(range(min = 0, max = 150))]
    pub age: Option<u8>,
}

async fn create_user(
    axum::Json(payload): axum::Json<CreateUserRequest>,
) -> Result<axum::Json<User>, AppError> {
    payload.validate()
        .map_err(|e| AppError::Validation(e.to_string()))?;
    // ... proceed with validated data
}
```

### 4. Minimize unsafe Code

```rust
// ✅ GOOD: Safety comment required for every unsafe block
// SAFETY: Pointer is guaranteed non-null by the caller contract.
// Alignment is correct because T: Repr(C).
unsafe {
    std::ptr::read(ptr)
}

// ❌ BAD: unsafe without justification
// unsafe { std::ptr::read(ptr) } // No SAFETY comment!

// ✅ BEST: Deny unsafe in crates that don't need it
// In lib.rs:
#![deny(unsafe_code)]
```

### 5. No Secrets in Logs

```rust
// ✅ GOOD: Log identifiers, not secrets
tracing::info!(user_id = %user.id, "user logged in successfully");

// ❌ BAD: Logging sensitive data
// tracing::info!("user logged in with password: {}", password);
// tracing::debug!("API key: {}", api_key);
```

### 6. Dependency Security

```bash
# ✅ GOOD: Regular security audits
cargo audit                    # Check for known vulnerabilities
cargo deny check               # License, advisory, and ban checks

# In CI/CD:
cargo audit --deny warnings
```

### 7. HTTPS and TLS

```rust
// ✅ GOOD: reqwest defaults to HTTPS with TLS verification
let client = reqwest::Client::builder()
    .timeout(std::time::Duration::from_secs(30))
    .build()?;

// ❌ BAD: Disabling TLS verification
// let client = reqwest::Client::builder()
//     .danger_accept_invalid_certs(true) // NEVER in production!
//     .build()?;
```

### 8. No Command Injection

```rust
// ❌ BAD: User input in subprocess commands
// std::process::Command::new("sh")
//     .arg("-c")
//     .arg(&user_input)  // Command injection!
//     .output()?;

// ✅ GOOD: Use typed arguments, not shell interpolation
std::process::Command::new("grep")
    .arg("-r")
    .arg(&search_pattern)  // Passed as argument, not shell-interpreted
    .arg(&directory)
    .output()?;
```

## Security Checklist

- [ ] No hard-coded secrets (use `dotenvy` + `std::env::var()`)
- [ ] Compile-time SQL queries (`sqlx::query!` / `sqlx::query_as!`)
- [ ] Input validation for all user data (`validator` crate)
- [ ] `unsafe` blocks have `// SAFETY:` comments
- [ ] `#![deny(unsafe_code)]` in crates that don't need FFI
- [ ] No secrets in log output
- [ ] `cargo audit` passes
- [ ] `cargo deny check` passes
- [ ] HTTPS for all API calls
- [ ] No `Command::new` with user-controlled input
- [ ] Security review before every commit (`security-reviewer` agent)

## Documentation References

- [`rules/security.md`](../../../../rules/security.md) - Detailed security rules
- [`CLAUDE.md`](../../../../CLAUDE.md) - Workspace security overview

<!-- Trigger Keywords: security standard, security best practices, secure coding, security gold standard, unsafe, cargo audit, sqlx injection -->
