---
name: deployment-kubernetes-quick
description: "Kubernetes deployment basics. Use when asking 'kubernetes deployment', 'k8s kailash', or 'kubernetes setup'."
---

# Kubernetes Deployment Quick Start

> **Skill Metadata**
> Category: `deployment`
> Priority: `LOW`

## Kubernetes Manifests

### Deployment

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kailash-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: kailash-app
  template:
    metadata:
      labels:
        app: kailash-app
    spec:
      containers:
        - name: app
          image: my-kailash-app:latest
          ports:
            - containerPort: 3000
          env:
            - name: OPENAI_API_KEY
              valueFrom:
                secretKeyRef:
                  name: kailash-secrets
                  key: openai-api-key
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: kailash-secrets
                  key: database-url
            - name: RUNTIME_TYPE
              value: "async"
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
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
```

### Service

```yaml
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: kailash-app
spec:
  type: LoadBalancer
  selector:
    app: kailash-app
  ports:
    - port: 80
      targetPort: 3000
```

### ConfigMap

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kailash-config
data:
  environment: production
  log-level: info
```

### Secret

```yaml
# secret.yaml — EXAMPLE ONLY, use `kubectl create secret` or external secrets manager in production
apiVersion: v1
kind: Secret
metadata:
  name: kailash-secrets
type: Opaque
data:
  openai-api-key: <base64-encoded-key>
  database-url: <base64-encoded-url>   # e.g. base64 of postgresql://user:pass@db:5432/mydb
```

## Deployment Commands

```bash
# Apply manifests
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml

# Check status
kubectl get pods
kubectl get services

# View logs
kubectl logs -f deployment/kailash-app

# Scale replicas
kubectl scale deployment kailash-app --replicas=5
```

## Kailash Framework Notes

- **Nexus** serves on port 3000 by default with a built-in `/health` endpoint
- **DataFlow** requires `DATABASE_URL` — pass via Secret, not ConfigMap
- **Kaizen** agents may need `OPENAI_API_KEY` or other LLM provider keys
- **RUNTIME_TYPE=async** is recommended for all Kailash deployments (Rust async runtime)
- Rust binary cold-starts in ~10ms — set low `initialDelaySeconds` on probes

## Best Practices

1. **Health checks** - Liveness and readiness probes (Nexus provides `/health`)
2. **Resource limits** - Set memory/CPU limits (Rust binaries are lightweight: 128Mi-512Mi typical)
3. **Secrets** - Use Kubernetes secrets or external secrets manager (Vault, AWS Secrets Manager) for credentials
4. **ConfigMaps** - For non-sensitive configuration only
5. **Horizontal scaling** - Multiple replicas with HPA
6. **Rolling updates** - Zero-downtime deployments

<!-- Trigger Keywords: kubernetes deployment, k8s kailash, kubernetes setup, k8s workflows -->
