---
name: react-integration-quick
description: "React + Kailash SDK integration. Use when asking 'react integration', 'react kailash', or 'kailash frontend'."
---

# React + Kailash Integration

> **Skill Metadata**
> Category: `frontend`
> Priority: `MEDIUM`
> SDK Version: `0.9.25+`

## Quick Setup

### 1. Backend API (Rust)

```rust
use kailash_nexus::{NexusApp, Preset};
use kailash_nexus::handler::Handler;
use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenvy::dotenv().ok();

    let registry = Arc::new(NodeRegistry::default());
    let mut builder = WorkflowBuilder::new();
    builder.add_node("LLMNode", "chat", ValueMap::from([
        ("provider".into(), Value::String("openai".into())),
        ("model".into(), Value::String(
            std::env::var("DEFAULT_LLM_MODEL").expect("DEFAULT_LLM_MODEL in .env").into()
        )),
        ("prompt".into(), Value::String("{{input.message}}".into())),
    ]));
    let workflow = builder.build(&registry)?;

    let app = NexusApp::new()
        .preset(Preset::Standard)
        .handler("/execute", Handler::from_workflow(workflow, registry));

    app.serve("0.0.0.0:3000").await?;
    Ok(())
}
```

### 2. React Frontend

```typescript
// src/api/workflow.ts
export async function executeWorkflow(message: string) {
  const response = await fetch('http://localhost:3000/execute', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({inputs: {message}})
  });
  return response.json();
}

// src/components/Chat.tsx
import { useState } from 'react';
import { executeWorkflow } from '../api/workflow';

export function Chat() {
  const [message, setMessage] = useState('');
  const [response, setResponse] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    const result = await executeWorkflow(message);
    setResponse(result.outputs.chat.response);
  };

  return (
    <form onSubmit={handleSubmit}>
      <input
        value={message}
        onChange={(e) => setMessage(e.target.value)}
        placeholder="Ask a question..."
      />
      <button type="submit">Send</button>
      {response && <div>{response}</div>}
    </form>
  );
}
```

## Streaming Responses

```typescript
// Backend (Rust) — enable SSE streaming on the NexusApp:
//   use kailash_nexus::agentui::SseHandler;
//   app.handler("/stream", SseHandler::from_workflow(workflow, registry));

// Frontend (React)
async function streamWorkflow(message: string) {
  const response = await fetch("http://localhost:3000/stream", {
    method: "POST",
    body: JSON.stringify({ inputs: { message } }),
  });

  const reader = response.body.getReader();
  const decoder = new TextDecoder();

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    const chunk = decoder.decode(value);
    console.log(chunk); // Update UI incrementally
  }
}
```

<!-- Trigger Keywords: react integration, react kailash, kailash frontend, react workflows -->
