---
name: workflow-pattern-rag
description: "RAG (Retrieval Augmented Generation) workflow patterns. Use when asking 'RAG', 'retrieval augmented', 'vector search', 'semantic search', or 'document Q&A'."
---

# RAG Workflow Patterns

Retrieval Augmented Generation patterns for AI-powered document search and Q&A.

> **Skill Metadata**
> Category: `workflow-patterns`
> Priority: `HIGH`
> SDK Version: `0.9.25+`
> Related Skills: [`nodes-ai-reference`](../nodes/nodes-ai-reference.md), [`workflow-pattern-ai-document`](workflow-pattern-ai-document.md)
> Related Subagents: `pattern-expert` (RAG workflows), `kaizen-specialist` (AI agents)

## Quick Reference

RAG workflow components:

- **Document ingestion** - Load and chunk documents
- **Embedding generation** - Convert text to vectors
- **Vector storage** - Store in vector database
- **Similarity search** - Find relevant chunks
- **LLM generation** - Generate answers with context

## Pattern 1: Document Ingestion Pipeline

```rust
use kailash_core::{WorkflowBuilder, Runtime, RuntimeConfig, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. Load document
builder.add_node("DocumentProcessorNode", "load_doc", ValueMap::from([
    ("file_path".into(), Value::String("{{input.document_path}}".into())),
    ("extract_metadata".into(), Value::Bool(true)),
]));

// 2. Split into chunks
builder.add_node("TextChunkerNode", "chunk_text", ValueMap::from([
    ("input".into(), Value::String("{{load_doc.content}}".into())),
    ("chunk_size".into(), Value::Integer(512)),
    ("chunk_overlap".into(), Value::Integer(50)),
    ("strategy".into(), Value::String("semantic".into())), // Preserve sentence boundaries
]));

// 3. Generate embeddings
let embedding_model = std::env::var("EMBEDDING_MODEL").expect("EMBEDDING_MODEL in .env");
builder.add_node("EmbeddingNode", "generate_embeddings", ValueMap::from([
    ("provider".into(), Value::String(
        std::env::var("EMBEDDING_PROVIDER").expect("EMBEDDING_PROVIDER in .env").into()
    )),
    ("model".into(), Value::String(embedding_model.into())),
    ("text".into(), Value::String("{{chunk_text.chunks}}".into())),
]));

// 4. Store in vector database
builder.add_node("VectorStoreNode", "store_vectors", ValueMap::from([
    ("collection".into(), Value::String("documents".into())),
    ("vectors".into(), Value::String("{{generate_embeddings.embeddings}}".into())),
    ("metadata".into(), Value::Object(ValueMap::from([
        ("doc_id".into(), Value::String("{{input.document_id}}".into())),
        ("chunk_index".into(), Value::String("{{chunk_text.indices}}".into())),
        ("text".into(), Value::String("{{chunk_text.chunks}}".into())),
    ]))),
]));

builder.connect("load_doc", "content", "chunk_text", "input");
builder.connect("chunk_text", "chunks", "generate_embeddings", "text");
builder.connect("generate_embeddings", "embeddings", "store_vectors", "vectors");

let workflow = builder.build(&registry)?;
let runtime = Runtime::new(RuntimeConfig::default(), registry);
let result = runtime.execute(&workflow, ValueMap::from([
    ("document_path".into(), Value::String("docs/manual.pdf".into())),
    ("document_id".into(), Value::String("doc_001".into())),
])).await?;
```

## Pattern 2: RAG Query Pipeline

```rust
use kailash_core::{WorkflowBuilder, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. Generate query embedding
let embedding_model = std::env::var("EMBEDDING_MODEL").expect("EMBEDDING_MODEL in .env");
builder.add_node("EmbeddingNode", "query_embedding", ValueMap::from([
    ("provider".into(), Value::String(
        std::env::var("EMBEDDING_PROVIDER").expect("EMBEDDING_PROVIDER in .env").into()
    )),
    ("model".into(), Value::String(embedding_model.into())),
    ("text".into(), Value::String("{{input.query}}".into())),
]));

// 2. Vector similarity search
builder.add_node("VectorSearchNode", "search_similar", ValueMap::from([
    ("collection".into(), Value::String("documents".into())),
    ("query_vector".into(), Value::String("{{query_embedding.embedding}}".into())),
    ("top_k".into(), Value::Integer(5)),
    ("min_score".into(), Value::Float(0.7)),
]));

// 3. Rerank results (optional)
builder.add_node("RerankNode", "rerank", ValueMap::from([
    ("query".into(), Value::String("{{input.query}}".into())),
    ("documents".into(), Value::String("{{search_similar.results}}".into())),
    ("model".into(), Value::String("rerank-english-v2.0".into())),
]));

// 4. Build context prompt
builder.add_node("TransformNode", "build_prompt", ValueMap::from([
    ("input".into(), Value::String("{{rerank.documents}}".into())),
    ("transformation".into(), Value::String(
        "join_context(input, 'Answer the question based on this context:', '{{input.query}}')".into()
    )),
]));

// 5. Generate answer with LLM
let llm_model = std::env::var("LLM_MODEL").expect("LLM_MODEL in .env");
builder.add_node("LLMNode", "generate_answer", ValueMap::from([
    ("provider".into(), Value::String(
        std::env::var("LLM_PROVIDER").expect("LLM_PROVIDER in .env").into()
    )),
    ("model".into(), Value::String(llm_model.into())),
    ("prompt".into(), Value::String("{{build_prompt.result}}".into())),
    ("temperature".into(), Value::Float(0.3)),
]));

builder.connect("query_embedding", "embedding", "search_similar", "query_vector");
builder.connect("search_similar", "results", "rerank", "documents");
builder.connect("rerank", "documents", "build_prompt", "input");
builder.connect("build_prompt", "result", "generate_answer", "prompt");
```

## Pattern 3: Multi-Document RAG

```rust
use kailash_core::{WorkflowBuilder, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. Query embedding
let embedding_model = std::env::var("EMBEDDING_MODEL").expect("EMBEDDING_MODEL in .env");
builder.add_node("EmbeddingNode", "query_embed", ValueMap::from([
    ("provider".into(), Value::String(
        std::env::var("EMBEDDING_PROVIDER").expect("EMBEDDING_PROVIDER in .env").into()
    )),
    ("model".into(), Value::String(embedding_model.into())),
    ("text".into(), Value::String("{{input.query}}".into())),
]));

// 2. Search multiple collections in parallel
builder.add_node("VectorSearchNode", "search_docs", ValueMap::from([
    ("collection".into(), Value::String("documents".into())),
    ("query_vector".into(), Value::String("{{query_embed.embedding}}".into())),
    ("top_k".into(), Value::Integer(3)),
]));

builder.add_node("VectorSearchNode", "search_code", ValueMap::from([
    ("collection".into(), Value::String("codebase".into())),
    ("query_vector".into(), Value::String("{{query_embed.embedding}}".into())),
    ("top_k".into(), Value::Integer(3)),
]));

builder.add_node("VectorSearchNode", "search_api", ValueMap::from([
    ("collection".into(), Value::String("api_docs".into())),
    ("query_vector".into(), Value::String("{{query_embed.embedding}}".into())),
    ("top_k".into(), Value::Integer(3)),
]));

// 3. Merge and rerank all results
builder.add_node("MergeNode", "merge_results", ValueMap::from([
    ("strategy".into(), Value::String("combine".into())),
]));

builder.add_node("RerankNode", "rerank_all", ValueMap::from([
    ("query".into(), Value::String("{{input.query}}".into())),
    ("documents".into(), Value::String("{{merge_results.combined}}".into())),
    ("top_k".into(), Value::Integer(5)),
]));

// 4. Generate comprehensive answer
let llm_model = std::env::var("LLM_MODEL").expect("LLM_MODEL in .env");
builder.add_node("LLMNode", "generate", ValueMap::from([
    ("provider".into(), Value::String(
        std::env::var("LLM_PROVIDER").expect("LLM_PROVIDER in .env").into()
    )),
    ("model".into(), Value::String(llm_model.into())),
    ("prompt".into(), Value::String(
        "Answer using context from docs, code, and API:\n\n\
         Context: {{rerank_all.documents}}\n\n\
         Question: {{input.query}}\n\n\
         Provide a comprehensive answer with examples.".into()
    )),
]));

// Parallel searches
builder.connect("query_embed", "embedding", "search_docs", "query_vector");
builder.connect("query_embed", "embedding", "search_code", "query_vector");
builder.connect("query_embed", "embedding", "search_api", "query_vector");

builder.connect("search_docs", "results", "merge_results", "input_docs");
builder.connect("search_code", "results", "merge_results", "input_code");
builder.connect("search_api", "results", "merge_results", "input_api");

builder.connect("merge_results", "combined", "rerank_all", "documents");
builder.connect("rerank_all", "documents", "generate", "context");
```

## Pattern 4: Conversational RAG with Memory

```rust
use kailash_core::{WorkflowBuilder, NodeRegistry};
use kailash_core::value::{Value, ValueMap};
use std::sync::Arc;

let registry = Arc::new(NodeRegistry::default());
let mut builder = WorkflowBuilder::new();

// 1. Load conversation history
builder.add_node("DatabaseQueryNode", "load_history", ValueMap::from([
    ("query".into(), Value::String(
        "SELECT role, content FROM messages WHERE conversation_id = ? ORDER BY created_at DESC LIMIT 5".into()
    )),
    ("parameters".into(), Value::Array(vec![
        Value::String("{{input.conversation_id}}".into()),
    ])),
]));

// 2. Build conversation context
builder.add_node("TransformNode", "build_context", ValueMap::from([
    ("input".into(), Value::String("{{load_history.results}}".into())),
    ("transformation".into(), Value::String("join_messages(input, 'role', 'content')".into())),
]));

// 3. Embed query with context
let embedding_model = std::env::var("EMBEDDING_MODEL").expect("EMBEDDING_MODEL in .env");
builder.add_node("EmbeddingNode", "embed_query", ValueMap::from([
    ("provider".into(), Value::String(
        std::env::var("EMBEDDING_PROVIDER").expect("EMBEDDING_PROVIDER in .env").into()
    )),
    ("model".into(), Value::String(embedding_model.into())),
    ("text".into(), Value::String("{{input.query}} Context: {{build_context.context}}".into())),
]));

// 4. Vector search
builder.add_node("VectorSearchNode", "search", ValueMap::from([
    ("collection".into(), Value::String("documents".into())),
    ("query_vector".into(), Value::String("{{embed_query.embedding}}".into())),
    ("top_k".into(), Value::Integer(5)),
]));

// 5. Generate answer with history
let llm_model = std::env::var("LLM_MODEL").expect("LLM_MODEL in .env");
builder.add_node("LLMNode", "generate", ValueMap::from([
    ("provider".into(), Value::String(
        std::env::var("LLM_PROVIDER").expect("LLM_PROVIDER in .env").into()
    )),
    ("model".into(), Value::String(llm_model.into())),
    ("prompt".into(), Value::String(
        "Conversation History:\n{{build_context.context}}\n\n\
         Relevant Documents:\n{{search.results}}\n\n\
         User: {{input.query}}\n\n\
         Provide a helpful answer based on the conversation and documents.".into()
    )),
]));

// 6. Save to conversation history
builder.add_node("DatabaseExecuteNode", "save_message", ValueMap::from([
    ("query".into(), Value::String(
        "INSERT INTO messages (conversation_id, role, content) VALUES (?, 'assistant', ?)".into()
    )),
    ("parameters".into(), Value::Array(vec![
        Value::String("{{input.conversation_id}}".into()),
        Value::String("{{generate.response}}".into()),
    ])),
]));

builder.connect("load_history", "results", "build_context", "input");
builder.connect("build_context", "context", "embed_query", "text");
builder.connect("embed_query", "embedding", "search", "query_vector");
builder.connect("search", "results", "generate", "context");
builder.connect("generate", "response", "save_message", "parameters");
```

## Best Practices

1. **Chunk size** - 256-1024 tokens, overlap 10-20%
2. **Embedding models** - Match query and document embeddings
3. **Reranking** - Improve precision after initial retrieval
4. **Context window** - Respect LLM context limits
5. **Metadata filtering** - Pre-filter by document type/date
6. **Conversation memory** - Include recent history for context

## Common Pitfalls

- **Too large chunks** - Diluted relevance
- **No overlap** - Missing context at boundaries
- **Wrong embedding model** - Poor similarity results
- **No reranking** - Low precision
- **Context overflow** - Exceeding LLM limits

## Related Skills

- **AI Nodes**: [`nodes-ai-reference`](../nodes/nodes-ai-reference.md)
- **Document Processing**: [`workflow-pattern-ai-document`](workflow-pattern-ai-document.md)
- **Kaizen Agents**: [`kaizen-specialist`](../../04-kaizen/kaizen-specialist.md)

<!-- Trigger Keywords: RAG, retrieval augmented, vector search, semantic search, document Q&A, embeddings -->
