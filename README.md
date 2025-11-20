# PickStream Application

[![CI/CD Pipeline](https://github.com/gcpt0801/pickstream-app/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/gcpt0801/pickstream-app/actions/workflows/ci-cd.yml)

PickStream is a microservices-based random name selection application deployed on Google Kubernetes Engine (GKE). This repository contains the application code, Helm charts, and unified CI/CD pipeline for automated deployments.

## 🏗️ Architecture

```
┌─────────────────┐
│   Ingress       │
│  (nginx)        │
└────────┬────────┘
         │
    ┌────┴─────┐
    │          │
┌───▼──────┐ ┌─▼──────────┐
│ Frontend │ │  Backend   │
│ (Nginx)  │ │ (Spring    │
│          │ │  Boot)     │
└──────────┘ └────────────┘
```

### Components

- **Backend**: Spring Boot 3.2.0 REST API (Java 17)
  - Random name selection service
  - In-memory name storage
  - Prometheus metrics
  - Health checks

- **Frontend**: Nginx-served static web application
  - Modern UI with gradient design
  - Real-time API communication
  - Responsive layout

- **Infrastructure**: Kubernetes resources managed via Helm
  - Horizontal Pod Autoscaling
  - Network Policies
  - Service Mesh ready

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose
- Java 17+ (for local backend development)
- Maven 3.9+ (for backend builds)
- kubectl (for Kubernetes deployments)
- Helm 3.13+ (for chart deployments)
- gcloud CLI (for GKE access)

### Local Development

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/pickstream-app.git
   cd pickstream-app
   ```

2. **Start services with Docker Compose**
   ```bash
   ./scripts/local-dev.sh start
   ```

3. **Access the application**
   - Frontend: http://localhost:8081
   - Backend API: http://localhost:8080
   - Health Check: http://localhost:8080/actuator/health
   - Metrics: http://localhost:8080/actuator/prometheus

4. **View logs**
   ```bash
   ./scripts/local-dev.sh logs
   ```

5. **Stop services**
   ```bash
   ./scripts/local-dev.sh stop
   ```

## 📦 Deployment

### GKE Deployment with Helm

1. **Configure kubectl**
   ```bash
   gcloud container clusters get-credentials pickstream-cluster \
     --zone=us-central1-a \
     --project=your-gcp-project-id
   ```

2. **Deploy to development**
   ```bash
   helm upgrade --install pickstream ./helm/pickstream \
     --namespace pickstream \
     --create-namespace \
     --values ./helm/pickstream/values.yaml \
     --values ./helm/pickstream/values-dev.yaml \
     --set global.projectId=your-gcp-project-id
   ```

3. **Verify deployment**
   ```bash
   kubectl get pods -n pickstream
   kubectl get svc -n pickstream
   kubectl get ingress -n pickstream
   ```

### Using GitHub Actions

Deployments are automated via GitHub Actions:

- **Backend CI**: Triggered on push to `services/backend/**`
- **Frontend CI**: Triggered on push to `services/frontend/**`
- **Deploy Dev**: Automatic on merge to `main`
- **Deploy Staging**: Manual trigger with image tag selection
- **Deploy Prod**: Manual trigger with confirmation required

## 🛠️ Development

### Backend Development

```bash
cd services/backend

# Run tests
./mvnw test

# Run locally
./mvnw spring-boot:run

# Build Docker image
docker build -t pickstream-backend .
```

### Frontend Development

```bash
cd services/frontend

# Test locally with Docker
docker build -t pickstream-frontend .
docker run -p 8080:80 pickstream-frontend
```

## 📚 Documentation

- [API Documentation](docs/API.md) - REST API endpoints and examples
- [Deployment Guide](docs/DEPLOYMENT.md) - Detailed deployment instructions
- [Local Development](docs/LOCAL_DEVELOPMENT.md) - Local setup guide

## 🔧 Configuration

### Environment Variables

**Backend**:
- `SPRING_PROFILES_ACTIVE`: Active Spring profile (development/production)
- `LOGGING_LEVEL_COM_PICKSTREAM`: Log level for application

**Frontend**:
- `BACKEND_SERVICE_HOST`: Backend service hostname
- `BACKEND_SERVICE_PORT`: Backend service port

### GitHub Secrets Required

Configure these secrets in your GitHub repository:

- `GCP_PROJECT_ID`: Google Cloud project ID
- `WIF_PROVIDER`: Workload Identity Federation provider
- `WIF_SERVICE_ACCOUNT`: Service account for WIF

## 🧪 Testing

### Backend Tests

```bash
cd services/backend
./mvnw test
./mvnw verify  # Integration tests
```

### Smoke Tests

```bash
# Test backend health
curl http://localhost:8080/api/health

# Get random name
curl http://localhost:8080/api/random-name

# Add a name
curl -X POST "http://localhost:8080/api/random-name?name=John"

# List all names
curl http://localhost:8080/api/names

# Delete a name
curl -X DELETE "http://localhost:8080/api/names/John"
```

## 📊 Monitoring

### Prometheus Metrics

Backend exposes Prometheus metrics at `/actuator/prometheus`:

```bash
# Port forward to access metrics locally
kubectl port-forward -n pickstream svc/pickstream-backend 8080:8080
curl http://localhost:8080/actuator/prometheus
```

### Health Checks

- Backend: `/actuator/health`
- Frontend: `/health`

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🔗 Related Repositories

- [pickstream-infrastructure](https://github.com/yourusername/pickstream-infrastructure) - Terraform for GKE cluster provisioning

## 📞 Support

For issues and questions, please open an issue on GitHub.

---

Built with ❤️ using Spring Boot, Docker, Kubernetes, and Helm
