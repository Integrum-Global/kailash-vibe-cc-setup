---
name: workflow-industry-logistics
description: "Logistics/supply chain workflows (tracking, routing, delivery). Use when asking 'logistics workflow', 'supply chain', 'shipment tracking', or 'route optimization'."
---

# Logistics/Supply Chain Workflows

> **Skill Metadata**
> Category: `industry-workflows`
> Priority: `MEDIUM`
> SDK Version: `0.9.25+`

## Pattern: Shipment Tracking and Delivery

```rust
use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. Create shipment
builder.add_node("DatabaseExecuteNode", "create_shipment", ValueMap::from([
    ("query".into(), Value::String(
        "INSERT INTO shipments (origin, destination, status) VALUES (?, ?, 'pending')".into()
    )),
    ("parameters".into(), Value::Array(vec![
        Value::String("{{input.origin}}".into()),
        Value::String("{{input.destination}}".into()),
    ])),
]));

// 2. Calculate optimal route
builder.add_node("HTTPRequestNode", "route_optimization", ValueMap::from([
    ("url".into(), Value::String("https://api.routingengine.com/optimize".into())),
    ("method".into(), Value::String("POST".into())),
    ("body".into(), Value::Object(ValueMap::from([
        ("origin".into(), Value::String("{{input.origin}}".into())),
        ("destination".into(), Value::String("{{input.destination}}".into())),
    ]))),
]));

// 3. Assign to driver
builder.add_node("DatabaseQueryNode", "find_driver", ValueMap::from([
    ("query".into(), Value::String(
        "SELECT id FROM drivers WHERE status = 'available' AND location_near(?, 50) LIMIT 1".into()
    )),
    ("parameters".into(), Value::Array(vec![
        Value::String("{{input.origin}}".into()),
    ])),
]));

// 4. Update shipment with route
builder.add_node("DatabaseExecuteNode", "update_shipment", ValueMap::from([
    ("query".into(), Value::String(
        "UPDATE shipments SET driver_id = ?, route = ?, status = 'in_transit' WHERE id = ?".into()
    )),
    ("parameters".into(), Value::Array(vec![
        Value::String("{{find_driver.id}}".into()),
        Value::String("{{route_optimization.route}}".into()),
        Value::String("{{create_shipment.id}}".into()),
    ])),
]));

// 5. Real-time tracking loop
builder.add_node("LoopNode", "track_location", ValueMap::from([
    ("condition".into(), Value::String("{{current_status}} != 'delivered'".into())),
    ("interval".into(), Value::Integer(300)), // Check every 5 minutes
]));

// 6. Update delivery status
builder.add_node("DatabaseExecuteNode", "mark_delivered", ValueMap::from([
    ("query".into(), Value::String(
        "UPDATE shipments SET status = 'delivered', delivered_at = NOW() WHERE id = ?".into()
    )),
    ("parameters".into(), Value::Array(vec![
        Value::String("{{create_shipment.id}}".into()),
    ])),
]));

builder.connect("create_shipment", "id", "route_optimization", "shipment_id");
builder.connect("route_optimization", "route", "find_driver", "location");
builder.connect("find_driver", "id", "update_shipment", "driver_id");
builder.connect("update_shipment", "status", "track_location", "current_status");
builder.connect("track_location", "result", "mark_delivered", "trigger");

let workflow = builder.build(&registry)?;
let runtime = Runtime::new(RuntimeConfig::default(), registry);
let result = runtime.execute(&workflow, ValueMap::new()).await?;
```

<!-- Trigger Keywords: logistics workflow, supply chain, shipment tracking, route optimization, delivery -->
