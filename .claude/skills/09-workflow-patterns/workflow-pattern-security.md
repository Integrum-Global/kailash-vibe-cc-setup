---
name: workflow-pattern-security
description: "Security workflow patterns (auth, encryption, audit). Use when asking 'security workflow', 'authentication', 'encryption workflow', or 'audit trail'."
---

# Security Workflow Patterns

Patterns for authentication, authorization, encryption, and audit workflows.

> **Skill Metadata**
> Category: `workflow-patterns`
> Priority: `HIGH`
> SDK Version: `0.9.25+`
> Related Skills: [`gold-security`](../../17-gold-standards/gold-security.md)

## Pattern: User Authentication Flow

```rust
use kailash_core::{WorkflowBuilder, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. Validate credentials
builder.add_node("DatabaseQueryNode", "check_user", ValueMap::from([
    ("query".into(), Value::String(
        "SELECT id, password_hash, role FROM users WHERE email = ?".into()
    )),
    ("parameters".into(), Value::Array(vec![
        Value::String("{{input.email}}".into()),
    ])),
]));

// 2. Verify password
builder.add_node("TransformNode", "verify_password", ValueMap::from([
    ("input".into(), Value::String("{{input.password}}".into())),
    ("stored_hash".into(), Value::String("{{check_user.password_hash}}".into())),
    ("transformation".into(), Value::String("bcrypt_verify(input, stored_hash)".into())),
]));

// 3. Check authorization
builder.add_node("ConditionalNode", "check_auth", ValueMap::from([
    ("condition".into(), Value::String("{{verify_password.match}} == true".into())),
    ("true_branch".into(), Value::String("generate_token".into())),
    ("false_branch".into(), Value::String("audit_failure".into())),
]));

// 4. Generate JWT
builder.add_node("TransformNode", "generate_token", ValueMap::from([
    ("input".into(), Value::Object(ValueMap::from([
        ("user_id".into(), Value::String("{{check_user.id}}".into())),
        ("role".into(), Value::String("{{check_user.role}}".into())),
    ]))),
    ("transformation".into(), Value::String("jwt_encode(input, secret, 'HS256')".into())),
]));

// 5. Audit log
builder.add_node("DatabaseExecuteNode", "audit_success", ValueMap::from([
    ("query".into(), Value::String(
        "INSERT INTO audit_log (user_id, action, timestamp) VALUES (?, 'login', NOW())".into()
    )),
    ("parameters".into(), Value::Array(vec![
        Value::String("{{check_user.id}}".into()),
    ])),
]));

builder.add_node("DatabaseExecuteNode", "audit_failure", ValueMap::from([
    ("query".into(), Value::String(
        "INSERT INTO audit_log (email, action, timestamp) VALUES (?, 'failed_login', NOW())".into()
    )),
    ("parameters".into(), Value::Array(vec![
        Value::String("{{input.email}}".into()),
    ])),
]));

builder.connect("check_user", "password_hash", "verify_password", "stored_hash");
builder.connect("verify_password", "match", "check_auth", "condition");
builder.connect("check_auth", "output_true", "generate_token", "input");
builder.connect("generate_token", "token", "audit_success", "parameters");
builder.connect("check_auth", "output_false", "audit_failure", "trigger");
```

<!-- Trigger Keywords: security workflow, authentication, encryption workflow, audit trail, user auth -->
