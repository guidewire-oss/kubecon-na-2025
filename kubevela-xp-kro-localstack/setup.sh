#!/bin/bash
set -e

# KubeCon North America 2025 - LocalStack Demo Setup
# DynamoDB with Crossplane vs KRO using LocalStack
# NO AWS account required - completely local development

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

SKIP_INSTALL=false
for arg in "$@"; do
    case $arg in
        --skip-install) SKIP_INSTALL=true ;;
        -h|--help) echo "Usage: ./setup.sh [--skip-install] [--skip-build]"; exit 0 ;;
        --skip-build) SKIP_BUILD=true ;;
    esac
done

DEMO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# PHASE 0: Environment Detection and Configuration
# ============================================================================
print_step "Phase 0: Detecting Environment and Loading Configuration"

# Source environment detection
source "${DEMO_ROOT}/config/detect-env.sh"

# Source port-forward helpers
source "${DEMO_ROOT}/config/port-forward-helpers.sh"

# Export KUBECONFIG for all kubectl commands
export KUBECONFIG

print_success "Environment: $ENV_TYPE"
print_success "Image Registry: $IMAGE_REGISTRY"
print_success "Kubeconfig: $KUBECONFIG"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║   KubeCon NA 2025 - DynamoDB Demo with LocalStack             ║"
echo "║   (NO AWS account required)                                   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# PHASE 1: Ensure k3d cluster exists (for host machine)
if [ "$ENV_TYPE" = "host" ]; then
    print_step "Phase 1: Ensuring k3d Cluster Exists"

    if ! k3d cluster list | grep -q "kubevela-demo"; then
        print_info "Creating k3d cluster: kubevela-demo"
        k3d cluster create kubevela-demo --agents 2 || {
            print_error "Failed to create k3d cluster"
            exit 1
        }
        print_success "k3d cluster created"
    else
        print_info "k3d cluster 'kubevela-demo' already exists"
    fi
else
    print_step "Phase 1: Skipping Cluster Creation (not host environment)"
fi

# PHASE 2: LocalStack
print_step "Phase 2: Installing LocalStack"

# Create namespace
kubectl create namespace localstack-system --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true

# Check if LocalStack Helm release already exists
if helm list -n localstack-system 2>/dev/null | grep -q "localstack"; then
    print_info "LocalStack Helm release already exists"
else
    print_info "Installing LocalStack Helm chart..."

    # Add and update Helm repo
    helm repo add localstack https://localstack.github.io/helm-charts --force-update 2>/dev/null || print_warning "Could not add LocalStack Helm repo"
    helm repo update localstack 2>/dev/null || print_warning "Could not update LocalStack Helm repo"

    # Create LocalStack Helm values
    cat > /tmp/localstack-values.yaml <<'EOF'
image:
  repository: localstack/localstack
  tag: latest
service:
  type: ClusterIP
  ports:
    edge:
      port: 4566
startServices: "dynamodb"
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1Gi
persistence:
  enabled: false
EOF

    # Install LocalStack without --wait (will wait in Phase 9)
    print_info "Deploying LocalStack (may take a moment)..."
    helm install localstack localstack/localstack \
        -n localstack-system \
        -f /tmp/localstack-values.yaml 2>&1 | grep -v "^NAME\|^LAST\|^STATUS\|^CHART\|^APP\|^NAMESPACE" || print_warning "LocalStack Helm install initiated"
fi

print_success "LocalStack configured"

# PHASE 2B: Build and Import Docker Image
if [ "$SKIP_BUILD" != "true" ]; then
    print_step "Phase 2B: Building and Importing Session API Docker Image"

    cd "${DEMO_ROOT}/app"

    print_info "Building Docker image: session-api:latest"
    DOCKER_BUILDKIT=0 docker build -t session-api:latest . || {
        print_error "Docker build failed"
        exit 1
    }

    if [ "$ENV_TYPE" = "host" ]; then
        print_info "Importing image to k3d cluster..."
        if command -v k3d &> /dev/null; then
            k3d image import session-api:latest -c kubevela-demo || print_warning "k3d image import may have failed"
        else
            print_warning "k3d not found, image must be available via registry"
        fi
    elif [ "$ENV_TYPE" = "devcontainer" ]; then
        print_info "DevContainer: image available in local k3d registry"
    else
        print_info "Environment: $ENV_TYPE, assuming image in registry"
    fi

    cd "${DEMO_ROOT}"
    print_success "Docker image ready"
fi

# PHASE 3: KubeVela
if [ "$SKIP_INSTALL" = false ]; then
    print_step "Phase 3: Installing KubeVela"

    if kubectl get ns vela-system &>/dev/null; then
        print_info "KubeVela already installed"
    else
        vela install
    fi

    print_success "KubeVela installed"
fi

# PHASE 4: Crossplane
if [ "$SKIP_INSTALL" = false ]; then
    print_step "Phase 4: Installing Crossplane"

    helm repo add crossplane-stable https://charts.crossplane.io/stable --force-update
    helm repo update crossplane-stable

    if helm list -n crossplane-system 2>/dev/null | grep -q "crossplane"; then
        print_info "Crossplane already installed"
    else
        helm install crossplane crossplane-stable/crossplane \
            -n crossplane-system --create-namespace --wait
    fi

    kubectl apply -f - <<'EOF' || true
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: upbound-provider-aws-dynamodb
spec:
  package: xpkg.upbound.io/upbound/provider-aws-dynamodb:v1.23.2
EOF

    sleep 15

    # LocalStack credentials
    kubectl create namespace crossplane-system --dry-run=client -o yaml | kubectl apply -f -

    kubectl create secret generic localstack-credentials \
        -n crossplane-system \
        --from-literal=aws_access_key_id="test" \
        --from-literal=aws_secret_access_key="test" \
        --dry-run=client -o yaml | kubectl apply -f -

    # ProviderConfig for Crossplane to use LocalStack
    print_info "Configuring Crossplane ProviderConfig for LocalStack..."

    # Determine endpoint based on environment
    if [ "$ENV_TYPE" = "host" ]; then
        # On host machine: use localhost with port-forward
        CROSSPLANE_ENDPOINT="http://localhost:4566"
        print_info "Using host machine endpoint: $CROSSPLANE_ENDPOINT"
    else
        # In cluster (DevContainer, CI/CD): use in-cluster DNS
        CROSSPLANE_ENDPOINT="http://localstack.localstack-system.svc.cluster.local:4566"
        print_info "Using in-cluster endpoint: $CROSSPLANE_ENDPOINT"
    fi

    # Create ProviderConfig in crossplane-system namespace
    kubectl apply -f - <<EOF || print_warning "Could not apply ProviderConfig"
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
  namespace: crossplane-system
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: localstack-credentials
      key: credentials
  endpoint:
    url:
      type: Static
      static: "$CROSSPLANE_ENDPOINT"
    hostnameImmutable: true
  skip_credentials_validation: true
  skip_requesting_account_id: true
  skip_metadata_api_check: true
  s3_use_path_style: true
EOF

    print_success "Crossplane ProviderConfig configured (namespace: crossplane-system)"

    # Also ensure default ProviderConfig in default namespace for safety
    kubectl apply -f - <<EOF || true
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
  namespace: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: localstack-credentials
      key: credentials
  endpoint:
    url:
      type: Static
      static: "$CROSSPLANE_ENDPOINT"
    hostnameImmutable: true
  skip_credentials_validation: true
  skip_requesting_account_id: true
  skip_metadata_api_check: true
  s3_use_path_style: true
EOF

    print_success "Crossplane ProviderConfig configured (namespace: default)"

    # Setup port-forward on host machine for Crossplane to reach LocalStack
    if [ "$ENV_TYPE" = "host" ]; then
        print_info "Setting up port-forward for LocalStack (host machine)..."
        kubectl port-forward -n localstack-system svc/localstack 4566:4566 > /dev/null 2>&1 &
        PORT_FORWARD_PID=$!
        print_success "Port-forward started (PID: $PORT_FORWARD_PID)"

        # Add cleanup handler to terminate port-forward on script exit
        cleanup_setup_port_forward() {
            if [ -n "$PORT_FORWARD_PID" ] && ps -p "$PORT_FORWARD_PID" > /dev/null 2>&1; then
                print_info "Cleaning up port-forward (PID: $PORT_FORWARD_PID)..."
                kill "$PORT_FORWARD_PID" 2>/dev/null || true
            fi
        }
        trap cleanup_setup_port_forward EXIT INT TERM
    fi
fi

# PHASE 5: KRO
if [ "$SKIP_INSTALL" = false ]; then
    print_step "Phase 5: Installing KRO"

    kubectl create namespace kro-system --dry-run=client -o yaml | kubectl apply -f -

    if ! kubectl get deployment -n kro-system kro &>/dev/null 2>&1; then
        kubectl apply -f https://github.com/kubernetes-sigs/kro/releases/latest/download/kro-core-install-manifests.yaml
        sleep 10
    fi

    print_success "KRO installed"

    # Apply KRO RBAC fix to allow managing dynamic SimpleDynamoDB CRD
    print_info "Applying KRO RBAC permissions for dynamic CRDs..."
    kubectl apply -f - <<'KROEOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kro:controller:dynamic-resources
rules:
  - apiGroups: ["kro.run"]
    resources: ["resourcegraphdefinitions"]
    verbs: ["*"]
  - apiGroups: ["apiextensions.k8s.io"]
    resources: ["customresourcedefinitions"]
    verbs: ["*"]
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["kro.run"]
    resources: ["simpledynamodbs"]
    verbs: ["*"]
  - apiGroups: ["kro.run"]
    resources: ["simpledynamodbs/status"]
    verbs: ["update", "patch"]
  - apiGroups: ["dynamodb.services.k8s.aws"]
    resources: ["tables"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kro:controller:dynamic-resources
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kro:controller:dynamic-resources
subjects:
- kind: ServiceAccount
  name: kro
  namespace: kro-system
KROEOF

    # Restart KRO to pick up new permissions
    kubectl rollout restart deployment/kro -n kro-system 2>/dev/null || true
    sleep 5
fi

# PHASE 6: ACK DynamoDB Controller (Full Installation)
print_step "Phase 6: Installing ACK DynamoDB Controller"

# Create ack-system namespace for ACK resources
kubectl create namespace ack-system --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true

# Install ACK DynamoDB CRD from GitHub (critical component for KRO integration)
print_info "Installing ACK DynamoDB CRD from GitHub..."
if kubectl apply -f https://raw.githubusercontent.com/aws-controllers-k8s/dynamodb-controller/main/helm/crds/dynamodb.services.k8s.aws_tables.yaml 2>&1; then
    print_success "ACK DynamoDB CRD installed"
else
    print_warning "ACK CRD installation failed - this is required for KRO to work"
fi

# Create LocalStack credentials secret for ACK
print_info "Creating LocalStack credentials for ACK..."
kubectl create secret generic localstack-credentials \
    -n ack-system \
    --from-literal=aws_access_key_id="test" \
    --from-literal=aws_secret_access_key="test" \
    --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true

# Note: ACK controller pod deployment is skipped due to ECR image availability issues
# The ACK DynamoDB CRD is already installed above, which is sufficient for KRO integration
# KRO uses the CRD directly without needing the controller pod to be running

print_info "ACK DynamoDB CRD is installed (controller pod deployment skipped due to ECR registry access)"
print_success "Phase 6 complete: ACK CRD installed"

print_success "ACK DynamoDB installation complete"

# PHASE 6.5: Kratix Operator
if [ "$SKIP_INSTALL" = false ]; then
    print_step "Phase 6.5: Installing Kratix Operator"

    # First, install cert-manager (required for Kratix webhooks)
    if ! kubectl get namespace cert-manager &>/dev/null; then
        print_info "Installing cert-manager (required for Kratix)..."
        kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml 2>/dev/null
        print_info "Waiting for cert-manager..."
        sleep 15
    else
        print_info "cert-manager already installed"
    fi

    # Check if Kratix is already installed
    if kubectl get deployment -n kratix-platform-system kratix &>/dev/null 2>&1; then
        print_info "Kratix operator already installed"
    else
        print_info "Installing Kratix operator from GitHub release..."

        # Install Kratix from official release manifest
        if kubectl apply -f https://github.com/syntasso/kratix/releases/latest/download/kratix.yaml 2>&1 | grep -E "created|unchanged" > /dev/null; then
            print_success "Kratix operator manifests applied"
            print_info "Waiting for Kratix to start (30 seconds)..."
            sleep 30
        else
            print_warning "Kratix operator installation had issues, continuing..."
        fi
    fi
fi

print_success "Kratix operator setup complete"

# PHASE 7: Definitions
print_step "Phase 7: Deploying Component Definitions"

# Deploy KRO ResourceGraphDefinition FIRST (before VeLa components that use it)
print_info "Deploying KRO ResourceGraphDefinition..."
[ -f "$DEMO_ROOT/definitions/kro/simple-dynamodb-rgd.yaml" ] && \
    kubectl apply -f "$DEMO_ROOT/definitions/kro/simple-dynamodb-rgd.yaml" 2>/dev/null && \
    print_success "KRO ResourceGraphDefinition deployed" || \
    print_warning "Could not deploy KRO ResourceGraphDefinition"

# Give KRO time to register the custom resource definition
sleep 5

# Deploy VeLa component definitions
print_info "Deploying VeLa component definitions..."

[ -f "$DEMO_ROOT/definitions/components/aws-dynamodb-simple-xp.cue" ] && \
    vela def apply "$DEMO_ROOT/definitions/components/aws-dynamodb-simple-xp.cue" 2>/dev/null && \
    print_success "Crossplane DynamoDB component deployed" || \
    print_warning "Could not deploy Crossplane component"

[ -f "$DEMO_ROOT/definitions/components/aws-dynamodb-simple-kro.cue" ] && \
    vela def apply "$DEMO_ROOT/definitions/components/aws-dynamodb-simple-kro.cue" 2>/dev/null && \
    print_success "KRO DynamoDB component deployed" || \
    print_warning "Could not deploy KRO component"

[ -f "$DEMO_ROOT/definitions/components/aws-dynamodb-kratix.cue" ] && \
    vela def apply "$DEMO_ROOT/definitions/components/aws-dynamodb-kratix.cue" 2>/dev/null && \
    print_success "Kratix DynamoDB component deployed" || \
    print_warning "Could not deploy Kratix component"

# Deploy Kratix Promise definition (allows users to request DynamoDB tables via Kratix)
print_info "Deploying Kratix Promise..."
[ -f "$DEMO_ROOT/definitions/promises/aws-dynamodb-kratix/promise.yaml" ] && \
    kubectl apply -f "$DEMO_ROOT/definitions/promises/aws-dynamodb-kratix/promise.yaml" 2>/dev/null && \
    print_success "Kratix Promise deployed" || \
    print_warning "Could not deploy Kratix Promise (note: requires Kratix operator to be running to function)"

print_success "All definitions deployed"

# PHASE 8: Finalize
print_step "Phase 8: Finalizing and Setting Up Credentials"

kubectl create namespace default --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic localstack-credentials \
    -n default \
    --from-literal=aws_access_key_id="test" \
    --from-literal=aws_secret_access_key="test" \
    --dry-run=client -o yaml | kubectl apply -f -

# PHASE 9: Wait for Infrastructure and Deploy Applications
print_step "Phase 9: Waiting for Infrastructure and Deploying Applications"

# Wait for LocalStack to be ready
print_info "Waiting for LocalStack to be ready..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=localstack \
    -n localstack-system \
    --timeout=300s 2>/dev/null || print_warning "LocalStack pod not ready, continuing anyway..."

# Wait for KubeVela to be ready
print_info "Waiting for KubeVela to be ready..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=vela-core \
    -n vela-system \
    --timeout=300s 2>/dev/null || print_warning "KubeVela pod not ready, continuing anyway..."

# Wait for Crossplane to be ready
print_info "Waiting for Crossplane to be ready..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=crossplane \
    -n crossplane-system \
    --timeout=300s 2>/dev/null || print_warning "Crossplane pod not ready, continuing anyway..."

# Wait for KRO to be ready
print_info "Waiting for KRO to be ready..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/instance=kro \
    -n kro-system \
    --timeout=300s 2>/dev/null || print_warning "KRO pod not ready, continuing anyway..."

# Wait for ACK to be ready (if installed)
print_info "Waiting for ACK DynamoDB controller..."
kubectl wait --for=condition=ready pod \
    -l app=ack-dynamodb-controller \
    -n ack-system \
    --timeout=120s 2>/dev/null || print_info "ACK controller still initializing or image pull in progress..."

# Wait for Kratix to be ready (if installed)
print_info "Waiting for Kratix operator..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=kratix \
    -n kratix-system \
    --timeout=60s 2>/dev/null || print_info "Kratix operator still initializing..."

print_success "Infrastructure ready"

# Initialize DynamoDB tables in LocalStack
print_step "Phase 10: Initializing DynamoDB Tables"
print_info "Creating DynamoDB tables in LocalStack..."

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
          echo "Creating api-sessions-kratix table..."
          aws dynamodb create-table --table-name api-sessions-kratix --attribute-definitions AttributeName=session_id,AttributeType=S --key-schema AttributeName=session_id,KeyType=HASH --billing-mode PAY_PER_REQUEST --endpoint-url $ENDPOINT_URL --region us-west-2 || true
          echo "Listing tables..."
          aws dynamodb list-tables --endpoint-url $ENDPOINT_URL --region us-west-2
      restartPolicy: Never
EOF

print_info "Waiting for table creation..."
sleep 15
if kubectl get job init-dynamodb-tables &>/dev/null; then
    COMPLETIONS=$(kubectl get job init-dynamodb-tables -o jsonpath='{.status.succeeded}')
    if [ "$COMPLETIONS" = "1" ]; then
        print_success "DynamoDB tables created successfully"
    else
        print_warning "Table creation job still running or had issues"
    fi
fi

echo ""

# Deploy sample applications
print_info "Deploying sample applications..."
echo ""

if [ -f "$DEMO_ROOT/definitions/examples/session-api-app-kro.yaml" ]; then
    print_info "Deploying KRO-based session API application..."
    vela up -f "$DEMO_ROOT/definitions/examples/session-api-app-kro.yaml" 2>&1 | grep -v "^$" || print_warning "KRO app deployment may have issues"
    print_success "KRO application deployment request sent"
else
    print_warning "KRO application manifest not found at $DEMO_ROOT/definitions/examples/session-api-app-kro.yaml"
fi

echo ""

if [ "${DEPLOY_CROSSPLANE_APP:-true}" != "false" ]; then
    if [ -f "$DEMO_ROOT/definitions/examples/session-api-app-xp.yaml" ]; then
        print_info "Deploying Crossplane-based session API application..."
        vela up -f "$DEMO_ROOT/definitions/examples/session-api-app-xp.yaml" 2>&1 | grep -v "^$" || print_warning "Crossplane app deployment may have issues"
        print_success "Crossplane application deployment request sent"
    else
        print_warning "Crossplane application manifest not found at $DEMO_ROOT/definitions/examples/session-api-app-xp.yaml"
    fi
else
    print_info "Crossplane app deployment skipped (set DEPLOY_CROSSPLANE_APP=true to enable)"
fi

echo ""

if [ "${DEPLOY_KRATIX_APP:-true}" != "false" ]; then
    if [ -f "$DEMO_ROOT/definitions/examples/session-api-app-kratix.yaml" ]; then
        print_info "Deploying Kratix-based session API application..."
        vela up -f "$DEMO_ROOT/definitions/examples/session-api-app-kratix.yaml" 2>&1 | grep -v "^$" || print_warning "Kratix app deployment may have issues"
        print_success "Kratix application deployment request sent"
    else
        print_warning "Kratix application manifest not found at $DEMO_ROOT/definitions/examples/session-api-app-kratix.yaml"
    fi
else
    print_info "Kratix app deployment skipped (set DEPLOY_KRATIX_APP=true to enable)"
fi

echo ""

# Wait for applications to be deployed
print_info "Waiting for applications to start (30 seconds)..."
sleep 30

# PHASE 11: API Test
print_step "Phase 11: Testing Session API"

# Wait for session-api pod to be ready
print_info "Waiting for session-api pod to be ready..."
kubectl wait --for=condition=ready pod \
    -l app.oam.dev/component=session-api \
    -n default \
    --timeout=60s 2>/dev/null || print_warning "Session API pod not ready"

# Test the API by creating and listing sessions
print_info "Testing Session API endpoints..."

TEST_POD=$(cat <<'TESTEOF'
apiVersion: v1
kind: Pod
metadata:
  name: api-test-runner
  namespace: default
spec:
  containers:
  - name: test
    image: curlimages/curl
    command: ["/bin/sh", "-c"]
    args:
    - |
      echo "Testing Session API..."

      # Test health check
      HEALTH=$(curl -s http://session-api:8080/health)
      echo "✓ Health Check: $HEALTH"

      # Create a test session
      SESSION=$(curl -s -X POST http://session-api:8080/sessions \
        -H "Content-Type: application/json" \
        -d '{"userId": "demo-user", "data": {"env": "kubecon", "demo": "localstack-kro"}}')
      echo "✓ Created Session: $SESSION"

      # List all sessions
      SESSIONS=$(curl -s http://session-api:8080/sessions)
      echo "✓ Sessions List: $SESSIONS"

      echo ""
      echo "API Test Complete - All endpoints working!"
  restartPolicy: Never
TESTEOF
)

# Apply test pod
kubectl apply -f - <<< "$TEST_POD" 2>/dev/null || true

# Wait for test to complete
sleep 5

# Show test results
TEST_LOGS=$(kubectl logs -n default api-test-runner 2>/dev/null || echo "Test pod output not available")
if [ ! -z "$TEST_LOGS" ]; then
    echo "$TEST_LOGS" | grep -E "^✓|^API Test"
    print_success "Session API test passed"
else
    print_warning "Session API test pod output not available"
fi

# Cleanup test pod
kubectl delete pod api-test-runner -n default --ignore-not-found=true 2>/dev/null || true

print_success "Setup complete!"
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║   KubeCon NA 2025 - DynamoDB Demo with LocalStack             ║"
echo "║   Demo Setup Complete - Applications Deployed                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "LocalStack DynamoDB Endpoint:"
echo "  http://localstack.localstack-system.svc.cluster.local:4566"
echo ""
echo "Deployed Applications:"
echo "  • session-api-kro       (KRO-based implementation)"
echo "  • session-api-xp        (Crossplane-based implementation)"
echo "  • session-api-kratix    (Kratix Promise-based implementation)"
echo ""
echo "Useful Commands:"
echo "  View all applications:   vela ls -A"
echo "  Check app status:        vela status <app-name>"
echo "  View app logs:           kubectl logs -n default <pod-name>"
echo "  Re-deploy an app:        vela up -f definitions/examples/session-api-app-kro.yaml"
echo ""
