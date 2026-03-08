---
name: nexus-agentui
description: "Nexus AgentUI: SSE-based real-time agent event streaming, AgentEvent types, AgentUILayer, broadcast channel, event buffering, frontend integration. Use when asking 'AgentUI', 'agent events', 'SSE streaming', 'real-time agent', 'AgentEvent', 'AgentUILayer', 'broadcast channel', 'agent started', 'thinking step', 'tool execution', 'agent completed', 'event stream', or 'agent-to-UI'."
---

# Nexus AgentUI

SSE-based real-time streaming of AI agent events to UI clients. Multiple concurrent clients supported via `tokio::sync::broadcast`.

## Architecture

```
Agent -> broadcast::Sender<AgentEvent> -> [SSE endpoint /agent/events] -> Client 1
                                                                        -> Client 2
                                                                        -> Client N
```

- Agents emit events via the broadcast sender during TAOD loop execution
- Each SSE client subscribes independently via `sender.subscribe()`
- Late-connecting clients receive buffered events first, then live events
- Events are serialized as JSON in SSE format: `event: agent_event\ndata: {...}\n\n`

## Module Structure

```
kailash_core::agentui
  AgentEvent        -- 16-variant enum (lifecycle, TAOD, metrics, multi-agent, custom)

kailash_nexus::agentui
  AgentUIState      -- broadcast::Sender + VecDeque event buffer
  AgentUILayer      -- Tower Layer injecting Sender into request extensions
  AgentUIMiddleware -- Tower Service produced by AgentUILayer
  agent_events_handler     -- SSE handler (GET /agent/events)
  agent_events_router      -- Router with default 100-event buffer
  agent_events_router_with_buffer -- Router with configurable buffer
```

## 1. Setting Up the Event Channel

```rust
use kailash_core::agentui::AgentEvent;
use kailash_nexus::agentui::agent_events_router;
use tokio::sync::broadcast;
use axum::Router;

// Create broadcast channel with capacity for 256 events
let (sender, _) = broadcast::channel::<AgentEvent>(256);

// Build router with SSE endpoint at GET /agent/events
let agentui_router = agent_events_router(sender.clone());

// Merge into your main app
let app = Router::new()
    .merge(agentui_router);
// Route: GET /agent/events -> SSE stream
```

### Custom Buffer Capacity

Late-connecting clients receive buffered events before live events. Default buffer is 100 events.

```rust
use kailash_nexus::agentui::agent_events_router_with_buffer;
use kailash_core::agentui::AgentEvent;
use tokio::sync::broadcast;

let (sender, _) = broadcast::channel::<AgentEvent>(256);

// Buffer up to 500 recent events for late clients
let router = agent_events_router_with_buffer(sender.clone(), 500);
```

## 2. Emitting Events from Agents

Pass the `broadcast::Sender` to your agent code. Events are emitted by calling `sender.send()`.

```rust
use kailash_core::agentui::AgentEvent;
use tokio::sync::broadcast;

async fn run_agent(sender: broadcast::Sender<AgentEvent>) {
    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0);

    // Emit: agent started
    let _ = sender.send(AgentEvent::AgentStarted {
        agent_id: "researcher".to_string(),
        task: "Analyze market trends".to_string(),
        timestamp,
    });

    // Emit: thinking step
    let _ = sender.send(AgentEvent::ThinkingStep {
        agent_id: "researcher".to_string(),
        thought: "I should search for recent market data".to_string(),
        step: 1,
        timestamp,
    });

    // Emit: tool selected
    let _ = sender.send(AgentEvent::ToolSelected {
        agent_id: "researcher".to_string(),
        tool_name: "web_search".to_string(),
        timestamp,
    });

    // Emit: tool execution started
    let _ = sender.send(AgentEvent::ToolExecutionStarted {
        agent_id: "researcher".to_string(),
        tool_name: "web_search".to_string(),
        timestamp,
    });

    // ... tool runs ...

    // Emit: tool execution completed
    let _ = sender.send(AgentEvent::ToolExecutionCompleted {
        agent_id: "researcher".to_string(),
        tool_name: "web_search".to_string(),
        result_preview: "Found 15 relevant articles".to_string(),
        duration_ms: 450,
        timestamp,
    });

    // Emit: agent completed
    let _ = sender.send(AgentEvent::AgentCompleted {
        agent_id: "researcher".to_string(),
        result_preview: "Market analysis complete: 3 key trends identified".to_string(),
        duration_ms: 5000,
        timestamp,
    });
}
```

## 3. AgentEvent Types (16 Variants)

All events are defined in `kailash_core::agentui::AgentEvent`. Every variant has `agent_id: String` and `timestamp: i64` (Unix epoch seconds).

### Lifecycle Events

```rust
AgentEvent::AgentStarted { agent_id, task, timestamp }
AgentEvent::AgentCompleted { agent_id, result_preview, duration_ms, timestamp }
AgentEvent::AgentError { agent_id, error, recoverable, timestamp }
```

### TAOD Loop Events

```rust
AgentEvent::ThinkingStep { agent_id, thought, step, timestamp }
AgentEvent::ToolSelected { agent_id, tool_name, timestamp }
AgentEvent::ToolExecutionStarted { agent_id, tool_name, timestamp }
AgentEvent::ToolExecutionCompleted { agent_id, tool_name, result_preview, duration_ms, timestamp }
AgentEvent::Observing { agent_id, observation, timestamp }
AgentEvent::DecisionMade { agent_id, decision, confidence, timestamp }
```

### Streaming

```rust
AgentEvent::PartialOutput { agent_id, content, timestamp }
```

### Metrics

```rust
AgentEvent::TokenUsage { agent_id, prompt_tokens, completion_tokens, timestamp }
AgentEvent::CostUpdate { agent_id, cost_usd, budget_remaining, timestamp }
```

### Memory

```rust
AgentEvent::MemoryOperation { agent_id, operation, key, timestamp }
```

### Multi-Agent

```rust
AgentEvent::Delegated { agent_id, target_agent, task, timestamp }
AgentEvent::DelegationResult { agent_id, source_agent, success, timestamp }
```

### Custom

```rust
AgentEvent::Custom { agent_id, event_name, data, timestamp }
// data: serde_json::Value -- arbitrary JSON payload
```

### Accessors

```rust
let event = AgentEvent::ThinkingStep { /* ... */ };
event.agent_id();   // -> &str
event.timestamp();  // -> i64
event.event_type(); // -> &'static str ("thinking_step")
```

## 4. JSON Serialization Format

Events use internally-tagged JSON with `snake_case` naming:

```json
{
  "type": "thinking_step",
  "agent_id": "researcher",
  "thought": "I should search for recent data",
  "step": 1,
  "timestamp": 1700000000
}
```

The SSE stream format is:

```
event: agent_event
data: {"type":"agent_started","agent_id":"researcher","task":"Analyze data","timestamp":1700000000}

event: agent_event
data: {"type":"thinking_step","agent_id":"researcher","thought":"...","step":1,"timestamp":1700000000}

```

## 5. AgentUILayer (Middleware)

Injects the broadcast `Sender` into request extensions so any handler can emit events.

```rust
use kailash_nexus::agentui::AgentUILayer;
use kailash_core::agentui::AgentEvent;
use tokio::sync::broadcast;
use axum::{extract::Extension, Router, routing::post};
use tower::ServiceBuilder;

let (sender, _) = broadcast::channel::<AgentEvent>(256);
let layer = AgentUILayer::new(sender.clone());

let app = Router::new()
    .route("/api/analyze", post(analyze_handler))
    .layer(ServiceBuilder::new().layer(layer));

async fn analyze_handler(
    Extension(sender): Extension<broadcast::Sender<AgentEvent>>,
) -> String {
    let _ = sender.send(AgentEvent::AgentStarted {
        agent_id: "handler-agent".to_string(),
        task: "Process analysis request".to_string(),
        timestamp: 0,
    });
    "Analysis started".to_string()
}
```

## 6. AgentUIState (Direct Access)

For advanced use cases, use `AgentUIState` directly to manage buffering.

```rust
use kailash_nexus::agentui::AgentUIState;
use kailash_core::agentui::AgentEvent;
use tokio::sync::broadcast;

let (sender, _) = broadcast::channel::<AgentEvent>(256);
let state = AgentUIState::new(sender.clone(), 100);

// Buffer events manually (e.g., from a background task)
let event = AgentEvent::AgentStarted {
    agent_id: "bg-agent".to_string(),
    task: "Background processing".to_string(),
    timestamp: 0,
};
state.buffer_event(&event);

// Late-connecting client gets buffered events
let buffered = state.buffered_events();
// buffered: Vec<AgentEvent>

// Access the underlying sender
let tx = state.sender();
let _ = tx.send(event);
```

Buffer eviction is FIFO: when the buffer reaches capacity, the oldest event is removed in O(1).

## 7. Frontend Integration

### JavaScript EventSource

```javascript
const eventSource = new EventSource("/agent/events");

eventSource.addEventListener("agent_event", (event) => {
  const data = JSON.parse(event.data);

  switch (data.type) {
    case "agent_started":
      console.log(`Agent ${data.agent_id} started: ${data.task}`);
      break;
    case "thinking_step":
      console.log(`Step ${data.step}: ${data.thought}`);
      break;
    case "tool_selected":
      console.log(`Using tool: ${data.tool_name}`);
      break;
    case "tool_execution_completed":
      console.log(`Tool ${data.tool_name} done in ${data.duration_ms}ms`);
      break;
    case "agent_completed":
      console.log(`Done in ${data.duration_ms}ms: ${data.result_preview}`);
      eventSource.close();
      break;
    case "agent_error":
      console.error(`Error: ${data.error} (recoverable: ${data.recoverable})`);
      break;
    case "cost_update":
      console.log(
        `Cost: $${data.cost_usd}, remaining: $${data.budget_remaining}`,
      );
      break;
    case "partial_output":
      // Append streaming content
      document.getElementById("output").textContent += data.content;
      break;
  }
});

eventSource.onerror = () => {
  console.log("SSE connection lost, reconnecting...");
};
```

### React Hook

```typescript
function useAgentEvents(url: string) {
  const [events, setEvents] = useState<AgentEvent[]>([]);
  const [status, setStatus] = useState<
    "connecting" | "connected" | "completed"
  >("connecting");

  useEffect(() => {
    const source = new EventSource(url);

    source.addEventListener("agent_event", (e: MessageEvent) => {
      const event = JSON.parse(e.data);
      setEvents((prev) => [...prev, event]);

      if (event.type === "agent_completed" || event.type === "agent_error") {
        setStatus("completed");
        source.close();
      }
    });

    source.onopen = () => setStatus("connected");
    source.onerror = () => source.close();

    return () => source.close();
  }, [url]);

  return { events, status };
}
```

## 8. Full Integration Example

```rust
use kailash_core::agentui::AgentEvent;
use kailash_nexus::agentui::{agent_events_router, AgentUILayer};
use kailash_nexus::middleware::stack::{MiddlewareConfig, build_middleware_router};
use kailash_nexus::middleware::Preset;
use tokio::sync::broadcast;
use axum::Router;

// Create event channel
let (sender, _) = broadcast::channel::<AgentEvent>(256);

// Build SSE endpoint
let agentui = agent_events_router(sender.clone());

// Build main API
let api = Router::new()
    .route("/api/analyze", axum::routing::post(|| async { "ok" }))
    .layer(AgentUILayer::new(sender.clone()));

// Apply middleware
let config = MiddlewareConfig::from_preset(Preset::SaaS);
let app = Router::new()
    .merge(agentui)
    .merge(api);
let app = build_middleware_router(app, &config)?;

// Start server
let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await?;
axum::serve(listener, app).await?;
```

<!-- Trigger Keywords: AgentUI, agent events, SSE streaming, real-time agent, AgentEvent, AgentUILayer, AgentUIState, broadcast channel, agent started, thinking step, tool selected, tool execution, agent completed, agent error, partial output, token usage, cost update, delegation, event stream, agent-to-UI, Server-Sent Events, event buffering, late client -->
