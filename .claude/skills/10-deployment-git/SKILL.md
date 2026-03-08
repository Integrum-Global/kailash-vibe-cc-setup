---
name: deployment-git
description: "Deployment and Git workflow guides for Kailash Rust applications including Docker multi-stage builds, Kubernetes orchestration, Git workflows, deployment onboarding, cloud deployment, and package releases. Use when asking about 'deployment', 'Docker deployment', 'Kubernetes deployment', 'containerization', 'K8s', 'Git workflow', 'Git branching', 'CI/CD', 'production deployment', 'Docker compose', 'container orchestration', 'deploy command', 'cloud deployment', 'package release', or 'deployment onboarding'."
---

# Deployment & Git Workflows

Deployment patterns and Git workflows for the Kailash Rust SDK.

## Overview

Production deployment patterns for:

- Docker multi-stage builds (Rust → minimal runtime image)
- Kubernetes orchestration
- Git workflows and branching strategies
- CI/CD with cargo and self-hosted runners
- Environment management

## Reference Documentation

### Deployment Lifecycle

- **[deployment-onboarding](deployment-onboarding.md)** - Deployment onboarding process
  - Codebase analysis
  - Structured questions for human architect
  - Research current best practices
  - Create deployment-config.md

- **[deployment-packages](deployment-packages.md)** - Package release workflow
  - PyPI and GitHub release process
  - Version bumping and changelog
  - CI-triggered releases
  - Rollback procedures

- **[deployment-cloud](deployment-cloud.md)** - Cloud deployment principles
  - CLI SSO authentication (AWS, Azure, GCP)
  - Managed vs self-hosted decisions
  - Right-sizing and cost optimization
  - SSL, monitoring, security baseline

### Docker Deployment

- **[deployment-docker-quick](deployment-docker-quick.md)** - Docker multi-stage builds for Rust binaries
- **[deployment-patterns](deployment-patterns.md)** - Docker Compose, K8s manifests, health checks

### Kubernetes Deployment

- **[deployment-kubernetes-quick](deployment-kubernetes-quick.md)** - K8s deployment manifests and scaling

### Git Workflow

- **[git-workflow-quick](git-workflow-quick.md)** - Branch strategy and commit conventions
- **[git-release-patterns](git-release-patterns.md)** - Pre-commit validation, release procedures, cargo publish

### Project Management

- **[github-management-patterns](github-management-patterns.md)** - GitHub issues, PRs, project boards
- **[project-management](project-management.md)** - Dual-tracking system (GitHub + local todos)
- **[todo-github-sync](todo-github-sync.md)** - Todo/GitHub sync patterns

## Docker Quick Reference

### Multi-Stage Rust Dockerfile

```dockerfile
FROM rust:1.82-slim AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/*
COPY . .
RUN cargo build --release --bin my-service

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates libssl3 curl \
    && rm -rf /var/lib/apt/lists/*
RUN useradd -r -s /bin/false appuser
USER appuser
COPY --from=builder /app/target/release/my-service /usr/local/bin/
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s CMD curl -f http://localhost:3000/health || exit 1
CMD ["my-service"]
```

## Pre-Commit Quality Pipeline

```bash
cargo fmt --all --check && \
cargo clippy --workspace -- -D warnings && \
cargo test --workspace && \
cargo audit
```

## Critical Rules

### Docker

- Use multi-stage builds (final image ~50MB)
- Rust binaries cold-start in ~10ms
- Unified Runtime (no sync/async split)
- Implement health checks via Nexus `/health`
- Use secrets for sensitive data
- NEVER commit secrets to images
- NEVER run as root user

### Git

- Use conventional commits: `feat(core): description`
- Pre-commit validation is MANDATORY
- Security review before EVERY commit
- NEVER commit directly to main
- NEVER force push to shared branches

## Related Skills

- **[03-nexus](../03-nexus/)** - Nexus API server deployment
- **[02-dataflow](../02-dataflow/)** - DataFlow database configuration
- **[01-core](../01-core/)** - Runtime execution patterns
- **[26-gold-standards](../26-gold-standards/)** - Standards and best practices

## Support

For deployment help, invoke:

- `deployment-specialist` - Deployment onboarding, package/cloud releases, Docker, K8s, CI runners
- `git-release-specialist` - Git workflows, cargo publish, CI pipeline
- `nexus-specialist` - Nexus server configuration
