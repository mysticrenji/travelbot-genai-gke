# Simple GenAI Travel Assistant Bot

A lightweight AI-powered travel assistant built with Google ADK, Vertex AI (Gemini), FastAPI, and Streamlit, deployed on Google Kubernetes Engine (GKE).

## Features

- Interactive travel assistant powered by Gemini 2.5 Pro
- FastAPI backend with Google ADK integration
- Clean Streamlit UI for easy interaction
- Cloud-native deployment on GKE with Config Connector
- Secure authentication using Workload Identity
- Containerized with Docker

A complete walkthrough is available on [Medium](https://renjithvr11.medium.com/building-a-simple-travel-assistant-with-google-adk-and-gemini-on-gke-38d58a5a42fc)

## Architecture

![Architecture](./img/travelbot_arch.png)

The application consists of two components:

1. **Backend (FastAPI)**: REST API that processes chat requests using Google ADK and Vertex AI
2. **Frontend (Streamlit)**: User interface that communicates with the backend

Both pods use the Kubernetes Service Account `adk-ksa`, which is:
- Linked to a Google Service Account (`adk-bot-sa`) via Workload Identity
- Image pulling is handled by the GKE Autopilot node SA with `roles/artifactregistry.reader` (no `imagePullSecrets` needed)

## Prerequisites

- Google Cloud Platform account with billing enabled
- GKE Autopilot cluster with **Workload Identity** and **Config Connector** enabled
- `gcloud` CLI configured
- `kubectl` configured to connect to your GKE cluster
- Docker installed locally
- Python 3.10+ (for local development)

## Project Structure

```
simple-genai-bot/
├── src/
│   ├── backend/
│   │   ├── main.py              # FastAPI backend with Google ADK
│   │   └── Dockerfile           # Backend container definition
│   └── frontend/
│       ├── frontend.py          # Streamlit UI application
│       └── Dockerfile.frontend  # Frontend container definition
├── k8s/
│   ├── deployment.yaml          # Full K8s deployment with Config Connector
├── requirements.txt             # Python dependencies for backend
├── .env                         # Environment variables (PROJECT_ID, NAMESPACE)
├── .gitignore                   # Git ignore patterns
├── run-local.sh                 # Run both services locally
├── docker-push.sh               # Build and push Docker images to GCR
└── README.md                    # This file
```

## Setup and Deployment

### 1. Clone the Repository

```bash
git clone <repository-url>
cd simple-genai-bot
```

### 2. Configure Environment

Update `.env` with your Google Cloud Project ID:

```bash
PROJECT_ID="your-project-id"
NAMESPACE="genai-bot"
```

### 3. Update Kubernetes Manifests

The k8s manifests use placeholders that need to be replaced with your actual values. Get your project number:

```bash
export PROJECT_ID="your-project-id"
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
```

Then replace the placeholders in both manifest files:

```bash
sed -i "s/YOUR_PROJECT_ID/$PROJECT_ID/g" k8s/deployment.yaml k8s/iam-k8s.yaml
sed -i "s/YOUR_PROJECT_NUMBER/$PROJECT_NUMBER/g" k8s/deployment.yaml k8s/iam-k8s.yaml
```

### 4. Enable Required Google Cloud APIs

```bash
gcloud config set project $PROJECT_ID

gcloud services enable \
    aiplatform.googleapis.com \
    container.googleapis.com \
    artifactregistry.googleapis.com \
    iamcredentials.googleapis.com
```

### 5. Build and Push Docker Images

```bash
./docker-push.sh        # Builds and pushes both images with tag v1
./docker-push.sh v2     # Or specify a custom tag
```

This script will:
- Configure Docker authentication with GCR (backed by Artifact Registry)
- Build backend image (`gcr.io/$PROJECT_ID/adk-bot:<tag>`)
- Build frontend image (`gcr.io/$PROJECT_ID/adk-frontend:<tag>`)
- Push both images to Artifact Registry

### 6. Create Namespace

```bash
kubectl create namespace genai-bot
```

### 7. Deploy to Kubernetes

```bash
kubectl apply -f k8s/deployment.yaml
```

This creates the following resources via Config Connector:
- **IAMServiceAccount**: Google Service Account `adk-bot-sa`
- **IAMPolicyMember** (Vertex AI): Grants `roles/aiplatform.user` to `adk-bot-sa`
- **IAMPolicyMember** (Artifact Registry - node): Grants `roles/artifactregistry.reader` to GKE Autopilot node SA (for image pulling)
- **IAMPolicyMember** (Artifact Registry - bot): Grants `roles/artifactregistry.reader` to `adk-bot-sa`
- **IAMPolicyMember** (Workload Identity): Binds K8s SA to Google SA

And the following Kubernetes resources:
- **ServiceAccount** `adk-ksa`: With Workload Identity annotation (no `imagePullSecrets` needed)
- **Deployment** `adk-backend`: FastAPI + Google ADK
- **Service** `adk-backend`: ClusterIP (internal)
- **Deployment** `adk-frontend`: Streamlit UI
- **Service** `adk-frontend-service`: LoadBalancer (external)

> **Note**: GCR (`gcr.io`) is backed by Artifact Registry. Image pulling on GKE Autopilot is handled by the node's Compute Engine default SA with `roles/artifactregistry.reader` - no image pull secrets or SA key files are needed.

### 8. Verify Deployment

```bash
# Check Config Connector resources (may take 2-3 minutes)
kubectl get iamserviceaccount,iampolicymember -n genai-bot

# Check pods
kubectl get pods -n genai-bot

# Check services and get external IP
kubectl get services -n genai-bot
```

### 9. Access the Application

```bash
EXTERNAL_IP=$(kubectl get service adk-frontend-service -n genai-bot \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Access the app at: http://$EXTERNAL_IP"
```

## Local Development

The easiest way to run locally (requires gcloud CLI configured with your project):

```bash
./run-local.sh
```

This starts both backend and frontend, using your gcloud Application Default Credentials for Vertex AI authentication.

- Backend: http://localhost:8080 (API docs at http://localhost:8080/docs)
- Frontend: http://localhost:8501
- Press `Ctrl+C` to stop both services

## API Endpoints

| Method | Endpoint  | Description                    |
|--------|-----------|--------------------------------|
| POST   | `/chat`   | Send a prompt to the AI agent  |
| GET    | `/health` | Health check                   |

**POST /chat** example:
```json
// Request
{ "prompt": "What are the best places to visit in Japan?" }

// Response
{ "response": "Japan offers amazing destinations like Tokyo, Kyoto, Osaka..." }
```

## Troubleshooting

### Image pull errors (ErrImagePull / ImagePullBackOff)

```bash
# Verify Config Connector created the Artifact Registry IAM binding
kubectl get iampolicymember gke-node-ar-access -n genai-bot -o yaml

# Verify the GKE node SA has artifactregistry.reader
gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings[].members" \
    --filter="bindings.role:artifactregistry.reader" \
    --format="table(bindings.role,bindings.members)"

# Check pod events for details
kubectl describe pod <pod-name> -n genai-bot
```

### Pods not starting

```bash
kubectl describe pod <pod-name> -n genai-bot
kubectl logs <pod-name> -n genai-bot
```

### Permission denied (Vertex AI)

```bash
# Verify Workload Identity annotation
kubectl describe sa adk-ksa -n genai-bot

# Verify IAM bindings
gcloud iam service-accounts get-iam-policy \
    adk-bot-sa@$PROJECT_ID.iam.gserviceaccount.com
```

### Frontend can't reach backend

```bash
kubectl get service adk-backend -n genai-bot
```

## Cleanup

```bash
# Delete all Kubernetes resources (Config Connector will clean up GCP resources)
kubectl delete namespace genai-bot

# Optionally delete Docker images from Artifact Registry
gcloud artifacts docker images delete gcr.io/$PROJECT_ID/adk-bot
gcloud artifacts docker images delete gcr.io/$PROJECT_ID/adk-frontend
```

## Technologies Used

| Technology | Purpose |
|------------|---------|
| Google ADK | Agent Development Kit for building AI agents |
| Vertex AI (Gemini 2.5 Pro) | Large language model |
| FastAPI | Backend REST API framework |
| Streamlit | Frontend web application |
| GKE Autopilot + Config Connector | Kubernetes deployment with declarative GCP resource management |
| Workload Identity | Secure pod-to-GCP authentication (Vertex AI access) |
| Artifact Registry (gcr.io) | Private Docker image storage |
| Docker | Containerization |
