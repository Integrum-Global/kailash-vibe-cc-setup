---
name: kaizen-streaming
description: "Streaming LLM responses for Kaizen agents. Use when asking about StreamingAgent, StreamHandler, TokenCollector, ChannelStreamHandler, StreamEvent, or token-by-token streaming."
---

# Kaizen Streaming: Token-by-Token LLM Responses

The streaming module wraps agents to deliver LLM responses token-by-token via a callback interface.

1. **`StreamHandler`** -- Trait with lifecycle callbacks (`on_start`, `on_token`, `on_end`, `on_error`)
2. **`StreamingAgent`** -- Wraps an `Agent` and forwards tokens to a handler
3. **`TokenCollector`** -- Handler that accumulates tokens into a string
4. **`ChannelStreamHandler`** -- Handler that collects `StreamEvent` objects into a list
5. **`StreamEvent`** -- Enum: `Start`, `Token(String)`, `End(String)`, `Error(String)`

## StreamHandler Trait

Callback interface for processing streaming LLM tokens. All methods have default no-op implementations. Implementations must be `Send + Sync`.

```rust
use kailash_kaizen::streaming::StreamHandler;
use kailash_kaizen::error::AgentError;

pub trait StreamHandler: Send + Sync {
    fn on_start(&self) {}
    fn on_token(&self, token: &str) { let _ = token; }
    fn on_end(&self, full_text: &str) { let _ = full_text; }
    fn on_error(&self, error: &AgentError) { let _ = error; }
}

// Custom handler example
struct PrintHandler;
impl StreamHandler for PrintHandler {
    fn on_token(&self, token: &str) {
        print!("{token}");  // Print tokens as they arrive
    }
    fn on_end(&self, full_text: &str) {
        println!("\n--- Complete ({} chars) ---", full_text.len());
    }
}
```

The trait is object-safe: `&dyn StreamHandler` and `Arc<dyn StreamHandler>` work.

## StreamingAgent

Wraps an `Agent` and streams its LLM responses. Uses `LlmClient::stream_completion()` for real SSE streaming; for mock providers, tokens are word-level chunks.

```rust
use kailash_kaizen::streaming::{StreamingAgent, TokenCollector, StreamHandler};
use kailash_kaizen::agent::concrete::Agent;
use kailash_kaizen::agent::BaseAgent;
use kailash_kaizen::types::AgentConfig;
use kailash_kaizen::llm::client::LlmClient;
use std::sync::Arc;

let config = AgentConfig {
    model: Some("gpt-4o".to_string()),
    ..AgentConfig::default()
};
let llm = LlmClient::from_env()?;
let agent = Agent::new(config, llm)?;

// With a handler
let collector = Arc::new(TokenCollector::new());
let streaming = StreamingAgent::new(agent, Some(collector.clone()));
let result = streaming.run("Hello!").await?;
println!("Full text: {}", collector.full_text());
println!("Tokens: {}", collector.token_count());

// Without a handler (falls back to regular agent.run())
let streaming = StreamingAgent::new(agent, None);
let result = streaming.run("Hello!").await?;

// Accessors
let model: &str = streaming.model();
let config: &AgentConfig = streaming.config();
```

### Constructor

```rust
StreamingAgent::new(agent: Agent, handler: Option<Arc<dyn StreamHandler>>) -> Self
```

### Lifecycle

1. `on_start()` -- called after the first token arrives (NOT before the request)
2. `on_token(token)` -- called for each token chunk
3. `on_end(full_text)` -- called when the stream completes, with the full accumulated text
4. `on_error(error)` -- called if the stream fails (no `on_start`/`on_end` in this case)

If the response is empty (no tokens), `on_start()` and `on_end("")` are both called.

### BaseAgent Implementation

`StreamingAgent` implements `BaseAgent`, so it can be used anywhere an agent is expected:

```rust
let result: AgentResult = streaming.run("Hello").await?;
// result.response contains the full text
// result.iterations == 1
// result.duration_ms records wall-clock time
```

## TokenCollector

A `StreamHandler` that accumulates all tokens into a `String`. Thread-safe via `Mutex` and `AtomicUsize`.

```rust
use kailash_kaizen::streaming::{TokenCollector, StreamHandler};

let collector = TokenCollector::new();

// Use as a StreamHandler
collector.on_start();
collector.on_token("Hello");
collector.on_token(" world");
collector.on_end("Hello world");

// Accessors
assert_eq!(collector.full_text(), "Hello world");
assert_eq!(collector.token_count(), 2);

// Reset for reuse (e.g., between multiple agent runs)
collector.reset();
assert_eq!(collector.full_text(), "");
assert_eq!(collector.token_count(), 0);
```

Also implements `Default` and `Debug`. `on_start`, `on_end`, and `on_error` are no-ops -- only `on_token` accumulates text.

## ChannelStreamHandler

A `StreamHandler` that collects all events as `StreamEvent` objects in a `Vec`. Thread-safe via `Mutex`.

```rust
use kailash_kaizen::streaming::{ChannelStreamHandler, StreamEvent, StreamHandler};

let handler = ChannelStreamHandler::new();

handler.on_start();
handler.on_token("Hello");
handler.on_token(" world");
handler.on_end("Hello world");

// Access collected events
let events: Vec<StreamEvent> = handler.events();  // Returns a clone
assert_eq!(events.len(), 4);
assert!(events[0].is_start());
assert!(events[1].is_token());
assert!(events[3].is_end());

// Event count without cloning
assert_eq!(handler.event_count(), 4);

// Push raw error string (bypasses AgentError wrapping)
handler.push_raw_error("connection lost");
```

Also implements `Default` and `Debug`.

## StreamEvent

Enum representing streaming lifecycle events.

```rust
use kailash_kaizen::streaming::StreamEvent;

let event = StreamEvent::Token("hello".into());

// Type checks
assert!(event.is_token());
assert!(!event.is_start());
assert!(!event.is_end());
assert!(!event.is_error());

// Text content
assert_eq!(event.text(), "hello");

// Text for each variant:
// Start -> ""
// Token(s) -> s
// End(s) -> s (full accumulated text)
// Error(s) -> s (error message)

// Display
println!("{}", event);  // StreamEvent::Token("hello")
```

## Python Binding

```python
from kailash import (
    StreamHandler, StreamingAgent, TokenCollector,
    ChannelStreamHandler, StreamEvent,
    Agent, AgentConfig, LlmClient,
)

# --- StreamHandler (subclassable) ---
class MyHandler(StreamHandler):
    def __init__(self):
        super().__init__()
        self.tokens = []

    def on_token(self, token):
        self.tokens.append(token)

    def on_end(self, full_text):
        print(f"Complete: {full_text}")

# --- TokenCollector ---
collector = TokenCollector()
# After streaming:
print(collector.full_text)    # property, not method
print(collector.token_count)  # property
collector.reset()

# --- ChannelStreamHandler ---
handler = ChannelStreamHandler()
# After streaming:
for event in handler.events:      # property, list of StreamEvent
    if event.is_token:
        print(event.text)
print(handler.event_count)        # property

# --- StreamEvent (factory methods) ---
event = StreamEvent.token("hello")
event = StreamEvent.start()
event = StreamEvent.end("full text")
event = StreamEvent.error("oops")
# Properties: is_token, is_start, is_end, is_error, text

# --- StreamingAgent ---
config = AgentConfig(model="gpt-4o")
client = LlmClient.mock(responses=["Hello world!"])
agent = Agent(config, client)

collector = TokenCollector()
streaming = StreamingAgent(agent, handler=collector)
result = streaming.run("Hello")       # dict with response, iterations, etc.
print(collector.full_text)

# handler can be: TokenCollector, ChannelStreamHandler, MyHandler (subclass), or None
streaming = StreamingAgent(agent)      # No handler
streaming = StreamingAgent(agent, handler=MyHandler())

# Property
print(streaming.model)  # str
```

## Source Files

- `crates/kailash-kaizen/src/streaming/handler.rs` -- `StreamHandler` trait
- `crates/kailash-kaizen/src/streaming/agent.rs` -- `StreamingAgent`
- `crates/kailash-kaizen/src/streaming/collector.rs` -- `TokenCollector`
- `crates/kailash-kaizen/src/streaming/channel.rs` -- `ChannelStreamHandler`, `StreamEvent`
- `bindings/kailash-python/src/kaizen/streaming.rs` -- Python bindings

<!-- Trigger Keywords: streaming, StreamingAgent, StreamHandler, TokenCollector, ChannelStreamHandler, StreamEvent, token streaming, on_token, on_start, on_end, stream LLM -->
