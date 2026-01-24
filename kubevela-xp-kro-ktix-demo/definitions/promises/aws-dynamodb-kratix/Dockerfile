FROM python:3.11-slim

WORKDIR /app

# Install dependencies for workflow execution
RUN pip install --no-cache-dir \
    pyyaml==6.0.1 \
    kubernetes==34.1.0 \
    requests==2.31.0

# Copy the workflow script
COPY workflow.py /app/

# Set the entrypoint
ENTRYPOINT ["python", "/app/workflow.py"]
