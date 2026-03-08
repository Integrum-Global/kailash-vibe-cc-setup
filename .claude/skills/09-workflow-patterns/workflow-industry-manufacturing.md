---
name: workflow-industry-manufacturing
description: "Manufacturing workflows (production, quality, inventory). Use when asking 'manufacturing workflow', 'production line', 'quality control', or 'inventory management'."
---

# Manufacturing Industry Workflows

> **Skill Metadata**
> Category: `industry-workflows`
> Priority: `MEDIUM`
> SDK Version: `0.9.25+`

## Pattern: Quality Control Workflow

```rust
use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. Production item check
builder.add_node("DatabaseQueryNode", "get_item", ValueMap::from([
    ("query".into(), Value::String(
        "SELECT * FROM production_items WHERE batch_id = ?".into()
    )),
    ("parameters".into(), Value::Array(vec![
        Value::String("{{input.batch_id}}".into()),
    ])),
]));

// 2. Run quality tests
builder.add_node("HTTPRequestNode", "quality_test", ValueMap::from([
    ("url".into(), Value::String(
        std::env::var("QUALITY_API_URL").expect("QUALITY_API_URL in .env").into()
    )),
    ("method".into(), Value::String("POST".into())),
    ("body".into(), Value::Object(ValueMap::from([
        ("item_id".into(), Value::String("{{get_item.id}}".into())),
    ]))),
]));

// 3. Evaluate results
builder.add_node("ConditionalNode", "check_quality", ValueMap::from([
    ("condition".into(), Value::String("{{quality_test.score}} >= 95".into())),
    ("true_branch".into(), Value::String("approve".into())),
    ("false_branch".into(), Value::String("reject".into())),
]));

// 4. Update inventory — approved
builder.add_node("DatabaseExecuteNode", "approve", ValueMap::from([
    ("query".into(), Value::String(
        "UPDATE production_items SET status = 'approved', quality_score = ? WHERE id = ?".into()
    )),
    ("parameters".into(), Value::Array(vec![
        Value::String("{{quality_test.score}}".into()),
        Value::String("{{get_item.id}}".into()),
    ])),
]));

// 4b. Update inventory — rejected
builder.add_node("DatabaseExecuteNode", "reject", ValueMap::from([
    ("query".into(), Value::String(
        "UPDATE production_items SET status = 'rejected', rejection_reason = ? WHERE id = ?".into()
    )),
    ("parameters".into(), Value::Array(vec![
        Value::String("{{quality_test.failure_reason}}".into()),
        Value::String("{{get_item.id}}".into()),
    ])),
]));

builder.connect("get_item", "id", "quality_test", "item_id");
builder.connect("quality_test", "score", "check_quality", "condition");
builder.connect("check_quality", "output_true", "approve", "trigger");
builder.connect("check_quality", "output_false", "reject", "trigger");

let workflow = builder.build(&registry)?;
let runtime = Runtime::new(RuntimeConfig::default(), registry);
let result = runtime.execute(&workflow, ValueMap::new()).await?;
```

<!-- Trigger Keywords: manufacturing workflow, production line, quality control, inventory management -->
