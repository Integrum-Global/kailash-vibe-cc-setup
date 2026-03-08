---
name: workflow-industry-healthcare
description: "Healthcare workflows (patient data, HIPAA, medical records). Use when asking 'healthcare workflow', 'patient workflow', 'HIPAA', or 'medical records'."
---

# Healthcare Industry Workflows

> **Skill Metadata**
> Category: `industry-workflows`
> Priority: `MEDIUM`
> SDK Version: `0.9.25+`

## Pattern: Patient Record Management (HIPAA Compliant)

```rust
use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. Authenticate user
builder.add_node("HTTPRequestNode", "authenticate", ValueMap::from([
    ("url".into(), Value::String(
        std::env::var("AUTH_ENDPOINT").expect("AUTH_ENDPOINT in .env").into()
    )),
    ("method".into(), Value::String("POST".into())),
]));

// 2. Check HIPAA authorization
builder.add_node("DatabaseQueryNode", "check_access", ValueMap::from([
    ("query".into(), Value::String(
        "SELECT role FROM healthcare_staff WHERE id = ? AND hipaa_certified = TRUE".into()
    )),
    ("parameters".into(), Value::Array(vec![
        Value::String("{{authenticate.user_id}}".into()),
    ])),
]));

// 3. Fetch patient record (encrypted)
builder.add_node("DatabaseQueryNode", "fetch_record", ValueMap::from([
    ("query".into(), Value::String(
        "SELECT encrypted_data FROM patient_records WHERE patient_id = ?".into()
    )),
    ("parameters".into(), Value::Array(vec![
        Value::String("{{input.patient_id}}".into()),
    ])),
]));

// 4. Decrypt data
builder.add_node("TransformNode", "decrypt", ValueMap::from([
    ("input".into(), Value::String("{{fetch_record.encrypted_data}}".into())),
    ("transformation".into(), Value::String("aes_decrypt(value, secret_key)".into())),
]));

// 5. Audit log
builder.add_node("DatabaseExecuteNode", "audit", ValueMap::from([
    ("query".into(), Value::String(
        "INSERT INTO hipaa_audit_log (staff_id, patient_id, action, timestamp) \
         VALUES (?, ?, 'record_access', NOW())".into()
    )),
    ("parameters".into(), Value::Array(vec![
        Value::String("{{authenticate.user_id}}".into()),
        Value::String("{{input.patient_id}}".into()),
    ])),
]));

builder.connect("authenticate", "user_id", "check_access", "parameters");
builder.connect("check_access", "role", "fetch_record", "authorization");
builder.connect("fetch_record", "encrypted_data", "decrypt", "input");
builder.connect("decrypt", "data", "audit", "parameters");

let workflow = builder.build(&registry)?;
let runtime = Runtime::new(RuntimeConfig::default(), registry);
let result = runtime.execute(&workflow, ValueMap::new()).await?;
```

<!-- Trigger Keywords: healthcare workflow, patient workflow, HIPAA, medical records, patient data -->
