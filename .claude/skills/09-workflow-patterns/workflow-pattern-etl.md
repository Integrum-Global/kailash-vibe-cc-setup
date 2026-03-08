---
name: workflow-pattern-etl
description: "ETL pipeline patterns (Extract, Transform, Load). Use when asking 'ETL', 'data pipeline', 'extract transform load', 'data migration', or 'data integration'."
---

# ETL Pipeline Patterns

Comprehensive patterns for Extract, Transform, Load workflows.

> **Skill Metadata**
> Category: `workflow-patterns`
> Priority: `HIGH`
> SDK Version: `0.9.25+`
> Related Skills: [`workflow-pattern-data`](workflow-pattern-data.md), [`dataflow-specialist`](../../02-dataflow/dataflow-specialist.md)
> Related Subagents: `dataflow-specialist` (database ETL), `pattern-expert` (ETL workflows)

## Quick Reference

ETL patterns enable:

- **Data extraction** - CSV, JSON, databases, APIs
- **Transformation** - Clean, normalize, enrich, aggregate
- **Loading** - Write to databases, files, APIs
- **Error handling** - Validation, retries, dead letter queues

## Pattern 1: CSV to Database ETL

```rust
use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. EXTRACT: Read CSV
builder.add_node("CSVReaderNode", "extract", ValueMap::from([
    ("file_path".into(), Value::String("data/customers.csv".into())),
    ("delimiter".into(), Value::String(",".into())),
    ("encoding".into(), Value::String("utf-8".into())),
]));

// 2. TRANSFORM: Validate data
builder.add_node("DataValidationNode", "validate", ValueMap::from([
    ("input".into(), Value::String("{{extract.data}}".into())),
    ("schema".into(), Value::Object(ValueMap::from([
        ("email".into(), Value::String("email".into())),
        ("age".into(), Value::String("integer".into())),
        ("name".into(), Value::String("string".into())),
    ]))),
    ("on_error".into(), Value::String("collect".into())), // Collect invalid rows
]));

// 3. TRANSFORM: Clean data
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
        Value::Object(ValueMap::from([
            ("field".into(), Value::String("phone".into())),
            ("operation".into(), Value::String("normalize_phone".into())),
        ])),
    ])),
]));

// 4. TRANSFORM: Enrich data
builder.add_node("HTTPRequestNode", "enrich_location", ValueMap::from([
    ("url".into(), Value::String("https://api.example.com/geocode".into())),
    ("method".into(), Value::String("POST".into())),
    ("body".into(), Value::String("{{clean.data}}".into())),
]));

// 5. LOAD: Insert to database
builder.add_node("DatabaseExecuteNode", "load", ValueMap::from([
    ("query".into(), Value::String(
        "INSERT INTO customers (name, email, age, location) \
         VALUES (?, ?, ?, ?) \
         ON CONFLICT (email) DO UPDATE SET \
         name = EXCLUDED.name, age = EXCLUDED.age, location = EXCLUDED.location".into()
    )),
    ("parameters".into(), Value::String("{{enrich_location.enriched_data}}".into())),
]));

// 6. Error handling: Log invalid rows
builder.add_node("CSVWriterNode", "log_errors", ValueMap::from([
    ("file_path".into(), Value::String("logs/invalid_rows.csv".into())),
    ("data".into(), Value::String("{{validate.invalid_data}}".into())),
    ("headers".into(), Value::Array(vec![
        Value::String("row".into()),
        Value::String("error".into()),
        Value::String("data".into()),
    ])),
]));

// Connect nodes
builder.connect("extract", "data", "validate", "input");
builder.connect("validate", "valid_data", "clean", "input");
builder.connect("clean", "data", "enrich_location", "body");
builder.connect("enrich_location", "enriched_data", "load", "parameters");
builder.connect("validate", "invalid_data", "log_errors", "data");

let workflow = builder.build(&registry)?;
let runtime = Runtime::new(RuntimeConfig::default(), registry);
let result = runtime.execute(&workflow, ValueMap::new()).await?;
```

## Pattern 2: API to Database ETL

```rust
use kailash_core::{WorkflowBuilder, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. EXTRACT: Paginated API
builder.add_node("SetVariableNode", "init_page", ValueMap::from([
    ("page".into(), Value::Integer(1)),
    ("has_more".into(), Value::Bool(true)),
]));

builder.add_node("HTTPRequestNode", "extract_api", ValueMap::from([
    ("url".into(), Value::String("https://api.example.com/users?page={{init_page.page}}".into())),
    ("method".into(), Value::String("GET".into())),
    ("headers".into(), Value::Object(ValueMap::from([
        ("Authorization".into(), Value::String(
            format!("Bearer {}", std::env::var("API_TOKEN").expect("API_TOKEN in .env")).into()
        )),
    ]))),
]));

// 2. TRANSFORM: Normalize API response
builder.add_node("TransformNode", "normalize", ValueMap::from([
    ("input".into(), Value::String("{{extract_api.data}}".into())),
    ("mapping".into(), Value::Object(ValueMap::from([
        ("user_id".into(), Value::String("id".into())),
        ("full_name".into(), Value::String("name".into())),
        ("email_address".into(), Value::String("email".into())),
        ("created_at".into(), Value::String("timestamp|iso8601".into())),
    ]))),
]));

// 3. TRANSFORM: Filter records
builder.add_node("FilterNode", "filter_active", ValueMap::from([
    ("input".into(), Value::String("{{normalize.data}}".into())),
    ("condition".into(), Value::String("status == 'active' AND created_at > '2024-01-01'".into())),
]));

// 4. LOAD: Batch insert
builder.add_node("DatabaseExecuteNode", "load_batch", ValueMap::from([
    ("query".into(), Value::String(
        "INSERT INTO users (user_id, full_name, email_address, created_at) VALUES (?, ?, ?, ?)".into()
    )),
    ("batch".into(), Value::Bool(true)),
    ("batch_size".into(), Value::Integer(100)),
    ("parameters".into(), Value::String("{{filter_active.filtered_data}}".into())),
]));

// 5. Check for more pages
builder.add_node("ConditionalNode", "check_more", ValueMap::from([
    ("condition".into(), Value::String("{{extract_api.has_next_page}} == true".into())),
    ("true_branch".into(), Value::String("next_page".into())),
    ("false_branch".into(), Value::String("complete".into())),
]));

// 6. Increment page
builder.add_node("TransformNode", "next_page", ValueMap::from([
    ("input".into(), Value::String("{{init_page.page}}".into())),
    ("transformation".into(), Value::String("value + 1".into())),
]));

// Loop for pagination
builder.connect("init_page", "page", "extract_api", "page");
builder.connect("extract_api", "data", "normalize", "input");
builder.connect("normalize", "data", "filter_active", "input");
builder.connect("filter_active", "filtered_data", "load_batch", "parameters");
builder.connect("load_batch", "result", "check_more", "input");
builder.connect("check_more", "output_true", "next_page", "input");
builder.connect("next_page", "result", "extract_api", "page"); // Loop!
```

## Pattern 3: Database to Database Migration

```rust
use kailash_core::{WorkflowBuilder, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. EXTRACT: Read from source DB
builder.add_node("DatabaseQueryNode", "extract_source", ValueMap::from([
    ("connection".into(), Value::String("source_db".into())),
    ("query".into(), Value::String(
        "SELECT id, name, email, created_at FROM legacy_users WHERE migrated = FALSE LIMIT 1000".into()
    )),
]));

// 2. TRANSFORM: Data mapping
builder.add_node("TransformNode", "transform_schema", ValueMap::from([
    ("input".into(), Value::String("{{extract_source.results}}".into())),
    ("transformations".into(), Value::Array(vec![
        Value::Object(ValueMap::from([
            ("source".into(), Value::String("id".into())),
            ("target".into(), Value::String("legacy_id".into())),
            ("type".into(), Value::String("string".into())),
        ])),
        Value::Object(ValueMap::from([
            ("source".into(), Value::String("name".into())),
            ("target".into(), Value::String("full_name".into())),
            ("type".into(), Value::String("string".into())),
        ])),
        Value::Object(ValueMap::from([
            ("source".into(), Value::String("email".into())),
            ("target".into(), Value::String("email_address".into())),
            ("type".into(), Value::String("lowercase".into())),
        ])),
        Value::Object(ValueMap::from([
            ("source".into(), Value::String("created_at".into())),
            ("target".into(), Value::String("registration_date".into())),
            ("type".into(), Value::String("datetime".into())),
        ])),
    ])),
]));

// 3. TRANSFORM: Validate business rules
builder.add_node("DataValidationNode", "validate_rules", ValueMap::from([
    ("input".into(), Value::String("{{transform_schema.data}}".into())),
    ("rules".into(), Value::Array(vec![
        Value::Object(ValueMap::from([
            ("field".into(), Value::String("email_address".into())),
            ("validation".into(), Value::String("email_format".into())),
        ])),
        Value::Object(ValueMap::from([
            ("field".into(), Value::String("full_name".into())),
            ("validation".into(), Value::String("not_empty".into())),
        ])),
        Value::Object(ValueMap::from([
            ("field".into(), Value::String("registration_date".into())),
            ("validation".into(), Value::String("valid_date".into())),
        ])),
    ])),
]));

// 4. LOAD: Insert to target DB
builder.add_node("DatabaseExecuteNode", "load_target", ValueMap::from([
    ("connection".into(), Value::String("target_db".into())),
    ("query".into(), Value::String(
        "INSERT INTO users (legacy_id, full_name, email_address, registration_date) VALUES (?, ?, ?, ?)".into()
    )),
    ("batch".into(), Value::Bool(true)),
    ("parameters".into(), Value::String("{{validate_rules.valid_data}}".into())),
]));

// 5. Update source DB (mark as migrated)
builder.add_node("DatabaseExecuteNode", "mark_migrated", ValueMap::from([
    ("connection".into(), Value::String("source_db".into())),
    ("query".into(), Value::String(
        "UPDATE legacy_users SET migrated = TRUE, migrated_at = NOW() WHERE id IN ({{load_target.inserted_ids}})".into()
    )),
]));

// 6. Handle failures
builder.add_node("DatabaseExecuteNode", "log_failures", ValueMap::from([
    ("connection".into(), Value::String("source_db".into())),
    ("query".into(), Value::String(
        "INSERT INTO migration_failures (legacy_id, error, data) VALUES (?, ?, ?)".into()
    )),
    ("parameters".into(), Value::String("{{validate_rules.invalid_data}}".into())),
]));

builder.connect("extract_source", "results", "transform_schema", "input");
builder.connect("transform_schema", "data", "validate_rules", "input");
builder.connect("validate_rules", "valid_data", "load_target", "parameters");
builder.connect("load_target", "inserted_ids", "mark_migrated", "ids");
builder.connect("validate_rules", "invalid_data", "log_failures", "parameters");
```

## Pattern 4: Real-Time Streaming ETL

```rust
use kailash_core::{WorkflowBuilder, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. EXTRACT: Stream from message queue
builder.add_node("MessageQueueConsumerNode", "extract_stream", ValueMap::from([
    ("queue_url".into(), Value::String("kafka://localhost:9092/events".into())),
    ("topic".into(), Value::String("user_events".into())),
    ("batch_size".into(), Value::Integer(50)),
]));

// 2. TRANSFORM: Parse events
builder.add_node("TransformNode", "parse_events", ValueMap::from([
    ("input".into(), Value::String("{{extract_stream.messages}}".into())),
    ("parsing".into(), Value::Object(ValueMap::from([
        ("format".into(), Value::String("json".into())),
        ("flatten".into(), Value::Bool(true)),
        ("extract_fields".into(), Value::Array(vec![
            Value::String("user_id".into()),
            Value::String("event_type".into()),
            Value::String("timestamp".into()),
            Value::String("data".into()),
        ])),
    ]))),
]));

// 3. TRANSFORM: Aggregate metrics
builder.add_node("AggregateNode", "calculate_metrics", ValueMap::from([
    ("input".into(), Value::String("{{parse_events.events}}".into())),
    ("group_by".into(), Value::Array(vec![
        Value::String("user_id".into()),
        Value::String("event_type".into()),
    ])),
    ("aggregations".into(), Value::Object(ValueMap::from([
        ("count".into(), Value::String("COUNT(*)".into())),
        ("avg_duration".into(), Value::String("AVG(data.duration)".into())),
        ("last_seen".into(), Value::String("MAX(timestamp)".into())),
    ]))),
    ("window".into(), Value::String("5m".into())), // 5-minute window
]));

// 4. LOAD: Write to time-series DB
builder.add_node("DatabaseExecuteNode", "load_metrics", ValueMap::from([
    ("connection".into(), Value::String("timescaledb".into())),
    ("query".into(), Value::String(
        "INSERT INTO user_metrics (user_id, event_type, count, avg_duration, last_seen, window_start) \
         VALUES (?, ?, ?, ?, ?, ?)".into()
    )),
    ("parameters".into(), Value::String("{{calculate_metrics.aggregated}}".into())),
]));

// 5. Acknowledge messages
builder.add_node("MessageQueueAckNode", "ack_messages", ValueMap::from([
    ("message_ids".into(), Value::String("{{extract_stream.message_ids}}".into())),
]));

builder.connect("extract_stream", "messages", "parse_events", "input");
builder.connect("parse_events", "events", "calculate_metrics", "input");
builder.connect("calculate_metrics", "aggregated", "load_metrics", "parameters");
builder.connect("load_metrics", "result", "ack_messages", "message_ids");
```

## Best Practices

1. **Batch processing** - Process in chunks (100-1000 records)
2. **Idempotent operations** - Use UPSERT/ON CONFLICT
3. **Error isolation** - Collect invalid data separately
4. **Transaction boundaries** - Commit per batch
5. **Progress tracking** - Mark processed records
6. **Data validation** - Validate at each stage
7. **Logging** - Track successes, failures, timing

## Common Pitfalls

- **No error handling** - Lost data on failures
- **Memory overload** - Loading entire datasets
- **Missing validation** - Invalid data in target
- **No rollback strategy** - Can't recover from failures
- **Poor performance** - Not using batch operations

## Related Skills

- **DataFlow Framework**: [`dataflow-specialist`](../../02-dataflow/dataflow-specialist.md)
- **Data Patterns**: [`workflow-pattern-data`](workflow-pattern-data.md)
- **Database Nodes**: [`nodes-database-reference`](../nodes/nodes-database-reference.md)

<!-- Trigger Keywords: ETL, data pipeline, extract transform load, data migration, data integration, batch processing -->
