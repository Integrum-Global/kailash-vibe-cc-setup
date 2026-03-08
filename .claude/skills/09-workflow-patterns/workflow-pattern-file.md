---
name: workflow-pattern-file
description: "File processing workflow patterns (CSV, JSON, PDF, batch). Use when asking 'file processing', 'batch file', 'document workflow', or 'file automation'."
---

# File Processing Workflow Patterns

Patterns for automated file processing, transformation, and batch operations.

> **Skill Metadata**
> Category: `workflow-patterns`
> Priority: `MEDIUM`
> SDK Version: `0.9.25+`
> Related Skills: [`nodes-data-reference`](../nodes/nodes-data-reference.md), [`workflow-pattern-etl`](workflow-pattern-etl.md)
> Related Subagents: `pattern-expert` (file workflows)

## Quick Reference

File processing patterns:

- **Batch file processing** - Process multiple files
- **File transformation** - Convert formats
- **Document extraction** - PDF, DOCX to text
- **Archive management** - ZIP, unzip, organize

## Pattern 1: Batch CSV Processing

```rust
use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. List CSV files
builder.add_node("FileListNode", "list_files", ValueMap::from([
    ("directory".into(), Value::String("data/input".into())),
    ("pattern".into(), Value::String("*.csv".into())),
]));

// 2. Process each file
builder.add_node("MapNode", "process_files", ValueMap::from([
    ("input".into(), Value::String("{{list_files.files}}".into())),
    ("workflow".into(), Value::String("process_single_csv".into())),
]));

// 3. Merge results
builder.add_node("MergeNode", "merge_results", ValueMap::from([
    ("inputs".into(), Value::String("{{process_files.results}}".into())),
    ("strategy".into(), Value::String("combine".into())),
]));

// 4. Write consolidated output
builder.add_node("CSVWriterNode", "write_output", ValueMap::from([
    ("file_path".into(), Value::String("data/output/consolidated.csv".into())),
    ("data".into(), Value::String("{{merge_results.combined}}".into())),
    ("headers".into(), Value::Array(vec![
        Value::String("id".into()),
        Value::String("name".into()),
        Value::String("value".into()),
    ])),
]));

builder.connect("list_files", "files", "process_files", "input");
builder.connect("process_files", "results", "merge_results", "inputs");
builder.connect("merge_results", "combined", "write_output", "data");

let workflow = builder.build(&registry)?;
let runtime = Runtime::new(RuntimeConfig::default(), registry);
let result = runtime.execute(&workflow, ValueMap::new()).await?;
```

## Pattern 2: PDF Document Extraction

```rust
use kailash_core::{WorkflowBuilder, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. Read PDF document
builder.add_node("DocumentProcessorNode", "extract_pdf", ValueMap::from([
    ("file_path".into(), Value::String("{{input.pdf_path}}".into())),
    ("extract_metadata".into(), Value::Bool(true)),
    ("preserve_structure".into(), Value::Bool(true)),
    ("page_numbers".into(), Value::Bool(true)),
]));

// 2. Extract tables
builder.add_node("TransformNode", "extract_tables", ValueMap::from([
    ("input".into(), Value::String("{{extract_pdf.content}}".into())),
    ("transformation".into(), Value::String("extract_tables()".into())),
]));

// 3. Extract text
builder.add_node("TransformNode", "extract_text", ValueMap::from([
    ("input".into(), Value::String("{{extract_pdf.content}}".into())),
    ("transformation".into(), Value::String("extract_text()".into())),
]));

// 4. Analyze with AI
let llm_model = std::env::var("LLM_MODEL").expect("LLM_MODEL in .env");
builder.add_node("LLMNode", "analyze_document", ValueMap::from([
    ("provider".into(), Value::String(
        std::env::var("LLM_PROVIDER").expect("LLM_PROVIDER in .env").into()
    )),
    ("model".into(), Value::String(llm_model.into())),
    ("prompt".into(), Value::String("Summarize this document: {{extract_text.text}}".into())),
]));

// 5. Save results
builder.add_node("JSONWriterNode", "save_results", ValueMap::from([
    ("file_path".into(), Value::String("output/{{input.pdf_name}}_analysis.json".into())),
    ("data".into(), Value::Object(ValueMap::from([
        ("metadata".into(), Value::String("{{extract_pdf.metadata}}".into())),
        ("tables".into(), Value::String("{{extract_tables.tables}}".into())),
        ("summary".into(), Value::String("{{analyze_document.response}}".into())),
    ]))),
    ("indent".into(), Value::Integer(2)),
]));

builder.connect("extract_pdf", "content", "extract_tables", "input");
builder.connect("extract_pdf", "content", "extract_text", "input");
builder.connect("extract_text", "text", "analyze_document", "prompt");
builder.connect("analyze_document", "response", "save_results", "data");
```

## Pattern 3: File Format Conversion

```rust
use kailash_core::{WorkflowBuilder, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. Read source file
builder.add_node("ConditionalNode", "detect_format", ValueMap::from([
    ("condition".into(), Value::String("{{input.file_ext}}".into())),
    ("branches".into(), Value::Object(ValueMap::from([
        (".csv".into(), Value::String("read_csv".into())),
        (".json".into(), Value::String("read_json".into())),
        (".xlsx".into(), Value::String("read_excel".into())),
    ]))),
]));

// 2. Read different formats
builder.add_node("CSVReaderNode", "read_csv", ValueMap::from([
    ("file_path".into(), Value::String("{{input.file_path}}".into())),
]));

builder.add_node("JSONReaderNode", "read_json", ValueMap::from([
    ("file_path".into(), Value::String("{{input.file_path}}".into())),
]));

builder.add_node("ExcelReaderNode", "read_excel", ValueMap::from([
    ("file_path".into(), Value::String("{{input.file_path}}".into())),
]));

// 3. Normalize to common format
builder.add_node("TransformNode", "normalize", ValueMap::from([
    ("input".into(), Value::String("{{read_csv.data || read_json.data || read_excel.data}}".into())),
    ("transformation".into(), Value::String("normalize_to_dict_list()".into())),
]));

// 4. Write in target format
builder.add_node("ConditionalNode", "write_format", ValueMap::from([
    ("condition".into(), Value::String("{{input.target_format}}".into())),
    ("branches".into(), Value::Object(ValueMap::from([
        ("csv".into(), Value::String("write_csv".into())),
        ("json".into(), Value::String("write_json".into())),
        ("parquet".into(), Value::String("write_parquet".into())),
    ]))),
]));

builder.connect("detect_format", "result", "normalize", "input");
builder.connect("normalize", "data", "write_format", "input");
```

## Pattern 4: Watch Folder Automation

```rust
use kailash_core::{WorkflowBuilder, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. Watch directory for new files
builder.add_node("FileWatchNode", "watch_folder", ValueMap::from([
    ("directory".into(), Value::String("data/inbox".into())),
    ("pattern".into(), Value::String("*.pdf".into())),
    ("event".into(), Value::String("created".into())),
]));

// 2. Validate file
builder.add_node("FileValidateNode", "validate", ValueMap::from([
    ("file_path".into(), Value::String("{{watch_folder.file_path}}".into())),
    ("min_size".into(), Value::Integer(1024)),      // 1KB minimum
    ("max_size".into(), Value::Integer(10485760)),   // 10MB maximum
    ("extensions".into(), Value::Array(vec![
        Value::String(".pdf".into()),
    ])),
]));

// 3. Process document
builder.add_node("DocumentProcessorNode", "process", ValueMap::from([
    ("file_path".into(), Value::String("{{validate.file_path}}".into())),
]));

// 4. Move to processed folder
builder.add_node("FileMoveNode", "move_file", ValueMap::from([
    ("source".into(), Value::String("{{validate.file_path}}".into())),
    ("destination".into(), Value::String("data/processed/{{watch_folder.filename}}".into())),
]));

// 5. On error, move to failed folder
builder.add_node("FileMoveNode", "move_failed", ValueMap::from([
    ("source".into(), Value::String("{{validate.file_path}}".into())),
    ("destination".into(), Value::String("data/failed/{{watch_folder.filename}}".into())),
]));

builder.connect("watch_folder", "file_path", "validate", "file_path");
builder.connect("validate", "file_path", "process", "file_path");
builder.connect("process", "result", "move_file", "source");
// Error handling connection
// builder.add_error_handler("process", "move_failed");
```

## Best Practices

1. **Error handling** - Move failed files to error folder
2. **File validation** - Check size, format, permissions
3. **Atomic operations** - Write to temp, then move
4. **Progress tracking** - Log processed files
5. **Cleanup** - Delete temp files
6. **Batch size** - Process in manageable chunks

## Common Pitfalls

- **No error handling** - Lost files on failures
- **Memory issues** - Loading large files entirely
- **Race conditions** - Multiple processors on same file
- **Missing validation** - Processing invalid files
- **No cleanup** - Accumulating temp files

## Related Skills

- **Data Nodes**: [`nodes-data-reference`](../nodes/nodes-data-reference.md)
- **ETL Patterns**: [`workflow-pattern-etl`](workflow-pattern-etl.md)

<!-- Trigger Keywords: file processing, batch file, document workflow, file automation, CSV processing, PDF extraction -->
