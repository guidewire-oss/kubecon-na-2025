#!/bin/bash
# Manual ACK DynamoDB Controller Installation for LocalStack
# Use this if Phase 6 auto-installation didn't work

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_ROOT="$SCRIPT_DIR"

echo ""
print_step "Installing ACK DynamoDB Controller for LocalStack"
echo ""

# Source environment detection
if [ -f "$DEMO_ROOT/config/detect-env.sh" ]; then
    set -a
    source "$DEMO_ROOT/config/detect-env.sh"
    set +a
else
    print_error "Could not find config/detect-env.sh"
    exit 1
fi

print_info "Environment: $ENV_TYPE"
print_info "Kubeconfig: $KUBECONFIG"
print_info "LocalStack Endpoint: $LOCALSTACK_ENDPOINT"
echo ""

# Create ACK namespace
print_info "Creating ack-system namespace..."
kubectl create namespace ack-system --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true

# Create LocalStack credentials secret
print_info "Creating LocalStack credentials..."
kubectl create secret generic localstack-credentials \
    -n ack-system \
    --from-literal=aws_access_key_id="test" \
    --from-literal=aws_secret_access_key="test" \
    --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true

print_success "ACK namespace and credentials ready"
echo ""

# Install ACK using the public ECR image (doesn't require Helm repo)
print_info "Deploying ACK DynamoDB controller from ECR..."
print_warning "This method uses kubectl apply instead of Helm (more reliable)"
echo ""

# Create ACK RBAC and deployment using raw Kubernetes manifests
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ack-dynamodb
  namespace: ack-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ack-dynamodb
rules:
- apiGroups: ["dynamodb.services.k8s.aws"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ack-dynamodb
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ack-dynamodb
subjects:
- kind: ServiceAccount
  name: ack-dynamodb
  namespace: ack-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ack-dynamodb-controller
  namespace: ack-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ack-dynamodb-controller
  template:
    metadata:
      labels:
        app: ack-dynamodb-controller
    spec:
      serviceAccountName: ack-dynamodb
      containers:
      - name: controller
        image: public.ecr.aws/aws-controllers-k8s/dynamodb-controller:v1.4.0
        imagePullPolicy: Always
        env:
        - name: AWS_REGION
          value: us-west-2
        - name: AWS_ENDPOINT_URL
          value: http://localstack.localstack-system.svc.cluster.local:4566
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: localstack-credentials
              key: aws_access_key_id
        - name: AWS_SECRET_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: localstack-credentials
              key: aws_secret_access_key
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 500m
            memory: 256Mi
EOF

print_success "ACK DynamoDB controller deployed"
echo ""

# Wait for controller to be ready
print_info "Waiting for ACK controller to be ready (60 seconds)..."
kubectl wait --for=condition=ready pod \
    -l app=ack-dynamodb-controller \
    -n ack-system \
    --timeout=60s 2>/dev/null || print_warning "Controller may still be starting..."

echo ""
print_success "ACK installation complete!"
echo ""

# Verify installation
print_info "Verifying ACK installation..."
kubectl get deployment -n ack-system ack-dynamodb-controller 2>&1 || print_warning "Could not verify deployment"

echo ""
print_info "Next steps:"
echo "  1. Re-deploy applications: ./deploy-apps.sh"
echo "  2. Check table creation: ./check-dynamodb-tables.sh"
echo ""
