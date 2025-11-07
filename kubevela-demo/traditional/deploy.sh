#!/bin/bash
# Traditional Approach - Deploy Script (Dagger Wrapper)
# Thin wrapper that calls Dagger pipeline for deployment

set -e

ENVIRONMENT="${1:-dev}"
IMAGE_TAG="${2:-v1.0.0-traditional}"

echo "=== Traditional Approach: Dagger-based Deployment ==="
echo "Environment: $ENVIRONMENT"
echo "Image Tag: $IMAGE_TAG"
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
export ENVIRONMENT="$ENVIRONMENT"
export IMAGE_TAG="$IMAGE_TAG"

cd dagger
go run main.go
