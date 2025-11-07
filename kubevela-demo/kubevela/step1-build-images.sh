#!/bin/bash
# KubeVela Demo - Step 1: Build Application Images
# This script builds the product catalog API image and pushes it to the local k3d registry

set -e

echo "=== KubeVela Demo - Step 1: Build Application Images ==="
echo ""

# Change to app directory
cd ../app

echo "Building KubeVela version..."
echo "  Building Docker image..."
DOCKER_BUILDKIT=0 docker build -t product-catalog-api:v1.0.0 .

echo "  Tagging for local registry..."
docker tag product-catalog-api:v1.0.0 localhost:5000/product-catalog-api:v1.0.0

echo "  Pushing to local registry..."
docker push localhost:5000/product-catalog-api:v1.0.0

echo ""
echo "✓ KubeVela image built and pushed successfully"
echo ""

# Build traditional version 
echo ""
echo "Building Traditional version..."
echo "  Tagging traditional version..."
docker tag product-catalog-api:v1.0.0 product-catalog-api:v1.0.0-traditional
docker tag product-catalog-api:v1.0.0-traditional localhost:5000/product-catalog-api:v1.0.0-traditional

echo "  Pushing to local registry..."
docker push localhost:5000/product-catalog-api:v1.0.0-traditional

echo ""
echo "✓ Traditional image built and pushed successfully"


echo ""
echo "=== Step 1 Complete ==="
echo ""
echo "Images available:"
echo "  - localhost:5000/product-catalog-api:v1.0.0 (KubeVela)"
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "  - localhost:5000/product-catalog-api:v1.0.0-traditional (Traditional)"
fi
echo ""
echo "Next steps:"
echo "  - For Traditional approach: cd ../traditional && ./step1-terraform.sh"
echo "  - For KubeVela approach: cd ../kubevela && ./step3-deploy.sh"
echo ""
