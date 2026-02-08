# Backend Dockerfile for GenAI Travel Bot
# Uses Python 3.10 slim image for smaller footprint

FROM python:3.10-slim

# Set working directory inside the container
WORKDIR /app

# Copy and install Python dependencies
# Copying requirements.txt separately allows Docker to cache this layer
# if dependencies don't change between builds
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY main.py .

# Expose port 8080 for the FastAPI application
# This is the port that uvicorn will listen on
EXPOSE 8080

# Run the FastAPI application with uvicorn
# --host 0.0.0.0: Listen on all network interfaces (required for container networking)
# --port 8080: Listen on port 8080
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]