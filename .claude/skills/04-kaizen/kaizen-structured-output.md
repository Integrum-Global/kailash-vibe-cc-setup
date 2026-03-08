---
name: kaizen-structured-output
description: "Structured output parsing with schema validation and retry. Use when asking 'structured output', 'LLM JSON output', 'OutputSchema', 'StructuredOutput', 'parse LLM response', 'JSON validation', 'output schema', 'retry parsing'."
---

# Kaizen Structured Output

`StructuredOutput` orchestrates the full lifecycle of extracting validated JSON from LLM responses: parse raw text to extract JSON, validate against a schema, and on failure generate a correction prompt and retry via an LLM callback.

## Architecture

```
Raw LLM text
  |
  v
StructuredOutputParser::parse()
  |-- Extracts JSON (raw, code fences, embedded)
  |-- Validates against OutputSchema
  |
  +-- Success -> Return validated serde_json::Value
  +-- Failure -> Build correction prompt
                  |
                  v
              llm_retry_fn(correction_prompt)
                  |
                  v
              Re-parse (up to max_retries times)
```

## Rust API

### OutputSchema

Source: `crates/kailash-kaizen/src/output/schema.rs`

Wraps a JSON Schema and validates data against it. Supports `type`, `properties`, `required`, nested objects, and array item validation.

```rust
use kailash_kaizen::output::OutputSchema;
use serde_json::json;

// From a serde_json::Value
let schema = OutputSchema::from_value(json!({
    "type": "object",
    "properties": {
        "name": {"type": "string"},
        "age": {"type": "integer"},
    },
    "required": ["name"]
}));

// From a JSON string
let schema = OutputSchema::from_json(r#"{"type": "object", "properties": {"name": {"type": "string"}}}"#)?;

// Validate data
assert!(schema.validate(&json!({"name": "Alice"})).is_ok());
assert!(schema.validate(&json!({"name": 42})).is_err());     // wrong type
assert!(schema.validate(&json!({})).is_err());                // missing required field
```

### StructuredOutput

Source: `crates/kailash-kaizen/src/output/structured.rs`

Coordinates parsing with automatic retry:

```rust
use kailash_kaizen::output::{OutputSchema, RetryConfig, StructuredOutput};
use serde_json::json;

let schema = OutputSchema::from_value(json!({
    "type": "object",
    "properties": { "answer": {"type": "string"} },
    "required": ["answer"]
}));

let so = StructuredOutput::new(schema)
    .with_retries(RetryConfig::new(2));  // max 2 retries

// Process raw LLM text -- first attempt
let result = so.process(
    r#"{"answer": "42"}"#,
    |_correction_prompt| Box::pin(async { Ok("ignored".to_string()) }),
).await?;
assert_eq!(result["answer"], "42");
```

The `process` method:
1. Attempts to parse and validate `raw` against the schema
2. On failure, generates a correction prompt and calls `llm_retry_fn`
3. Repeats up to `max_retries` times
4. Returns `Err(AgentError::Serialization)` if all retries exhausted

### RetryConfig

```rust
use kailash_kaizen::output::RetryConfig;

let config = RetryConfig::new(3);  // max 3 retries (default)

// Custom correction prompt template
let config = config.with_template(
    "Fix: {errors}\nExpected schema: {schema}"
);

assert_eq!(config.max_retries(), 3);
```

### Extracting JSON from LLM Text

`StructuredOutputParser::parse` handles multiple formats:

```rust
use kailash_kaizen::output::StructuredOutputParser;

// Raw JSON
StructuredOutputParser::parse(r#"{"name": "Alice"}"#, &schema)?;

// Code fence wrapped
StructuredOutputParser::parse("```json\n{\"name\": \"Alice\"}\n```", &schema)?;

// JSON embedded in prose
StructuredOutputParser::parse("Here is the result:\n{\"name\": \"Alice\"}\nDone.", &schema)?;
```

## Python API

Source: `bindings/kailash-python/src/kaizen/output.rs`

### OutputSchema

```python
from kailash import OutputSchema

# From a dict
schema = OutputSchema({
    "type": "object",
    "properties": {"name": {"type": "string"}},
    "required": ["name"],
})

# From a JSON string
schema = OutputSchema.from_json('{"type": "object", "properties": {"name": {"type": "string"}}}')

# Validate (returns True or raises ValueError)
schema.validate({"name": "Alice"})  # True
schema.validate({"name": 42})       # raises ValueError

# Get schema as dict
d = schema.to_dict()
```

### StructuredOutput

Constructor takes a schema (dict or OutputSchema) and optional `max_retries`:

```python
from kailash import StructuredOutput, OutputSchema

# From a dict (auto-wrapped in OutputSchema)
so = StructuredOutput(
    {"type": "object", "properties": {"name": {"type": "string"}}, "required": ["name"]},
    max_retries=3,  # default: 3
)

# From an OutputSchema instance
schema = OutputSchema({"type": "object", "required": ["name"]})
so = StructuredOutput(schema, max_retries=2)

# Parse raw LLM text (no retry, just extract + validate)
result = so.parse('{"name": "Alice"}')
assert result == {"name": "Alice"}

# Also handles code fences
result = so.parse('```json\n{"name": "Bob"}\n```')
assert result == {"name": "Bob"}
```

### Parse with Retry

Uses an `LlmClient` to re-prompt on failure:

```python
from kailash import StructuredOutput, LlmClient

client = LlmClient(provider="mock")
so = StructuredOutput({"type": "object", "required": ["answer"]}, max_retries=2)

# parse_with_retry calls the LLM again on parse/validation failure
result = so.parse_with_retry(
    '{"answer": "42"}',
    llm_client=client,
    model="mock-model",
)
```

### RetryConfig

```python
from kailash import RetryConfig

config = RetryConfig(max_retries=5)
config = RetryConfig(max_retries=2, template="Fix: {errors}. Schema: {schema}")

print(config.max_retries)  # 5
print(config.template)     # the template string
```

The template must contain both `{errors}` and `{schema}` placeholders.

## Common Patterns

### Extracting Structured Data from LLM

```python
from kailash import StructuredOutput

so = StructuredOutput({
    "type": "object",
    "properties": {
        "sentiment": {"type": "string"},
        "confidence": {"type": "number"},
        "keywords": {
            "type": "array",
            "items": {"type": "string"},
        },
    },
    "required": ["sentiment", "confidence"],
})

llm_response = '''Here is my analysis:
```json
{"sentiment": "positive", "confidence": 0.95, "keywords": ["great", "love"]}
```
'''

result = so.parse(llm_response)
assert result["sentiment"] == "positive"
```

### Nested Schema Validation

```python
schema = OutputSchema({
    "type": "object",
    "properties": {
        "address": {
            "type": "object",
            "properties": {
                "city": {"type": "string"},
                "zip": {"type": "string"},
            },
            "required": ["city"],
        },
    },
    "required": ["address"],
})

schema.validate({"address": {"city": "NYC", "zip": "10001"}})  # OK
schema.validate({"address": {}})  # raises ValueError: missing "city"
```

## Source Files

- `crates/kailash-kaizen/src/output/schema.rs` -- `OutputSchema`, `ValidationError`
- `crates/kailash-kaizen/src/output/structured.rs` -- `StructuredOutput`
- `crates/kailash-kaizen/src/output/parser.rs` -- `StructuredOutputParser`, `ParseError`
- `crates/kailash-kaizen/src/output/retry.rs` -- `RetryConfig`
- `bindings/kailash-python/src/kaizen/output.rs` -- `PyOutputSchema`, `PyRetryConfig`, `PyStructuredOutput`

<!-- Trigger Keywords: structured output, StructuredOutput, OutputSchema, LLM JSON, parse LLM response, JSON validation, output schema, retry parsing, RetryConfig, StructuredOutputParser, code fence extraction -->
