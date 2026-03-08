# Connection Patterns Skill

Node connection patterns for the Kailash WorkflowBuilder.

## Usage

`/connection-patterns` -- Reference for builder.connect(), fan-out, fan-in, branching, and loop patterns

## Basic Connection

```rust
// builder.connect(source_node_id, source_output, target_node_id, target_input)
builder.connect("uppercase", "result", "log", "data");
//               ^source     ^output   ^target  ^input
```

The four arguments:

1. `source_node_id` -- ID of the node producing the value
2. `source_output` -- Name of the output field on the source node
3. `target_node_id` -- ID of the node consuming the value
4. `target_input` -- Name of the input field on the target node

## Common Input/Output Names by Node Category

| Node Type           | Outputs                       | Inputs                                 |
| ------------------- | ----------------------------- | -------------------------------------- |
| `TextTransformNode` | `result`                      | `text`, `operation`                    |
| `JSONTransformNode` | `result`                      | `data`, `expression`                   |
| `LogNode`           | `data`                        | `data`, `level`                        |
| `NoOpNode`          | `data`                        | `data`                                 |
| `ConditionalNode`   | `true_output`, `false_output` | `condition`, `true_data`, `false_data` |
| `SwitchNode`        | `case_<value>`                | `value`, `cases`                       |
| `MergeNode`         | `merged`                      | `inputs` (array)                       |
| `LoopNode`          | `iteration`, `final`          | `items`, `current`                     |
| `LLMNode`           | `response`, `usage`           | `prompt`, `system`                     |
| `HTTPRequestNode`   | `response`, `status`          | `url`, `method`, `body`                |
| `SQLQueryNode`      | `rows`, `count`               | `query`, `params`                      |
| `FileReaderNode`    | `content`, `metadata`         | `path`                                 |

## Fan-Out (One Output to Multiple Inputs)

Route a single node's output to several downstream nodes. Each downstream node receives the same value.

```rust
builder
    // Source node
    .add_node("HTTPRequestNode", "fetch", config)

    // Two consumers of the same output
    .add_node("JSONTransformNode", "parse_name", {
        let mut c = ValueMap::new();
        c.insert(Arc::from("expression"), Value::String(Arc::from("@.name")));
        c
    })
    .add_node("JSONTransformNode", "parse_email", {
        let mut c = ValueMap::new();
        c.insert(Arc::from("expression"), Value::String(Arc::from("@.email")));
        c
    })
    .add_node("LogNode", "audit", ValueMap::new())

    // Fan-out: "response" output goes to three different nodes
    .connect("fetch", "response", "parse_name", "data")
    .connect("fetch", "response", "parse_email", "data")
    .connect("fetch", "response", "audit", "data");
```

**DAG topology:**

```
fetch → parse_name
      → parse_email
      → audit
```

## Fan-In (Multiple Outputs to One Input via MergeNode)

Combine outputs from parallel nodes into a single stream using `MergeNode`.

```rust
builder
    // Parallel processors (same level in DAG)
    .add_node("LLMNode", "summarize", summarize_config)
    .add_node("LLMNode", "classify", classify_config)
    .add_node("SentimentNode", "sentiment", ValueMap::new())

    // MergeNode combines all inputs into an array
    .add_node("MergeNode", "combine", ValueMap::new())
    .add_node("JSONTransformNode", "aggregate", aggregate_config)

    // Fan-in: multiple outputs → MergeNode "inputs" field (receives array)
    // Note: MergeNode accumulates all connected inputs into Value::Array
    .connect("summarize", "response", "combine", "inputs")
    .connect("classify", "response", "combine", "inputs")
    .connect("sentiment", "result", "combine", "inputs")

    // Continue after merge
    .connect("combine", "merged", "aggregate", "data");
```

**DAG topology:**

```
summarize ↘
classify  → combine → aggregate
sentiment ↗
```

## ConditionalNode Branching

Route execution based on a boolean condition. Only one branch executes (with `ConditionalMode::SkipBranches`, the default).

```rust
builder
    .add_node("ConditionalNode", "check_auth", ValueMap::new())
    .add_node("LLMNode", "process_premium", premium_config)
    .add_node("TextTransformNode", "process_basic", basic_config)
    .add_node("LogNode", "result_log", ValueMap::new())

    // Feed the condition (must be Value::Bool) and optional branch data
    // The workflow inputs map feeds into the first level of nodes
    // "condition" input accepts a bool

    // True branch: premium path
    .connect("check_auth", "true_output", "process_premium", "prompt")
    // False branch: basic path
    .connect("check_auth", "false_output", "process_basic", "text")

    // Both branches converge at the log
    .connect("process_premium", "response", "result_log", "data")
    .connect("process_basic", "result", "result_log", "data");
```

**Note**: With `ConditionalMode::SkipBranches`, the unmet branch's nodes are skipped entirely. With `ConditionalMode::EvaluateAll`, both branches execute regardless.

```rust
// ConditionalNode inputs:
//   "condition"  -- Value::Bool (required)
//   "true_data"  -- Optional data to pass through to true_output
//   "false_data" -- Optional data to pass through to false_output
//
// ConditionalNode outputs:
//   "true_output"  -- emitted when condition == true
//   "false_output" -- emitted when condition == false

let mut condition_config = ValueMap::new();
// No config needed -- condition comes from runtime inputs
```

## SwitchNode Multi-Branch

Route to one of N branches based on a value match.

```rust
builder
    .add_node("SwitchNode", "route", {
        let mut c = ValueMap::new();
        // Define cases as an array of case values
        c.insert(Arc::from("cases"), Value::Array(vec![
            Value::String(Arc::from("pdf")),
            Value::String(Arc::from("csv")),
            Value::String(Arc::from("json")),
        ]));
        c
    })
    .add_node("PDFReaderNode", "handle_pdf", ValueMap::new())
    .add_node("CSVProcessorNode", "handle_csv", ValueMap::new())
    .add_node("JSONTransformNode", "handle_json", ValueMap::new())

    // SwitchNode generates outputs named "case_<value>"
    .connect("route", "case_pdf", "handle_pdf", "path")
    .connect("route", "case_csv", "handle_csv", "path")
    .connect("route", "case_json", "handle_json", "data");
```

## LoopNode Feedback Connections

Process items in a collection iteratively. `LoopNode` emits one item per iteration.

```rust
builder
    // LoopNode iterates over an array input
    .add_node("LoopNode", "loop", ValueMap::new())
    .add_node("LLMNode", "process_item", item_config)
    .add_node("LogNode", "log_item", ValueMap::new())

    // "iteration" output: current item value (emitted each iteration)
    // "final" output: emitted once after all iterations complete
    .connect("loop", "iteration", "process_item", "prompt")
    .connect("process_item", "response", "log_item", "data");

// LoopNode inputs:
//   "items" -- Value::Array (required) -- the collection to iterate
//   "current" -- (internal feedback, do not connect manually)
//
// LoopNode outputs:
//   "iteration" -- Value of current item (emitted per iteration)
//   "final"     -- All iteration results collected (emitted once at end)
```

## Linear Pipeline (Most Common Pattern)

```rust
builder
    .add_node("FileReaderNode", "read", ValueMap::new())
    .add_node("JSONTransformNode", "transform", transform_config)
    .add_node("LLMNode", "analyze", analyze_config)
    .add_node("FileWriterNode", "write", ValueMap::new())
    .connect("read", "content", "transform", "data")
    .connect("transform", "result", "analyze", "prompt")
    .connect("analyze", "response", "write", "content");
```

## Parallel Processing (Level-Based Execution)

Nodes at the same topological level run concurrently. Create parallel paths by having multiple nodes depend on the same upstream node but not on each other.

```rust
builder
    .add_node("FileReaderNode", "source", ValueMap::new())

    // These three have no dependency on each other -- run in parallel at Level 1
    .add_node("LLMNode", "llm_summary", summary_config)
    .add_node("JSONTransformNode", "extract_meta", meta_config)
    .add_node("HashingNode", "compute_hash", ValueMap::new())

    // All three feed into final aggregator at Level 2
    .add_node("MergeNode", "aggregate", ValueMap::new())

    .connect("source", "content", "llm_summary", "prompt")
    .connect("source", "content", "extract_meta", "data")
    .connect("source", "content", "compute_hash", "data")

    .connect("llm_summary", "response", "aggregate", "inputs")
    .connect("extract_meta", "result", "aggregate", "inputs")
    .connect("compute_hash", "hash", "aggregate", "inputs");
```

**Execution levels:**

```
Level 0: [source]
Level 1: [llm_summary, extract_meta, compute_hash]  <-- parallel
Level 2: [aggregate]
```

## Workflow Inputs → First Nodes

Global workflow inputs (passed to `runtime.execute`) are automatically available to all nodes in Level 0 (nodes with no incoming connections). The field names in the input `ValueMap` match the node's input parameter names.

```rust
// Workflow with two root nodes, both consuming from global inputs
builder
    .add_node("TextTransformNode", "upper", upper_config)
    .add_node("JSONTransformNode", "parse", parse_config)
    // No .connect() needed for root nodes -- they receive from global inputs

    // Global inputs must contain both "text" (for upper) and "data" (for parse)
    ;

let mut inputs = ValueMap::new();
inputs.insert(Arc::from("text"), Value::String(Arc::from("hello")));
inputs.insert(Arc::from("data"), Value::Object(BTreeMap::new()));
runtime.execute(&workflow, inputs).await?;
```

## Error: Connection to Non-Existent Node

`builder.build(&registry)?` catches connection errors at build time:

```rust
builder
    .add_node("LogNode", "log", ValueMap::new())
    .connect("nonexistent", "output", "log", "data");  // Error at build()

let workflow = builder.build(&registry);
// Err(BuildError::NodeNotFound { id: "nonexistent" })
```

## Verify

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo test -p kailash-core -- connection --nocapture 2>&1
```
