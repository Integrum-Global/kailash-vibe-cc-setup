---
name: workflow-industry-finance
description: "Finance industry workflows (payments, fraud, compliance). Use when asking 'finance workflow', 'payment processing', 'fraud detection', or 'financial compliance'."
---

# Finance Industry Workflows

> **Skill Metadata**
> Category: `industry-workflows`
> Priority: `MEDIUM`
> SDK Version: `0.9.25+`

## Pattern: Payment Processing with Fraud Detection

```rust
use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. Validate payment details
builder.add_node("DataValidationNode", "validate", ValueMap::from([
    ("input".into(), Value::String("{{input.payment}}".into())),
    ("schema".into(), Value::Object(ValueMap::from([
        ("amount".into(), Value::String("decimal".into())),
        ("card_number".into(), Value::String("credit_card".into())),
    ]))),
]));

// 2. Fraud check
builder.add_node("HTTPRequestNode", "fraud_check", ValueMap::from([
    ("url".into(), Value::String("https://api.fraudcheck.com/analyze".into())),
    ("method".into(), Value::String("POST".into())),
    ("body".into(), Value::String("{{validate.valid_data}}".into())),
]));

// 3. Risk assessment
builder.add_node("ConditionalNode", "assess_risk", ValueMap::from([
    ("condition".into(), Value::String("{{fraud_check.risk_score}}".into())),
    ("branches".into(), Value::Object(ValueMap::from([
        ("low".into(), Value::String("process_payment".into())),
        ("medium".into(), Value::String("manual_review".into())),
        ("high".into(), Value::String("reject_payment".into())),
    ]))),
]));

// 4. Process payment
builder.add_node("HTTPRequestNode", "process_payment", ValueMap::from([
    ("url".into(), Value::String("https://api.paymentgateway.com/charge".into())),
    ("method".into(), Value::String("POST".into())),
    ("body".into(), Value::String("{{validate.valid_data}}".into())),
]));

// 5. Record transaction
builder.add_node("DatabaseExecuteNode", "record", ValueMap::from([
    ("query".into(), Value::String(
        "INSERT INTO transactions (amount, status, timestamp) VALUES (?, ?, NOW())".into()
    )),
    ("parameters".into(), Value::Array(vec![
        Value::String("{{input.amount}}".into()),
        Value::String("completed".into()),
    ])),
]));

builder.connect("validate", "valid_data", "fraud_check", "body");
builder.connect("fraud_check", "risk_score", "assess_risk", "condition");
builder.connect("assess_risk", "output_low", "process_payment", "body");
builder.connect("process_payment", "result", "record", "parameters");

let workflow = builder.build(&registry)?;
let runtime = Runtime::new(RuntimeConfig::default(), registry);
let result = runtime.execute(&workflow, ValueMap::new()).await?;
```

<!-- Trigger Keywords: finance workflow, payment processing, fraud detection, financial compliance -->
