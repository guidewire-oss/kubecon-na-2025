#!/bin/bash
# Cleanup script for traditional approach
# Equivalent to: vela delete product-catalog
# Deletes all resources from all environments (dev, staging, prod)

set -e

echo "=== Traditional Approach: Complete Cleanup ==="
echo ""

# Load AWS credentials from .env.aws (for AWS CLI and Terraform)
if [ -f "../../.env.aws" ]; then
    echo "Loading AWS credentials from .env.aws..."
    source ../../.env.aws
    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    export AWS_SESSION_TOKEN
    export AWS_DEFAULT_REGION

    # Force Terraform to use environment variables
    unset AWS_PROFILE
    unset AWS_SDK_LOAD_CONFIG
    export AWS_CONFIG_FILE=/dev/null
    export AWS_SHARED_CREDENTIALS_FILE=/dev/null

    echo "✓ AWS credentials loaded"
    echo ""
else
    echo "Warning: .env.aws not found. AWS operations may fail."
    echo "Please create .env.aws in the kubecon-na-2025 directory"
    echo ""
fi

# Delete Kubernetes resources from all environments
echo "=== Cleaning up Kubernetes resources ==="
for ENV in dev staging prod; do
    echo "Processing $ENV environment..."

    # Check if namespace exists
    if kubectl get namespace $ENV &>/dev/null; then
        # Delete resources by type
        kubectl delete hpa imp-product-catalog-hpa -n $ENV --ignore-not-found=true
        kubectl delete service imp-product-catalog -n $ENV --ignore-not-found=true
        kubectl delete deployment imp-product-catalog -n $ENV --ignore-not-found=true
        kubectl delete configmap product-api-config -n $ENV --ignore-not-found=true
        kubectl delete serviceaccount product-api-sa -n $ENV --ignore-not-found=true
        echo "  ✓ $ENV resources deleted"
    else
        echo "  ✓ $ENV namespace doesn't exist (skipping)"
    fi
done

echo ""

# Clean up AWS infrastructure
echo "=== Cleaning up AWS infrastructure ==="

BUCKET_NAME="tenant-atlantis-product-images-imperative"

# Empty S3 bucket before Terraform destroy (required for non-empty buckets)
echo "Emptying S3 bucket: $BUCKET_NAME"
if command -v aws &> /dev/null; then
    # Check if bucket exists
    if aws s3 ls "s3://$BUCKET_NAME" 2>/dev/null; then
        echo "  Removing all objects from bucket..."
        aws s3 rm "s3://$BUCKET_NAME" --recursive 2>/dev/null || true
        echo "  ✓ Bucket emptied"
    else
        echo "  ✓ Bucket doesn't exist (skipping)"
    fi
else
    echo "  Warning: AWS CLI not found. Cannot empty bucket."
    echo "  Terraform destroy may fail if bucket has objects."
fi

echo ""

# Destroy Terraform infrastructure
echo "Destroying Terraform resources..."
cd terraform

if [ -f "terraform.tfstate" ]; then
    echo "  Running terraform destroy..."
    terraform destroy -auto-approve
    echo "  ✓ Terraform resources destroyed"
else
    echo "  ✓ No Terraform state found (skipping)"
fi

cd ..

echo ""

# Optional: Clean up local Docker images
echo "=== Cleaning up local Docker images ==="
IMAGE_TAG="v1.0.0-imperative"
docker rmi localhost:5000/imp-product-catalog:${IMAGE_TAG} 2>/dev/null && echo "  ✓ Removed localhost:5000/imp-product-catalog:${IMAGE_TAG}" || echo "  ✓ Image not found (skipping)"
docker rmi imp-product-catalog:${IMAGE_TAG} 2>/dev/null && echo "  ✓ Removed imp-product-catalog:${IMAGE_TAG}" || echo "  ✓ Image not found (skipping)"

echo ""
echo "=== Cleanup Complete ==="
echo ""
echo "All resources have been deleted:"
echo "  ✓ Kubernetes resources (dev, staging, prod namespaces)"
echo "  ✓ S3 bucket: $BUCKET_NAME (emptied and deleted)"
echo "  ✓ IAM roles and policies"
echo "  ✓ Docker images (local)"
echo ""
echo "Compare with KubeVela cleanup:"
echo "  Traditional: ./cleanup.sh"
echo "  KubeVela:    vela delete product-catalog"
echo ""
