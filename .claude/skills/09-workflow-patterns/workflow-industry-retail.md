---
name: workflow-industry-retail
description: "Retail/e-commerce workflows (orders, inventory, shipping). Use when asking 'retail workflow', 'e-commerce', 'order processing', or 'inventory sync'."
---

# Retail/E-Commerce Workflows

> **Skill Metadata**
> Category: `industry-workflows`
> Priority: `MEDIUM`
> SDK Version: `0.9.25+`

## Pattern: Order Fulfillment Workflow

```rust
use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. Receive order
builder.add_node("DatabaseExecuteNode", "create_order", ValueMap::from([
    ("query".into(), Value::String(
        "INSERT INTO orders (customer_id, items, total) VALUES (?, ?, ?)".into()
    )),
    ("parameters".into(), Value::Array(vec![
        Value::String("{{input.customer_id}}".into()),
        Value::String("{{input.items}}".into()),
        Value::String("{{input.total}}".into()),
    ])),
]));

// 2. Check inventory
builder.add_node("DatabaseQueryNode", "check_inventory", ValueMap::from([
    ("query".into(), Value::String(
        "SELECT quantity FROM inventory WHERE product_id = ?".into()
    )),
    ("parameters".into(), Value::Array(vec![
        Value::String("{{input.product_id}}".into()),
    ])),
]));

// 3. Reserve stock
builder.add_node("DatabaseExecuteNode", "reserve_stock", ValueMap::from([
    ("query".into(), Value::String(
        "UPDATE inventory SET quantity = quantity - ? WHERE product_id = ?".into()
    )),
    ("parameters".into(), Value::Array(vec![
        Value::String("{{input.quantity}}".into()),
        Value::String("{{input.product_id}}".into()),
    ])),
]));

// 4. Process payment
builder.add_node("HTTPRequestNode", "payment", ValueMap::from([
    ("url".into(), Value::String("https://api.stripe.com/charges".into())),
    ("method".into(), Value::String("POST".into())),
    ("body".into(), Value::Object(ValueMap::from([
        ("amount".into(), Value::String("{{input.total}}".into())),
        ("customer".into(), Value::String("{{input.customer_id}}".into())),
    ]))),
]));

// 5. Create shipping label
builder.add_node("HTTPRequestNode", "shipping", ValueMap::from([
    ("url".into(), Value::String("https://api.shippo.com/shipments".into())),
    ("method".into(), Value::String("POST".into())),
    ("body".into(), Value::Object(ValueMap::from([
        ("address".into(), Value::String("{{input.address}}".into())),
        ("weight".into(), Value::String("{{input.weight}}".into())),
    ]))),
]));

// 6. Send confirmation
builder.add_node("HTTPRequestNode", "notify_customer", ValueMap::from([
    ("url".into(), Value::String("https://api.sendgrid.com/mail/send".into())),
    ("method".into(), Value::String("POST".into())),
    ("body".into(), Value::Object(ValueMap::from([
        ("to".into(), Value::String("{{input.email}}".into())),
        ("subject".into(), Value::String("Order Confirmed".into())),
        ("tracking".into(), Value::String("{{shipping.tracking_number}}".into())),
    ]))),
]));

builder.connect("create_order", "order_id", "check_inventory", "order_id");
builder.connect("check_inventory", "quantity", "reserve_stock", "available");
builder.connect("reserve_stock", "result", "payment", "body");
builder.connect("payment", "transaction_id", "shipping", "payment_ref");
builder.connect("shipping", "tracking_number", "notify_customer", "tracking");

let workflow = builder.build(&registry)?;
let runtime = Runtime::new(RuntimeConfig::default(), registry);
let result = runtime.execute(&workflow, ValueMap::new()).await?;
```

<!-- Trigger Keywords: retail workflow, e-commerce, order processing, inventory sync, order fulfillment -->
