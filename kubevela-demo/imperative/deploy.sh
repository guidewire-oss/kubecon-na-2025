#!/bin/bash
# Traditional Approach - Deploy Script (Dagger Wrapper)
# Thin wrapper that calls Dagger pipeline for deployment

set -e

ENVIRONMENT="${1:-dev}"
IMAGE_TAG="${2:-v1.0.0-imperative}"

echo "=== Traditional Approach: Dagger-based Deployment ==="
echo "Environment: $ENVIRONMENT"
echo "Image Tag: $IMAGE_TAG"
echo ""

# Step 1: Build and push Docker image
echo "Building Docker image..."
cd ../app
DOCKER_BUILDKIT=0 docker build -t localhost:5000/imp-product-catalog:$IMAGE_TAG .
echo "Pushing image to k3d registry..."
docker push localhost:5000/imp-product-catalog:$IMAGE_TAG
echo "✓ Image built and pushed to localhost:5000 (accessible as k3d-registry.localhost:5000 from cluster)"
cd ../imperative
echo ""

# Load AWS credentials
if [ -f "../../.env.aws" ]; then
    source ../../.env.aws
    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    export AWS_SESSION_TOKEN
    export AWS_DEFAULT_REGION
fi

# Run Dagger pipeline
# Note: Must run from dagger/ directory for go.mod, but paths in main.go expect parent directory
export ENVIRONMENT="$ENVIRONMENT"
export IMAGE_TAG="$IMAGE_TAG"

cd dagger
go run main.go
