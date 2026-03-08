# Test Workflow Skill

Run comprehensive workflow tests for a specific Kailash crate.

## Usage

`/test-workflow <crate>` -- Run all tests, clippy, and doc tests for the specified crate

Examples:
- `/test-workflow core` -- Test kailash-core
- `/test-workflow nodes` -- Test kailash-nodes
- `/test-workflow kaizen` -- Test kailash-kaizen
- `/test-workflow nexus` -- Test kailash-nexus
- `/test-workflow all` -- Test entire workspace

## Crate Mapping

| Shorthand      | Crate Name              | Test Focus                                         |
| -------------- | ----------------------- | -------------------------------------------------- |
| `value`        | `kailash-value`         | Value enum, serde, conversions                     |
| `core`         | `kailash-core`          | Node trait, WorkflowBuilder, Runtime, 20 nodes     |
| `macros`       | `kailash-macros`        | Proc-macros, trybuild compile tests                |
| `nodes`        | `kailash-nodes`         | 100+ I/O, AI, auth, security, monitoring nodes     |
| `plugin`       | `kailash-plugin`        | WASM runtime (wasmtime), native cdylib loading     |
| `plugin-guest` | `kailash-plugin-guest`  | Guest SDK for WASM plugins                         |
| `capi`         | `kailash-capi`          | C ABI, opaque pointers, null safety                |
| `dataflow`     | `kailash-dataflow`      | sqlx models, query generation                      |
| `nexus`        | `kailash-nexus`         | axum routes, handlers, MCP server, SSE             |
| `kaizen`       | `kailash-kaizen`        | Agent, LlmClient, tools, orchestration, memory     |
| `enterprise`   | `kailash-enterprise`    | RBAC, audit, multi-tenancy                         |
| `python`       | `kailash-python`        | PyO3 bindings                                      |
| `node-binding` | `kailash-node`          | napi-rs bindings                                   |
| `wasm`         | `kailash-wasm`          | wasm-bindgen bindings                              |
| `all`          | (workspace)             | All crates                                         |

## Steps

1. Run unit tests for the specified crate:

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo test -p kailash-{crate} 2>&1
```

2. Run clippy lint check:

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo clippy -p kailash-{crate} -- -D warnings 2>&1
```

3. Run doc tests (included in `cargo test` but verify separately if needed):

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo test -p kailash-{crate} --doc 2>&1
```

4. Optionally run integration tests if available:

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo test -p kailash-{crate} --features integration 2>&1
```

5. Report results:
   - Total test count (passed/failed/ignored)
   - Any clippy warnings
   - Any failing doc tests
   - Test duration

## Quick Commands

### Test entire workspace

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo test --workspace 2>&1
```

### Clippy entire workspace

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo clippy --workspace -- -D warnings 2>&1
```

### Format check entire workspace

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo fmt --all --check 2>&1
```

### Full quality gate (tests + clippy + fmt)

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo fmt --all --check 2>&1 && cargo clippy --workspace -- -D warnings 2>&1 && cargo test --workspace 2>&1
```

### Test with output (for debugging)

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo test -p kailash-{crate} -- --nocapture 2>&1
```

### Test a specific test by name

```bash
PATH="./.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" SDKROOT=$(xcrun --show-sdk-path) cargo test -p kailash-{crate} -- {test_name} 2>&1
```

## Verify

After running tests, check for:
- All tests pass (0 failures)
- No clippy warnings with `-D warnings`
- `cargo fmt --check` passes
- No `todo!()` or `unimplemented!()` in production code
- Doc tests compile and pass
