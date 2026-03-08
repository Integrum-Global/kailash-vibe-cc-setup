---
name: kaizen-checkpoint
description: "Checkpoint, resume, and interrupt for Kaizen agents. Use when asking about 'checkpoint', 'agent resume', 'agent state', 'save agent', 'restore agent', 'CheckpointStorage', 'AgentInterrupt', 'graceful shutdown', or 'interrupt callback'."
---

# Kaizen Checkpoint/Resume & Interrupt

Persist and restore agent state with `CheckpointStorage`, `AgentCheckpoint`, and two built-in backends. Interrupt running agents gracefully with `AgentInterrupt`.

## AgentCheckpoint

A serializable snapshot of an agent's state at a point in time.

```rust
use kailash_kaizen::checkpoint::{AgentCheckpoint, CheckpointStorage};

// Create a new checkpoint (auto-generates UUID and timestamp)
let mut checkpoint = AgentCheckpoint::new("researcher", "gpt-4o");

// Fields (all public):
// - checkpoint_id: String         (UUID v4, auto-generated)
// - agent_name: String
// - model: String
// - conversation: Vec<ConversationTurn>   (empty by default)
// - memory_snapshot: serde_json::Value    (Null by default)
// - tool_state: serde_json::Value         (Null by default)
// - created_at: String                    (ISO 8601, auto-generated via chrono)
// - metadata: serde_json::Value           (empty Object by default)

// Populate fields
checkpoint.memory_snapshot = serde_json::json!({"context": "market research"});
checkpoint.metadata = serde_json::json!({"progress": 0.5, "step": "analysis"});
```

`AgentCheckpoint` derives `Debug`, `Clone`, `Serialize`, `Deserialize`.

## CheckpointStorage Trait

```rust
pub trait CheckpointStorage: Send + Sync + 'static {
    fn save(&self, checkpoint: &AgentCheckpoint)
        -> Pin<Box<dyn Future<Output = Result<String, AgentError>> + Send + '_>>;

    fn load(&self, checkpoint_id: &str)
        -> Pin<Box<dyn Future<Output = Result<AgentCheckpoint, AgentError>> + Send + '_>>;

    fn list(&self, agent_name: &str)
        -> Pin<Box<dyn Future<Output = Result<Vec<AgentCheckpoint>, AgentError>> + Send + '_>>;

    fn delete(&self, checkpoint_id: &str)
        -> Pin<Box<dyn Future<Output = Result<(), AgentError>> + Send + '_>>;
}
```

The trait is object-safe (`dyn CheckpointStorage` is `Send + Sync`).

## InMemoryCheckpointStorage

HashMap-backed storage for testing and development. Data is lost when the process exits.

```rust
use kailash_kaizen::checkpoint::{
    AgentCheckpoint, InMemoryCheckpointStorage, CheckpointStorage,
};

let storage = InMemoryCheckpointStorage::new();

// Save a checkpoint
let checkpoint = AgentCheckpoint::new("assistant", "gpt-4o");
let id = storage.save(&checkpoint).await?;

// Load it back
let restored = storage.load(&id).await?;
assert_eq!(restored.agent_name, "assistant");

// List all checkpoints for an agent
let all = storage.list("assistant").await?;
assert_eq!(all.len(), 1);

// Delete a checkpoint
storage.delete(&id).await?;
```

Also implements `Default`.

## FileCheckpointStorage

JSON file-backed storage. Each checkpoint is stored as `{base_dir}/{checkpoint_id}.json`. The directory is created on first save if it does not exist.

```rust
use kailash_kaizen::checkpoint::{
    AgentCheckpoint, FileCheckpointStorage, CheckpointStorage,
};

// Constructor accepts impl Into<PathBuf>
let storage = FileCheckpointStorage::new("/tmp/agent-checkpoints");

// Save -- writes to /tmp/agent-checkpoints/{checkpoint_id}.json
let mut checkpoint = AgentCheckpoint::new("researcher", "gpt-4o");
checkpoint.metadata = serde_json::json!({"task": "market research"});
let id = storage.save(&checkpoint).await?;

// Load -- reads from disk
let restored = storage.load(&id).await?;

// List -- scans directory for all .json files matching agent_name
let checkpoints = storage.list("researcher").await?;

// Delete -- removes the .json file
storage.delete(&id).await?;
```

## AgentInterrupt

Thread-safe interrupt mechanism for graceful agent shutdown, with callbacks, chaining, and checkpoint integration.

```rust
use kailash_kaizen::dx::interrupt::AgentInterrupt;
use std::time::Duration;

let interrupt = AgentInterrupt::new();

// Check state
assert!(!interrupt.is_interrupted());

// Register a callback (invoked once when interrupt fires)
interrupt.on_interrupt(|| println!("interrupted!"));

// Fire the interrupt (sets flag + calls all callbacks once)
interrupt.request_interrupt();
assert!(interrupt.is_interrupted());

// Clear the interrupt (resets flag but does NOT re-enable callbacks)
interrupt.clear();
assert!(!interrupt.is_interrupted());

// Graceful shutdown -- spawns a background thread that fires the
// interrupt after the timeout if it has not already been set
let interrupt = AgentInterrupt::new();
interrupt.request_graceful_shutdown(Duration::from_secs(30));

// Chain interrupts -- when this fires, chained ones also fire
let parent = AgentInterrupt::new();
let child = std::sync::Arc::new(AgentInterrupt::new());
parent.chain(child.clone());
parent.request_interrupt();
assert!(child.is_interrupted());

// Checkpoint on interrupt -- saves agent memory snapshot when interrupted
use kailash_kaizen::memory::SessionMemory;
use std::sync::Arc;
let memory = Arc::new(SessionMemory::new());
let interrupt = AgentInterrupt::new();
interrupt.checkpoint_on_interrupt(
    memory,
    serde_json::json!({"task": "research", "step": 3}),
);
```

### Key Behaviors

- **Fire-once callbacks**: Callbacks run exactly once, even if `request_interrupt()` is called multiple times
- **Chaining**: `parent.chain(child)` -- when parent fires, child fires too
- **Graceful shutdown**: `request_graceful_shutdown(timeout)` spawns a thread that waits then fires
- **`checkpoint_on_interrupt(memory, data)`**: Registers a callback that stores `data` in the memory under the key `"_checkpoint"` when the interrupt fires

## Integration Pattern

```rust
use kailash_kaizen::checkpoint::{
    AgentCheckpoint, FileCheckpointStorage, CheckpointStorage,
};

// After each agent task completion, save a checkpoint
async fn save_agent_state(
    storage: &impl CheckpointStorage,
    agent_name: &str,
    model: &str,
    conversation: Vec<kailash_kaizen::types::ConversationTurn>,
    memory: serde_json::Value,
) -> Result<String, kailash_kaizen::error::AgentError> {
    let mut checkpoint = AgentCheckpoint::new(agent_name, model);
    checkpoint.conversation = conversation;
    checkpoint.memory_snapshot = memory;
    storage.save(&checkpoint).await
}

// Resume an agent from its most recent checkpoint
async fn resume_agent(
    storage: &impl CheckpointStorage,
    agent_name: &str,
) -> Result<Option<AgentCheckpoint>, kailash_kaizen::error::AgentError> {
    let mut checkpoints = storage.list(agent_name).await?;
    // Sort by created_at descending to get the most recent
    checkpoints.sort_by(|a, b| b.created_at.cmp(&a.created_at));
    Ok(checkpoints.into_iter().next())
}
```

## Source Files

- `crates/kailash-kaizen/src/checkpoint/mod.rs` -- re-exports
- `crates/kailash-kaizen/src/checkpoint/storage.rs` -- `AgentCheckpoint`, `CheckpointStorage` trait, `InMemoryCheckpointStorage`, `FileCheckpointStorage`
- `crates/kailash-kaizen/src/dx/interrupt.rs` -- `AgentInterrupt`

<!-- Trigger Keywords: checkpoint, agent resume, restore agent, save agent, agent state, CheckpointStorage, InMemoryCheckpointStorage, FileCheckpointStorage, AgentCheckpoint, AgentInterrupt, graceful shutdown, interrupt, checkpoint_on_interrupt -->
