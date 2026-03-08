# Configure Alerts Skill

Set up alert and notification nodes for Discord, Slack, email, or PagerDuty.

## Usage

`/configure-alerts <provider>` -- Configure an alert node for the given provider

Examples:

- `/configure-alerts discord`
- `/configure-alerts slack`
- `/configure-alerts email`
- `/configure-alerts pagerduty`

## Steps

1. Read existing alert node patterns from:
   - `crates/kailash-nodes/src/alerts/mod.rs` -- register_alert_nodes, alert node types
   - `crates/kailash-nodes/src/alerts/discord.rs` -- DiscordAlertNode
   - `crates/kailash-nodes/src/alerts/slack.rs` -- SlackAlertNode
   - `crates/kailash-nodes/src/alerts/email.rs` -- EmailAlertNode
   - `crates/kailash-nodes/src/alerts/pagerduty.rs` -- PagerDutyAlertNode

2. Ensure the required environment variables are set in `.env` (see Environment Variables table below).

3. Create or modify the workflow to include the appropriate alert node with the correct configuration.

4. Test the notification by running the workflow with a sample alert payload.

## Environment Variables

Each provider requires specific environment variables in `.env`:

| Provider    | Required Variables                                                      |
| ----------- | ----------------------------------------------------------------------- |
| `discord`   | `DISCORD_WEBHOOK_URL`                                                   |
| `slack`     | `SLACK_WEBHOOK_URL`                                                     |
| `email`     | `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_FROM` |
| `pagerduty` | `PAGERDUTY_ROUTING_KEY`                                                 |

## Template

### Discord Alert

```rust
use std::sync::Arc;
use kailash_core::node::NodeRegistry;
use kailash_core::runtime::{Runtime, RuntimeConfig};
use kailash_core::WorkflowBuilder;
use kailash_nodes::alerts::register_alert_nodes;
use kailash_value::{Value, ValueMap};

fn main() {
    dotenvy::dotenv().ok();

    let mut registry = NodeRegistry::new();
    register_alert_nodes(&mut registry);
    let registry = Arc::new(registry);

    // Read webhook URL from .env -- NEVER hardcode
    let webhook_url = std::env::var("DISCORD_WEBHOOK_URL")
        .expect("DISCORD_WEBHOOK_URL must be set in .env");

    let mut builder = WorkflowBuilder::new();
    builder.add_node("DiscordAlertNode", "alert", {
        let mut config = ValueMap::new();
        config.insert(Arc::from("webhook_url"), Value::String(Arc::from(webhook_url.as_str())));
        config
    });

    let workflow = builder.build(&registry).expect("workflow should build");
    let runtime = Runtime::new(RuntimeConfig::default(), registry);

    let mut inputs = ValueMap::new();
    inputs.insert(Arc::from("title"), Value::String(Arc::from("Deployment Alert")));
    inputs.insert(Arc::from("message"), Value::String(Arc::from("Service v2.1.0 deployed successfully")));
    inputs.insert(Arc::from("severity"), Value::String(Arc::from("info")));

    let result = runtime.execute_sync(&workflow, inputs).expect("execution should succeed");
    println!("Alert sent: {:?}", result.run_id);
}
```

### Slack Alert

```rust
use std::sync::Arc;
use kailash_core::node::NodeRegistry;
use kailash_core::runtime::{Runtime, RuntimeConfig};
use kailash_core::WorkflowBuilder;
use kailash_nodes::alerts::register_alert_nodes;
use kailash_value::{Value, ValueMap};

fn main() {
    dotenvy::dotenv().ok();

    let webhook_url = std::env::var("SLACK_WEBHOOK_URL")
        .expect("SLACK_WEBHOOK_URL must be set in .env");

    let mut registry = NodeRegistry::new();
    register_alert_nodes(&mut registry);
    let registry = Arc::new(registry);

    let mut builder = WorkflowBuilder::new();
    builder.add_node("SlackAlertNode", "alert", {
        let mut config = ValueMap::new();
        config.insert(Arc::from("webhook_url"), Value::String(Arc::from(webhook_url.as_str())));
        config.insert(Arc::from("channel"), Value::String(Arc::from("#alerts")));
        config
    });

    let workflow = builder.build(&registry).expect("workflow should build");
    let runtime = Runtime::new(RuntimeConfig::default(), registry);

    let mut inputs = ValueMap::new();
    inputs.insert(Arc::from("title"), Value::String(Arc::from("Build Failed")));
    inputs.insert(Arc::from("message"), Value::String(Arc::from("CI pipeline failed on main branch")));
    inputs.insert(Arc::from("severity"), Value::String(Arc::from("error")));

    let result = runtime.execute_sync(&workflow, inputs).expect("execution should succeed");
    println!("Alert sent: {:?}", result.run_id);
}
```

### Email Alert

```rust
use std::sync::Arc;
use kailash_core::node::NodeRegistry;
use kailash_core::runtime::{Runtime, RuntimeConfig};
use kailash_core::WorkflowBuilder;
use kailash_nodes::alerts::register_alert_nodes;
use kailash_value::{Value, ValueMap};

fn main() {
    dotenvy::dotenv().ok();

    let smtp_host = std::env::var("SMTP_HOST").expect("SMTP_HOST must be set in .env");
    let smtp_port = std::env::var("SMTP_PORT").expect("SMTP_PORT must be set in .env");
    let smtp_username = std::env::var("SMTP_USERNAME").expect("SMTP_USERNAME must be set in .env");
    let smtp_password = std::env::var("SMTP_PASSWORD").expect("SMTP_PASSWORD must be set in .env");
    let smtp_from = std::env::var("SMTP_FROM").expect("SMTP_FROM must be set in .env");

    let mut registry = NodeRegistry::new();
    register_alert_nodes(&mut registry);
    let registry = Arc::new(registry);

    let mut builder = WorkflowBuilder::new();
    builder.add_node("EmailAlertNode", "alert", {
        let mut config = ValueMap::new();
        config.insert(Arc::from("smtp_host"), Value::String(Arc::from(smtp_host.as_str())));
        config.insert(Arc::from("smtp_port"), Value::String(Arc::from(smtp_port.as_str())));
        config.insert(Arc::from("smtp_username"), Value::String(Arc::from(smtp_username.as_str())));
        config.insert(Arc::from("smtp_password"), Value::String(Arc::from(smtp_password.as_str())));
        config.insert(Arc::from("from"), Value::String(Arc::from(smtp_from.as_str())));
        config
    });

    let workflow = builder.build(&registry).expect("workflow should build");
    let runtime = Runtime::new(RuntimeConfig::default(), registry);

    let mut inputs = ValueMap::new();
    inputs.insert(Arc::from("to"), Value::String(Arc::from("ops@example.com")));
    inputs.insert(Arc::from("subject"), Value::String(Arc::from("Critical: Database CPU > 90%")));
    inputs.insert(Arc::from("message"), Value::String(Arc::from("Database server db-prod-01 CPU usage exceeded 90% threshold.")));
    inputs.insert(Arc::from("severity"), Value::String(Arc::from("critical")));

    let result = runtime.execute_sync(&workflow, inputs).expect("execution should succeed");
    println!("Email alert sent: {:?}", result.run_id);
}
```

### PagerDuty Alert

```rust
use std::sync::Arc;
use kailash_core::node::NodeRegistry;
use kailash_core::runtime::{Runtime, RuntimeConfig};
use kailash_core::WorkflowBuilder;
use kailash_nodes::alerts::register_alert_nodes;
use kailash_value::{Value, ValueMap};

fn main() {
    dotenvy::dotenv().ok();

    let routing_key = std::env::var("PAGERDUTY_ROUTING_KEY")
        .expect("PAGERDUTY_ROUTING_KEY must be set in .env");

    let mut registry = NodeRegistry::new();
    register_alert_nodes(&mut registry);
    let registry = Arc::new(registry);

    let mut builder = WorkflowBuilder::new();
    builder.add_node("PagerDutyAlertNode", "alert", {
        let mut config = ValueMap::new();
        config.insert(Arc::from("routing_key"), Value::String(Arc::from(routing_key.as_str())));
        config
    });

    let workflow = builder.build(&registry).expect("workflow should build");
    let runtime = Runtime::new(RuntimeConfig::default(), registry);

    let mut inputs = ValueMap::new();
    inputs.insert(Arc::from("title"), Value::String(Arc::from("Production Outage")));
    inputs.insert(Arc::from("message"), Value::String(Arc::from("API gateway returning 503 for all requests")));
    inputs.insert(Arc::from("severity"), Value::String(Arc::from("critical")));
    inputs.insert(Arc::from("source"), Value::String(Arc::from("api-gateway-prod")));

    let result = runtime.execute_sync(&workflow, inputs).expect("execution should succeed");
    println!("PagerDuty incident created: {:?}", result.run_id);
}
```

## Verify

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo test -p kailash-nodes -- alerts && cargo clippy -p kailash-nodes -- -D warnings
```
