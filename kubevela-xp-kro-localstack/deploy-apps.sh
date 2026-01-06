#!/bin/bash
# Manual deployment of sample applications
# Use this if Phase 9 auto-deployment didn't work

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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_ROOT="$SCRIPT_DIR"

echo ""
print_step "Manual Application Deployment"
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

# Check if vela is available
if ! command -v vela &> /dev/null; then
    print_error "vela CLI not found. Please install KubeVela first: vela install"
    exit 1
fi

print_success "vela CLI found"
echo ""

# Deploy KRO application
if [ -f "$DEMO_ROOT/definitions/examples/session-api-app-kro.yaml" ]; then
    print_step "Deploying KRO-based Session API"
    print_info "File: $DEMO_ROOT/definitions/examples/session-api-app-kro.yaml"
    echo ""

    if vela up -f "$DEMO_ROOT/definitions/examples/session-api-app-kro.yaml"; then
        print_success "KRO application deployed successfully"
    else
        print_error "KRO application deployment failed"
        exit 1
    fi
else
    print_error "KRO application manifest not found"
    exit 1
fi

echo ""

# Deploy Crossplane application
if [ -f "$DEMO_ROOT/definitions/examples/session-api-app-xp.yaml" ]; then
    print_step "Deploying Crossplane-based Session API"
    print_info "File: $DEMO_ROOT/definitions/examples/session-api-app-xp.yaml"
    echo ""

    if vela up -f "$DEMO_ROOT/definitions/examples/session-api-app-xp.yaml"; then
        print_success "Crossplane application deployed successfully"
    else
        print_error "Crossplane application deployment failed"
        exit 1
    fi
else
    print_error "Crossplane application manifest not found"
    exit 1
fi

echo ""
print_success "All applications deployed"
echo ""

# Wait for applications to initialize
print_info "Waiting for applications to initialize (30 seconds)..."
sleep 30

echo ""
print_step "Deployment Summary"
echo ""

# Show deployment status
print_info "Application Status:"
vela ls -A || print_error "Could not retrieve application status"

echo ""
print_info "Pod Status:"
kubectl get pods -n default || print_error "Could not retrieve pod status"

echo ""
print_step "Next Steps"
echo ""
echo "Check DynamoDB tables:"
echo "  ./check-dynamodb-tables.sh"
echo ""
echo "View application details:"
echo "  vela status session-api-app-kro"
echo "  vela status session-api-app-xp"
echo ""
echo "View logs:"
echo "  kubectl logs -n default -l app=session-api-kro --tail=50"
echo "  kubectl logs -n default -l app=session-api-xp --tail=50"
echo ""
