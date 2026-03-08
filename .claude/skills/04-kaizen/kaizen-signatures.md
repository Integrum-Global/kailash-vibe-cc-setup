---
name: kaizen-structured-output
description: "Structured output parsing and validation for Kaizen agents. Use when asking about StructuredOutput, OutputSchema, StructuredOutputParser, RetryConfig, JSON extraction from LLM responses, or output validation."
---

# Kaizen Structured Output: Parse-Validate-Retry Pipeline

The output module extracts JSON from free-text LLM responses, validates it against a schema, and optionally retries with correction prompts.

1. **`OutputSchema`** -- JSON Schema definition and validation
2. **`StructuredOutputParser`** -- JSON extraction from raw LLM text (3 strategies)
3. **`RetryConfig`** -- Retry parameters and correction prompt templates
4. **`StructuredOutput`** -- Coordinator that orchestrates the full pipeline

## OutputSchema

Wraps a `serde_json::Value` representing a JSON Schema. Supports type checking, required properties, nested objects, and array item validation.

```rust
use kailash_kaizen::output::OutputSchema;
use serde_json::json;

// From a serde_json::Value
let schema = OutputSchema::from_value(json!({
    "type": "object",
    "properties": {
        "name": {"type": "string"},
        "age": {"type": "integer"},
        "address": {
            "type": "object",
            "properties": {
                "city": {"type": "string"}
            },
            "required": ["city"]
        }
    },
    "required": ["name", "age"]
}));

// From a JSON string
let schema = OutputSchema::from_json(r#"{"type": "object"}"#)?;

// Access the raw schema
let raw: &serde_json::Value = schema.schema();

// Validate data against the schema
let valid = json!({"name": "Alice", "age": 30});
assert!(schema.validate(&valid).is_ok());

let invalid = json!({"name": 42});  // wrong type + missing "age"
let errors = schema.validate(&invalid).unwrap_err();
// errors: Vec<ValidationError> with { path, message } fields
for err in &errors {
    println!("{}: {}", err.path, err.message);
}
```

### ValidationError

```rust
pub struct ValidationError {
    pub path: String,     // JSONPath-like: ".name", ".address.city", "[1]"
    pub message: String,  // Human-readable: "expected type \"string\", got \"integer\""
}
```

### Supported Validation

- **Type checking**: `"string"`, `"integer"`, `"number"`, `"boolean"`, `"array"`, `"object"`, `"null"`
- **Required fields**: `"required": ["name", "age"]`
- **Nested objects**: Recursive property validation
- **Array items**: `"items": {"type": "string"}` validates each element
- **Extra fields**: Allowed by default (no `additionalProperties` enforcement)

## StructuredOutputParser

Stateless parser that extracts JSON from raw LLM text using three strategies in order:

1. **Raw JSON** -- parse entire text as JSON
2. **Code fence** -- extract from ` ```json ... ``` ` or ` ``` ... ``` `
3. **Embedded JSON** -- find first `{` or `[` and match brackets

````rust
use kailash_kaizen::output::{OutputSchema, StructuredOutputParser};
use serde_json::json;

let schema = OutputSchema::from_value(json!({
    "type": "object",
    "properties": { "name": {"type": "string"} },
    "required": ["name"]
}));

// Strategy 1: Raw JSON
let raw = r#"{"name": "Alice"}"#;
let value = StructuredOutputParser::parse(raw, &schema)?;
assert_eq!(value["name"], "Alice");

// Strategy 2: Code fence
let raw = "Here is the result:\n```json\n{\"name\": \"Bob\"}\n```\nDone.";
let value = StructuredOutputParser::parse(raw, &schema)?;

// Strategy 3: Embedded JSON
let raw = "The answer is: {\"name\": \"Carol\"} as requested.";
let value = StructuredOutputParser::parse(raw, &schema)?;
````

### ParseError

```rust
pub enum ParseError {
    ExtractionFailed { raw_text: String },           // No JSON found
    ValidationFailed { extracted: Value, errors: Vec<ValidationError> }, // JSON found but invalid
}
```

## RetryConfig

Controls how many retries are allowed and the correction prompt template.

```rust
use kailash_kaizen::output::RetryConfig;

// Default: 3 retries with built-in correction template
let config = RetryConfig::default();
assert_eq!(config.max_retries(), 3);

// Custom retry count
let config = RetryConfig::new(5);

// Custom template (MUST contain {errors} and {schema} placeholders)
let config = RetryConfig::new(2)
    .with_template("Fix these errors: {errors}\nSchema: {schema}");

// Build a correction prompt from actual errors
let prompt = config.build_correction_prompt(
    &["missing required field \"name\"".to_string()],
    r#"{"type": "object", "required": ["name"]}"#,
);
// prompt contains the error details and schema for re-prompting the LLM

// Access template
let template: &str = config.template();
```

The default template instructs the LLM to respond with ONLY valid JSON matching the schema, including the error details and expected schema.

## StructuredOutput

Coordinator that orchestrates the full parse-validate-retry pipeline. On first parse failure, it generates a correction prompt and calls an LLM retry function up to `max_retries` times.

```rust
use kailash_kaizen::output::{OutputSchema, RetryConfig, StructuredOutput};
use serde_json::json;

let schema = OutputSchema::from_value(json!({
    "type": "object",
    "properties": { "answer": {"type": "string"} },
    "required": ["answer"]
}));

let so = StructuredOutput::new(schema)
    .with_retries(RetryConfig::new(2));

// Accessors
let _schema: &OutputSchema = so.schema();
let _retry: &RetryConfig = so.retry_config();

// Process with retry -- the closure calls the LLM with the correction prompt
let result = so.process(
    r#"{"answer": "42"}"#,
    |correction_prompt| Box::pin(async move {
        // In practice: call llm.complete() with the correction prompt
        Ok(r#"{"answer": "fixed"}"#.to_string())
    }),
).await?;
assert_eq!(result["answer"], "42");  // Succeeds on first attempt, no retry needed
```

### Pipeline Flow

```
Raw LLM text
  -> StructuredOutputParser::parse(raw, schema)
  -> Ok(value)?  Return value
  -> Err(parse_error)?
       -> RetryConfig::build_correction_prompt(errors, schema)
       -> llm_retry_fn(correction_prompt).await?
       -> StructuredOutputParser::parse(retry_response, schema)
       -> Repeat up to max_retries times
       -> All retries exhausted? AgentError::Serialization
```

### Error Handling

- First-attempt failure with `max_retries == 0`: returns `AgentError::Serialization` immediately
- All retries exhausted: returns `AgentError::Serialization` with validation details
- LLM retry function error: propagated directly as the returned error

## Python Binding

````python
from kailash import OutputSchema, RetryConfig, StructuredOutput

# OutputSchema -- constructor takes a dict
schema = OutputSchema({
    "type": "object",
    "properties": {"name": {"type": "string"}},
    "required": ["name"]
})

# From JSON string
schema = OutputSchema.from_json('{"type": "object"}')

# Validate -- returns True or raises ValueError
schema.validate({"name": "Alice"})  # True
# schema.validate({"name": 42})     # raises ValueError with details

# Access raw schema as dict
raw = schema.to_dict()

# RetryConfig
config = RetryConfig(max_retries=5)
config = RetryConfig(max_retries=2, template="Fix: {errors}. Schema: {schema}")
print(config.max_retries)   # property
print(config.template)      # property

# StructuredOutput -- schema can be OutputSchema or a dict
so = StructuredOutput({"type": "object", "required": ["name"]}, max_retries=3)
so = StructuredOutput(schema, max_retries=2)

# Parse without retry -- extracts and validates JSON
result = so.parse('{"name": "Alice"}')
assert result == {"name": "Alice"}

# Parse with code fences
result = so.parse('```json\n{"name": "Bob"}\n```')

# Parse with retry via LLM client
from kailash import LlmClient
client = LlmClient.mock(responses=["corrected response"])
result = so.parse_with_retry('bad input', client, model="gpt-4o")

# Property
print(so.max_retries)  # int
````

## Source Files

- `crates/kailash-kaizen/src/output/schema.rs` -- `OutputSchema`, `ValidationError`
- `crates/kailash-kaizen/src/output/parser.rs` -- `StructuredOutputParser`, `ParseError`
- `crates/kailash-kaizen/src/output/retry.rs` -- `RetryConfig`
- `crates/kailash-kaizen/src/output/structured.rs` -- `StructuredOutput`
- `bindings/kailash-python/src/kaizen/output.rs` -- Python bindings

<!-- Trigger Keywords: structured output, OutputSchema, StructuredOutputParser, RetryConfig, StructuredOutput, JSON extraction, output validation, parse LLM output, correction prompt, schema validation -->
