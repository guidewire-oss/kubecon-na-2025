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
        --from-literal=credentials="[default]
aws_access_key_id = test
aws_secret_access_key = test" \
        --dry-run=client -o yaml | kubectl apply -f -

    # ProviderConfig for Crossplane to use LocalStack
    print_info "Configuring Crossplane ProviderConfig for LocalStack..."
    kubectl apply -f - <<'EOF' || print_warning "Could not apply ProviderConfig"
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
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
      static: "http://localstack.localstack-system.svc.cluster.local:4566"
    hostnameImmutable: true
  skip_credentials_validation: true
  skip_requesting_account_id: true
  skip_metadata_api_check: true
  s3_use_path_style: true
EOF

    print_success "Crossplane ProviderConfig configured"

    # Also ensure default ProviderConfig in default namespace for safety
    kubectl apply -f - <<'EOF' || true
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
      static: "http://localstack.localstack-system.svc.cluster.local:4566"
    hostnameImmutable: true
  skip_credentials_validation: true
  skip_requesting_account_id: true
  skip_metadata_api_check: true
  s3_use_path_style: true
EOF

    print_success "Crossplane configured"
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
fi

# PHASE 6: ACK (Optional - only if not already installed)
print_step "Phase 6: Checking ACK DynamoDB Controller"

kubectl create namespace ack-system --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true

kubectl create secret generic localstack-credentials \
    -n ack-system \
    --from-literal=credentials="[default]
aws_access_key_id = test
aws_secret_access_key = test" \
    --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true

if helm list -n ack-system 2>/dev/null | grep -q "ack-dynamodb"; then
    print_success "ACK DynamoDB controller already installed"
else
    print_info "ACK DynamoDB controller not installed (optional - KRO will still work)"
    print_info "Attempting to install ACK (with 60 second timeout)..."

    if helm repo add aws-controllers-k8s https://aws-controllers-k8s.github.io/community 2>/dev/null && \
       helm repo update aws-controllers-k8s 2>/dev/null; then
        timeout 60 helm install ack-dynamodb-controller oci://public.ecr.aws/aws-controllers-k8s/dynamodb-chart \
            -n ack-system \
            --set=aws.region=us-west-2 \
            --set=aws.endpoint_url=http://localstack.localstack-system.svc.cluster.local:4566 \
            --set=aws.credentials.secretName=localstack-credentials 2>&1 >/dev/null && \
            print_success "ACK DynamoDB controller installed" || \
            print_warning "ACK installation timed out or failed (optional - continuing without it)"
    else
        print_warning "Could not add ACK Helm repo (optional - continuing without it)"
    fi
fi

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

print_success "All definitions deployed"

# PHASE 8: Finalize
print_step "Phase 8: Finalizing"

kubectl create namespace default --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic localstack-credentials \
    -n default \
    --from-literal=credentials="[default]
aws_access_key_id = test
aws_secret_access_key = test" \
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
    --timeout=60s 2>/dev/null || print_info "ACK not available (optional - KRO tables may use alternative method)"

print_success "Infrastructure ready"

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

if [ -f "$DEMO_ROOT/definitions/examples/session-api-app-xp.yaml" ]; then
    print_info "Deploying Crossplane-based session API application..."
    vela up -f "$DEMO_ROOT/definitions/examples/session-api-app-xp.yaml" 2>&1 | grep -v "^$" || print_warning "Crossplane app deployment may have issues"
    print_success "Crossplane application deployment request sent"
else
    print_warning "Crossplane application manifest not found at $DEMO_ROOT/definitions/examples/session-api-app-xp.yaml"
fi

echo ""

# Wait for applications to be deployed
print_info "Waiting for applications to start (30 seconds)..."
sleep 30

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
echo "  • session-api-kro   (KRO-based implementation)"
echo "  • session-api-xp    (Crossplane-based implementation)"
echo ""
echo "Useful Commands:"
echo "  View all applications:   vela ls -A"
echo "  Check app status:        vela status <app-name>"
echo "  View app logs:           kubectl logs -n default <pod-name>"
echo "  Re-deploy an app:        vela up -f definitions/examples/session-api-app-kro.yaml"
echo ""
