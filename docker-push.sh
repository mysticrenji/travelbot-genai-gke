#!/bin/bash

# Build and push Docker images to Google Container Registry (GCR)
# Usage:
#   ./docker-push.sh          # Builds and pushes both images with version from .env (default: v1)
#   ./docker-push.sh v2       # Builds and pushes both images with tag v2

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load environment variables from .env
if [ -f "$SCRIPT_DIR/.env" ]; then
    export $(cat "$SCRIPT_DIR/.env" | grep -v '^#' | xargs)
else
    echo -e "${RED}Error: .env file not found!${NC}"
    exit 1
fi

if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Error: PROJECT_ID is not set in .env${NC}"
    exit 1
fi

# Image tag from argument or default to v1
TAG="${1:-v1}"

echo -e "${GREEN}Building and pushing images to gcr.io/${PROJECT_ID}${NC}"
echo -e "${GREEN}Tag: ${TAG}${NC}"
echo ""

# Configure Docker to authenticate with GCR
echo -e "${GREEN}[1/5] Configuring Docker authentication...${NC}"
gcloud auth configure-docker --quiet

# Build backend image
echo -e "${GREEN}[2/5] Building backend image...${NC}"
docker build -t gcr.io/${PROJECT_ID}/adk-bot:${TAG} \
    -f "$SCRIPT_DIR/src/backend/Dockerfile" \
    "$SCRIPT_DIR/src/backend/"

# Build frontend image
echo -e "${GREEN}[3/5] Building frontend image...${NC}"
docker build -t gcr.io/${PROJECT_ID}/adk-frontend:${TAG} \
    -f "$SCRIPT_DIR/src/frontend/Dockerfile.frontend" \
    "$SCRIPT_DIR/src/frontend/"

# Push backend image
echo -e "${GREEN}[4/5] Pushing backend image...${NC}"
docker push gcr.io/${PROJECT_ID}/adk-bot:${TAG}

# Push frontend image
echo -e "${GREEN}[5/5] Pushing frontend image...${NC}"
docker push gcr.io/${PROJECT_ID}/adk-frontend:${TAG}

echo ""
echo -e "${GREEN}Done! Images pushed:${NC}"
echo "  gcr.io/${PROJECT_ID}/adk-bot:${TAG}"
echo "  gcr.io/${PROJECT_ID}/adk-frontend:${TAG}"
