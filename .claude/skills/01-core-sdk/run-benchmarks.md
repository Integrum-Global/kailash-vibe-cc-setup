# Run Benchmarks Skill

Run and report Kailash performance benchmarks.

## Usage

`/run-benchmarks [crate]` -- Run Criterion benchmarks for a specific crate or all crates

Examples:

- `/run-benchmarks` -- Run all benchmarks (kailash-core + kailash-nodes)
- `/run-benchmarks core` -- Run kailash-core benchmarks only
- `/run-benchmarks nodes` -- Run kailash-nodes benchmarks only

## Steps

1. Run benchmarks for the specified target:

**All benchmarks:**

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo bench -p kailash-core 2>&1 && cargo bench -p kailash-nodes 2>&1
```

**kailash-core only:**

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo bench -p kailash-core 2>&1
```

**kailash-nodes only:**

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo bench -p kailash-nodes 2>&1
```

2. Report results organized by group:

### kailash-core benchmark groups (`crates/kailash-core/benches/workflow_bench.rs`)

- **workflow_build**: Build time for 5/20/100 node workflows
- **workflow_execute**: Execution overhead for 5/20/100 node NoOp workflows (target: <30us for 20-node)
- **value_type**: Clone, serialize, deserialize, construct, lookup benchmarks
- **parallelism_scaling**: 20-node wide workflow at concurrent=1/4/8
- **throughput**: Workflows/second for 5/20 node pipelines

### kailash-nodes benchmark groups (`crates/kailash-nodes/benches/phase5_bench.rs`)

- **jwt_auth**: JWT token generation and validation (~1us)
- **encryption**: AES-256-GCM encrypt/decrypt at various payload sizes (1KB ~6us)
- **hashing**: BLAKE3, SHA-256, Argon2 hashing benchmarks (blake3 ~333ns)
- **input_sanitization**: HTML sanitization throughput
- **data_masking**: PII masking throughput
- **health_check**: Health check node execution
- **metrics_collector**: Metrics collection throughput
- **anomaly_detection**: Anomaly detection latency
- **audit_log**: Audit log entry creation
- **permission_check**: RBAC permission evaluation

3. Compare against previous results if available in `target/criterion/`

4. Highlight any results that exceed target thresholds

## Quick verify (compile only):

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo bench -p kailash-core --no-run 2>&1 && cargo bench -p kailash-nodes --no-run 2>&1
```
