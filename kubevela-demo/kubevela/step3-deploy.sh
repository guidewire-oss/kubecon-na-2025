#!/bin/bash
# KubeVela Demo - Step 3: Deploy Application with KubeVela
# This script deploys the product catalog application using KubeVela

set -e

echo "=== KubeVela Demo - Step 3: Deploy Application ==="
echo ""

# Check if we're in the right directory
if [ ! -f "application.yaml" ]; then
    echo "Error: application.yaml not found. Please run this script from the kubevela directory."
    exit 1
fi

# One-time: Install Crossplane S3 component
echo "Step 3a: Installing Crossplane S3 Component Definitions..."
echo "  Applying XRD (CompositeResourceDefinition)..."
kubectl apply -f crossplane/s3/xrd.yaml

echo "  Applying Composition..."
kubectl apply -f crossplane/s3/composition.yaml

echo "  Applying ComponentDefinition with vela CLI..."
if ! command -v vela &> /dev/null; then
    echo "  Warning: vela CLI not found. Please install it:"
    echo "    curl -fsSl https://kubevela.io/script/install.sh | bash"
    exit 1
fi

vela def apply components/s3/s3-bucket.cue

echo "  ✓ Crossplane S3 component installed"
echo ""

# Setup AWS credentials
echo "Step 3b: Setting up AWS credentials..."
if [ -f "../setup-aws-credentials.sh" ]; then
    echo "  Setting up AWS credentials for all environments..."
    cd .. && ./setup-aws-credentials.sh "dev staging prod" && cd kubevela
    echo "  ✓ AWS credentials configured"
else
    echo "  Error: setup-aws-credentials.sh not found in parent directory"
    exit 1
fi
echo ""

# Deploy the application
echo "Step 3c: Deploying application with KubeVela..."
vela up -f application.yaml

echo ""
echo "  ✓ Application deployed to dev environment"
echo ""

# Wait for deployment to be ready
echo "Waiting for application to be ready in dev..."
sleep 10

# Check status
echo ""
echo "=== Application Status ==="
vela status kv-product-catalog

echo ""
echo "=== Kubernetes Resources (dev) ==="
kubectl get pods,hpa -n dev

echo ""
echo "=== Step 3 Complete ==="
echo ""
echo "The application is deployed to the dev environment."
echo ""
echo "Next steps for Progressive Delivery:"
echo ""
echo "  # Deploy to staging (after dev health checks pass):"
echo "  vela workflow resume kv-product-catalog && sleep 30"
echo "  kubectl get pods,hpa -n staging"
echo ""
echo "  # Deploy to production (after staging health checks pass):"
echo "  vela workflow resume kv-product-catalog && sleep 60"
echo "  kubectl get pods,hpa -n prod"
echo ""
echo "  # View complete status:"
echo "  vela status kv-product-catalog"
echo ""
