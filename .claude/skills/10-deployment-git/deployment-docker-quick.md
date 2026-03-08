---
name: deployment-docker-quick
description: "Docker deployment quick start for Rust binaries. Use when asking 'docker deployment', 'containerize kailash', or 'docker setup'."
---

# Docker Deployment Quick Start

> **Skill Metadata**
> Category: `deployment`
> Priority: `HIGH`

## Multi-Stage Dockerfile

```dockerfile
# Stage 1: Build
FROM rust:1.82-slim AS builder

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy workspace manifests for dependency caching
COPY Cargo.toml Cargo.lock ./
COPY crates/ crates/

# Build release binary
RUN cargo build --release --bin my-service

# Stage 2: Runtime (minimal image)
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates libssl3 curl \
    && rm -rf /var/lib/apt/lists/*

# Non-root user
RUN useradd -r -s /bin/false appuser
USER appuser

COPY --from=builder /app/target/release/my-service /usr/local/bin/

# Expose API port (Nexus default: 3000)
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:3000/health || exit 1

CMD ["my-service"]
```

## Application Setup

```rust
// src/main.rs
use kailash_nexus::prelude::*;
use serde_json::json;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenvy::dotenv().ok();

    let mut app = Nexus::new().preset(Preset::Standard);

    app.handler("greet", |name: String| async move {
        Ok(json!({ "message": format!("Hello, {}!", name) }))
    });

    app.start().await?;
    Ok(())
}
```

## Build and Run

```bash
# Build image
docker build -t my-kailash-app .

# Run container
docker run -p 3000:3000 \
  -e OPENAI_API_KEY=${OPENAI_API_KEY} \
  -e DATABASE_URL=${DATABASE_URL} \
  my-kailash-app

# Access API
curl http://localhost:3000/health
```

## Docker Compose

```yaml
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}
      - RUNTIME_TYPE=async
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:15
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
```

```bash
# Run with Docker Compose
docker-compose up -d

# View logs
docker-compose logs -f app
```

## Production Considerations

1. **Multi-stage builds** - Final image ~50MB vs ~2GB for build stage
2. **Static linking** - Use `x86_64-unknown-linux-musl` target for fully static binaries
3. **Non-root user** - Security best practice
4. **Health checks** - `/health` endpoint via Nexus
5. **Environment variables** - All secrets from .env or Docker secrets
6. **Volume mounts** - For persistent data
7. **Cold start** - Rust binary starts in ~10ms (vs seconds for Python)

## Static Binary with Alpine

```dockerfile
FROM rust:1.82-alpine AS builder
RUN apk add --no-cache musl-dev openssl-dev openssl-libs-static
WORKDIR /app
COPY . .
RUN cargo build --release --target x86_64-unknown-linux-musl

FROM alpine:3.19
RUN apk add --no-cache ca-certificates && \
    adduser -D -s /bin/false appuser
USER appuser
COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/my-service /usr/local/bin/
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["my-service"]
```

<!-- Trigger Keywords: docker deployment, containerize kailash, docker setup, kailash docker, multi-stage build, rust docker -->
