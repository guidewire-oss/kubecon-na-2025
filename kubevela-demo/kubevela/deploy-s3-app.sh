#!/bin/bash
set -e  # Exit on error

echo "=== S3 Storage App Deployment Script ==="
echo ""

# Activate virtual environment if it exists
if [ -d "../../.venv" ]; then
    echo "Activating virtual environment from ../../.venv"
    source ../../.venv/bin/activate
    echo "✓ Virtual environment activated"
    echo ""
fi

# Step 1: Build and push Docker image
echo "=== Step 1: Building and pushing Docker image ==="
echo ""

# Check if Dockerfile exists
if [ ! -f "../../component-contributor-demo/kv-product-cat-api/Dockerfile" ]; then
    echo "⚠ Warning: Dockerfile not found at ../../component-contributor-demo/kv-product-cat-api/Dockerfile"
    echo "Skipping image build. Assuming image already exists..."
else
    cd ../../component-contributor-demo/kv-product-cat-api

    echo "Building Docker image..."
    docker build -t kv-product-cat-api:v1.0.0 .

    echo ""
    echo "Tagging image for k3d registry..."
    docker tag kv-product-cat-api:v1.0.0 localhost:5000/kv-product-cat-api:v1.0.0

    echo ""
    echo "Pushing image to k3d registry..."
    docker push localhost:5000/kv-product-cat-api:v1.0.0

    echo "✓ Image built and pushed successfully"
    echo ""

    cd ../../kubevela-demo/kubevela
fi

# Step 2: Apply Crossplane XRD and Composition
echo "=== Step 2: Applying Crossplane S3 resources ==="
echo ""

# Check if XRD exists
if [ -f "crossplane/s3/xrd.yaml" ]; then
    echo "Applying S3 XRD..."
    kubectl apply -f crossplane/s3/xrd.yaml
    echo "✓ XRD applied"
    echo ""
    sleep 2
else
    echo "⚠ Warning: crossplane/s3/xrd.yaml not found"
fi

# Check if Composition exists
if [ -f "crossplane/s3/composition.yaml" ]; then
    echo "Applying S3 Composition..."
    kubectl apply -f crossplane/s3/composition.yaml
    echo "✓ Composition applied"
    echo ""
    sleep 2
else
    echo "⚠ Warning: crossplane/s3/composition.yaml not found"
fi

# Step 3: Load component definitions
echo "=== Step 3: Loading KubeVela component definitions ==="
echo ""

# Check if vela CLI is available
if ! command -v vela &> /dev/null; then
    echo "✗ vela CLI not found. Please install it."
    exit 1
fi

# Apply s3-bucket-base component definition
if [ -f "components/s3/s3-bucket-base.cue" ]; then
    echo "Loading s3-bucket component definition..."
    cd components/s3
    vela def apply s3-bucket-base.cue
    cd ../..
    echo "✓ s3-bucket component definition loaded"
    echo ""
    sleep 1
else
    echo "⚠ Warning: components/s3/s3-bucket-base.cue not found"
fi

# Apply s3-bucket (simple-s3) component definition
if [ -f "components/s3/s3-bucket.cue" ]; then
    echo "Loading simple-s3 component definition..."
    cd components/s3
    vela def apply s3-bucket.cue
    cd ../..
    echo "✓ simple-s3 component definition loaded"
    echo ""
    sleep 1
else
    echo "⚠ Warning: components/s3/s3-bucket.cue not found"
fi

# Step 4: Load trait definitions
echo "=== Step 4: Loading KubeVela trait definitions ==="
echo ""

# Apply s3-versioning trait definition
if [ -f "components/s3/s3-versioning-trait.cue" ]; then
    echo "Loading s3-versioning trait definition..."
    cd components/s3
    vela def apply s3-versioning-trait.cue
    cd ../..
    echo "✓ s3-versioning trait definition loaded"
    echo ""
    sleep 1
else
    echo "⚠ Warning: components/s3/s3-versioning-trait.cue not found"
fi

# Step 5: Verify component and trait definitions
echo "=== Step 5: Verifying definitions ==="
echo ""

echo "Component definitions:"
kubectl get componentdefinition -n vela-system | grep -E "NAME|s3-bucket|simple-s3" || echo "No S3 component definitions found"
echo ""

echo "Trait definitions:"
kubectl get traitdefinition -n vela-system | grep -E "NAME|s3-versioning" || echo "No S3 trait definitions found"
echo ""

# Step 6: Create namespaces for environments
echo "=== Step 6: Creating environment namespaces ==="
echo ""

for ns in dev staging prod; do
    if kubectl get namespace $ns &>/dev/null; then
        echo "✓ Namespace $ns already exists"
    else
        echo "Creating namespace $ns..."
        kubectl create namespace $ns
        echo "✓ Namespace $ns created"
    fi
done
echo ""

# Step 7: Deploy the application
echo "=== Step 7: Deploying S3 Storage Application ==="
echo ""

if [ ! -f "s3-bucket-app.yaml" ]; then
    echo "✗ s3-bucket-app.yaml not found"
    exit 1
fi

echo "Deploying application..."
vela up -f s3-bucket-app.yaml

echo ""
echo "✓ Application deployment initiated"
echo ""

# Step 8: Check application status
echo "=== Step 8: Checking application status ==="
echo ""

sleep 3

echo "Application status:"
vela status s3-storage-app
echo ""

echo "Applications:"
vela ls
echo ""

# Step 9: Show workflow status
echo "=== Step 9: Workflow status ==="
echo ""

echo "To check workflow progress, run:"
echo "  vela status s3-storage-app --detail"
echo ""
echo "To approve staging deployment, run:"
echo "  vela workflow resume s3-storage-app --step approval-staging"
echo ""
echo "To approve production deployment, run:"
echo "  vela workflow resume s3-storage-app --step approval-prod"
echo ""

echo "=== Deployment Complete! ==="
echo ""
echo "Summary:"
echo "  ✓ Docker image built and pushed (if needed)"
echo "  ✓ Crossplane XRD and Composition applied"
echo "  ✓ Component definitions loaded (s3-bucket, simple-s3)"
echo "  ✓ Trait definitions loaded (s3-versioning)"
echo "  ✓ Environment namespaces created (dev, staging, prod)"
echo "  ✓ Application deployed"
echo ""
echo "The workflow will:"
echo "  1. Deploy S3 bucket to dev → Deploy app to dev → Health check"
echo "  2. Wait for manual approval for staging"
echo "  3. Deploy S3 bucket to staging → Deploy app to staging → Health check"
echo "  4. Wait for manual approval for production"
echo "  5. Deploy S3 bucket to prod → Deploy app to prod → Health check"
echo ""
