---
name: gold-error-handling
description: "Gold standard for error handling in the Kailash Rust SDK. Use when asking 'error handling standard', 'handle errors', or 'error patterns'."
---

# Gold Standard: Error Handling

> **Skill Metadata**
> Category: `gold-standards`
> Priority: `HIGH`

## Error Handling Patterns

### 1. Use Result and the ? Operator

```rust
use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

async fn run_payment_workflow() -> Result<ValueMap, Box<dyn std::error::Error>> {
    let mut builder = WorkflowBuilder::new();

    // Critical operation
    builder.add_node("HTTPRequestNode", "payment_api", ValueMap::from([
        ("url".into(), Value::String("https://api.stripe.com/charge".into())),
        ("method".into(), Value::String("POST".into())),
        ("timeout".into(), Value::Integer(30)),
    ]));

    let registry = Arc::new(NodeRegistry::default());
    let workflow = builder.build(&registry)?; // ? propagates build errors
    let runtime = Runtime::new(RuntimeConfig::default(), registry);
    let result = runtime.execute(&workflow, ValueMap::new()).await?; // ? propagates execution errors

    Ok(result.results["payment_api"].clone())
}
```

### 2. Define Domain Errors with thiserror

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum PaymentError {
    #[error("invalid amount: {0} (must be positive)")]
    InvalidAmount(f64),

    #[error("payment gateway timeout after {timeout_secs}s")]
    GatewayTimeout { timeout_secs: u64 },

    #[error("payment declined: {reason}")]
    Declined { reason: String },

    #[error("workflow error: {0}")]
    Workflow(#[from] kailash_core::NodeError),

    #[error("database error: {0}")]
    Database(#[from] sqlx::Error),
}
```

### 3. Validation Before Processing

```rust
use kailash_core::NodeError;

fn validate_payment_input(inputs: &ValueMap) -> Result<(), NodeError> {
    let amount = inputs.get("amount")
        .and_then(|v| v.as_f64())
        .ok_or_else(|| NodeError::ExecutionFailed {
            message: "amount is required and must be a number".to_string(),
            source: None,
        })?;

    if amount <= 0.0 {
        return Err(NodeError::ExecutionFailed {
            message: format!("amount must be positive, got {amount}"),
            source: None,
        });
    }

    let email = inputs.get("email")
        .and_then(|v| v.as_str())
        .ok_or_else(|| NodeError::ExecutionFailed {
            message: "email is required".to_string(),
            source: None,
        })?;

    if !email.contains('@') {
        return Err(NodeError::ExecutionFailed {
            message: format!("invalid email format: {email}"),
            source: None,
        });
    }

    Ok(())
}
```

### 4. Graceful Degradation with Fallback

```rust
async fn fetch_with_fallback(primary_url: &str, fallback_url: &str) -> Result<String, Box<dyn std::error::Error>> {
    // Try primary
    match reqwest::get(primary_url).await {
        Ok(response) if response.status().is_success() => {
            Ok(response.text().await?)
        }
        Ok(response) => {
            tracing::warn!(
                status = %response.status(),
                url = primary_url,
                "primary API returned error, trying fallback"
            );
            let fallback = reqwest::get(fallback_url).await?;
            Ok(fallback.text().await?)
        }
        Err(e) => {
            tracing::warn!(
                error = %e,
                url = primary_url,
                "primary API failed, trying fallback"
            );
            let fallback = reqwest::get(fallback_url).await?;
            Ok(fallback.text().await?)
        }
    }
}
```

### 5. Structured Error Logging

```rust
use tracing::{error, info};
use kailash_core::runtime::{Runtime, ExecutionResult};
use kailash_core::error::RuntimeError;
use kailash_core::workflow::Workflow;
use kailash_value::ValueMap;

async fn execute_workflow_with_logging(
    runtime: &Runtime,
    workflow: &Workflow,
    inputs: ValueMap,
) -> Result<ExecutionResult, RuntimeError> {
    info!("starting workflow execution");

    match runtime.execute(workflow, inputs).await {
        Ok(result) => {
            info!(
                run_id = %result.run_id,
                node_count = result.results.len(),
                "workflow completed successfully"
            );
            Ok(result)
        }
        Err(e) => {
            error!(
                error = %e,
                "workflow execution failed"
            );
            Err(e)
        }
    }
}
```

### 6. Node-Level Error Handling

```rust
impl Node for RobustApiNode {
    fn execute(
        &self,
        inputs: ValueMap,
        _ctx: &ExecutionContext,
    ) -> Pin<Box<dyn Future<Output = Result<ValueMap, NodeError>> + Send + '_>> {
        Box::pin(async move {
            let url = inputs.get("url")
                .and_then(|v| v.as_str())
                .ok_or(NodeError::MissingInput { name: "url".to_string() })?;

            // Retry with exponential backoff
            let mut last_error = None;
            for attempt in 0..3 {
                match reqwest::get(url).await {
                    Ok(response) if response.status().is_success() => {
                        let body = response.text().await.map_err(|e| {
                            NodeError::ExecutionFailed {
                                message: format!("failed to read response body: {e}"),
                                source: None,
                            }
                        })?;
                        return Ok(ValueMap::from([
                            ("result".into(), Value::String(body.into())),
                            ("status".into(), Value::String("success".into())),
                        ]));
                    }
                    Ok(response) => {
                        last_error = Some(format!("HTTP {}", response.status()));
                    }
                    Err(e) => {
                        last_error = Some(e.to_string());
                    }
                }

                // Exponential backoff
                let delay = std::time::Duration::from_millis(100 * 2u64.pow(attempt));
                tokio::time::sleep(delay).await;
            }

            Err(NodeError::ExecutionFailed {
                message: format!("all retries exhausted: {}", last_error.unwrap_or_default()),
                source: None,
            })
        })
    }

    // ... type_name, input_params, output_params
}
```

## Anti-Patterns

```rust
// ❌ BAD: Using unwrap() in production code
let value = inputs.get("key").unwrap(); // Panics on None!

// ❌ BAD: Silently swallowing errors
let _ = fallible_operation(); // Error discarded!

// ❌ BAD: Catch-all with no context
if let Err(_) = operation() { } // What went wrong?

// ❌ BAD: panic! in async code (tears down tokio runtime)
panic!("something went wrong");

// ✅ GOOD: Use ? operator
let value = inputs.get("key")
    .ok_or(NodeError::MissingInput { name: "key".to_string() })?;

// ✅ GOOD: Map errors with context
let data = std::fs::read_to_string(path)
    .map_err(|e| NodeError::ExecutionFailed {
        message: format!("failed to read {path}: {e}"),
        source: None,
    })?;
```

## Gold Standard Checklist

- [ ] All fallible operations return `Result<T, E>`
- [ ] Custom error types defined with `thiserror`
- [ ] `?` operator for error propagation (no `unwrap()` in production)
- [ ] Input validation before processing
- [ ] Fallback paths for external APIs
- [ ] Structured error logging with `tracing`
- [ ] Retry logic with exponential backoff for network calls
- [ ] Error context preserved (not swallowed)
- [ ] Error tests in test suite (`assert!(result.is_err())`)

<!-- Trigger Keywords: error handling standard, handle errors, error patterns, error handling gold standard, Result, thiserror -->
