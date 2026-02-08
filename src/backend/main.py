"""
GenAI Travel Assistant - FastAPI Backend

This module provides a REST API for interacting with a travel assistant AI agent.
It uses Google's Agent Development Kit (ADK) with Vertex AI (Gemini) to process
user queries and provide travel-related assistance.

The backend exposes two main endpoints:
- POST /chat: Process user travel queries
- GET /health: Health check endpoint for monitoring
"""

import os
import uuid
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from google.adk.agents import Agent
from google.adk.runners import Runner
from google.adk.sessions import InMemorySessionService
from google.genai import types

# Configure Vertex AI via environment variables
# The google.genai Client reads these automatically:
#   GOOGLE_GENAI_USE_VERTEXAI - enables Vertex AI mode
#   GOOGLE_CLOUD_PROJECT      - GCP project ID
#   GOOGLE_CLOUD_LOCATION     - GCP region
# In GKE: credentials come from Workload Identity
# Locally: credentials come from gcloud ADC
os.environ.setdefault("GOOGLE_GENAI_USE_VERTEXAI", "true")
os.environ.setdefault("GOOGLE_CLOUD_PROJECT", os.getenv("PROJECT_ID", ""))
os.environ.setdefault("GOOGLE_CLOUD_LOCATION", "us-central1")

# Initialize the FastAPI application
app = FastAPI()

# Define the AI Agent using Google ADK
# This agent uses Gemini 2.5 Pro from Vertex AI as the underlying language model
# Authentication is handled via Workload Identity in GKE (no explicit credentials needed)
travel_agent = Agent(
    name="travel_helper",
    model="gemini-2.5-pro",
    instruction="You are a helpful travel assistant. Keep answers short and fun."
)

# Session service stores conversation history in memory
session_service = InMemorySessionService()

# Runner orchestrates agent execution within sessions
runner = Runner(
    app_name="travel_bot",
    agent=travel_agent,
    session_service=session_service,
)

class ChatRequest(BaseModel):
    """Request model for chat endpoint."""
    prompt: str

@app.post("/chat")
async def chat(request: ChatRequest):
    """Process a chat message through the AI travel agent."""
    try:
        # Create a unique session for each request
        user_id = "user"
        session_id = str(uuid.uuid4())

        # Create a new session
        session_service.create_session(
            app_name="travel_bot",
            user_id=user_id,
            session_id=session_id,
        )

        # Build the user message in ADK's expected format
        user_message = types.Content(
            role="user",
            parts=[types.Part(text=request.prompt)],
        )

        # Run the agent and collect response text from events
        response_text = ""
        async for event in runner.run_async(
            user_id=user_id,
            session_id=session_id,
            new_message=user_message,
        ):
            # Extract text from the agent's final response
            if event.content and event.content.parts:
                for part in event.content.parts:
                    if part.text:
                        response_text += part.text

        return {"response": response_text or "No response generated."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
def health():
    """Health check endpoint for Kubernetes probes and monitoring."""
    return {"status": "ok"}