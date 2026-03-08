---
name: gold-documentation
description: "Gold standard for documentation in the Kailash Rust SDK. Use when asking 'documentation standard', 'how to document', or 'docs best practices'."
---

# Gold Standard: Documentation

> **Skill Metadata**
> Category: `gold-standards`
> Priority: `MEDIUM`

## Documentation Principles

### 1. Rustdoc for Public API

````rust
/// Process a payment for a customer.
///
/// # Arguments
///
/// * `amount` - Payment amount in USD (must be positive)
/// * `customer_id` - Unique customer identifier
///
/// # Returns
///
/// Payment result with status and transaction ID.
///
/// # Errors
///
/// Returns [`PaymentError::InvalidAmount`] if amount <= 0.
/// Returns [`PaymentError::GatewayTimeout`] if payment gateway fails.
///
/// # Examples
///
/// ```rust
/// let result = process_payment(99.99, "cust_123").await?;
/// assert_eq!(result.status, "success");
/// ```
pub async fn process_payment(amount: f64, customer_id: &str) -> Result<PaymentResult, PaymentError> {
    if amount <= 0.0 {
        return Err(PaymentError::InvalidAmount(amount));
    }

    // Implementation...
    Ok(PaymentResult {
        status: "success".to_string(),
        transaction_id: "txn_456".to_string(),
    })
}
````

### 2. Workflow Documentation

```rust
use kailash_core::WorkflowBuilder;
use kailash_core::value::{Value, ValueMap};

// ✅ GOOD: Document workflow purpose and flow
let mut builder = WorkflowBuilder::new();

// Step 1: Validate payment details
builder.add_node("SchemaValidatorNode", "validate_payment", ValueMap::from([
    ("schema".into(), Value::Object(ValueMap::from([
        ("amount".into(), Value::String("decimal > 0".into())),
    ]))),
]));

// Step 2: Process with payment gateway
builder.add_node("HTTPRequestNode", "charge_card", ValueMap::from([
    ("url".into(), Value::String("https://api.stripe.com/charges".into())),
    ("method".into(), Value::String("POST".into())),
]));

// Step 3: Record transaction in database
builder.add_node("SQLQueryNode", "record_transaction", ValueMap::from([
    ("query".into(), Value::String(
        "INSERT INTO transactions (amount, status) VALUES ($1, $2)".into()
    )),
]));

builder.connect("validate_payment", "result", "charge_card", "payment_data");
builder.connect("charge_card", "result", "record_transaction", "transaction_data");
```

### 3. Module-Level Documentation

````rust
//! # Payment Processing Module
//!
//! This module handles payment processing through the Stripe API.
//!
//! ## Overview
//!
//! - Validates payment input
//! - Charges the card via Stripe
//! - Records the transaction
//!
//! ## Usage
//!
//! ```rust
//! use crate::payment::process_payment;
//!
//! let result = process_payment(99.99, "cust_123").await?;
//! ```

mod payment {
    // ...
}
````

### 4. Inline Comments

```rust
// ✅ GOOD: Explain WHY, not WHAT
// Use exponential backoff to avoid overwhelming the API
// during temporary outages (max 5 retries over 31 seconds)
let delay = std::time::Duration::from_millis(100 * 2u64.pow(retry_count));

// ❌ BAD: Stating the obvious
// Increment the counter by 1
// counter += 1;
```

### 5. Doc Tests (Verified Examples)

````rust
/// Doubles the input value.
///
/// # Examples
///
/// ```
/// use kailash_core::value::Value;
///
/// let input = Value::Integer(21);
/// let result = double_value(&input);
/// assert_eq!(result, Value::Integer(42));
/// ```
pub fn double_value(input: &Value) -> Value {
    match input {
        Value::Integer(n) => Value::Integer(n * 2),
        Value::Float(n) => Value::Float(n * 2.0),
        other => other.clone(),
    }
}
````

### 6. Generate and Review Docs

```bash
# Generate documentation for the workspace
cargo doc --workspace --no-deps --open

# Run doc tests to verify examples compile and pass
cargo test --doc --workspace
```

## Documentation Checklist

- [ ] Rustdoc (`///`) for all public functions, structs, enums, traits
- [ ] Module-level docs (`//!`) for each module
- [ ] `# Arguments`, `# Returns`, `# Errors`, `# Examples` sections
- [ ] Doc tests (`/// ````) that compile and pass
- [ ] Inline comments explain WHY, not WHAT
- [ ] `cargo doc` generates without warnings
- [ ] `cargo test --doc` passes
- [ ] Code examples use real types from the crate
- [ ] Documentation stays up-to-date with code changes

<!-- Trigger Keywords: documentation standard, how to document, docs best practices, documentation gold standard, rustdoc -->
