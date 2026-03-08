---
name: workflow-pattern-ai-document
description: "AI document processing patterns (OCR, extraction, analysis). Use when asking 'AI document', 'document AI', 'OCR workflow', or 'intelligent document processing'."
---

# AI Document Processing Patterns

AI-powered document analysis, extraction, and classification workflows.

> **Skill Metadata**
> Category: `workflow-patterns`
> Priority: `MEDIUM`
> SDK Version: `0.9.25+`
> Related Skills: [`workflow-pattern-rag`](workflow-pattern-rag.md), [`nodes-ai-reference`](../nodes/nodes-ai-reference.md)

## Pattern: Invoice Processing with AI

```rust
use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. Read document
builder.add_node("DocumentProcessorNode", "read_invoice", ValueMap::from([
    ("file_path".into(), Value::String("{{input.invoice_path}}".into())),
]));

// 2. OCR extraction
let vision_model = std::env::var("VISION_MODEL").expect("VISION_MODEL in .env");
builder.add_node("LLMNode", "extract_fields", ValueMap::from([
    ("provider".into(), Value::String(
        std::env::var("LLM_PROVIDER").expect("LLM_PROVIDER in .env").into()
    )),
    ("model".into(), Value::String(vision_model.into())),
    ("prompt".into(), Value::String(
        "Extract: invoice_number, date, amount, vendor from this invoice".into()
    )),
    ("image".into(), Value::String("{{read_invoice.content}}".into())),
]));

// 3. Validate extracted data
builder.add_node("DataValidationNode", "validate", ValueMap::from([
    ("input".into(), Value::String("{{extract_fields.data}}".into())),
    ("schema".into(), Value::Object(ValueMap::from([
        ("invoice_number".into(), Value::String("string".into())),
        ("date".into(), Value::String("date".into())),
        ("amount".into(), Value::String("decimal".into())),
        ("vendor".into(), Value::String("string".into())),
    ]))),
]));

// 4. Store in database
builder.add_node("DatabaseExecuteNode", "store", ValueMap::from([
    ("query".into(), Value::String(
        "INSERT INTO invoices (number, date, amount, vendor) VALUES (?, ?, ?, ?)".into()
    )),
    ("parameters".into(), Value::String("{{validate.valid_data}}".into())),
]));

builder.connect("read_invoice", "content", "extract_fields", "image");
builder.connect("extract_fields", "data", "validate", "input");
builder.connect("validate", "valid_data", "store", "parameters");

let workflow = builder.build(&registry)?;
let runtime = Runtime::new(RuntimeConfig::default(), registry);
let result = runtime.execute(&workflow, ValueMap::new()).await?;
```

<!-- Trigger Keywords: AI document, document AI, OCR workflow, intelligent document processing, invoice extraction -->
