#!/bin/bash
# Check DynamoDB Tables in LocalStack
# This script runs on the host machine and lists all DynamoDB tables created in LocalStack

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_ROOT="$SCRIPT_DIR"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║        DynamoDB Tables in LocalStack                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Source environment detection
if [ -f "$DEMO_ROOT/config/detect-env.sh" ]; then
    source "$DEMO_ROOT/config/detect-env.sh"
else
    print_error "Could not find config/detect-env.sh"
    exit 1
fi

# Source port-forward helpers
if [ -f "$DEMO_ROOT/config/port-forward-helpers.sh" ]; then
    source "$DEMO_ROOT/config/port-forward-helpers.sh"
else
    print_error "Could not find config/port-forward-helpers.sh"
    exit 1
fi

# Get kubeconfig
KUBECONFIG=$(get_kubeconfig)
if [ -z "$KUBECONFIG" ]; then
    print_error "Could not find kubeconfig"
    exit 1
fi

print_info "Environment: $ENV_TYPE"
print_info "Kubeconfig: $KUBECONFIG"
print_info "LocalStack Endpoint: $LOCALSTACK_ENDPOINT"
echo ""

# Verify kubeconfig is valid
if ! kubectl --kubeconfig="$KUBECONFIG" cluster-info &>/dev/null; then
    print_error "Kubeconfig is not valid or cluster not accessible"
    exit 1
fi

print_success "Kubernetes cluster accessible"
echo ""

# Get LocalStack pod
print_info "Looking for LocalStack pod..."
LOCALSTACK_POD=$(kubectl --kubeconfig="$KUBECONFIG" get pod -n localstack-system \
    -l app.kubernetes.io/name=localstack -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$LOCALSTACK_POD" ]; then
    print_error "LocalStack pod not found in localstack-system namespace"
    print_info "Is LocalStack installed? Run: ./setup.sh"
    exit 1
fi

print_success "Found LocalStack pod: $LOCALSTACK_POD"
echo ""

# Method 1: List tables directly from pod
print_info "Method 1: Listing tables via kubectl exec"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TABLES=$(kubectl --kubeconfig="$KUBECONFIG" exec -n localstack-system "$LOCALSTACK_POD" -- \
    aws dynamodb list-tables \
    --endpoint-url=http://localhost:4566 \
    --region=us-west-2 \
    --output=json 2>/dev/null || echo '{"TableNames":[]}')

TABLE_COUNT=$(echo "$TABLES" | grep -o '"TableNames"' | wc -l)

if [ "$TABLE_COUNT" -eq 0 ]; then
    print_warning "No tables found in LocalStack"
    echo "This is expected if applications haven't deployed yet."
    echo ""
    print_info "Check application status with: vela ls -A"
    echo ""
else
    TABLE_LIST=$(echo "$TABLES" | jq -r '.TableNames[]' 2>/dev/null || echo "")

    if [ -z "$TABLE_LIST" ]; then
        print_warning "No tables found"
    else
        print_success "Found the following DynamoDB tables:"
        echo ""
        echo "$TABLE_LIST" | while read table; do
            echo "  • $table"
        done
        echo ""
    fi
fi

# Method 2: Try port-forward method for host machines
if [ "$TEST_ENDPOINT_MODE" = "portforward" ]; then
    echo ""
    print_info "Method 2: Using port-forward (host machine only)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Setup cleanup trap
    setup_cleanup_trap 2>/dev/null || true

    # Setup port-forward
    print_info "Setting up port-forward to LocalStack..."
    setup_all_port_forwards 2>/dev/null || print_warning "Could not setup port-forward"

    # Give port-forward time to establish
    sleep 2

    # Check if endpoint is accessible
    if verify_endpoint_accessible "$LOCALSTACK_ENDPOINT" 3 2>/dev/null; then
        print_success "LocalStack accessible via port-forward"
        echo ""

        # Try listing tables via localhost
        if command -v aws &> /dev/null; then
            print_info "Listing tables via AWS CLI..."
            aws dynamodb list-tables \
                --endpoint-url="$LOCALSTACK_ENDPOINT" \
                --region=us-west-2 \
                --output=table 2>/dev/null || print_warning "Could not list tables via AWS CLI"
        else
            print_warning "AWS CLI not found on host machine"
        fi
    else
        print_warning "LocalStack not accessible via port-forward"
    fi

    # Cleanup port-forwards
    cleanup_port_forwards 2>/dev/null || true
fi

echo ""
print_info "Checking application deployment status..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check KRO application
print_info "KRO Application Status:"
kubectl --kubeconfig="$KUBECONFIG" get application session-api-app-kro -n default -o jsonpath='{.status.phase}' 2>/dev/null && echo "" || echo "Not deployed"

# Check Crossplane application
print_info "Crossplane Application Status:"
kubectl --kubeconfig="$KUBECONFIG" get application session-api-app-xp -n default -o jsonpath='{.status.phase}' 2>/dev/null && echo "" || echo "Not deployed"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                        Useful Commands                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "View all applications:"
echo "  vela ls -A"
echo ""
echo "Check application details:"
echo "  vela status session-api-app-kro"
echo "  vela status session-api-app-xp"
echo ""
echo "View pods:"
echo "  kubectl get pods -n default"
echo ""
echo "View DynamoDB resources:"
echo "  kubectl get table -A"
echo ""
echo "Describe a table:"
echo "  kubectl describe table <table-name> -n default"
echo ""
echo "View logs from session API:"
echo "  kubectl logs -n default -l app=session-api-kro --tail=50"
echo "  kubectl logs -n default -l app=session-api-xp --tail=50"
echo ""
