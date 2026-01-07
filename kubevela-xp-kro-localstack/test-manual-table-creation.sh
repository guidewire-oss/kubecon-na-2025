#!/bin/bash
# Manual table creation test - helps identify where the issue is
# Tests both KRO and Crossplane implementations independently

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

print_step() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
}

print_subsection() {
    echo -e "\n${CYAN}→ $1${NC}"
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

# Source environment detection
if [ -f "$DEMO_ROOT/config/detect-env.sh" ]; then
    source "$DEMO_ROOT/config/detect-env.sh"
else
    print_error "Could not find config/detect-env.sh"
    exit 1
fi

print_step "Manual Table Creation Test - KRO vs Crossplane"

# ============================================================================
# TEST 1: KRO SimpleDynamoDB
# ============================================================================
print_step "TEST 1: KRO SimpleDynamoDB Table Creation"

print_subsection "Creating SimpleDynamoDB resource..."

kubectl apply -f - <<'EOF'
apiVersion: kro.run/v1alpha1
kind: SimpleDynamoDB
metadata:
  name: test-kro-manual-table
  namespace: default
spec:
  tableName: test-kro-manual
  region: us-west-2
EOF

print_success "SimpleDynamoDB resource created"

print_subsection "Waiting 10 seconds for KRO to process..."
sleep 10

print_subsection "Checking SimpleDynamoDB resource status..."
echo ""
kubectl get simpledynamodb test-kro-manual-table -n default -o yaml

print_subsection "Checking if ACK Table was created by KRO..."
echo ""
TABLES=$(kubectl get table.dynamodb.services.k8s.aws -A -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
if [ -z "$TABLES" ]; then
    print_error "No ACK Table resources found"
    echo "  → KRO is not converting SimpleDynamoDB to Table"
    echo "  → Check KRO logs: kubectl logs -n kro-system -l app.kubernetes.io/instance=kro | tail -50"
else
    print_success "ACK Table resources found: $TABLES"
    print_subsection "ACK Table details:"
    kubectl get table.dynamodb.services.k8s.aws -A -o yaml
fi

print_subsection "Checking ACK controller logs for errors..."
echo ""
kubectl logs -n ack-system -l app=ack-dynamodb-controller --tail=50 2>/dev/null | tail -20 || print_warning "Cannot get ACK logs"

print_subsection "Checking LocalStack for table..."
echo ""
LOCALSTACK_POD=$(kubectl get pod -n localstack-system -l app.kubernetes.io/name=localstack -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$LOCALSTACK_POD" ]; then
    kubectl exec -n localstack-system "$LOCALSTACK_POD" -- \
      bash -c "aws dynamodb list-tables --endpoint-url=http://localhost:4566 --region=us-west-2 2>/dev/null" 2>/dev/null || print_warning "Cannot query LocalStack"
else
    print_error "LocalStack pod not found"
fi

# ============================================================================
# TEST 2: Crossplane DynamoDB Table
# ============================================================================
print_step "TEST 2: Crossplane DynamoDB Table Creation"

print_subsection "Creating Crossplane Table resource..."

kubectl apply -f - <<'EOF'
apiVersion: dynamodb.aws.upbound.io/v1beta1
kind: Table
metadata:
  name: test-xp-manual-table
  namespace: default
spec:
  forProvider:
    region: us-west-2
    attribute:
      - name: id
        type: S
    hashKey: id
    billingMode: PAY_PER_REQUEST
  providerConfigRef:
    name: default
EOF

print_success "Crossplane Table resource created"

print_subsection "Waiting 10 seconds for Crossplane to process..."
sleep 10

print_subsection "Checking Crossplane Table resource status..."
echo ""
kubectl get table.dynamodb.aws.upbound.io test-xp-manual-table -n default -o yaml

print_subsection "Checking Crossplane controller logs for errors..."
echo ""
kubectl logs -n crossplane-system -l app=crossplane --tail=50 2>/dev/null | tail -20 || print_warning "Cannot get Crossplane logs"

print_subsection "Checking LocalStack for table..."
echo ""
LOCALSTACK_POD=$(kubectl get pod -n localstack-system -l app.kubernetes.io/name=localstack -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$LOCALSTACK_POD" ]; then
    kubectl exec -n localstack-system "$LOCALSTACK_POD" -- \
      bash -c "aws dynamodb list-tables --endpoint-url=http://localhost:4566 --region=us-west-2 2>/dev/null" 2>/dev/null || print_warning "Cannot query LocalStack"
else
    print_error "LocalStack pod not found"
fi

# ============================================================================
# SUMMARY
# ============================================================================
print_step "SUMMARY AND NEXT STEPS"

echo ""
echo "If SimpleDynamoDB created but no ACK Table:"
echo "  → KRO RGD is not watching SimpleDynamoDB"
echo "  → Check: kubectl get resourcegraphdefinitions"
echo "  → Check KRO logs: kubectl logs -n kro-system | grep -i simpledynamodb"
echo ""
echo "If ACK Table created but no LocalStack table:"
echo "  → ACK controller not syncing with LocalStack"
echo "  → Check: kubectl logs -n ack-system -l app=ack-dynamodb-controller | grep -i error"
echo "  → Verify: kubectl logs -n ack-system -l app=ack-dynamodb-controller | grep -i localstack"
echo ""
echo "If Crossplane Table created but no LocalStack table:"
echo "  → Crossplane provider not syncing with LocalStack"
echo "  → Check: kubectl logs -n crossplane-system -l app=crossplane | grep -i error"
echo "  → Verify: kubectl get providerconfig default -o yaml | grep endpoint"
echo ""
echo "To clean up test resources:"
echo "  kubectl delete simpledynamodb test-kro-manual-table -n default"
echo "  kubectl delete table.dynamodb.aws.upbound.io test-xp-manual-table -n default"
echo ""

print_success "Manual test complete!"
