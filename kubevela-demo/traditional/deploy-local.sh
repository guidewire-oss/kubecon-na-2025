#!/bin/bash
# Local deployment script for traditional approach
# This mimics what GitHub Actions would do, but runs locally against k3d cluster

set -e

# Parse command line arguments
CLEANUP=false
ENVIRONMENT="dev"
IMAGE_TAG="v1.0.0-traditional"

while [[ $# -gt 0 ]]; do
  case $1 in
    --cleanup)
      CLEANUP=true
      shift
      ;;
    *)
      if [ -z "$ENVIRONMENT_SET" ]; then
        ENVIRONMENT=$1
        ENVIRONMENT_SET=true
      else
        IMAGE_TAG=$1
      fi
      shift
      ;;
  esac
done

echo "=== Traditional Approach: Local Deployment Script ==="
echo "Environment: $ENVIRONMENT"
echo "Image Tag: $IMAGE_TAG"
echo "Cleanup: $CLEANUP"
echo ""

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
    echo "⚠ Warning: .env.aws not found. Terraform may fail without AWS credentials."
fi
echo ""

# Cleanup if requested
if [ "$CLEANUP" = true ]; then
    echo "=== Cleanup: Destroying existing resources ==="

    # Delete Kubernetes resources by resource type (ignore manifest namespace conflicts)
    echo "  Deleting Kubernetes resources from ${ENVIRONMENT} namespace..."
    kubectl delete hpa product-catalog-api-hpa -n ${ENVIRONMENT} --ignore-not-found=true
    kubectl delete service product-catalog-api -n ${ENVIRONMENT} --ignore-not-found=true
    kubectl delete deployment product-catalog-api -n ${ENVIRONMENT} --ignore-not-found=true
    kubectl delete configmap product-api-config -n ${ENVIRONMENT} --ignore-not-found=true
    kubectl delete serviceaccount product-api-sa -n ${ENVIRONMENT} --ignore-not-found=true

    # Delete Terraform resources
    echo "  Destroying Terraform infrastructure..."
    cd terraform
    if [ -f "terraform.tfstate" ]; then
        terraform destroy -auto-approve
    else
        echo "  No Terraform state found, skipping destroy"
    fi
    cd ..

    # Delete local Docker images
    echo "  Cleaning up Docker images..."
    docker rmi localhost:5000/product-catalog-api:${IMAGE_TAG} 2>/dev/null || true
    docker rmi product-catalog-api:${IMAGE_TAG} 2>/dev/null || true

    echo "  ✓ Cleanup complete"
    echo ""
fi

# Step 1: Terraform (one-time infrastructure setup)
echo "Step 1: Terraform Infrastructure Setup (one-time)"
cd terraform

# Check if Terraform is initialized
if [ ! -d ".terraform" ]; then
    echo "  Initializing Terraform..."
    terraform init
fi

# Apply Terraform (creates S3 bucket)
echo "  Applying Terraform configuration..."
terraform plan -out=tfplan
terraform apply tfplan
rm tfplan

echo "  ✓ Infrastructure provisioned"
cd ..

# Step 1.5: Setup AWS Credentials
echo ""
echo "Step 1.5: Setup AWS Credentials"
if [ -f "../setup-aws-credentials.sh" ]; then
    echo "  Setting up AWS credentials for ${ENVIRONMENT} namespace..."
    cd .. && ./setup-aws-credentials.sh "${ENVIRONMENT}" && cd traditional
    echo "  ✓ AWS credentials configured"
else
    echo "  Warning: setup-aws-credentials.sh not found, skipping credentials setup"
    echo "  Pods may fail if aws-credentials secret doesn't exist"
fi

# Step 2: Build Docker image
echo ""
echo "Step 2: Build Docker Image"
cd ../app

echo "  Building image..."
DOCKER_BUILDKIT=0 docker build -t product-catalog-api:${IMAGE_TAG} .

echo "  Tagging for local registry..."
docker tag product-catalog-api:${IMAGE_TAG} localhost:5000/product-catalog-api:${IMAGE_TAG}

echo "  Pushing to local registry..."
docker push localhost:5000/product-catalog-api:${IMAGE_TAG}

echo "  ✓ Image built and pushed"
cd ../traditional

# Step 3: Deploy to Kubernetes
echo ""
echo "Step 3: Deploy to Kubernetes (${ENVIRONMENT} environment)"

# Create namespace if it doesn't exist
kubectl create namespace ${ENVIRONMENT} --dry-run=client -o yaml | kubectl apply -f -

# Get IAM role ARN from Terraform outputs
cd terraform
IAM_ROLE_ARN=$(terraform output -raw iam_role_arn)
cd ..

# Apply Kubernetes manifests
echo "  Applying K8s manifests..."
# Inject IAM role into ServiceAccount
cat k8s/serviceaccount.yaml | \
    sed "s|PLACEHOLDER_IAM_ROLE_ARN|${IAM_ROLE_ARN}|g" | \
    kubectl apply -f - -n ${ENVIRONMENT}

kubectl apply -f k8s/configmap.yaml -n ${ENVIRONMENT}

# Update deployment with correct image tag and namespace
cat k8s/deployment.yaml | \
    sed "s|k3d-registry.localhost:5000/product-catalog-api:v1.0.0-traditional|k3d-registry.localhost:5000/product-catalog-api:${IMAGE_TAG}|g" | \
    kubectl apply -f - -n ${ENVIRONMENT}

kubectl apply -f k8s/service.yaml -n ${ENVIRONMENT}
kubectl apply -f k8s/hpa.yaml -n ${ENVIRONMENT}

echo "  ✓ Kubernetes manifests applied"

# Step 4: Wait for deployment
echo ""
echo "Step 4: Waiting for deployment to be ready..."
kubectl rollout status deployment/product-catalog-api -n ${ENVIRONMENT} --timeout=120s

# Step 5: Verify deployment
echo ""
echo "Step 5: Verify deployment"
kubectl get pods -n ${ENVIRONMENT}
kubectl get svc -n ${ENVIRONMENT}
kubectl get hpa -n ${ENVIRONMENT}

# Step 6: Functional API Testing
echo ""
echo "Step 6: Functional API Testing"
echo "  Waiting for API to be ready..."

# Wait for the API to be healthy
MAX_RETRIES=30
RETRY_COUNT=0
SERVICE_URL="http://product-catalog-api.${ENVIRONMENT}.svc.cluster.local"

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if kubectl run test-api-health --image=curlimages/curl:latest --rm -i --restart=Never -n ${ENVIRONMENT} -- \
        curl -f -s "${SERVICE_URL}/health" > /dev/null 2>&1; then
        echo "  ✓ API is healthy"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "  ✗ API health check failed after ${MAX_RETRIES} attempts"
        exit 1
    fi
    sleep 2
done

# Test 1: Create a product (POST)
echo "  Testing POST /products (create product)..."
CREATE_RESPONSE=$(kubectl run test-api-create --image=curlimages/curl:latest --rm -i --restart=Never -n ${ENVIRONMENT} -- \
    curl -s -X POST "${SERVICE_URL}/products" \
    -H "Content-Type: application/json" \
    -d '{"name":"test-product","description":"Automated test","price":99.99}')

if [ $? -ne 0 ]; then
    echo "  ✗ POST request failed"
    exit 1
fi

# Extract product ID from response
PRODUCT_ID=$(echo "$CREATE_RESPONSE" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

if [ -z "$PRODUCT_ID" ]; then
    echo "  ✗ Failed to extract product ID from response"
    echo "  Response: $CREATE_RESPONSE"
    exit 1
fi

echo "  ✓ Product created with ID: $PRODUCT_ID"

# Test 2: Retrieve the product (GET)
echo "  Testing GET /products/${PRODUCT_ID} (retrieve product)..."
GET_RESPONSE=$(kubectl run test-api-get --image=curlimages/curl:latest --rm -i --restart=Never -n ${ENVIRONMENT} -- \
    curl -s -w "\n%{http_code}" "${SERVICE_URL}/products/${PRODUCT_ID}")

HTTP_CODE=$(echo "$GET_RESPONSE" | tail -n 1)
RESPONSE_BODY=$(echo "$GET_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
    echo "  ✗ GET request failed with HTTP ${HTTP_CODE}"
    echo "  Response: $RESPONSE_BODY"
    exit 1
fi

# Verify the retrieved product matches
RETRIEVED_ID=$(echo "$RESPONSE_BODY" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

if [ "$RETRIEVED_ID" != "$PRODUCT_ID" ]; then
    echo "  ✗ Product ID mismatch: expected $PRODUCT_ID, got $RETRIEVED_ID"
    exit 1
fi

echo "  ✓ Product retrieved and verified successfully"
echo "  ✓ Functional API tests passed"

echo ""
echo "=== Deployment Complete ==="
echo "Environment: ${ENVIRONMENT}"
echo "Image: localhost:5000/product-catalog-api:${IMAGE_TAG}"
echo ""
echo "Usage examples:"
echo "  ./deploy-local.sh dev                              # Deploy to dev (uses v1.0.0-traditional)"
echo "  ./deploy-local.sh staging v1.0.1-traditional       # Deploy to staging with specific tag"
echo "  ./deploy-local.sh --cleanup dev                    # Cleanup ONE environment and redeploy"
echo ""
echo "Complete cleanup (all environments + AWS):"
echo "  ./cleanup.sh                                       # Equivalent to 'vela delete product-catalog'"
