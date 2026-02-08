"""
GenAI Travel Assistant - Streamlit Frontend

This module provides a simple web interface for users to interact with
the travel assistant AI bot. It displays a chat interface and communicates
with the FastAPI backend to process user queries.

The frontend is designed to run in Kubernetes and connects to the backend
via internal service discovery.
"""

import streamlit as st
import requests
import os

# Configure the backend URL
# In Kubernetes, this should point to the internal ClusterIP service name
# The service name "adk-backend" is automatically resolvable via K8s DNS
# For local development, override with: export BACKEND_URL="http://localhost:8080"
BACKEND_URL = os.getenv("BACKEND_URL", "http://adk-backend:80")

# Configure the Streamlit page
st.title("🤖 Vertex AI Travel Agent")
st.markdown("Ask me anything about travel!")

# Create the user input field
user_query = st.text_input("Where do you want to go?")

# Handle the "Ask Agent" button click
if st.button("Ask Agent"):
    # Only proceed if user has entered a query
    if user_query:
        # Show a loading spinner while waiting for the backend response
        with st.spinner("Thinking..."):
            try:
                # Send POST request to the FastAPI backend /chat endpoint
                response = requests.post(
                    f"{BACKEND_URL}/chat",
                    json={"prompt": user_query}
                )

                # Check if the request was successful
                if response.status_code == 200:
                    # Parse the JSON response and extract the agent's answer
                    data = response.json()
                    st.success(data.get("response", "No response text found."))
                else:
                    # Display error if the backend returned a non-200 status
                    st.error(f"Error: {response.status_code}")

            except Exception as e:
                # Handle connection errors (e.g., backend is down or unreachable)
                st.error(f"Connection failed: {e}")