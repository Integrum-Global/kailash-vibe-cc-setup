---
name: kaizen-observability
description: "Observability stack for Kaizen agents. Use when asking about ObservabilityManager, MetricsCollector, TracingManager, LogAggregator, SpanContext, agent metrics, distributed tracing, or log aggregation."
---

# Kaizen Observability: Metrics, Tracing, and Logging

The observability module provides three subsystems coordinated by a central manager:

1. **`MetricsCollector`** -- Latency, token counts, errors, and tool calls per agent
2. **`TracingManager`** -- Hierarchical spans with parent-child relationships
3. **`LogAggregator`** -- Structured log entries with ring buffer storage
4. **`SpanContext`** -- Trace/span ID propagation for distributed tracing
5. **`ObservabilityManager`** -- Coordinator that owns all three subsystems

All types are `Send + Sync` and safe for concurrent use.

## SpanContext

Carries trace_id, span_id, and parent_span_id for distributed tracing. Uses UUID v4 for IDs.

```rust
use kailash_kaizen::observability::span::SpanContext;

// Create a root span (new trace_id, no parent)
let root = SpanContext::root("agent-run");
assert!(root.parent_span_id.is_none());

// Create a child span (inherits trace_id, parent = root.span_id)
let child = root.child("llm-call");
assert_eq!(child.trace_id, root.trace_id);
assert_eq!(child.parent_span_id, Some(root.span_id.clone()));

// Public fields:
// - trace_id: String
// - span_id: String
// - parent_span_id: Option<String>
// - name: String
```

Implements `Clone`, `Debug`, `Serialize`, `Deserialize`.

## MetricsCollector

Thread-safe metrics collection using `DashMap`. Records latency, token counts, errors, and tool calls per agent.

```rust
use kailash_kaizen::observability::metrics::MetricsCollector;
use std::time::Duration;

let mc = MetricsCollector::new();

// Record latency (increments total_calls by 1)
mc.record_latency("planner", Duration::from_millis(250));

// Record token usage
mc.record_tokens("planner", 500, 200);  // input_tokens, output_tokens

// Record an error
mc.record_error("planner", "timeout");

// Record a tool call
mc.record_tool_call("planner", "search", Duration::from_millis(100));

// Get a snapshot of all agent metrics
let snapshot = mc.get_metrics();
// snapshot: HashMap<String, AgentMetrics>
let m = &snapshot["planner"];
println!("Calls: {}", m.total_calls);
println!("Avg latency: {}ms", m.avg_latency_ms);
println!("Input tokens: {}", m.total_input_tokens);
println!("Output tokens: {}", m.total_output_tokens);
println!("Errors: {}", m.error_count);
println!("Tool calls: {}", m.tool_calls);

// Reset all metrics
mc.reset();
```

### AgentMetrics Fields

- `total_calls: u64` -- Number of latency records
- `total_latency_ms: u64` -- Sum of all latency durations in ms
- `avg_latency_ms: f64` -- Average latency (total/calls)
- `total_input_tokens: u64`
- `total_output_tokens: u64`
- `error_count: u64`
- `tool_calls: u64`

## TracingManager

Creates and manages hierarchical spans stored by trace ID. Uses `DashMap` for concurrent access.

```rust
use kailash_kaizen::observability::tracing::TracingManager;

let tm = TracingManager::new();

// Start a root span (creates a new trace)
let root = tm.start_span("agent-run", None);

// Start a child span under the root
let child = tm.start_span("llm-call", Some(&root));

// Add attributes to a span
tm.add_span_attribute(&child, "model", "gpt-4o");
tm.add_span_attribute(&child, "tokens", "700");

// End spans (records end_time)
tm.end_span(&child);
tm.end_span(&root);

// Retrieve a complete trace
let trace = tm.get_trace(&root.trace_id).unwrap();
assert_eq!(trace.trace_id, root.trace_id);
assert_eq!(trace.spans.len(), 2);

// Each span has:
// - span_id: String
// - parent_span_id: Option<String>
// - name: String
// - start_time: u64          (Unix ms)
// - end_time: Option<u64>    (Unix ms, None if still active)
// - attributes: HashMap<String, String>

// List all trace IDs
let ids: Vec<String> = tm.all_trace_ids();
```

Operations on nonexistent spans/traces are no-ops (best-effort). `Trace` and `Span` implement `Serialize`/`Deserialize`.

## LogAggregator

Structured log collection with ring buffer storage and filtering. Uses `Mutex<VecDeque>` internally.

```rust
use kailash_kaizen::observability::logging::{LogAggregator, LogLevel};

// Create with capacity (oldest entries evicted when full)
let la = LogAggregator::new(10_000);

// Log an entry
la.log(
    LogLevel::Info,
    "planner",           // agent_name
    "Processing started", // message
    None,                 // metadata: Option<HashMap<String, String>>
    None,                 // span_context: Option<SpanContext>
);

// Log with metadata and span context
use std::collections::HashMap;
use kailash_kaizen::observability::span::SpanContext;

let mut meta = HashMap::new();
meta.insert("code".to_string(), "500".to_string());
let span = SpanContext::root("op");

la.log(
    LogLevel::Error,
    "planner",
    "Request failed",
    Some(meta),
    Some(span),
);

// Query logs with filters
let all = la.get_logs(None, None, None);  // (level, agent_name, limit)
let errors = la.get_logs(Some(LogLevel::Error), None, None);
let planner = la.get_logs(None, Some("planner"), None);
let recent = la.get_logs(None, None, Some(10));  // last 10

// Each LogEntry has:
// - timestamp: u64                     (Unix ms)
// - level: LogLevel                    (Debug, Info, Warn, Error)
// - agent_name: String
// - message: String
// - metadata: Option<HashMap<String, String>>
// - span_context: Option<SpanContext>

// Entry count
let count = la.len();
```

### LogLevel

```rust
pub enum LogLevel { Debug, Info, Warn, Error }
```

`LogLevel::from_str_checked("info")` parses a string (case-insensitive), returning `Result<LogLevel, String>`.

## ObservabilityManager

Coordinator that owns a `MetricsCollector`, `TracingManager`, and `LogAggregator` (capacity: 10,000). Provides JSON export helpers.

```rust
use kailash_kaizen::observability::manager::ObservabilityManager;
use kailash_kaizen::observability::logging::LogLevel;
use std::time::Duration;

let mgr = ObservabilityManager::new();

// Access subsystems via references
mgr.metrics().record_latency("agent-1", Duration::from_millis(100));
mgr.metrics().record_tokens("agent-1", 500, 200);

let root = mgr.tracing().start_span("agent-run", None);
let child = mgr.tracing().start_span("llm-call", Some(&root));
mgr.tracing().add_span_attribute(&child, "model", "gpt-4o");

mgr.logging().log(LogLevel::Info, "agent-1", "LLM call complete", None, Some(child.clone()));

mgr.tracing().end_span(&child);
mgr.tracing().end_span(&root);

// Export metrics as JSON string
let json: String = mgr.export_metrics_json();
// {"agent-1": {"total_calls": 1, "avg_latency_ms": 100.0, ...}}

// Export a specific trace as JSON string
let json: Result<String, String> = mgr.export_trace_json(&root.trace_id);
```

Also implements `Default` and `Debug`.

## Python Binding

```python
from kailash import (
    SpanContext, MetricsCollector, TracingManager,
    LogAggregator, ObservabilityManager,
)

# --- SpanContext ---
root = SpanContext.root("agent-run")
child = root.child("llm-call")
print(root.trace_id)           # str
print(root.span_id)            # str
print(root.parent_span_id)     # None for root
print(root.name)               # "agent-run"
print(child.parent_span_id)    # == root.span_id

# --- MetricsCollector ---
mc = MetricsCollector()
mc.record_latency("agent-1", 250)        # duration_ms
mc.record_tokens("agent-1", 500, 200)    # input_tokens, output_tokens
mc.record_error("agent-1", "timeout")
mc.record_tool_call("agent-1", "search", 100)  # tool_name, duration_ms
snapshot = mc.get_metrics()
# {"agent-1": {"total_calls": 1, "avg_latency_ms": 250.0, ...}}
mc.reset()

# --- TracingManager ---
tm = TracingManager()
root = tm.start_span("agent-run")            # no parent
child = tm.start_span("llm-call", parent=root)
tm.add_span_attribute(child, "model", "gpt-4o")
tm.end_span(child)
tm.end_span(root)
trace = tm.get_trace(root.trace_id)
# {"trace_id": "...", "spans": [{"span_id": "...", ...}]}

# --- LogAggregator ---
la = LogAggregator(max_entries=1000)
la.log("info", "agent-1", "Processing started")
la.log("error", "agent-1", "Failed", metadata={"code": "500"})
la.log("debug", "agent-1", "Details", span_context=root)
logs = la.get_logs()                    # all logs
logs = la.get_logs(level="error")       # filter by level
logs = la.get_logs(agent_name="agent-1")  # filter by agent
# Each log: {"timestamp", "level", "agent_name", "message", "metadata", "span_context"}

# --- ObservabilityManager ---
mgr = ObservabilityManager()
mgr.metrics.record_latency("agent-1", 250)
ctx = mgr.tracing.start_span("operation")
mgr.logging.log("info", "agent-1", "Started")
mgr.tracing.end_span(ctx)

json_str = mgr.export_metrics_json()       # str
json_str = mgr.export_trace_json(ctx.trace_id)  # str, raises ValueError if not found

# Subsystem properties (shared state with manager)
mc = mgr.metrics     # MetricsCollector
tm = mgr.tracing     # TracingManager
la = mgr.logging     # LogAggregator
```

## Source Files

- `crates/kailash-kaizen/src/observability/span.rs` -- `SpanContext`
- `crates/kailash-kaizen/src/observability/metrics.rs` -- `MetricsCollector`, `AgentMetrics`
- `crates/kailash-kaizen/src/observability/tracing.rs` -- `TracingManager`, `Trace`, `Span`
- `crates/kailash-kaizen/src/observability/logging.rs` -- `LogAggregator`, `LogLevel`, `LogEntry`
- `crates/kailash-kaizen/src/observability/manager.rs` -- `ObservabilityManager`
- `bindings/kailash-python/src/kaizen/observability.rs` -- Python bindings

<!-- Trigger Keywords: observability, ObservabilityManager, MetricsCollector, TracingManager, LogAggregator, SpanContext, agent metrics, distributed tracing, log aggregation, span, trace, latency, token count -->
