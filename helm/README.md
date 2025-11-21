# Helm Charts

This folder contains Kubernetes deployment configurations using Helm.

## What is Helm?

Helm is a package manager for Kubernetes. It uses templates to deploy applications with all their Kubernetes resources (deployments, services, etc.) in one go.

## Structure

```
helm/
└── pickstream/              # Helm chart for the application
    ├── Chart.yaml           # Chart metadata (name, version)
    ├── values.yaml          # Configuration values
    └── templates/           # Kubernetes resource templates
        ├── backend/         # Backend deployment, service, HPA
        ├── frontend/        # Frontend deployment, service, HPA
        ├── namespace.yaml   # Namespace definition
        └── serviceaccount.yaml # Service account for pods
```

## Key Files Explained

### Chart.yaml
Defines chart metadata like name, version, and description.

### values.yaml
Contains all configuration values:
- Image repositories and tags
- Resource limits (CPU, memory)
- Replica counts (1 for each service)
- Autoscaling settings (enabled)
- Service types and ports
- Health check settings

### templates/
Kubernetes YAML files with Go templating:
- `{{ .Values.backend.image.tag }}` - Inserts values from values.yaml
- Allows reusable, configurable deployments

## Deploying Manually

**Prerequisites:**
- kubectl configured for your cluster
- Helm 3 installed

**Deploy:**
```bash
helm upgrade --install pickstream ./helm/pickstream \
  --namespace pickstream \
  --create-namespace \
  --values ./helm/pickstream/values.yaml \
  --set global.projectId=YOUR_GCP_PROJECT_ID \
  --set backend.image.tag=latest \
  --set frontend.image.tag=latest
```

**Check deployment:**
```bash
kubectl get pods -n pickstream
kubectl get svc -n pickstream
```

## Configuration Values

### Common Settings

**Replicas:**
- Base: 1 backend, 1 frontend
- Autoscaling: Scales up based on CPU/memory usage
- Backend: min 1, max 5 pods
- Frontend: min 1, max 3 pods

**Resources:**
Backend needs more CPU/memory than frontend (runs Java application)

**Health Probes:**
- `livenessProbe` - Restarts pod if unhealthy
- `readinessProbe` - Routes traffic only to ready pods
- `startupProbe` - Waits for slow-starting apps

### Important Values

```yaml
# Backend image
backend.image.repository: us-central1-docker.pkg.dev/PROJECT/pickstream/pickstream-backend
backend.image.tag: latest

# Frontend image  
frontend.image.repository: us-central1-docker.pkg.dev/PROJECT/pickstream/pickstream-frontend
frontend.image.tag: latest

# Service type for external access
frontend.service.type: LoadBalancer
```

## Understanding Templates

Templates use Go templating syntax:

```yaml
# Example from backend/deployment.yaml
replicas: {{ .Values.backend.replicaCount }}
image: "{{ .Values.backend.image.repository }}:{{ .Values.backend.image.tag }}"
```

This gets values from `values.yaml`:
```yaml
backend:
  replicaCount: 1
  image:
    repository: us-central1-docker.pkg.dev/project/pickstream/backend
    tag: latest
```

## Automatic Deployment

The CI/CD pipeline automatically deploys when you push to main:
1. Builds Docker images
2. Pushes to Artifact Registry
3. Runs Helm with the git commit SHA as the image tag
4. Waits for deployment to complete

## Troubleshooting

**Check pod status:**
```bash
kubectl get pods -n pickstream
kubectl describe pod <pod-name> -n pickstream
```

**View logs:**
```bash
kubectl logs -n pickstream <pod-name>
kubectl logs -n pickstream -l app.kubernetes.io/component=backend
```

**Check services:**
```bash
kubectl get svc -n pickstream
```

**Get external IP (LoadBalancer):**
```bash
kubectl get svc pickstream-frontend -n pickstream
```

## Best Practices

1. **Always use specific image tags** - Don't rely on `latest` in production
2. **Set resource limits** - Prevents pods from consuming too much
3. **Configure health probes** - Ensures Kubernetes knows when pods are ready
4. **Use namespaces** - Isolates applications from each other
5. **Version your charts** - Update Chart.yaml version when making changes

## Learn More

- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Our Troubleshooting Guide](../docs/TROUBLESHOOTING.md)
