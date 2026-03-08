---
name: workflow-pattern-data
description: "Data processing pipeline patterns (clean, transform, aggregate). Use when asking 'data pipeline', 'data processing', 'data transformation', or 'data cleaning'."
---

# Data Processing Pipeline Patterns

Patterns for data cleaning, transformation, and aggregation workflows.

> **Skill Metadata**
> Category: `workflow-patterns`
> Priority: `HIGH`
> SDK Version: `0.9.25+`
> Related Skills: [`workflow-pattern-etl`](workflow-pattern-etl.md), [`nodes-transform-reference`](../nodes/nodes-transform-reference.md)

## Pattern: Data Quality Pipeline

```rust
use kailash_core::{WorkflowBuilder, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. Load data
builder.add_node("CSVReaderNode", "load", ValueMap::from([
    ("file_path".into(), Value::String("data.csv".into())),
]));

// 2. Remove duplicates
builder.add_node("DeduplicateNode", "dedupe", ValueMap::from([
    ("input".into(), Value::String("{{load.data}}".into())),
    ("key_fields".into(), Value::Array(vec![
        Value::String("email".into()),
    ])),
]));

// 3. Validate schema
builder.add_node("DataValidationNode", "validate", ValueMap::from([
    ("input".into(), Value::String("{{dedupe.data}}".into())),
    ("schema".into(), Value::Object(ValueMap::from([
        ("email".into(), Value::String("email".into())),
        ("age".into(), Value::String("integer".into())),
    ]))),
]));

// 4. Clean fields
builder.add_node("TransformNode", "clean", ValueMap::from([
    ("input".into(), Value::String("{{validate.valid_data}}".into())),
    ("transformations".into(), Value::Array(vec![
        Value::Object(ValueMap::from([
            ("field".into(), Value::String("email".into())),
            ("operation".into(), Value::String("lowercase".into())),
        ])),
        Value::Object(ValueMap::from([
            ("field".into(), Value::String("name".into())),
            ("operation".into(), Value::String("trim".into())),
        ])),
    ])),
]));

// 5. Aggregate metrics
builder.add_node("AggregateNode", "aggregate", ValueMap::from([
    ("input".into(), Value::String("{{clean.data}}".into())),
    ("group_by".into(), Value::Array(vec![
        Value::String("country".into()),
    ])),
    ("aggregations".into(), Value::Object(ValueMap::from([
        ("count".into(), Value::String("COUNT(*)".into())),
        ("avg_age".into(), Value::String("AVG(age)".into())),
    ]))),
]));

builder.connect("load", "data", "dedupe", "input");
builder.connect("dedupe", "data", "validate", "input");
builder.connect("validate", "valid_data", "clean", "input");
builder.connect("clean", "data", "aggregate", "input");
```

<!-- Trigger Keywords: data pipeline, data processing, data transformation, data cleaning, data quality -->
