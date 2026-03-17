# CI/CD Infrastructure for Python Projects

Patterns and principles for CI/CD pipelines in Python projects. Covers GitHub Actions workflows, test matrices, documentation deployment, and release automation.

## GitHub Actions Workflow Patterns

### Test Workflow (on every push/PR)

```yaml
name: Tests
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    strategy:
      matrix:
        python-version: ["3.10", "3.11", "3.12"]
        os: [ubuntu-latest, macos-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
      - name: Install dependencies
        run: pip install -e ".[dev]"
      - name: Lint
        run: ruff check . && ruff format --check .
      - name: Test
        run: pytest --tb=short
```

### Pure Python Package Build

```yaml
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: pip install build
      - run: python -m build
      - uses: actions/upload-artifact@v4
        with:
          name: dist
          path: dist/
```

### Tag-Triggered Publishing

```yaml
name: Publish
on:
  push:
    tags: ["v*"]

jobs:
  # ... build jobs above ...

  publish-testpypi:
    needs: [build]
    runs-on: ubuntu-latest
    environment: testpypi
    permissions:
      id-token: write  # for trusted publisher (OIDC)
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: dist
          path: dist/
      - uses: pypa/gh-action-pypi-publish@release/v1
        with:
          repository-url: https://test.pypi.org/legacy/

  publish-pypi:
    needs: [publish-testpypi]
    runs-on: ubuntu-latest
    environment: pypi
    permissions:
      id-token: write
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: dist
          path: dist/
      - uses: pypa/gh-action-pypi-publish@release/v1

  github-release:
    needs: [publish-pypi]
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
      - name: Create GitHub Release
        run: gh release create ${{ github.ref_name }} --generate-notes
        env:
          GH_TOKEN: ${{ github.token }}
```

## Test Matrix Design

### Python Version Strategy

| Python Version | Support Level | Notes |
| -------------- | ------------- | ----- |
| 3.10 | Minimum supported | Test on CI |
| 3.11 | Supported | Test on CI |
| 3.12 | Primary / Latest | Test on CI, build docs |
| 3.13+ | Future | Add when stable |

### OS Strategy

| OS | When to Include | Notes |
| -- | --------------- | ----- |
| Linux (ubuntu-latest) | Always | Primary platform |
| macOS (macos-latest) | If platform-specific code | ARM (M1+) |
| Windows (windows-latest) | If platform-specific code | MSVC toolchain |

### Matrix Optimization

- Use `fail-fast: false` to see all failures, not just the first
- Run linting only on one Python version (fastest feedback)
- Run full test suite on all matrix combinations
- Cache pip dependencies for faster runs

## Documentation Deployment

### ReadTheDocs

```yaml
# .readthedocs.yaml
version: 2
build:
  os: ubuntu-22.04
  tools:
    python: "3.12"
sphinx:
  configuration: docs/conf.py
python:
  install:
    - method: pip
      path: .
      extra_requirements:
        - docs
```

### GitHub Pages (via GitHub Actions)

```yaml
name: Deploy Docs
on:
  push:
    branches: [main]

jobs:
  deploy-docs:
    runs-on: ubuntu-latest
    permissions:
      pages: write
      id-token: write
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: pip install -e ".[docs]"
      - run: cd docs && make html  # or: mkdocs build
      - uses: actions/upload-pages-artifact@v3
        with:
          path: docs/_build/html  # or: site/
      - uses: actions/deploy-pages@v4
```

## Release Automation Patterns

### Preferred: Tag-Triggered Pipeline

The recommended pattern:

1. Developer bumps version and updates CHANGELOG
2. Developer pushes a version tag: `git tag v1.2.3 && git push origin v1.2.3`
3. CI automatically:
   - Builds packages
   - Runs tests on built packages
   - Publishes to TestPyPI
   - Publishes to production PyPI
   - Creates GitHub Release with auto-generated notes

### Alternative: Manual Workflow Dispatch

```yaml
on:
  workflow_dispatch:
    inputs:
      version:
        description: "Version to release (e.g., 1.2.3)"
        required: true
      skip_testpypi:
        description: "Skip TestPyPI (patch releases only)"
        type: boolean
        default: false
```

## CI Debugging

### Common Failure Patterns

| Symptom | Likely Cause | Fix |
| ------- | ------------ | --- |
| Build fails on Linux | Missing system deps | Add `apt-get install` step |
| Build fails on macOS | Wrong SDK version | Pin macOS runner version |
| Tests pass locally, fail on CI | Environment difference | Check Python version, OS, env vars |
| Publishing fails | Auth misconfigured | Check trusted publisher or token setup |

### Debugging Commands

```bash
# List recent CI runs
gh run list --limit 10

# Watch a specific run
gh run watch <run-id>

# Download CI logs
gh run download <run-id> --name logs

# Re-run failed jobs
gh run rerun <run-id> --failed
```

## What to Research Live

The agent should always research these before configuring -- they change frequently:

- Current GitHub Actions action versions (@v4 vs @v5, etc.)
- Current `gh-action-pypi-publish` version and OIDC setup
- Current ReadTheDocs build configuration format
- Current best practices for trusted publisher (OIDC) setup on PyPI

Use `web search` and CLI `--help` rather than relying on trained knowledge.

---

## Docker Deployment Patterns (Learned from Production)

These patterns come from running real deployments and represent hard-won lessons about what goes wrong.

### Pattern 1: GIT_HASH Cache Buster in Dockerfiles

The standard `--no-cache` flag is wasteful — it rebuilds everything including OS packages and pip/npm dependencies. The GIT_HASH ARG pattern gives you targeted cache invalidation: only layers that depend on source code are invalidated when your code changes.

```dockerfile
# Place BEFORE source COPY — everything after this is invalidated when hash changes
ARG GIT_HASH=dev
RUN echo "Build: $GIT_HASH"   # This RUN invalidates the cache when GIT_HASH changes

COPY . .
RUN pip install -e .
```

```bash
# Build with cache busting on every real commit, cache hits on re-runs
export GIT_HASH=$(git rev-parse --short HEAD)
docker compose -f docker-compose.prod.yml build backend
```

**Result**: Typical build time drops from 5-10 minutes (--no-cache) to under 60 seconds.

**Rule**: If you find yourself reaching for `--no-cache`, add or fix the `GIT_HASH` ARG instead.

### Pattern 2: NEVER Hot-Patch Running Containers

`docker cp` into a running container is NOT a deployment:

| Change type | Why docker cp fails |
|-------------|-------------------|
| Python source code | pip-installed package is in site-packages, not your source tree; module already loaded in memory |
| FastAPI/Nexus routes | Routes registered at startup; running process never discovers new routes |
| React/SPA build | Build manifest and asset fingerprints are out of sync; browser may load wrong bundle |

**The only correct procedure**:
1. Commit the change
2. `export GIT_HASH=$(git rev-parse --short HEAD)`
3. `docker compose -f docker-compose.prod.yml build <service>`
4. `docker compose -f docker-compose.prod.yml up -d <service>`

### Pattern 3: Dev / Staging / Production Compose Separation

Use three separate compose files — never try to express environment differences purely through variables in a single file.

| File | Purpose | Key characteristics |
|------|---------|-------------------|
| `docker-compose.dev.yml` | Local development | Source volume mounts, DB ports exposed to loopback, `ENVIRONMENT=development` |
| `docker-compose.staging.yml` | Pre-production gate | Same Dockerfiles as prod, different ports, isolated volumes, `ENVIRONMENT=staging` |
| `docker-compose.prod.yml` | Live production | No volume mounts, no exposed DB ports, resource limits, `ENVIRONMENT=production` |

**Why separate files**: Production config must be immediately readable. Mental merging of base + override files introduces errors under pressure.

### Pattern 4: Staging Gate Enforcement

The staging gate prevents code from reaching production without verification. The mechanism uses a `.staging-passed` file containing the verified commit hash.

**Flow**:
```
stage.sh                              deploy.sh
  ↓                                     ↓
Build same images as prod             Check .staging-passed exists
Start on staging ports                Verify hash == git rev-parse HEAD
Run health checks                     If match: proceed
Run smoke tests (optional)            If missing/stale: BLOCK
Write .staging-passed = $GIT_HASH     After deploy: rm .staging-passed
```

**Scripts**: See `deploy/scripts/` for `stage.sh.template`, `deploy.sh.template`, and `promote.sh.template`.

**Hook enforcement**: `validate-prod-deploy.js` (PreToolUse Bash hook) intercepts production docker compose commands and verifies the marker before allowing them to run. This catches accidental bypasses even when running commands manually.

### Pattern 5: nginx Must Serve index.html with No-Cache Headers for SPAs

When nginx serves a React/Vue/Angular app, `index.html` MUST have cache-prevention headers. All other assets (with content-hashed filenames) can be cached aggressively.

```nginx
# index.html — never cache (entry point to the versioned bundle)
location = /index.html {
    add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate";
    add_header Pragma "no-cache";
    add_header Expires "0";
}

# Content-hashed assets — cache forever (filename changes on rebuild)
location ~* \.(js|css|woff2?|ttf|ico|png|svg)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

**Why this matters**: A browser that caches `index.html` will serve stale JavaScript to users after deployment. The user sees the new URL but runs the old code. This produces ghost bugs that are very hard to diagnose.

See `deploy/nginx-spa.conf.template` for the full nginx configuration.

### Pattern 6: Database Ports Must Not Be Exposed in Production

Production compose files must NOT expose database or cache ports to the host.

```yaml
# WRONG in production — exposes DB to host and potentially internet
postgres:
  ports:
    - "5432:5432"

# CORRECT — DB accessible only within Docker network
postgres:
  # no ports: section
  networks:
    - app_network
```

Development compose may expose ports to `127.0.0.1` for local tooling.

### Pattern 7: Password/Bcrypt Operations Require Python Scripts

Shell variable expansion silently corrupts bcrypt hashes. The `$` in `$2b$12$...` is expanded by bash as an empty variable.

**Wrong**:
```bash
# $2b$12$... becomes $2b$12$ after bash expansion — hash is destroyed
docker exec postgres psql -U app -c "UPDATE users SET hash='$2b$12$...' WHERE ..."
```

**Correct**:
```bash
# Write a Python script, copy it in, run it — Python doesn't mangle $
docker cp /tmp/reset_password.py app_container:/tmp/reset_password.py
docker exec -e NEW_PASSWORD="..." app_container python3 /tmp/reset_password.py
```

**General rule**: For any database operation with special characters (`$`, `\`, quotes), use a Python script inside the container rather than shell interpolation.
