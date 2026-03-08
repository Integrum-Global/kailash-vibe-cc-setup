---
name: workflow-pattern-business-rules
description: "Business rule engine patterns. Use when asking 'business rules', 'rule engine', 'conditional logic', or 'decision workflow'."
---

# Business Rule Engine Patterns

> **Skill Metadata**
> Category: `workflow-patterns`
> Priority: `MEDIUM`
> SDK Version: `0.9.25+`

## Pattern: Discount Calculation Rules

```rust
use kailash_core::{WorkflowBuilder, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. Load customer data
builder.add_node("DatabaseQueryNode", "load_customer", ValueMap::from([
    ("query".into(), Value::String("SELECT * FROM customers WHERE id = ?".into())),
    ("parameters".into(), Value::Array(vec![
        Value::String("{{input.customer_id}}".into()),
    ])),
]));

// 2. Check membership tier
builder.add_node("ConditionalNode", "check_tier", ValueMap::from([
    ("condition".into(), Value::String("{{load_customer.tier}}".into())),
    ("branches".into(), Value::Object(ValueMap::from([
        ("gold".into(), Value::String("gold_discount".into())),
        ("silver".into(), Value::String("silver_discount".into())),
        ("bronze".into(), Value::String("bronze_discount".into())),
    ]))),
]));

// 3. Calculate discounts
builder.add_node("TransformNode", "gold_discount", ValueMap::from([
    ("input".into(), Value::String("{{input.amount}}".into())),
    ("transformation".into(), Value::String("value * 0.80".into())), // 20% off
]));

builder.add_node("TransformNode", "silver_discount", ValueMap::from([
    ("input".into(), Value::String("{{input.amount}}".into())),
    ("transformation".into(), Value::String("value * 0.90".into())), // 10% off
]));

builder.add_node("TransformNode", "bronze_discount", ValueMap::from([
    ("input".into(), Value::String("{{input.amount}}".into())),
    ("transformation".into(), Value::String("value * 0.95".into())), // 5% off
]));

// 4. Apply additional rules
builder.add_node("ConditionalNode", "check_bulk", ValueMap::from([
    ("condition".into(), Value::String("{{input.quantity}} > 10".into())),
    ("true_branch".into(), Value::String("bulk_discount".into())),
    ("false_branch".into(), Value::String("final_price".into())),
]));

builder.connect("load_customer", "tier", "check_tier", "condition");
builder.connect("check_tier", "result", "check_bulk", "input");
```

<!-- Trigger Keywords: business rules, rule engine, conditional logic, decision workflow -->
