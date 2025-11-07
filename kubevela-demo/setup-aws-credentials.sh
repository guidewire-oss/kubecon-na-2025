#!/bin/bash
# Unified AWS Credentials Setup
# Works for KubeVela, Traditional, and Crossplane deployments
# Creates AWS credentials secrets from .env.aws file in BOTH formats

set -e

ENVIRONMENTS="${1:-dev staging prod}"

echo "=== AWS Credentials Setup ==="
echo "Setting up credentials for environments: $ENVIRONMENTS"
echo ""

# Check if .env.aws exists (try both locations)
if [ -f "../.env.aws" ]; then
    ENV_FILE="../.env.aws"
elif [ -f ".env.aws" ]; then
    ENV_FILE=".env.aws"
else
    echo "Error: .env.aws not found"
    echo ""
    echo "Please create .env.aws with:"
    echo "  AWS_ACCESS_KEY_ID=your-access-key"
    echo "  AWS_SECRET_ACCESS_KEY=your-secret-key"
    echo "  AWS_SESSION_TOKEN=your-session-token  # Optional"
    echo "  AWS_DEFAULT_REGION=us-west-2"
    exit 1
fi

# Load AWS credentials
echo "Loading AWS credentials from $ENV_FILE..."
source "$ENV_FILE"

if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "Error: AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY not set in .env.aws"
    exit 1
fi

echo "✓ AWS credentials loaded"
echo ""

# Create secrets for each environment
for ENV in $ENVIRONMENTS; do
    echo "Processing environment: $ENV"

    # Create namespace if it doesn't exist
    if ! kubectl get namespace $ENV &>/dev/null; then
        echo "  Creating namespace $ENV..."
        kubectl create namespace $ENV
    else
        echo "  ✓ Namespace $ENV exists"
    fi

    # Create AWS credentials secret with BOTH formats
    echo "  Creating aws-credentials secret (env vars + credentials file)..."

    # Build credentials file content
    CREDENTIALS_CONTENT="[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}"

    if [ -n "$AWS_SESSION_TOKEN" ]; then
        CREDENTIALS_CONTENT="${CREDENTIALS_CONTENT}
aws_session_token = ${AWS_SESSION_TOKEN}"
    fi

    # Create secret with both formats
    if [ -n "$AWS_SESSION_TOKEN" ]; then
        kubectl create secret generic aws-credentials \
            --from-literal=AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
            --from-literal=AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
            --from-literal=AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN}" \
            --from-literal=AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-west-2}" \
            --from-literal=credentials="$CREDENTIALS_CONTENT" \
            --namespace $ENV \
            --dry-run=client -o yaml | kubectl apply -f -
    else
        kubectl create secret generic aws-credentials \
            --from-literal=AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
            --from-literal=AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
            --from-literal=AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-west-2}" \
            --from-literal=credentials="$CREDENTIALS_CONTENT" \
            --namespace $ENV \
            --dry-run=client -o yaml | kubectl apply -f -
    fi

    # Verify secret exists
    if kubectl get secret aws-credentials -n $ENV &>/dev/null; then
        echo "  ✓ Secret created successfully in $ENV"
    else
        echo "  ✗ Failed to create secret in $ENV"
        exit 1
    fi
    echo ""
done

# Also create in crossplane-system for Crossplane (if namespace exists)
if kubectl get namespace crossplane-system &>/dev/null; then
    echo "Processing crossplane-system namespace..."

    # Create credentials in Crossplane format (credentials file only)
    echo "  Creating aws-credentials secret (credentials file for Crossplane)..."

    CREDENTIALS_CONTENT="[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}"

    if [ -n "$AWS_SESSION_TOKEN" ]; then
        CREDENTIALS_CONTENT="${CREDENTIALS_CONTENT}
aws_session_token = ${AWS_SESSION_TOKEN}"
    fi

    kubectl create secret generic aws-credentials \
        --from-literal=credentials="$CREDENTIALS_CONTENT" \
        --namespace crossplane-system \
        --dry-run=client -o yaml | kubectl apply -f -

    echo "  ✓ Crossplane credentials created"
    echo ""
fi

echo "=== AWS Credentials Setup Complete ==="
echo ""
echo "Credentials have been created in the following namespaces:"
for ENV in $ENVIRONMENTS; do
    if kubectl get secret aws-credentials -n $ENV &>/dev/null 2>&1; then
        echo "  ✓ $ENV (env vars + credentials file)"
    fi
done

if kubectl get secret aws-credentials -n crossplane-system &>/dev/null 2>&1; then
    echo "  ✓ crossplane-system (credentials file)"
fi

echo ""
echo "Your applications can now access AWS services using either:"
echo "  - Environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)"
echo "  - Credentials file (mounted at /aws/credentials)"
echo ""
echo "Usage:"
echo "  ./setup-aws-credentials.sh                    # Setup dev, staging, prod"
echo "  ./setup-aws-credentials.sh \"dev\"              # Setup only dev"
echo "  ./setup-aws-credentials.sh \"dev staging\"     # Setup dev and staging"
echo ""
