---
name: flutter-integration-quick
description: "Flutter + Kailash integration. Use when asking 'flutter integration', 'flutter kailash', or 'mobile kailash'."
---

# Flutter + Kailash Integration

> **Skill Metadata**
> Category: `frontend`
> Priority: `LOW`
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

### 2. Flutter Frontend

```dart
// lib/services/workflow_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class WorkflowService {
  static const String baseUrl = 'http://localhost:3000';

  Future<Map<String, dynamic>> executeWorkflow(String message) async {
    final response = await http.post(
      Uri.parse('$baseUrl/execute'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'inputs': {'message': message}}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to execute workflow');
    }
  }
}

// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import '../services/workflow_service.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _service = WorkflowService();
  String _response = '';

  void _sendMessage() async {
    final result = await _service.executeWorkflow(_controller.text);
    setState(() {
      _response = result['outputs']['chat']['response'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(hintText: 'Ask a question...'),
          ),
          ElevatedButton(
            onPressed: _sendMessage,
            child: Text('Send'),
          ),
          if (_response.isNotEmpty) Text(_response),
        ],
      ),
    );
  }
}
```

<!-- Trigger Keywords: flutter integration, flutter kailash, mobile kailash, flutter workflows -->
