# Value Type Guide Skill

Working with the Kailash `Value` enum -- the universal data type for all workflow data.

## Usage

`/value-type-guide` -- Quick reference for the Value enum, ValueMap, and common patterns

## The Value Enum

```rust
use std::sync::Arc;
use std::collections::BTreeMap;
use bytes::Bytes;

pub enum Value {
    Null,
    Bool(bool),
    Integer(i64),
    Float(f64),
    String(Arc<str>),              // Zero-cost cloning via reference counting
    Bytes(Bytes),                  // Binary data without allocation overhead
    Array(Vec<Value>),
    Object(BTreeMap<Arc<str>, Value>),  // Deterministic iteration order
}

pub type ValueMap = BTreeMap<Arc<str>, Value>;
```

## Creating Values

```rust
use kailash_value::{Value, ValueMap};
use std::sync::Arc;

// Primitives
let null = Value::Null;
let yes = Value::Bool(true);
let count = Value::Integer(42);
let pi = Value::Float(3.14159);
let msg = Value::String(Arc::from("hello world"));

// From conversions (auto-into Value)
let v: Value = 42i64.into();
let v: Value = 3.14f64.into();
let v: Value = true.into();
let v: Value = "hello".into();            // &str -> Value::String(Arc<str>)
let v: Value = "world".to_string().into(); // String -> Value::String(Arc<str>)

// Arrays
let arr = Value::Array(vec![
    Value::Integer(1),
    Value::Integer(2),
    Value::Integer(3),
]);

// Objects (BTreeMap for deterministic order)
let mut map = BTreeMap::new();
map.insert(Arc::from("name"), Value::String(Arc::from("Alice")));
map.insert(Arc::from("age"), Value::Integer(30));
let obj = Value::Object(map);

// Binary data
let bytes = Value::Bytes(bytes::Bytes::from(vec![0u8, 1, 2, 3]));
```

## ValueMap (Node Inputs/Outputs)

```rust
use kailash_value::{Value, ValueMap};
use std::sync::Arc;

// Building a ValueMap for node configuration
let mut config = ValueMap::new();
config.insert(Arc::from("operation"), Value::String(Arc::from("uppercase")));
config.insert(Arc::from("max_length"), Value::Integer(100));
config.insert(Arc::from("enabled"), Value::Bool(true));

// Insert via Arc<str> key
let key: Arc<str> = Arc::from("custom_field");
config.insert(key, Value::Float(1.5));

// Lookup (key must be &Arc<str> or comparable)
let op = config.get("operation" as &str);  // Note: coerce &str to &str for lookup
// OR:
let key = Arc::from("operation");
let op = config.get(&key);
```

## Accessing Values

```rust
let v = Value::String(Arc::from("hello"));

// Type accessors -- return Option<T>
let s: Option<&str> = v.as_str();          // "hello"
let i: Option<i64>  = v.as_i64();          // None (wrong type)
let f: Option<f64>  = v.as_f64();          // None
let b: Option<bool> = v.as_bool();         // None

// Check type
let is_null   = v.is_null();
let is_string = v.is_string();
let is_number = v.is_number();  // Integer OR Float
let is_array  = v.is_array();
let is_object = v.is_object();

// Get array items
if let Value::Array(items) = &v {
    for item in items {
        println!("{:?}", item);
    }
}

// Get object fields
if let Value::Object(map) = &v {
    for (key, val) in map {
        println!("{}: {:?}", key, val);
    }
}
```

## serde_json Interop

```rust
use kailash_value::Value;
use serde_json;

// From serde_json::Value
let json: serde_json::Value = serde_json::json!({
    "name": "Alice",
    "age": 30,
    "active": true
});
let kailash_val: Value = json.into();  // From<serde_json::Value>

// To serde_json::Value
let json_back: serde_json::Value = kailash_val.into();  // Into<serde_json::Value>

// Serialize/Deserialize
let serialized = serde_json::to_string(&Value::Integer(42)).unwrap();
let deserialized: Value = serde_json::from_str("42").unwrap();
```

## Common Patterns in Node Implementation

```rust
// Extracting inputs in a node's execute() method
fn execute(&self, inputs: ValueMap, _ctx: &ExecutionContext)
    -> Pin<Box<dyn Future<Output = Result<ValueMap, NodeError>> + Send + '_>>
{
    Box::pin(async move {
        // Required string input
        let text = inputs.get("text" as &str)
            .and_then(|v| v.as_str())
            .ok_or_else(|| NodeError::MissingInput { name: "text".into() })?
            .to_string();

        // Optional integer input with default
        let max_length = inputs.get("max_length" as &str)
            .and_then(|v| v.as_i64())
            .unwrap_or(256) as usize;

        // Optional boolean with default
        let enabled = inputs.get("enabled" as &str)
            .and_then(|v| v.as_bool())
            .unwrap_or(true);

        // Build output ValueMap
        let mut output = ValueMap::new();
        output.insert(Arc::from("result"), Value::String(Arc::from(text.as_str())));
        output.insert(Arc::from("length"), Value::Integer(text.len() as i64));
        Ok(output)
    })
}
```

## Arc<str> -- Why It Matters

```rust
// Arc<str> enables zero-cost cloning of string keys
let key: Arc<str> = Arc::from("expensive_string_key");

// Cloning is O(1) -- just increments a reference count
let key2 = key.clone();  // No allocation, no memcpy

// BTreeMap uses Arc<str> keys for deterministic ordering AND zero-cost cloning
let mut map: BTreeMap<Arc<str>, Value> = BTreeMap::new();
map.insert(Arc::from("z"), Value::Null);
map.insert(Arc::from("a"), Value::Null);
map.insert(Arc::from("m"), Value::Null);
// Iteration order: "a", "m", "z" (alphabetical, always deterministic)
```

## Display and Debug

```rust
let v = Value::Object({
    let mut m = BTreeMap::new();
    m.insert(Arc::from("name"), Value::String(Arc::from("Alice")));
    m.insert(Arc::from("score"), Value::Float(9.5));
    m
});

println!("{}", v);   // Display: {"name": "Alice", "score": 9.5}
println!("{:?}", v); // Debug: Object({"name": String("Alice"), "score": Float(9.5)})
```

## Verify

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo test -p kailash-value -- --nocapture 2>&1
```
