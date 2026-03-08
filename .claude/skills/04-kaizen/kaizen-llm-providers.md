---
name: kaizen-llm-providers
description: "LLM provider configuration for Kaizen agents. Use when asking about LlmClient, provider setup, OpenAI, Anthropic, Google, Mistral, Cohere, API keys, model names, from_env, or switching providers."
---

# Kaizen LLM Providers

The `LlmClient` sends completion requests to multiple LLM providers with automatic provider detection from the model name, retry logic, and exponential backoff.

## Supported Providers

| Provider  | Model Prefixes              | API Key Env Var                      | Base URL                                           |
| --------- | --------------------------- | ------------------------------------ | -------------------------------------------------- |
| OpenAI    | `gpt-`, `o1-`, `o3-`, `o4-` | `OPENAI_API_KEY`                     | `https://api.openai.com/v1`                        |
| Anthropic | `claude-`                   | `ANTHROPIC_API_KEY`                  | `https://api.anthropic.com/v1`                     |
| Google    | `gemini-`                   | `GOOGLE_API_KEY` or `GEMINI_API_KEY` | `https://generativelanguage.googleapis.com/v1beta` |
| Mistral   | `mistral-`, `mixtral-`      | `MISTRAL_API_KEY`                    | `https://api.mistral.ai/v1`                        |
| Cohere    | `command-`                  | `COHERE_API_KEY`                     | `https://api.cohere.ai/v2`                         |

## .env Setup (Required)

All API keys and model names MUST come from `.env`. Never hardcode them.

```bash
# .env
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
GOOGLE_API_KEY=AIza...
MISTRAL_API_KEY=...
COHERE_API_KEY=...

# Model names
DEFAULT_LLM_MODEL=gpt-5
```

## LlmClient::from_env() (Production)

The preferred way to create a client. Reads all API keys from environment variables. At least one key must be set.

```rust
use kailash_kaizen::llm::client::LlmClient;

dotenvy::dotenv().ok();

let client = LlmClient::from_env()?;
// Reads: OPENAI_API_KEY, ANTHROPIC_API_KEY, GOOGLE_API_KEY/GEMINI_API_KEY,
//        MISTRAL_API_KEY, COHERE_API_KEY
// At least one must be set, otherwise returns LlmClientError::NoKeysConfigured
```

## LlmClient::new() + Builder (Testing)

For tests and custom configurations:

```rust
use std::time::Duration;
use kailash_kaizen::llm::client::LlmClient;
use kailash_kaizen::types::LlmProvider;

let client = LlmClient::new()
    .with_openai_key("sk-...")
    .with_anthropic_key("sk-ant-...")
    .with_google_key("AIza...")
    .with_max_retries(3)              // Default: 3
    .with_timeout(Duration::from_secs(60))  // Default: 60s
    .with_retry_base_delay(Duration::from_secs(1)); // Default: 1s

// Override base URL for testing with wiremock
let client = LlmClient::new()
    .with_openai_key("test-key")
    .with_base_url(LlmProvider::OpenAi, "http://localhost:8080/v1")
    .with_max_retries(0);  // No retries in tests
```

## Making LLM Requests

```rust
use kailash_kaizen::llm::client::LlmClient;
use kailash_kaizen::types::{LlmRequest, LlmResponse, ConversationTurn};

let client = LlmClient::from_env()?;

let request = LlmRequest {
    model: std::env::var("DEFAULT_LLM_MODEL").expect("model in .env"),
    messages: vec![ConversationTurn::user("What is Rust?")],
    system_prompt: Some("You are a helpful assistant.".into()),
    tools: None,        // Optional: Vec<ToolDef> for function calling
    temperature: Some(0.7),
    max_tokens: Some(1000),
};

let response: LlmResponse = client.complete(&request).await?;
println!("Content: {}", response.content);
println!("Finish reason: {:?}", response.finish_reason);
println!("Token usage: {} total", response.usage.total_tokens);

// If the model requested tool calls:
for tool_call in &response.tool_calls {
    println!("Tool: {} ({})", tool_call.tool_name, tool_call.id);
}
```

## Provider Detection

The provider is automatically detected from the model name prefix:

```rust
use kailash_kaizen::types::{detect_provider, LlmProvider};

assert_eq!(detect_provider("gpt-5")?, LlmProvider::OpenAi);
assert_eq!(detect_provider("o3-mini")?, LlmProvider::OpenAi);
assert_eq!(detect_provider("claude-3-opus")?, LlmProvider::Anthropic);
assert_eq!(detect_provider("gemini-1.5-pro")?, LlmProvider::Google);
assert_eq!(detect_provider("mistral-large")?, LlmProvider::Mistral);
assert_eq!(detect_provider("command-r-plus")?, LlmProvider::Cohere);

// Case-insensitive
assert_eq!(detect_provider("GPT-4")?, LlmProvider::OpenAi);

// Unknown prefix returns error
let result = detect_provider("llama-3-70b");
assert!(result.is_err()); // AgentError::UnknownProvider
```

## Switching Providers

Simply change the model name in `.env`. The `LlmClient` routes to the correct provider automatically:

```bash
# .env -- switch by changing this one line
DEFAULT_LLM_MODEL=gpt-5            # Uses OpenAI
# DEFAULT_LLM_MODEL=claude-3-opus   # Uses Anthropic
# DEFAULT_LLM_MODEL=gemini-1.5-pro  # Uses Google
# DEFAULT_LLM_MODEL=mistral-large   # Uses Mistral
```

```rust
// No code changes needed -- provider is detected from model name
let model = std::env::var("DEFAULT_LLM_MODEL")?;
let request = LlmRequest {
    model, // Provider auto-detected
    messages: vec![ConversationTurn::user("Hello")],
    ..Default::default()  // Note: LlmRequest does not impl Default,
                          // fill all fields explicitly
};
```

## Model Resolution with AgentConfig

```rust
use kailash_kaizen::types::{AgentConfig, resolve_model};

// Option 1: Explicit model in config
let config = AgentConfig {
    model: Some("gpt-5".to_string()),
    ..AgentConfig::default()
};
let model = resolve_model(&config)?;
// model == "gpt-5"

// Option 2: Read from env var (default: DEFAULT_LLM_MODEL)
let config = AgentConfig::default();
// Reads std::env::var("DEFAULT_LLM_MODEL")
let model = resolve_model(&config)?;

// Option 3: Custom env var
let config = AgentConfig {
    model_env_var: "ANTHROPIC_PROD_MODEL".to_string(),
    model: None,
    ..AgentConfig::default()
};
let model = resolve_model(&config)?;
```

## API Key Resolution

```rust
use kailash_kaizen::types::{get_api_key, api_key_env_vars, LlmProvider};

// Get the API key for a provider
let key = get_api_key(LlmProvider::OpenAi)?;
// Reads OPENAI_API_KEY

let key = get_api_key(LlmProvider::Google)?;
// Reads GOOGLE_API_KEY, falls back to GEMINI_API_KEY

// List env var names for a provider
let vars = api_key_env_vars(LlmProvider::Google);
// ["GOOGLE_API_KEY", "GEMINI_API_KEY"]
```

## Using LlmClient with Agents

```rust
use std::sync::Arc;
use kailash_kaizen::agent::concrete::Agent;
use kailash_kaizen::llm::client::LlmClient;
use kailash_kaizen::types::AgentConfig;

dotenvy::dotenv().ok();

let config = AgentConfig {
    model: Some(std::env::var("DEFAULT_LLM_MODEL")
        .map_err(|_| kailash_kaizen::error::AgentError::Config(
            "DEFAULT_LLM_MODEL not set".into()
        ))?),
    system_prompt: Some("You are a helpful assistant.".into()),
    ..AgentConfig::default()
};

let llm = LlmClient::from_env()
    .map_err(|e| kailash_kaizen::error::AgentError::Config(e.to_string()))?;

let mut agent = Agent::new(config, llm)?;

// Stateful chat (maintains conversation history)
let response = agent.chat("Hello!").await?;
let followup = agent.chat("Tell me more.").await?;

// Stateless single-shot (via BaseAgent trait, no history mutation)
use kailash_kaizen::agent::BaseAgent;
let result = agent.run("One-off question").await?;
```

## Sharing LlmClient Across Agents

```rust
use std::sync::Arc;
use kailash_kaizen::agent::concrete::Agent;
use kailash_kaizen::llm::client::LlmClient;
use kailash_kaizen::types::AgentConfig;

let shared_llm = Arc::new(LlmClient::from_env()
    .map_err(|e| kailash_kaizen::error::AgentError::Config(e.to_string()))?);

let agent1 = Agent::new(
    AgentConfig {
        model: Some("gpt-5".into()),
        ..AgentConfig::default()
    },
    LlmClient::new(), // placeholder
)?.with_shared_llm(Arc::clone(&shared_llm));

let agent2 = Agent::new(
    AgentConfig {
        model: Some("gpt-5".into()),
        ..AgentConfig::default()
    },
    LlmClient::new(), // placeholder
)?.with_shared_llm(Arc::clone(&shared_llm));

// Both agents share the same HTTP client and API keys
```

## Error Handling

```rust
use kailash_kaizen::llm::client::LlmClientError;
use kailash_kaizen::error::AgentError;

// LlmClientError variants:
// LlmClientError::Http(reqwest::Error)         -- network failure
// LlmClientError::ApiError { provider, status, message }  -- API error response
// LlmClientError::MissingApiKey(provider)       -- no key for provider
// LlmClientError::UnsupportedProvider(model)    -- unknown model prefix
// LlmClientError::Deserialization(msg)          -- response parse failure
// LlmClientError::NoKeysConfigured              -- no API keys at all
// LlmClientError::RetriesExhausted { attempts, last_error }

// All convert to AgentError via From<LlmClientError>
```

## Retry Behavior

The client automatically retries on:

- **429 (Rate Limited)**: Exponential backoff with `retry_base_delay`
- **5xx (Server Error)**: Exponential backoff

Non-retryable errors (400, 401, 403, 404) fail immediately.

```rust
use std::time::Duration;
use kailash_kaizen::llm::client::LlmClient;

let client = LlmClient::new()
    .with_openai_key("sk-...")
    .with_max_retries(5)                          // Up to 5 retries
    .with_retry_base_delay(Duration::from_secs(2)); // 2s, 4s, 8s, 16s, 32s
```

## Testing with wiremock

```rust
use kailash_kaizen::llm::client::LlmClient;
use kailash_kaizen::types::LlmProvider;
use wiremock::{MockServer, Mock, ResponseTemplate, matchers::{method, path}};

let server = MockServer::start().await;

Mock::given(method("POST"))
    .and(path("/chat/completions"))
    .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
        "id": "chatcmpl-test",
        "choices": [{
            "index": 0,
            "message": {"role": "assistant", "content": "Hello!"},
            "finish_reason": "stop"
        }],
        "usage": {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15}
    })))
    .mount(&server)
    .await;

let client = LlmClient::new()
    .with_openai_key("test-key")
    .with_base_url(LlmProvider::OpenAi, &server.uri())
    .with_max_retries(0);
```

<!-- Trigger Keywords: LlmClient, LLM provider, OpenAI, Anthropic, Google, Gemini, Mistral, Cohere, from_env, API key, model name, provider detection, switching providers, streaming -->
