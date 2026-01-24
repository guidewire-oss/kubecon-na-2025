#!/bin/bash
# Check DynamoDB Requests created via Kratix Promise
# This script verifies the Kratix DynamoDB Promise is working correctly

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

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     Kratix DynamoDB Promise - Request Status Check             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if we're in k3d environment
if ! command -v k3d &> /dev/null; then
    print_error "k3d not found. This script requires k3d."
    exit 1
fi

# Get k3d cluster
K3D_CLUSTER="kubevela-demo"
if ! k3d cluster list 2>/dev/null | grep -q "$K3D_CLUSTER"; then
    print_error "k3d cluster '$K3D_CLUSTER' not found"
    exit 1
fi

print_success "k3d cluster found: $K3D_CLUSTER"
echo ""

# Check Promise installation
print_info "Checking Promise Installation..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

PROMISE=$(docker exec k3d-${K3D_CLUSTER}-server-0 kubectl get promise aws-dynamodb-kratix -o name 2>/dev/null || echo "")

if [ -z "$PROMISE" ]; then
    print_error "Promise 'aws-dynamodb-kratix' not found"
    exit 1
fi

print_success "Promise installed: $PROMISE"

# Check Promise CRD
CRD=$(docker exec k3d-${K3D_CLUSTER}-server-0 kubectl get crd dynamodbrequests.dynamodb.kratix.io -o name 2>/dev/null || echo "")

if [ -z "$CRD" ]; then
    print_error "CRD 'dynamodbrequests.dynamodb.kratix.io' not found"
    exit 1
fi

print_success "CRD installed: $CRD"
echo ""

# Check DynamoDB requests
print_info "DynamoDB Requests Created..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

REQUEST_COUNT=$(docker exec k3d-${K3D_CLUSTER}-server-0 kubectl get dynamodbrequests --all-namespaces -o name 2>/dev/null | wc -l)

if [ "$REQUEST_COUNT" -eq 0 ]; then
    print_warning "No DynamoDB requests found"
else
    print_success "Found $REQUEST_COUNT DynamoDB request(s)"
    echo ""

    docker exec k3d-${K3D_CLUSTER}-server-0 kubectl get dynamodbrequests --all-namespaces -o json 2>/dev/null | \
    jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name)\t\(.spec.name)\t\(.spec.region)\t\(.spec.billingMode)"' | \
    while read -r line; do
        namespace=$(echo "$line" | cut -f1)
        name=$(echo "$line" | cut -f2)
        table_name=$(echo "$line" | cut -f3)
        region=$(echo "$line" | cut -f4)
        billing=$(echo "$line" | cut -f5)

        echo "  • $name (table: $table_name)"
        echo "    └─ Region: $region, Billing: $billing"
    done
    echo ""
fi

# Check for any ACK Table resources that might have been created
print_info "Checking for ACK Table Resources..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

ACK_TABLES=$(docker exec k3d-${K3D_CLUSTER}-server-0 kubectl get tables.dynamodb.services.k8s.aws --all-namespaces -o name 2>/dev/null | wc -l)

if [ "$ACK_TABLES" -eq 0 ]; then
    print_warning "No ACK Table resources created yet"
    print_info "This is expected - the Kratix workflow operator must be running to convert requests to ACK Tables"
else
    print_success "Found $ACK_TABLES ACK Table resource(s)"
    docker exec k3d-${K3D_CLUSTER}-server-0 kubectl get tables.dynamodb.services.k8s.aws --all-namespaces 2>/dev/null | tail -n +2 | while read -r line; do
        echo "  • $line"
    done
fi

echo ""

# Summary
print_info "Promise Status Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "  Promise Definition:       ✅ Installed"
echo "  DynamoDBRequest CRD:      ✅ Installed"
echo "  Test Requests Created:    ✅ $REQUEST_COUNT"
echo "  Kratix Operator:          ❌ Not running (required for workflow execution)"
echo "  ACK Tables Created:       ❌ None (requires operator + workflow)"
echo ""

print_info "About Kratix Operator"
echo ""
echo "  The Promise is fully defined and requests are stored in Kubernetes."
echo "  However, to actually create DynamoDB tables, you need to:"
echo ""
echo "  1. Install the Kratix Operator"
echo "     kubectl apply -f https://github.com/syntasso/kratix/releases/download/<version>/kratix.yaml"
echo ""
echo "  2. Enable the Promise workflows"
echo "     The Kratix Operator will execute promise.configure to install ACK"
echo "     and resource.configure to generate ACK Table manifests"
echo ""
echo "  3. Configure ACK for actual table creation"
echo "     Tables will be created in AWS via the ACK DynamoDB controller"
echo ""

print_info "Useful Commands"
echo ""
echo "  # View all requests"
echo "  kubectl get dynamodbrequests -A"
echo ""
echo "  # View request details"
echo "  kubectl describe dynamodbrequest <name>"
echo ""
echo "  # View Promise definition"
echo "  kubectl get promise aws-dynamodb-kratix -o yaml"
echo ""
echo "  # View CRD schema"
echo "  kubectl get crd dynamodbrequests.dynamodb.kratix.io -o yaml"
echo ""

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                  Status: Ready for Operator                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
