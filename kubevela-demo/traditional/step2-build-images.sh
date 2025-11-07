#!/bin/bash
# Traditional Approach - Step 2: Build Docker Images
# This script builds the product catalog API image and pushes it to the local k3d registry

set -e

IMAGE_TAG="${IMAGE_TAG:-v1.0.0-traditional}"

echo "=== Traditional Approach - Step 2: Build Docker Images ==="
echo "Image Tag: ${IMAGE_TAG}"
echo ""

# Change to app directory
cd ../app

echo "Building Docker image..."
echo "  Building image with tag: product-catalog-api:${IMAGE_TAG}..."
DOCKER_BUILDKIT=0 docker build -t product-catalog-api:${IMAGE_TAG} .

echo "  Tagging for local registry..."
docker tag product-catalog-api:${IMAGE_TAG} localhost:5000/product-catalog-api:${IMAGE_TAG}

echo "  Pushing to local registry..."
docker push localhost:5000/product-catalog-api:${IMAGE_TAG}

echo ""
echo "✓ Image built and pushed successfully"

# Return to traditional directory
cd ../traditional

echo ""
echo "=== Step 2 Complete ==="
echo ""
echo "Image available:"
echo "  - localhost:5000/product-catalog-api:${IMAGE_TAG}"
echo ""
echo "Verify the image in registry:"
echo "  curl http://localhost:5000/v2/product-catalog-api/tags/list"
echo ""
echo "Next steps:"
echo "  ./deploy-local.sh dev                  # Deploy to dev environment"
echo "  ./deploy-local.sh --cleanup dev        # Clean up and deploy to dev"
echo "  ./deploy-local.sh staging              # Deploy to staging environment"
echo ""
echo "Or deploy manually with kubectl:"
echo "  kubectl create namespace dev"
echo "  kubectl apply -f k8s/ -n dev"
echo ""
