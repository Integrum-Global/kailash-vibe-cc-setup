---
name: workflow-pattern-project-mgmt
description: "Project management workflow patterns (tasks, approvals, notifications). Use when asking 'project workflow', 'task automation', or 'approval workflow'."
---

# Project Management Workflow Patterns

> **Skill Metadata**
> Category: `workflow-patterns`
> Priority: `MEDIUM`
> SDK Version: `0.9.25+`

## Pattern: Task Approval Workflow

```rust
use kailash_core::{WorkflowBuilder, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. Create task
builder.add_node("DatabaseExecuteNode", "create_task", ValueMap::from([
    ("query".into(), Value::String(
        "INSERT INTO tasks (title, description, status) VALUES (?, ?, 'pending')".into()
    )),
    ("parameters".into(), Value::Array(vec![
        Value::String("{{input.title}}".into()),
        Value::String("{{input.description}}".into()),
    ])),
]));

// 2. Notify approver
builder.add_node("HTTPRequestNode", "notify_approver", ValueMap::from([
    ("url".into(), Value::String("https://api.slack.com/messages".into())),
    ("method".into(), Value::String("POST".into())),
    ("body".into(), Value::Object(ValueMap::from([
        ("text".into(), Value::String("New task needs approval: {{input.title}}".into())),
    ]))),
]));

// 3. Wait for approval
builder.add_node("WaitForEventNode", "wait_approval", ValueMap::from([
    ("event_type".into(), Value::String("task_approved".into())),
    ("timeout".into(), Value::Integer(86400)), // 24 hours
]));

// 4. Update status
builder.add_node("DatabaseExecuteNode", "update_status", ValueMap::from([
    ("query".into(), Value::String(
        "UPDATE tasks SET status = 'approved' WHERE id = ?".into()
    )),
    ("parameters".into(), Value::Array(vec![
        Value::String("{{create_task.task_id}}".into()),
    ])),
]));

builder.connect("create_task", "task_id", "notify_approver", "task_id");
builder.connect("notify_approver", "result", "wait_approval", "trigger");
builder.connect("wait_approval", "event_data", "update_status", "parameters");
```

<!-- Trigger Keywords: project workflow, task automation, approval workflow, project management -->
