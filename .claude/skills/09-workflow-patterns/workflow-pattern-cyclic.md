---
name: workflow-pattern-cyclic
description: "Cyclic workflow patterns with loops and iterations. Use when asking 'loop workflow', 'cyclic', 'iterate', 'repeat until', or 'workflow cycles'."
---

# Cyclic Workflow Patterns

Patterns for implementing loops, iterations, and cyclic workflows.

> **Skill Metadata**
> Category: `workflow-patterns`
> Priority: `HIGH`
> SDK Version: `0.9.25+`
> Related Skills: [`workflow-pattern-etl`](workflow-pattern-etl.md), [`pattern-expert`](../../01-core-sdk/pattern-expert.md)
> Related Subagents: `pattern-expert` (cyclic workflows)

## Quick Reference

Cyclic workflows enable:

- **Loop until condition** - Repeat until success/threshold
- **Batch processing** - Process items in chunks
- **Retry logic** - Automatic retry with backoff
- **Iterative refinement** - Multi-pass processing

## Pattern 1: Loop Until Condition

```rust
use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. Initialize counter
builder.add_node("SetVariableNode", "init_counter", ValueMap::from([
    ("variable_name".into(), Value::String("counter".into())),
    ("value".into(), Value::Integer(0)),
]));

// 2. Process iteration
builder.add_node("HTTPRequestNode", "check_status", ValueMap::from([
    ("url".into(), Value::String("https://api.example.com/status".into())),
    ("method".into(), Value::String("GET".into())),
]));

// 3. Evaluate condition
builder.add_node("ConditionalNode", "check_complete", ValueMap::from([
    ("condition".into(), Value::String("{{check_status.status}} == 'completed'".into())),
    ("true_branch".into(), Value::String("complete".into())),
    ("false_branch".into(), Value::String("increment".into())),
]));

// 4. Increment counter
builder.add_node("TransformNode", "increment", ValueMap::from([
    ("input".into(), Value::String("{{init_counter.counter}}".into())),
    ("transformation".into(), Value::String("value + 1".into())),
]));

// 5. Check max iterations
builder.add_node("ConditionalNode", "check_max", ValueMap::from([
    ("condition".into(), Value::String("{{increment.result}} < 10".into())),
    ("true_branch".into(), Value::String("wait".into())),
    ("false_branch".into(), Value::String("timeout".into())),
]));

// 6. Wait before retry
builder.add_node("DelayNode", "wait", ValueMap::from([
    ("duration_seconds".into(), Value::Integer(5)),
]));

// 7. Loop back (connect to check_status)
builder.connect("init_counter", "counter", "check_status", "input");
builder.connect("check_status", "status", "check_complete", "condition");
builder.connect("check_complete", "output_false", "increment", "input");
builder.connect("increment", "result", "check_max", "condition");
builder.connect("check_max", "output_true", "wait", "trigger");
builder.connect("wait", "done", "check_status", "input"); // Loop!

let workflow = builder.build(&registry)?;
let runtime = Runtime::new(RuntimeConfig::default(), registry);
let result = runtime.execute(&workflow, ValueMap::new()).await?;
```

## Pattern 2: Batch Processing

```rust
use kailash_core::{WorkflowBuilder, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. Load all items
builder.add_node("DatabaseQueryNode", "load_items", ValueMap::from([
    ("query".into(), Value::String("SELECT id, data FROM items WHERE processed = FALSE".into())),
    ("batch_size".into(), Value::Integer(100)),
]));

// 2. Split into batches
builder.add_node("BatchSplitNode", "split_batches", ValueMap::from([
    ("input".into(), Value::String("{{load_items.results}}".into())),
    ("batch_size".into(), Value::Integer(10)),
]));

// 3. Process each batch
builder.add_node("MapNode", "process_batch", ValueMap::from([
    ("input".into(), Value::String("{{split_batches.batches}}".into())),
    ("operation".into(), Value::String("process_item".into())),
]));

// 4. Update database
builder.add_node("DatabaseExecuteNode", "mark_processed", ValueMap::from([
    ("query".into(), Value::String(
        "UPDATE items SET processed = TRUE WHERE id IN ({{process_batch.ids}})".into()
    )),
]));

// 5. Check for more items
builder.add_node("ConditionalNode", "check_more", ValueMap::from([
    ("condition".into(), Value::String("{{load_items.has_more}} == true".into())),
    ("true_branch".into(), Value::String("load_items".into())), // Loop back!
    ("false_branch".into(), Value::String("complete".into())),
]));

builder.connect("load_items", "results", "split_batches", "input");
builder.connect("split_batches", "batches", "process_batch", "input");
builder.connect("process_batch", "ids", "mark_processed", "ids");
builder.connect("mark_processed", "result", "check_more", "condition");
builder.connect("check_more", "output_true", "load_items", "trigger");
```

## Pattern 3: Exponential Backoff Retry

```rust
use kailash_core::{WorkflowBuilder, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. Initialize retry state
builder.add_node("SetVariableNode", "init_retry", ValueMap::from([
    ("retry_count".into(), Value::Integer(0)),
    ("backoff_seconds".into(), Value::Integer(1)),
]));

// 2. Execute operation
builder.add_node("HTTPRequestNode", "api_call", ValueMap::from([
    ("url".into(), Value::String("https://api.example.com/operation".into())),
    ("method".into(), Value::String("POST".into())),
    ("timeout".into(), Value::Integer(30)),
]));

// 3. Check success
builder.add_node("ConditionalNode", "check_success", ValueMap::from([
    ("condition".into(), Value::String("{{api_call.status_code}} == 200".into())),
    ("true_branch".into(), Value::String("success".into())),
    ("false_branch".into(), Value::String("check_retry".into())),
]));

// 4. Check retry count
builder.add_node("ConditionalNode", "check_retry", ValueMap::from([
    ("condition".into(), Value::String("{{init_retry.retry_count}} < 5".into())),
    ("true_branch".into(), Value::String("calculate_backoff".into())),
    ("false_branch".into(), Value::String("failed".into())),
]));

// 5. Calculate exponential backoff
builder.add_node("TransformNode", "calculate_backoff", ValueMap::from([
    ("input".into(), Value::String("{{init_retry.backoff_seconds}}".into())),
    ("transformation".into(), Value::String("value * 2".into())), // Exponential: 1, 2, 4, 8, 16 seconds
]));

// 6. Wait with backoff
builder.add_node("DelayNode", "backoff_wait", ValueMap::from([
    ("duration_seconds".into(), Value::String("{{calculate_backoff.result}}".into())),
]));

// 7. Increment retry counter
builder.add_node("TransformNode", "increment_retry", ValueMap::from([
    ("input".into(), Value::String("{{init_retry.retry_count}}".into())),
    ("transformation".into(), Value::String("value + 1".into())),
]));

// 8. Loop back to retry
builder.connect("init_retry", "retry_count", "api_call", "retry");
builder.connect("api_call", "status_code", "check_success", "condition");
builder.connect("check_success", "output_false", "check_retry", "condition");
builder.connect("check_retry", "output_true", "calculate_backoff", "input");
builder.connect("calculate_backoff", "result", "backoff_wait", "duration_seconds");
builder.connect("backoff_wait", "done", "increment_retry", "input");
builder.connect("increment_retry", "result", "api_call", "retry"); // Loop!
```

## Pattern 4: Iterative Refinement

```rust
use kailash_core::{WorkflowBuilder, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

let llm_model = std::env::var("LLM_MODEL").expect("LLM_MODEL in .env");
let llm_provider = std::env::var("LLM_PROVIDER").expect("LLM_PROVIDER in .env");

// 1. Initial prompt
builder.add_node("SetVariableNode", "init_prompt", ValueMap::from([
    ("prompt".into(), Value::String("Write a product description for: {{product_name}}".into())),
    ("iteration".into(), Value::Integer(0)),
]));

// 2. Generate content (LLM)
builder.add_node("LLMNode", "generate", ValueMap::from([
    ("provider".into(), Value::String(llm_provider.clone().into())),
    ("model".into(), Value::String(llm_model.clone().into())),
    ("prompt".into(), Value::String("{{init_prompt.prompt}}".into())),
]));

// 3. Evaluate quality
builder.add_node("LLMNode", "evaluate", ValueMap::from([
    ("provider".into(), Value::String(llm_provider.clone().into())),
    ("model".into(), Value::String(llm_model.clone().into())),
    ("prompt".into(), Value::String("Rate this description 1-10: {{generate.response}}".into())),
]));

// 4. Check quality threshold
builder.add_node("ConditionalNode", "check_quality", ValueMap::from([
    ("condition".into(), Value::String("{{evaluate.score}} >= 8".into())),
    ("true_branch".into(), Value::String("approved".into())),
    ("false_branch".into(), Value::String("refine".into())),
]));

// 5. Refine prompt with feedback
builder.add_node("LLMNode", "refine", ValueMap::from([
    ("provider".into(), Value::String(llm_provider.into())),
    ("model".into(), Value::String(llm_model.into())),
    ("prompt".into(), Value::String(
        "Improve this: {{generate.response}}. Feedback: {{evaluate.feedback}}".into()
    )),
]));

// 6. Check max iterations
builder.add_node("ConditionalNode", "check_max", ValueMap::from([
    ("condition".into(), Value::String("{{init_prompt.iteration}} < 3".into())),
    ("true_branch".into(), Value::String("increment".into())),
    ("false_branch".into(), Value::String("use_best".into())),
]));

// 7. Increment iteration
builder.add_node("TransformNode", "increment", ValueMap::from([
    ("input".into(), Value::String("{{init_prompt.iteration}}".into())),
    ("transformation".into(), Value::String("value + 1".into())),
]));

// Loop back for refinement
builder.connect("init_prompt", "prompt", "generate", "prompt");
builder.connect("generate", "response", "evaluate", "prompt");
builder.connect("evaluate", "score", "check_quality", "condition");
builder.connect("check_quality", "output_false", "refine", "input");
builder.connect("refine", "response", "check_max", "condition");
builder.connect("check_max", "output_true", "increment", "input");
builder.connect("increment", "result", "generate", "iteration"); // Loop!
```

## Best Practices

1. **Always set max iterations** - Prevent infinite loops
2. **Use explicit loop counters** - Track iteration count
3. **Implement backoff delays** - Avoid overwhelming systems
4. **Store intermediate results** - Enable debugging/recovery
5. **Clear exit conditions** - Define success/failure states
6. **Monitor loop metrics** - Track iterations, duration, success rate

## Common Pitfalls

- **No exit condition** - Infinite loops
- **Missing max iterations** - Runaway processes
- **No backoff delay** - API rate limiting
- **Memory leaks** - Accumulating state in loops
- **Poor error handling** - Unhandled failures in iterations

## Related Skills

- **ETL Patterns**: [`workflow-pattern-etl`](workflow-pattern-etl.md)
- **Error Handling**: [`gold-error-handling`](../../17-gold-standards/gold-error-handling.md)
- **Conditional Logic**: [`nodes-logic-reference`](../nodes/nodes-logic-reference.md)

<!-- Trigger Keywords: loop workflow, cyclic, iterate, repeat until, workflow cycles, retry logic, batch processing -->
