# DataFlow Skills Index

Skills for `kailash-dataflow` -- the database framework built on kailash-core and sqlx.

Source: `crates/kailash-dataflow/src/`

---

## Skill Files

| File                        | Description                                                                                | Use When                                                                |
| --------------------------- | ------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------- |
| `dataflow-quickstart.md`    | 5-minute introduction: DataFlow::new(), ModelDefinition, register_nodes, DataFlowExpress   | Getting started, first-time setup                                       |
| `dataflow-models.md`        | ModelDefinition builder API, FieldType, FieldBuilder, field constraints, validation        | Defining models, field configuration, understanding generated nodes     |
| `dataflow-crud-patterns.md` | All 11 CRUD + bulk node input/output shapes, filter operators, workflow integration        | Building queries, understanding input ValueMap structure, filter syntax |
| `dataflow-transactions.md`  | DataFlowTransaction, begin/commit/rollback, RAII auto-rollback, SqlConnection, pool config | Transaction management, connection pooling, begin_immediate for SQLite  |
| `dataflow-multi-tenancy.md` | QueryInterceptor, TenantContext, TenantContextMiddleware, tenant propagation               | Row-level tenant isolation, per-tenant queries, admin bypass            |
| `dataflow-gotchas.md`       | 15 common pitfalls: PK naming, timestamp auto-management, Create vs Update params          | Debugging errors, understanding validation failures, avoiding mistakes  |

## Quick Navigation

- **"How do I create a model?"** -> `dataflow-models.md` or `dataflow-quickstart.md`
- **"What inputs does CreateUser expect?"** -> `dataflow-crud-patterns.md`
- **"How do I filter with $gt, $in, $like?"** -> `dataflow-crud-patterns.md`
- **"How do I do CRUD without workflows?"** -> `dataflow-quickstart.md` (DataFlowExpress section)
- **"How do I use transactions?"** -> `dataflow-transactions.md`
- **"How do I add multi-tenancy?"** -> `dataflow-multi-tenancy.md`
- **"Why is my create/update failing?"** -> `dataflow-gotchas.md`
- **"What's the difference between Create and Update inputs?"** -> `dataflow-gotchas.md` (gotcha #3)
- **"How do I configure the connection pool?"** -> `dataflow-transactions.md`
- **"What SQL dialect differences exist?"** -> `dataflow-gotchas.md` (gotcha #11)
- **"How do bulk operations work?"** -> `dataflow-crud-patterns.md`
- **"How do I inspect the database schema at runtime?"** -> `dataflow-quickstart.md` (Inspector section)
- **"How do I use DataFlow from Python?"** -> `dataflow-quickstart.md` (Python binding section)

## Key Concepts

- **DataFlow is NOT an ORM** -- it generates workflow nodes that wrap sqlx queries
- **11 nodes per model**: Create, Read, Update, Delete, List, Upsert, Count, BulkCreate, BulkUpdate, BulkDelete, BulkUpsert
- **Runtime builder API**: `ModelDefinition::new()` with fluent `.field()` calls (not a proc-macro)
- **Value-based I/O**: All inputs and outputs use `BTreeMap<Arc<str>, Value>` (ValueMap)
- **Auto dialect detection**: SQLite, PostgreSQL, MySQL from connection URL via `QueryDialect::from_url()`
- **Two usage modes**: Node-based (via WorkflowBuilder) or direct CRUD (via DataFlowExpress)
- **Multi-database**: sqlx Any driver with dialect-aware query generation
