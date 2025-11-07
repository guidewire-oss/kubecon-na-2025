#!/bin/bash
# Traditional Approach - Step 1: Terraform Infrastructure Setup
# This script provisions AWS infrastructure (S3 bucket) using Terraform

set -e

echo "=== Traditional Approach - Step 1: Terraform Infrastructure Setup ==="
echo ""

# Check if we're in the right directory
if [ ! -d "terraform" ]; then
    echo "Error: terraform directory not found. Please run this script from the traditional directory."
    exit 1
fi

# Load AWS credentials from .env.aws
if [ -f "../../.env.aws" ]; then
    echo "Loading AWS credentials from .env.aws..."
    source ../../.env.aws
    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    export AWS_SESSION_TOKEN
    export AWS_DEFAULT_REGION

    # Force Terraform to ignore AWS config files and use environment variables only
    unset AWS_PROFILE
    unset AWS_SDK_LOAD_CONFIG
    export AWS_CONFIG_FILE=/dev/null
    export AWS_SHARED_CREDENTIALS_FILE=/dev/null

    echo "✓ AWS credentials loaded (using access keys, bypassing AWS config)"
else
    echo "⚠ Warning: ../../.env.aws not found. Terraform may fail without AWS credentials."
    echo ""
    echo "Please create .env.aws in the kubecon-NA-2025 directory with:"
    echo "  AWS_ACCESS_KEY_ID=your-access-key"
    echo "  AWS_SECRET_ACCESS_KEY=your-secret-key"
    echo "  AWS_SESSION_TOKEN=your-session-token"
    echo "  AWS_DEFAULT_REGION=us-west-2"
    exit 1
fi

echo ""

# Change to terraform directory
cd terraform

# Check if Terraform is initialized
if [ ! -d ".terraform" ]; then
    echo "Initializing Terraform..."
    terraform init
    echo "✓ Terraform initialized"
else
    echo "✓ Terraform already initialized"
fi

echo ""

# Apply Terraform (creates S3 bucket)
echo "Applying Terraform configuration..."
echo "  This will create:"
echo "    - S3 bucket: tenant-atlantis-product-images-traditional"
echo "    - IAM role for EKS pod access"
echo ""

terraform plan -out=tfplan
terraform apply tfplan
rm tfplan

echo ""
echo "✓ Infrastructure provisioned successfully"

# Get outputs
echo ""
echo "=== Terraform Outputs ==="
terraform output

cd ..

echo ""
echo "=== Step 1 Complete ==="
echo ""
echo "Infrastructure created:"
echo "  - S3 bucket: tenant-atlantis-product-images-traditional"
echo "  - IAM role for pod authentication"
echo ""
echo "Next steps:"
echo "  ./step2-build-images.sh    # Build and push Docker images"
echo "  ./deploy-local.sh dev      # Deploy to Kubernetes (includes all steps)"
echo ""
