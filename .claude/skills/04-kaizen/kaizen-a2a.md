---
name: kaizen-a2a
description: "Agent-to-Agent (A2A) communication protocol for Kaizen. Use when asking about A2A protocol, AgentCard, AgentRegistry, MessageBus, inter-agent messaging, capability-based discovery, or agent delegation."
---

# Kaizen A2A: Agent-to-Agent Communication Protocol

The A2A protocol provides agent discovery, registration, and inter-agent messaging for multi-agent coordination beyond the orchestration runtime.

## Components

| Type                 | Module           | Purpose                                                  |
| -------------------- | ---------------- | -------------------------------------------------------- |
| `AgentCard`          | `a2a::discovery` | Describes an agent's identity, capabilities, and schemas |
| `AgentRegistry`      | `a2a::discovery` | Discovers agents by capability (thread-safe)             |
| `A2AMessage`         | `a2a::messaging` | Message exchanged between agents                         |
| `MessageType`        | `a2a::messaging` | Enum: TaskRequest, TaskResponse, StatusUpdate, etc.      |
| `MessageBus`         | `a2a::messaging` | Trait for message transport                              |
| `InMemoryMessageBus` | `a2a::messaging` | In-memory queue-based message bus                        |
| `A2AProtocol`        | `a2a::messaging` | High-level protocol combining discovery + messaging      |

## AgentCard: Describing Agent Capabilities

```rust
use kailash_kaizen::a2a::AgentCard;

// Create an agent card with a generated UUID
let card = AgentCard::new("researcher", "Researches topics using web search")
    .with_capability("text-generation")
    .with_capability("research")
    .with_capability("web-search")
    .with_input_schema(serde_json::json!({
        "type": "object",
        "properties": {
            "query": {"type": "string"},
            "depth": {"type": "integer"}
        },
        "required": ["query"]
    }))
    .with_output_schema(serde_json::json!({
        "type": "object",
        "properties": {
            "findings": {"type": "string"},
            "sources": {"type": "array"}
        }
    }));

// Each card has a unique UUID
assert!(!card.id.is_empty());
assert_eq!(card.name, "researcher");
assert!(card.has_capability("research"));
assert!(!card.has_capability("code-review"));
```

## AgentRegistry: Capability-Based Discovery

Thread-safe registry backed by `Mutex<HashMap>`.

```rust
use std::sync::Arc;
use kailash_kaizen::a2a::{AgentCard, AgentRegistry};

let registry = Arc::new(AgentRegistry::new());

// Register agents
let researcher_card = AgentCard::new("researcher", "Researches topics")
    .with_capability("research")
    .with_capability("text-generation");
let researcher_id = registry.register(researcher_card);

let coder_card = AgentCard::new("coder", "Writes code")
    .with_capability("code-generation")
    .with_capability("code-review");
let coder_id = registry.register(coder_card);

let reviewer_card = AgentCard::new("reviewer", "Reviews code")
    .with_capability("code-review");
registry.register(reviewer_card);

// Discover agents by capability
let code_reviewers = registry.discover("code-review");
assert_eq!(code_reviewers.len(), 2); // coder + reviewer

let researchers = registry.discover("research");
assert_eq!(researchers.len(), 1);

let none = registry.discover("data-analysis");
assert!(none.is_empty());

// Fetch a specific agent by ID
let card = registry.get(&researcher_id);
assert!(card.is_some());

// List all registered agents
let all = registry.list_all();
assert_eq!(all.len(), 3);

// Unregister an agent
assert!(registry.unregister(&coder_id));
assert_eq!(registry.len(), 2);
```

## MessageBus: Inter-Agent Communication

### InMemoryMessageBus

Queue-based message transport. Each agent ID maps to a queue of pending messages. Messages are drained on `receive()`.

```rust
use kailash_kaizen::a2a::{A2AMessage, InMemoryMessageBus, MessageBus, MessageType};

let bus = InMemoryMessageBus::new();

// Send a task request
let msg = A2AMessage::new(
    "client-agent",
    "worker-agent",
    MessageType::TaskRequest,
    serde_json::json!({"task": "analyze data", "data": [1, 2, 3]}),
);
bus.send(msg).await?;

// Check pending count
let count = bus.peek("worker-agent").await?;
assert_eq!(count, 1);

// Receive drains the queue
let messages = bus.receive("worker-agent").await?;
assert_eq!(messages.len(), 1);
assert_eq!(messages[0].from_agent, "client-agent");

// Queue is now empty
let empty = bus.receive("worker-agent").await?;
assert!(empty.is_empty());
```

### A2AMessage

```rust
use kailash_kaizen::a2a::{A2AMessage, MessageType};

let msg = A2AMessage::new(
    "sender-id",
    "receiver-id",
    MessageType::TaskRequest,
    serde_json::json!({"input": "data"}),
);

// Each message has a unique UUID and ISO 8601 timestamp
assert!(!msg.id.is_empty());
assert!(!msg.timestamp.is_empty());

// Correlation ID links request/response pairs
let response = A2AMessage::new(
    "receiver-id",
    "sender-id",
    MessageType::TaskResponse,
    serde_json::json!({"result": 42}),
)
.with_correlation_id(&msg.id);

assert_eq!(response.correlation_id, Some(msg.id.clone()));
```

### MessageType Variants

```rust
use kailash_kaizen::a2a::MessageType;

MessageType::TaskRequest;       // Request to perform a task
MessageType::TaskResponse;      // Response to a task request
MessageType::StatusUpdate;      // Status update about an ongoing task
MessageType::CapabilityQuery;   // Query about agent capabilities
MessageType::CapabilityResponse; // Response to a capability query
MessageType::Error;             // Error message
```

## A2AProtocol: High-Level Communication

Combines `AgentRegistry` and `MessageBus` for discover-and-delegate semantics.

```rust
use std::sync::Arc;
use kailash_kaizen::a2a::{
    AgentCard, AgentRegistry, InMemoryMessageBus, A2AProtocol, MessageType,
};

let registry = Arc::new(AgentRegistry::new());
let bus = Arc::new(InMemoryMessageBus::new());

// Register a worker agent
let worker_card = AgentCard::new("analyzer", "Analyzes data")
    .with_capability("analysis");
let worker_id = registry.register(worker_card);

let protocol = A2AProtocol::new(registry, bus.clone());

// Step 1: Discover an agent by capability and send a task
let request = protocol
    .discover_and_delegate(
        "analysis",                                    // capability to find
        serde_json::json!({"data": [1, 2, 3]}),       // task payload
        "client",                                       // sender ID
    )
    .await?;
// request.to_agent == worker_id (auto-discovered)
// request.message_type == TaskRequest

// Step 2: Worker receives the task
let worker_messages = bus.receive(&worker_id).await?;
assert_eq!(worker_messages.len(), 1);
let task = &worker_messages[0];
assert_eq!(task.message_type, MessageType::TaskRequest);

// Step 3: Worker responds
let response = protocol
    .respond(task, serde_json::json!({"mean": 2.0}))
    .await?;
// response.correlation_id == Some(task.id)
// response.to_agent == "client"

// Step 4: Client receives response
let client_messages = bus.receive("client").await?;
assert_eq!(client_messages.len(), 1);
assert_eq!(client_messages[0].payload["mean"], 2.0);
assert_eq!(client_messages[0].correlation_id, Some(request.id.clone()));
```

### Error: No Agent Found

```rust
let result = protocol
    .discover_and_delegate("nonexistent-capability", serde_json::Value::Null, "client")
    .await;
// Err(AgentError::ToolNotFound("no agent with capability: nonexistent-capability"))
```

## Implementing a Custom MessageBus

For production use with Redis, NATS, or other transports:

```rust
use std::{future::Future, pin::Pin};
use kailash_kaizen::a2a::{A2AMessage, MessageBus};
use kailash_kaizen::error::AgentError;

struct RedisMessageBus {
    // redis connection pool
}

impl MessageBus for RedisMessageBus {
    fn send(
        &self,
        message: A2AMessage,
    ) -> Pin<Box<dyn Future<Output = Result<(), AgentError>> + Send + '_>> {
        Box::pin(async move {
            // Serialize and publish to Redis channel/list
            let json = serde_json::to_string(&message)
                .map_err(|e| AgentError::MemoryError(e.to_string()))?;
            // redis.lpush(&message.to_agent, &json).await...
            Ok(())
        })
    }

    fn receive(
        &self,
        agent_id: &str,
    ) -> Pin<Box<dyn Future<Output = Result<Vec<A2AMessage>, AgentError>> + Send + '_>> {
        let agent_id = agent_id.to_string();
        Box::pin(async move {
            // Drain all messages from the agent's Redis list
            // let items = redis.lrange(&agent_id, 0, -1).await...
            // redis.del(&agent_id).await...
            Ok(Vec::new())
        })
    }

    fn peek(
        &self,
        agent_id: &str,
    ) -> Pin<Box<dyn Future<Output = Result<usize, AgentError>> + Send + '_>> {
        let agent_id = agent_id.to_string();
        Box::pin(async move {
            // let len = redis.llen(&agent_id).await...
            Ok(0)
        })
    }
}
```

## Protocol Accessors

```rust
// Access underlying components
let registry_ref = protocol.registry();
let bus_ref: &dyn MessageBus = protocol.bus();
```

<!-- Trigger Keywords: A2A, agent-to-agent, AgentCard, AgentRegistry, MessageBus, InMemoryMessageBus, A2AProtocol, inter-agent, capability discovery, agent communication, delegation -->
