---
name: deployment-patterns
description: "Docker and Kubernetes deployment patterns for Rust applications. Use for 'Docker Compose', 'Kubernetes deployment', 'container orchestration', 'health checks', or 'secrets management'."
---

# Deployment Patterns

> **Skill Metadata**
> Category: `deployment`
> Priority: `HIGH`
> Technologies: Docker, Docker Compose, Kubernetes

## Docker Compose Service Architecture

```yaml
services:
  # Kailash Nexus API Service
  backend:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: ${PROJECT_NAME}_backend
    environment:
      - ENVIRONMENT=${ENVIRONMENT:-production}
      - DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      - REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379/0
      - JWT_SECRET=${JWT_SECRET}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - RUNTIME_TYPE=async
    ports:
      - "${BACKEND_PORT:-3000}:3000"
    volumes:
      - backend_logs:/var/log/app
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - app_frontend
      - app_backend
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: "4"
          memory: 2G
        reservations:
          cpus: "1"
          memory: 512M
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 5s

  # PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    container_name: ${PROJECT_NAME}_postgres
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_HOST_AUTH_METHOD: scram-sha-256
    # SECURITY: Remove port mapping in production — only expose via app_backend network
    ports:
      - "${POSTGRES_PORT:-5432}:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 20s
    networks:
      - app_backend
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: "2"
          memory: 4G

  # Redis Cache
  redis:
    image: redis:7-alpine
    container_name: ${PROJECT_NAME}_redis
    # SECURITY: Remove port mapping in production — only expose via app_backend network
    ports:
      - "${REDIS_PORT:-6379}:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - app_backend
    restart: unless-stopped
    command: >
      redis-server
      --appendonly yes
      --appendfsync everysec
      --maxmemory 1gb
      --maxmemory-policy allkeys-lru
      --requirepass ${REDIS_PASSWORD}

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
  backend_logs:
    driver: local

networks:
  app_frontend:
    driver: bridge
  app_backend:
    driver: bridge
    internal: true
```

## Environment Configuration Template

```bash
# ==============================================================================
# APPLICATION ENVIRONMENT
# ==============================================================================

ENVIRONMENT=production

# ==============================================================================
# DATABASE CONFIGURATION (PostgreSQL)
# ==============================================================================

POSTGRES_DB=app_db
POSTGRES_USER=app_user
POSTGRES_PASSWORD=               # REQUIRED — generate with: openssl rand -hex 16
POSTGRES_PORT=5432

# ==============================================================================
# REDIS CONFIGURATION
# ==============================================================================

REDIS_PASSWORD=               # REQUIRED — generate with: openssl rand -hex 16
REDIS_PORT=6379

# ==============================================================================
# AUTHENTICATION AND SECURITY
# ==============================================================================

# Generate with: openssl rand -hex 32
JWT_SECRET=                    # REQUIRED — generate with: openssl rand -hex 32

# ==============================================================================
# AI/LLM CONFIGURATION
# ==============================================================================

OPENAI_API_KEY=                # REQUIRED — your OpenAI API key
DEFAULT_LLM_MODEL=             # Set to your preferred model (e.g. gpt-4o, claude-sonnet-4-20250514)

# ==============================================================================
# CORS AND FRONTEND
# ==============================================================================

CORS_ORIGINS=http://localhost:3000,https://app.yourdomain.com

# ==============================================================================
# SERVICE PORTS
# ==============================================================================

BACKEND_PORT=3000

# ==============================================================================
# SECURITY NOTES
# ==============================================================================
# 1. NEVER commit .env files to version control
# 2. Generate secrets with: openssl rand -hex 32
# 3. Use secrets management tools (Vault, AWS Secrets Manager)
# 4. Rotate secrets regularly
```

## Secret Generation Commands

```bash
# JWT Secret Key (32 bytes = 64 hex characters)
openssl rand -hex 32

# Database Password (16 bytes = 32 hex characters)
openssl rand -hex 16

# Redis Password (16 bytes = 32 hex characters)
openssl rand -hex 16
```

## Kubernetes Deployment

### Backend Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    app: backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: your-registry/kailash-service:latest
          ports:
            - containerPort: 3000
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: database-url
            - name: JWT_SECRET
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: jwt-secret
            - name: RUNTIME_TYPE
              value: "async"
          envFrom:
            - configMapRef:
                name: app-config
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 1000m
              memory: 512Mi
          livenessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 3
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  selector:
    app: backend
  ports:
    - protocol: TCP
      port: 3000
      targetPort: 3000
  type: ClusterIP
```

### Horizontal Pod Autoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend
  minReplicas: 3
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

## Health Check Patterns

### Application Health Endpoints (Rust/axum)

```rust
use axum::{Json, routing::get, Router};
use serde_json::json;

async fn health_check() -> Json<serde_json::Value> {
    Json(json!({"status": "healthy"}))
}

async fn readiness_check(
    pool: axum::extract::Extension<sqlx::PgPool>,
) -> Result<Json<serde_json::Value>, axum::http::StatusCode> {
    sqlx::query("SELECT 1")
        .execute(pool.as_ref())
        .await
        .map_err(|_| axum::http::StatusCode::SERVICE_UNAVAILABLE)?;

    Ok(Json(json!({"status": "ready"})))
}

// Register in Nexus or raw axum router
let router = Router::new()
    .route("/health", get(health_check))
    .route("/ready", get(readiness_check));
```

## Common Deployment Workflows

### Initial Setup (Docker Compose)

```bash
# 1. Copy environment template
cp .env.example .env

# 2. Generate secure secrets
JWT_SECRET=$(openssl rand -hex 32)
POSTGRES_PASSWORD=$(openssl rand -hex 16)
REDIS_PASSWORD=$(openssl rand -hex 16)

# 3. Update .env file with generated secrets
# 4. Start services
docker-compose up -d

# 5. Check service health
docker-compose ps
curl http://localhost:3000/health
```

### Production Deployment (Kubernetes)

```bash
# 1. Create namespace
kubectl create namespace production

# 2. Create secrets (use generated values — NEVER hardcode credentials)
kubectl create secret generic app-secrets \
  --from-literal=database-url="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}" \
  --from-literal=jwt-secret="$(openssl rand -hex 32)" \
  --namespace=production

# 3. Apply deployments
kubectl apply -f k8s/ -n production

# 4. Verify
kubectl get pods -n production
```

## Troubleshooting Commands

```bash
# Check logs
docker-compose logs -f backend
kubectl logs -f deployment/backend -n production

# Check health
docker-compose ps
kubectl get pods -n production

# Verify environment variables
docker-compose exec backend env | grep DATABASE_URL

# Check resource usage
docker stats
kubectl top pods -n production
```

<!-- Trigger Keywords: Docker Compose, Kubernetes deployment, container orchestration, health checks, secrets management, docker deployment, k8s deployment, environment variables, docker secrets, kubernetes secrets -->
