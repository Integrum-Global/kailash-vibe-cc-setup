# Deployment Rules

## Scope

These rules apply to all deployment operations and deployment-related files.

## MUST Rules

### 1. CLI SSO Authentication Only

All cloud provider access MUST use CLI SSO authentication. No long-lived credentials.

**Correct**:

```bash
aws sso login --profile my-profile
az login
gcloud auth login
```

**Incorrect**:

```
❌ AWS_ACCESS_KEY_ID=AKIA...
❌ AZURE_CLIENT_SECRET=...
❌ GOOGLE_APPLICATION_CREDENTIALS pointing to committed JSON
```

**Enforced by**: validate-deployment.js hook, security-reviewer agent
**Violation**: BLOCK deployment

### 2. SSL Required for Production

All production endpoints MUST use HTTPS/TLS.

**Applies to**:

- API endpoints
- Web applications
- Webhook URLs
- Database connections (where supported)

### 3. Monitoring Before Go-Live

Production deployments MUST have monitoring configured before receiving traffic.

**Minimum requirements**:

- Health check endpoint responding
- Error alerting configured
- Basic metrics collection (CPU, memory, request rate)

### 4. Secrets via Provider's Secrets Manager

Production secrets MUST use the cloud provider's secrets management service, not environment variables on the host or committed files.

**Examples**:

- AWS: Secrets Manager or Parameter Store
- Azure: Key Vault
- GCP: Secret Manager

### 5. Deployment Config Documented

Every project that deploys MUST have `deploy/deployment-config.md` at the project root. Run `/deploy` to create it via the onboarding process.

### 6. AsyncLocalRuntime for Containers

Kailash applications deployed in Docker or any container environment MUST use `AsyncLocalRuntime`. Never use `LocalRuntime` in containers — it causes event loop hangs.

**Correct**:

```python
from kailash import AsyncLocalRuntime
rt = AsyncLocalRuntime(reg)
```

**Incorrect**:

```
❌ from kailash import LocalRuntime  # hangs in Docker
❌ rt = LocalRuntime(reg)            # hangs in Docker
```

**Enforced by**: deployment-specialist agent, code review
**Violation**: BLOCK deployment

### 7. Research Before Executing

Cloud provider CLIs and services change frequently. MUST verify current syntax via web search or `--help` before running deployment commands. Do NOT rely on memorized commands that may be outdated.

### 8. NEVER Hot-Patch Running Containers

Hot-patching a running container with `docker cp` does NOT constitute a deployment. It will silently fail to take effect and cause hours of debugging. This applies to both Python backend and frontend (SPA) changes.

**Why `docker cp` does not work for Python changes:**

- The Python package is pip-installed into the image at build time. The site-packages copy is what gets imported.
- Python caches compiled bytecode at startup. Deleting `__pycache__` after the process is running does nothing — the module is already in memory.
- Nexus/FastAPI registers routes at startup. A hot-patched file containing a new route will never be discovered by the running process.

**Why `docker cp` does not work for frontend SPA changes:**

- The React/SPA build artifact in the nginx container is a snapshot from the build step at image build time. Copying new files in may appear to work for static assets but does not update the build manifest or cache-busted asset fingerprints.

**ALWAYS rebuild on code changes:**

```bash
# The Dockerfile uses a GIT_HASH build arg as a cache buster.
# When GIT_HASH changes, Docker invalidates the source copy + install layers.
# NO --no-cache needed — the cache buster handles it automatically.
export GIT_HASH=$(git rev-parse --short HEAD)

docker compose -f docker-compose.prod.yml build {{SERVICE_NAME}}
docker compose -f docker-compose.prod.yml up -d {{SERVICE_NAME}}
```

**Why NOT `--no-cache`:**

`--no-cache` rebuilds EVERYTHING from scratch — system packages, pip dependencies, all layers. This takes 5-10 minutes even when only source code changed. The `GIT_HASH` ARG in the Dockerfile invalidates only the layers that depend on source code, while keeping cached system packages and dependencies. Targeted builds take under 60 seconds.

**Correct procedure for any code change:**

1. Commit changes and ensure git history is current
2. Pull latest on the server
3. `export GIT_HASH=$(git rev-parse --short HEAD)`
4. `docker compose -f docker-compose.prod.yml build <service>`
5. `docker compose -f docker-compose.prod.yml up -d <service>`

### 9. Use GIT_HASH Cache Buster in Dockerfiles

Dockerfiles MUST include a `GIT_HASH` build ARG to enable targeted cache invalidation. Pass `--build-arg GIT_HASH=$(git rev-parse --short HEAD)` on every build.

**Pattern**:

```dockerfile
# Declare near source COPY so only source-dependent layers are invalidated
ARG GIT_HASH=dev
RUN echo "Build: $GIT_HASH"  # forces cache invalidation when hash changes
COPY . .
RUN pip install -e .
```

**This means**: Never use `--no-cache` in normal deployments. If you find yourself reaching for `--no-cache`, add or fix the `GIT_HASH` ARG instead.

### 10. nginx Must Serve index.html with No-Cache Headers for SPAs

For Single Page Applications (React, Vue, Angular, etc.) served by nginx, the `index.html` entry point MUST be served with cache-prevention headers. All other static assets (JS, CSS, fonts with content-hashed filenames) may be cached aggressively.

**Why**: Browsers that cache `index.html` will serve stale JavaScript bundles to users after a deployment, causing broken experiences and ghost bugs.

**Correct nginx configuration**:

```nginx
location = /index.html {
    add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate";
    add_header Pragma "no-cache";
    add_header Expires "0";
    try_files $uri /index.html;
}

# Content-hashed assets can be cached forever
location ~* \.(js|css|woff2?|ttf|eot|ico|png|svg)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

**Incorrect**: Serving `index.html` with default nginx caching or `Cache-Control: max-age=3600`.

### 11. Never Deploy to Production Without Staging Verification

Production MUST NOT receive code that has not passed the staging pipeline.

The pipeline is: **local dev → staging → production**. Each gate must pass before the next stage is promoted.

**Step 1 — Local dev** (`docker-compose.dev.yml`):
- Hot-reload via volume-mounted source; no rebuild required
- `ENVIRONMENT=development` — development RBAC, verbose logging
- Database and cache ports exposed to host for tooling access

**Step 2 — Staging** (`docker-compose.staging.yml`):
- Runs on the same server as production, on different ports (e.g. API: 8001, Web: 3001)
- Uses the SAME Dockerfiles as production — tests the actual image that will ship
- Separate data volumes; separate database name; containers prefixed to avoid overlap
- `ENVIRONMENT=staging` — production RBAC enforced; email/payment sending disabled
- On PASS, writes `.staging-passed` marker containing the passing commit hash

**Step 3 — Production** (`docker-compose.prod.yml`):
- Deploy script reads `.staging-passed` and verifies it matches the current commit
- If the marker is absent or stale (code changed after staging ran), deploy is blocked
- After a successful production deploy, the marker is cleared — staging must run again next time
- Emergency override: `deploy.sh --skip-staging` (requires documenting reason in `deploy/deployment-config.md`)

**Correct sequence**:

```bash
git pull origin main
bash deploy/scripts/stage.sh      # must print "STAGING PASSED"
bash deploy/scripts/deploy.sh     # checks .staging-passed, then deploys
```

**Incorrect**:

```
❌ bash deploy/scripts/deploy.sh   (without running stage.sh first)
❌ --skip-staging without written justification in deployment-config.md
❌ Hot-patching containers to bypass either gate
```

**Enforced by**: `deploy.sh` staging gate check, `validate-prod-deploy.js` PreToolUse hook
**Violation**: BLOCK production deploy

### 12. Claude Code Hook Enforces the Staging Gate

A Claude Code `PreToolUse` hook (`validate-prod-deploy.js`) intercepts Bash commands BEFORE they execute and blocks any attempt to deploy directly to production without a passing staging marker.

**Commands that are intercepted and blocked**:

- Any command matching `docker.*compose.*prod.*up`
- Any command matching `docker.*compose.*prod.*build`
- Any command matching `docker.*compose.*prod.*restart`
- Any bare `docker restart <container>` command
- Any SSH command to the production server that also runs `docker compose`

**How it verifies staging**:

1. Looks for `.staging-passed` in the repo root
2. Reads the commit hash stored in the marker
3. Checks `git rev-parse HEAD` to get the current commit
4. If the commits match: ALLOW with a confirmation message
5. If missing or mismatched: BLOCK with a clear error and the correct recovery steps

**The only escape hatch**: Add `--skip-staging` to the exact command. The hook will allow it but emit a loud warning. Document the reason in `deploy/deployment-config.md`.

### 13. Database Ports Must Not Be Exposed to Host in Production

Production compose files MUST NOT expose database or cache ports to the host network.

**Incorrect** (in docker-compose.prod.yml):

```yaml
postgres:
  ports:
    - "5432:5432"   # ❌ exposes DB to host (and potentially internet)
```

**Correct** (services communicate on internal Docker network only):

```yaml
postgres:
  # No ports: section — accessible only within Docker network
  networks:
    - app_backend
```

**Why**: Exposing database ports to the host allows direct connections that bypass application-level authentication and audit logging. On cloud VMs without a strict firewall, this can expose the database to the internet.

**Exception for development**: `docker-compose.dev.yml` may expose database ports to the host for local tooling (e.g. `127.0.0.1:5432:5432`), but MUST restrict to loopback only.

### 14. Separate Compose Files for Dev, Staging, and Production

Projects with Docker deployments MUST maintain separate compose files for each environment. Never use a single compose file with environment variable switches for behavior that differs between environments.

**Required files**:

- `docker-compose.dev.yml` — volume mounts for hot reload, ports exposed, debug logging
- `docker-compose.staging.yml` — production images, different ports, isolated volumes
- `docker-compose.prod.yml` — no volume mounts, no exposed DB ports, resource limits

**Why separate files** instead of a base + override pattern:

- Production config is immediately readable without mental merging
- `docker compose config` shows the exact merged result, but humans reading files need clarity
- Staging file can be reviewed on its own as a preflight check

### 15. Password and Bcrypt Operations Inside Containers Require Python Scripts

Shell escaping silently destroys bcrypt hashes. The `$` characters in bcrypt hashes are interpreted by bash as variable references and replaced with empty strings. The resulting stored hash will never match any password.

**Incorrect** (shell escaping corrupts the hash):

```bash
# WRONG — $2b$12$... will be mangled by bash variable expansion
docker exec postgres psql -U postgres -c \
  "UPDATE users SET password_hash = '$2b$12$...' WHERE email = 'admin@example.com'"
```

**Correct** (use a Python script inside the container):

```bash
cat > /tmp/reset_password.py << 'PYEOF'
import bcrypt
import psycopg2
import os

new_password = os.environ["NEW_PASSWORD"]
hashed = bcrypt.hashpw(new_password.encode(), bcrypt.gensalt()).decode()

conn = psycopg2.connect(
    host=os.environ["DB_HOST"],
    dbname=os.environ["POSTGRES_DB"],
    user=os.environ["POSTGRES_USER"],
    password=os.environ["POSTGRES_PASSWORD"]
)
cur = conn.cursor()
cur.execute(
    "UPDATE users SET password_hash = %s WHERE email = %s",
    (hashed, os.environ["TARGET_EMAIL"])
)
conn.commit()
cur.close()
conn.close()
print(f"Password reset successfully.")
PYEOF

docker cp /tmp/reset_password.py {{APP_CONTAINER}}:/tmp/reset_password.py
docker exec -e NEW_PASSWORD="NewSecurePass!" \
            -e TARGET_EMAIL="admin@example.com" \
            -e DB_HOST="{{DB_HOST}}" \
            -e POSTGRES_DB="{{POSTGRES_DB}}" \
            -e POSTGRES_USER="{{POSTGRES_USER}}" \
            -e POSTGRES_PASSWORD="{{POSTGRES_PASSWORD}}" \
            {{APP_CONTAINER}} python3 /tmp/reset_password.py
```

**Rule**: For any database operation involving special characters (`$`, `\`, single quotes), write a Python script, copy it in with `docker cp`, and execute with `docker exec` passing secrets via `-e` flags rather than embedding them in the script.

## MUST NOT Rules

### 1. No Long-Lived Cloud Credentials

MUST NOT store AWS access keys, Azure client secrets, or GCP service account JSON in:

- `.env` files
- Source code
- CI configuration (use CI's native secrets)
- Docker images

### 2. No Deployment Without Tests

MUST NOT deploy to production without a passing test suite.

### 3. No Unattended Destructive Operations

MUST NOT execute destructive cloud operations (delete resources, terminate instances, drop databases) without explicit human approval.

### 4. No Hardcoded Infrastructure

MUST NOT hardcode IP addresses, instance IDs, or resource ARNs in application code. Use service discovery, DNS, or configuration.

### 5. No --no-cache in Normal Deployments

MUST NOT use `docker compose build --no-cache` as a standard deployment practice. If a rebuild is incomplete, fix the `GIT_HASH` ARG in the Dockerfile instead. `--no-cache` rebuilds all layers including OS packages and pip/npm dependencies — this takes 5-10x longer and wastes CI minutes.

## Production Checklist

Before any production deployment:

- [ ] All tests pass
- [ ] TypeScript / type checks clean (if applicable)
- [ ] `stage.sh` run and `.staging-passed` marker present for current commit
- [ ] Security review completed
- [ ] SSL/TLS configured
- [ ] Monitoring and alerting configured
- [ ] Secrets in provider's secrets manager
- [ ] Deployment runbook up to date in `deploy/deployment-config.md`
- [ ] Database migrations reviewed for destructive operations (DROP, ALTER DROP COLUMN)
- [ ] Rollback procedure documented and tested
- [ ] Right-sizing verified (check reserved instances / savings plans first)
- [ ] README.md and docs/ version numbers updated to match release
- [ ] DNS configured
- [ ] Human approval obtained

## Deployment Verification Checklist

After every deployment to production:

- [ ] Confirm expected commits are present on server (`git log --oneline -3`)
- [ ] All containers healthy (`docker compose -f docker-compose.prod.yml ps`)
- [ ] Health endpoint returns OK (`curl https://{{YOUR_DOMAIN}}/api/health`)
- [ ] Login/auth flow works end-to-end in the browser (not just health check)
- [ ] Any post-deploy data reload steps completed (see deployment-config.md)

## Exceptions

Deployment rule exceptions require:

1. Explicit human approval
2. Documentation in deployment-config.md
3. Time-limited (must be remediated)
