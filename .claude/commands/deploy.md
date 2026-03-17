# /deploy - Deployment Command

Standalone deployment command. Not a workspace phase — runs independently after any number of implement/redteam cycles.

## What This Phase Does (present to user)

Get the project live — whether that's publishing a software package, deploying to the cloud, or both. If this is your first deployment, we'll walk through setup questions. Nothing goes live without your explicit approval at every step.

## Your Role (communicate to user)

Answer setup questions about where and how to deploy (we'll explain each option and its implications), and approve each step before it happens. You'll always know what's about to happen before it does.

## Deployment Config

Read `deploy/deployment-config.md` at the project root. This is the single source of truth for how this project deploys.

## Mode Detection

### If `deploy/deployment-config.md` does NOT exist → Onboard Mode

Run the deployment onboarding process:

1. **Analyze the codebase**
   - What type of project? (package, web app, API service, CLI tool, multi-service)
   - What build system? (setuptools, hatch, poetry)
   - Existing deployment artifacts? (Dockerfile, docker-compose, k8s manifests, terraform, CI workflows)
   - What services does it depend on? (databases, caches, queues, external APIs)
   - What Kailash frameworks are used? (DataFlow, Nexus, Kaizen, MCP, Enterprise)
   - What database backends does DataFlow use? (check model definitions for `DataFlowModel`, `FieldDef`)
   - Does the app use Nexus? (check for `NexusPlatform`, workflow registration, multi-channel endpoints)

2. **Ask the human (explain implications of each choice)**

   For each question, explain what the options mean and recommend based on context:

   - **How should we release this?** Explain: "A package release means other developers can install your software. A cloud deployment means users access it via a website or app. You might need both."
   - **Where should we host it?** Don't just list "AWS, Azure, GCP" — explain: "AWS is the most widely used with the broadest services. Azure works well if your organization already uses Microsoft tools. GCP is strong for data and AI. All three are fine — do you have existing accounts or preferences?"
   - **What about costs?** Provide estimates where possible: "A basic cloud setup typically costs $X-Y/month. The main costs are [explain]. Want me to look at budget-friendly options?"
   - **Domain and security**: Explain in practical terms: "Do you have a website address (domain name) for this? If not, we can set one up. We'll automatically set up secure connections (HTTPS) so your users' data is protected."
   - **Monitoring**: "Should we set up alerts so you're notified if the app goes down or has problems? I'd recommend this for anything user-facing."
   - **Kailash-specific (if applicable)**:
     - If DataFlow: Database provider preference? (managed PostgreSQL, self-hosted MySQL, SQLite for dev only, MongoDB)
     - If Nexus: API domain? Reverse proxy preference (nginx, Caddy, cloud ALB)? CORS configuration?
     - If Kaizen: LLM provider? (OpenAI, Anthropic, Ollama for local) GPU/ML inference requirements?
     - If Enterprise: RBAC/ABAC storage backend? Audit log retention policy?

3. **Research current best practices**
   - Use web search for current provider-specific guidance
   - Use CLI help for current command syntax
   - Do NOT rely on encoded knowledge — providers change constantly

4. **Create `deploy/deployment-config.md`**
   - Document all decisions with rationale
   - Include step-by-step deployment runbook
   - Include rollback procedure
   - Include production checklist

5. **STOP — present to human for review**

### If `deploy/deployment-config.md` EXISTS → Execute Mode

Read the config and execute the appropriate track:

#### Package Release Track

1. **Pre-release prep**
   - Update README.md and CHANGELOG.md
   - Build docs (sphinx/mkdocs if configured)
   - Run full test suite
   - Security review

2. **Git workflow**
   - Stage all changes
   - Commit with conventional message: `chore: release vX.Y.Z`
   - Push (or create PR if protected branch)
   - Watch CI, merge when green

3. **Publish**
   - GitHub Release with tag
   - PyPI publish (if configured): `python -m build && twine upload dist/*.whl`
   - Verify: `pip install package==X.Y.Z` in clean venv

#### Cloud Deployment Track

1. **Pre-deploy**
   - Run full test suite
   - Security review
   - Build artifacts (Docker image, etc.)

2. **Authenticate**
   - CLI SSO login (aws sso login / az login / gcloud auth login)
   - Verify correct account and region

3. **Deploy**
   - Follow the runbook in deployment-config.md
   - Use CLI commands — research current syntax if unsure
   - Human approval gate before each destructive operation

4. **Verify**
   - Health checks pass
   - SSL working
   - Monitoring receiving data
   - Run smoke tests against production

5. **Report**
   - Document deployment in `deploy/deployments/YYYY-MM-DD-vX.Y.Z.md`
   - Note any issues encountered

## Agent Teams

- **deployment-specialist** — Analyze codebase, run onboarding, guide deployment
- **git-release-specialist** — Git workflow, PR creation, version management
- **security-reviewer** — Pre-deployment security audit (MANDATORY)
- **testing-specialist** — Verify test coverage before deploy

## Critical Rules

- NEVER hardcode cloud credentials — use CLI SSO only
- NEVER deploy without running tests first
- NEVER skip security review before deploy
- NEVER hot-patch containers with `docker cp` — always rebuild the image
- NEVER use `--no-cache` in normal builds — use the GIT_HASH ARG cache buster instead
- ALWAYS get human approval before destructive cloud operations
- ALWAYS run staging before production (`bash deploy/scripts/stage.sh`)
- ALWAYS document deployments in `deploy/deployments/`
- Research current CLI syntax — do not assume stale knowledge is correct

**Automated enforcement**:
- `validate-deployment.js` hook blocks commits containing cloud credentials in deployment files
- `validate-prod-deploy.js` hook blocks production Docker commands unless `.staging-passed` is current

## Deploy Script Templates

`deploy/` contains templates for standard deployment patterns. Copy and customize for the project:

| Template | Purpose |
|----------|---------|
| `deploy/scripts/deploy.sh.template` | Production deploy with staging gate |
| `deploy/scripts/stage.sh.template` | Staging verification — writes `.staging-passed` on pass |
| `deploy/scripts/dev.sh.template` | Start local development environment |
| `deploy/scripts/promote.sh.template` | Full pipeline: staging then production |
| `deploy/Dockerfile.template` | GIT_HASH cache-busted multi-stage Dockerfile |
| `deploy/docker-compose.prod.yml.template` | Production compose (no volume mounts, no exposed DB ports) |
| `deploy/docker-compose.dev.yml.template` | Development compose (with volume mounts, loopback DB ports) |
| `deploy/nginx-spa.conf.template` | nginx with no-cache on index.html for SPAs |

Replace all `{{PLACEHOLDER}}` values with project-specific values when instantiating a template.
