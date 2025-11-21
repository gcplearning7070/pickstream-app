# Pickstream Application

A simple microservices application that demonstrates deployment to Google Kubernetes Engine (GKE) using Helm and automated CI/CD.

## What Does This Application Do?

Pickstream displays random names from a list. It's designed to teach:
- Microservices architecture
- Containerization with Docker
- Kubernetes deployment
- Automated CI/CD pipelines

## Architecture

```
Browser  ──────▶  Frontend (Nginx)  ──────▶  Backend (Spring Boot)
                       │
                       ▼
                 Static UI Files
                 
Backend API:
- GET /api/random-name  - Get a random name
- GET /api/names        - List all names  
- GET /api/health       - Health check
```

## Project Structure

```
pickstream-app/
├── .github/workflows/     # CI/CD pipeline
│   └── ci-cd.yml         # Automated build and deploy
├── services/             # Application code
│   ├── backend/         # Spring Boot API
│   └── frontend/        # Nginx + HTML/CSS/JS
├── helm/                # Kubernetes deployment
│   └── pickstream/      # Helm chart
├── docs/                # Documentation
└── docker-compose.yml   # Local development
```

## Quick Start

### Run Locally

```bash
# Start both services
docker-compose up

# Access at http://localhost:8081
```

Backend runs on port 8080, frontend on 8081.

### Deploy to GKE (Automatic)

**Just push to main branch!** The CI/CD pipeline automatically:
1. Builds Docker images
2. Pushes to Artifact Registry
3. Deploys to your GKE cluster

**Required GitHub Secrets:**
- `WIF_PROVIDER` - Workload Identity Federation provider
- `WIF_SERVICE_ACCOUNT` - GCP service account
- `GCP_PROJECT_ID` - Your GCP project

## How It Works

### CI/CD Pipeline

When you push to main:
1. **Authenticate** - Uses Workload Identity (no keys needed!)
2. **Build** - Creates Docker images for backend and frontend
3. **Push** - Uploads images to Google Artifact Registry
4. **Deploy** - Uses Helm to deploy to GKE
5. **Verify** - Checks that everything is running

### Kubernetes Setup

The Helm chart creates:
- **Namespace:** `pickstream` (isolates resources)
- **Backend Deployment:** 1 pod with Spring Boot (autoscaling enabled)
- **Frontend Deployment:** 1 pod with Nginx (autoscaling enabled)
- **Backend Service:** Internal (ClusterIP)
- **Frontend Service:** External (LoadBalancer)
- **Service Account:** For pod identity

### Accessing Your Application

After deployment:
```bash
# Get the external IP
kubectl get svc pickstream-frontend -n pickstream

# Look for EXTERNAL-IP and open in browser
```

## Making Changes

### Update the UI
1. Edit `services/frontend/public/index.html` or `services/frontend/public/js/app.js`
2. Push to main
3. CI/CD builds and deploys automatically

### Update the API  
1. Edit Java code in `services/backend/src/main/java/com/pickstream/`
2. Push to main
3. CI/CD builds and deploys automatically

### Change Deployment Settings
1. Edit `helm/pickstream/values.yaml`
2. Push to main
3. CI/CD applies changes

## Monitoring

### View Running Pods
```bash
kubectl get pods -n pickstream
```

### Check Logs
```bash
# Backend
kubectl logs -n pickstream -l app.kubernetes.io/component=backend

# Frontend
kubectl logs -n pickstream -l app.kubernetes.io/component=frontend
```

### Test the Backend Directly
```bash
# Port forward
kubectl port-forward -n pickstream svc/pickstream-backend 8080:8080

# Test API
curl http://localhost:8080/api/random-name
```

## Common Issues

**Pods not starting?**
- Check image pull permissions
- View pod details: `kubectl describe pod <pod-name> -n pickstream`

**502 Bad Gateway?**
- Backend might not be ready yet
- Check backend logs

**Can't access application?**
- Verify LoadBalancer has external IP: `kubectl get svc -n pickstream`
- Check firewall rules allow HTTP traffic

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for detailed solutions.

## Technology Stack

**Backend:**
- Spring Boot 3.2.0
- Java 17
- Maven

**Frontend:**
- Nginx Alpine
- HTML, CSS, JavaScript

**Infrastructure:**
- Google Kubernetes Engine (GKE)
- Google Artifact Registry
- Helm 3
- GitHub Actions
- Workload Identity Federation

## Learn More

- **Services Guide:** [services/README.md](services/README.md)
- **Helm Charts:** [helm/README.md](helm/README.md)
- **Troubleshooting:** [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- **Infrastructure:** [docs/INFRASTRUCTURE_AUTOMATION.md](docs/INFRASTRUCTURE_AUTOMATION.md)

## Prerequisites

**For Local Development:**
- Docker and Docker Compose

**For GKE Deployment:**
- GCP project with GKE cluster
- Artifact Registry repository  
- Workload Identity Federation configured
- GitHub repository secrets configured

---

Built for learning microservices, Kubernetes, and CI/CD! 🚀
