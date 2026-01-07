#!/bin/bash
# Initialize DynamoDB tables in LocalStack
# This script creates the necessary tables for the session API applications

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_step "Initializing DynamoDB Tables in LocalStack"

# Create the Job manifest
print_info "Creating table initialization job..."

kubectl apply -f - << 'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: init-dynamodb-tables
  namespace: default
spec:
  ttlSecondsAfterFinished: 60
  backoffLimit: 2
  template:
    spec:
      containers:
      - name: create
        image: amazon/aws-cli:latest
        imagePullPolicy: IfNotPresent
        env:
        - name: AWS_ACCESS_KEY_ID
          value: "test"
        - name: AWS_SECRET_ACCESS_KEY
          value: "test"
        - name: AWS_DEFAULT_REGION
          value: "us-west-2"
        - name: ENDPOINT_URL
          value: "http://localstack.localstack-system.svc.cluster.local:4566"
        command:
        - /bin/bash
        - -c
        - |
          echo "Creating api-sessions-kro table..."
          aws dynamodb create-table --table-name api-sessions-kro --attribute-definitions AttributeName=id,AttributeType=S --key-schema AttributeName=id,KeyType=HASH --billing-mode PAY_PER_REQUEST --endpoint-url $ENDPOINT_URL --region us-west-2 || true
          echo "Creating api-sessions-xp table..."
          aws dynamodb create-table --table-name api-sessions-xp --attribute-definitions AttributeName=id,AttributeType=S --key-schema AttributeName=id,KeyType=HASH --billing-mode PAY_PER_REQUEST --endpoint-url $ENDPOINT_URL --region us-west-2 || true
          echo "Listing tables..."
          aws dynamodb list-tables --endpoint-url $ENDPOINT_URL --region us-west-2
      restartPolicy: Never
EOF

print_info "Waiting for job to complete..."
sleep 10

# Check job status
if kubectl get job init-dynamodb-tables &>/dev/null; then
    COMPLETIONS=$(kubectl get job init-dynamodb-tables -o jsonpath='{.status.succeeded}')
    if [ "$COMPLETIONS" = "1" ]; then
        print_success "DynamoDB tables initialized successfully"
        echo ""
        print_info "Table list:"
        kubectl logs -l job-name=init-dynamodb-tables | tail -10
    else
        print_info "Job still running or failed. Check status with:"
        echo "  kubectl describe job init-dynamodb-tables"
        echo "  kubectl logs -l job-name=init-dynamodb-tables"
    fi
else
    echo "Could not find job"
    exit 1
fi

echo ""
print_success "DynamoDB initialization complete!"
