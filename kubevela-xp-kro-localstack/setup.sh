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

kubectl create namespace localstack-system --dry-run=client -o yaml | kubectl apply -f -

if kubectl get deployment -n localstack-system -l app.kubernetes.io/name=localstack &>/dev/null 2>&1; then
    print_info "LocalStack already installed"
else
    helm repo add localstack https://localstack.github.io/helm-charts --force-update
    helm repo update localstack

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

    helm install localstack localstack/localstack \
        -n localstack-system \
        -f /tmp/localstack-values.yaml \
        --wait --timeout 300s 2>/dev/null || {
        print_warning "LocalStack install slow, waiting..."
        sleep 15
    }
fi

print_success "LocalStack ready"

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

    # ProviderConfig
    kubectl apply -f - <<'EOF' || true
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

# PHASE 6: ACK
if [ "$SKIP_INSTALL" = false ]; then
    print_step "Phase 6: Installing ACK DynamoDB"

    kubectl create namespace ack-system --dry-run=client -o yaml | kubectl apply -f -

    kubectl create secret generic localstack-credentials \
        -n ack-system \
        --from-literal=credentials="[default]
aws_access_key_id = test
aws_secret_access_key = test" \
        --dry-run=client -o yaml | kubectl apply -f -

    if ! helm list -n ack-system 2>/dev/null | grep -q "ack-dynamodb"; then
        helm repo add aws-controllers-k8s https://aws-controllers-k8s.github.io/community 2>/dev/null || true
        helm repo update aws-controllers-k8s 2>/dev/null || print_warning "Failed to update aws-controllers-k8s repo"

        helm install ack-dynamodb-controller oci://public.ecr.aws/aws-controllers-k8s/dynamodb-chart \
            -n ack-system --create-namespace \
            --set=aws.region=us-west-2 \
            --set=aws.endpoint_url=http://localstack.localstack-system.svc.cluster.local:4566 \
            --set=aws.credentials.secretName=localstack-credentials \
            --wait 2>/dev/null || print_warning "ACK install slow, continuing..."
    fi

    print_success "ACK DynamoDB installed"
fi

# PHASE 7: Definitions
print_step "Phase 7: Deploying Definitions"

[ -f "$DEMO_ROOT/definitions/components/aws-dynamodb-simple-xp.cue" ] && \
    vela def apply "$DEMO_ROOT/definitions/components/aws-dynamodb-simple-xp.cue" 2>/dev/null || true

[ -f "$DEMO_ROOT/definitions/components/aws-dynamodb-simple-kro.cue" ] && \
    vela def apply "$DEMO_ROOT/definitions/components/aws-dynamodb-simple-kro.cue" 2>/dev/null || true

[ -f "$DEMO_ROOT/definitions/kro/simple-dynamodb-rgd.yaml" ] && \
    kubectl apply -f "$DEMO_ROOT/definitions/kro/simple-dynamodb-rgd.yaml" 2>/dev/null || true

print_success "Definitions deployed"

# PHASE 8: Finalize
print_step "Phase 8: Finalizing"

kubectl create namespace default --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic localstack-credentials \
    -n default \
    --from-literal=credentials="[default]
aws_access_key_id = test
aws_secret_access_key = test" \
    --dry-run=client -o yaml | kubectl apply -f -

print_success "Setup complete!"
echo ""
echo "LocalStack DynamoDB Demo is ready at:"
echo "  http://localstack.localstack-system.svc.cluster.local:4566"
echo ""
echo "Deploy example: vela up -f definitions/examples/session-api-app.yaml"
echo "Check status:   vela ls -A"
echo ""
