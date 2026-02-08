#!/bin/bash

# Run the GenAI Travel Bot locally
# Prerequisites: gcloud CLI configured with your project

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load PROJECT_ID from .env
if [ -f "$SCRIPT_DIR/.env" ]; then
    export $(cat "$SCRIPT_DIR/.env" | grep -v '^#' | xargs)
fi

echo -e "${GREEN}Starting GenAI Travel Bot locally...${NC}"
echo -e "${GREEN}Project: ${PROJECT_ID}${NC}"

# Use Application Default Credentials (no key file needed)
echo -e "${GREEN}Setting up authentication via gcloud ADC...${NC}"
gcloud auth application-default print-access-token > /dev/null 2>&1 || {
    echo -e "${YELLOW}Setting up Application Default Credentials...${NC}"
    gcloud auth application-default login
}

export GOOGLE_CLOUD_PROJECT="$PROJECT_ID"

# Install dependencies
echo -e "${GREEN}Installing backend dependencies...${NC}"
pip install -q -r "$SCRIPT_DIR/requirements.txt"
pip install -q streamlit requests

# Start backend
echo -e "${GREEN}Starting backend on http://localhost:8080 ...${NC}"
cd "$SCRIPT_DIR/src/backend"
uvicorn main:app --host 0.0.0.0 --port 8080 --reload &
BACKEND_PID=$!

# Wait for backend to be ready
echo -e "${YELLOW}Waiting for backend to start...${NC}"
for i in {1..15}; do
    if curl -s http://localhost:8080/health > /dev/null 2>&1; then
        echo -e "${GREEN}Backend is ready!${NC}"
        break
    fi
    sleep 1
done

# Start frontend
# --server.headless=true skips the Streamlit welcome email prompt
echo -e "${GREEN}Starting frontend on http://localhost:8501 ...${NC}"
export BACKEND_URL="http://localhost:8080"
cd "$SCRIPT_DIR/src/frontend"
streamlit run frontend.py --server.port=8501 --server.address=0.0.0.0 --server.headless=true &
FRONTEND_PID=$!

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Bot is running!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "  Backend:  http://localhost:8080"
echo -e "  API Docs: http://localhost:8080/docs"
echo -e "  Frontend: http://localhost:8501"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop both services${NC}"

# Cleanup on exit
cleanup() {
    echo -e "\n${GREEN}Shutting down...${NC}"
    kill $BACKEND_PID $FRONTEND_PID 2>/dev/null
    wait $BACKEND_PID $FRONTEND_PID 2>/dev/null
    echo -e "${GREEN}Done.${NC}"
}
trap cleanup EXIT INT TERM

# Wait for either process to exit
wait
