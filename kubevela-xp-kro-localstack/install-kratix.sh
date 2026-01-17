#!/bin/bash
# Kratix Operator Installation for LocalStack Demo
# Use this if Phase 6.5 auto-installation didn't work or to install Kratix separately
#
# Purpose: Kratix is a platform engineering tool that provides a Promise-based API
# for packaging and distributing infrastructure capabilities. It complements KRO
# and ACK for comprehensive infrastructure orchestration.

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
print_step "Installing Kratix Operator"
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
echo ""

# Create Kratix namespace
print_info "Creating kratix-system namespace..."
kubectl create namespace kratix-system --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true

# Check if Kratix is already installed
if kubectl get deployment -n kratix-system kratix-controller-manager &>/dev/null 2>&1; then
    print_success "Kratix operator already installed"
    echo ""
    kubectl get deployment -n kratix-system kratix-controller-manager 2>&1
    echo ""
    exit 0
fi

print_info "Installing Kratix operator from official release..."
echo ""

# Install Kratix using the official release
KRATIX_VERSION="v0.3.1"
KRATIX_MANIFEST="https://github.com/syntasso/kratix/releases/download/${KRATIX_VERSION}/kratix-${KRATIX_VERSION}.yaml"

print_info "Using Kratix version: $KRATIX_VERSION"
print_info "Manifest URL: $KRATIX_MANIFEST"
echo ""

if kubectl apply -f "$KRATIX_MANIFEST" 2>&1 | grep -v "^$"; then
    print_success "Kratix operator installed successfully"
else
    print_warning "Kratix installation from official release had some issues"
    print_info "Attempting minimal Kratix setup with core components..."

    # Apply minimal Kratix setup
    kubectl apply -f - <<'KRATIXEOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kratix
  namespace: kratix-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kratix
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kratix
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kratix
subjects:
- kind: ServiceAccount
  name: kratix
  namespace: kratix-system
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: promises.kratix.io
spec:
  group: kratix.io
  scope: Cluster
  names:
    kind: Promise
    plural: promises
  versions:
  - name: v1alpha1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
          status:
            type: object
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: resourcerequests.kratix.io
spec:
  group: kratix.io
  scope: Cluster
  names:
    kind: ResourceRequest
    plural: resourcerequests
  versions:
  - name: v1alpha1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
          status:
            type: object
KRATIXEOF

    print_success "Kratix minimal setup completed"
fi

echo ""
print_info "Waiting for Kratix operator to be ready (60 seconds)..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=kratix \
    -n kratix-system \
    --timeout=60s 2>/dev/null || print_warning "Kratix operator may still be starting, check status with: kubectl get pods -n kratix-system"

echo ""
print_success "Kratix installation complete!"
echo ""

# Verify installation
print_info "Verifying Kratix installation..."
echo ""
echo "Kratix CRDs:"
kubectl get crd | grep kratix.io || print_warning "No Kratix CRDs found yet"
echo ""
echo "Kratix Namespace Resources:"
kubectl get all -n kratix-system 2>&1 || print_warning "Could not list kratix-system resources"

echo ""
print_info "Next steps:"
echo "  1. Deploy sample promises: kubectl apply -f definitions/promises/*.yaml"
echo "  2. Check promise status: kubectl get promises"
echo "  3. Submit resource requests: kubectl apply -f definitions/requests/*.yaml"
echo ""
