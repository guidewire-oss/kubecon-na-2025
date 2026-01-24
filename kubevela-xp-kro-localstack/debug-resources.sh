#!/bin/bash
# Comprehensive diagnostic script for LocalStack demo troubleshooting
# Shows the state of all Kubernetes resources and controller logs

set +e  # Don't exit on errors - we want to see all diagnostics

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

print_section() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
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

print_section "LocalStack Demo Resource Diagnostics"
echo "Environment: $ENV_TYPE"
echo "Kubeconfig: $KUBECONFIG"
echo "LocalStack Endpoint: $LOCALSTACK_ENDPOINT"
echo ""

# ============================================================================
# 1. INFRASTRUCTURE PODS
# ============================================================================
print_section "1. INFRASTRUCTURE PODS STATUS"

print_subsection "LocalStack"
kubectl get pods -n localstack-system 2>/dev/null || print_error "Cannot access localstack-system namespace"

print_subsection "KubeVela"
kubectl get pods -n vela-system 2>/dev/null || print_error "Cannot access vela-system namespace"

print_subsection "Crossplane"
kubectl get pods -n crossplane-system 2>/dev/null || print_error "Cannot access crossplane-system namespace"

print_subsection "KRO"
kubectl get pods -n kro-system 2>/dev/null || print_error "Cannot access kro-system namespace"

print_subsection "ACK"
kubectl get pods -n ack-system 2>/dev/null || print_error "Cannot access ack-system namespace"

# ============================================================================
# 2. APPLICATION RESOURCES
# ============================================================================
print_section "2. APPLICATION RESOURCES"

print_subsection "KubeVela Applications"
kubectl get applications -A 2>/dev/null || print_error "Cannot list applications"

print_subsection "Application Components"
kubectl get components -A 2>/dev/null || print_error "Cannot list components"

print_subsection "Application Traits"
kubectl get traits -A 2>/dev/null || print_error "Cannot list traits"

# ============================================================================
# 3. DYNAMODB TABLE RESOURCES
# ============================================================================
print_section "3. DYNAMODB TABLE RESOURCES (CRITICAL)"

print_subsection "SimpleDynamoDB Resources (KRO Input)"
kubectl get simpledynamodb -A 2>/dev/null && print_success "SimpleDynamoDB resources found" || {
    print_warning "No SimpleDynamoDB resources found"
    echo "  → This is created by KRO component in VeLa application"
    echo "  → If none exist, VeLa application may not be deploying components"
}

print_subsection "ACK DynamoDB Table Resources (KRO Output)"
kubectl get table.dynamodb.services.k8s.aws -A 2>/dev/null && print_success "ACK Table resources found" || {
    print_warning "No ACK DynamoDB Table resources found"
    echo "  → This should be created by KRO ResourceGraphDefinition"
    echo "  → If KRO RGD is watching SimpleDynamoDB, it should create these"
}

print_subsection "Crossplane DynamoDB Table Resources"
kubectl get table.dynamodb.aws.upbound.io -A 2>/dev/null && print_success "Crossplane Table resources found" || {
    print_warning "No Crossplane Table resources found"
    echo "  → This is created by Crossplane component in VeLa application"
    echo "  → If none exist, VeLa application may not be deploying components"
}

print_subsection "All DynamoDB-related resources"
kubectl get all -A -l app.kubernetes.io/part-of=dynamodb 2>/dev/null || print_warning "No DynamoDB labeled resources found"

# ============================================================================
# 4. VELA COMPONENT DEFINITIONS
# ============================================================================
print_section "4. VELA COMPONENT DEFINITIONS"

print_subsection "Available Component Types"
kubectl get componentdefinitions -n vela-system 2>/dev/null | grep -E "aws-dynamodb|simple" || print_warning "DynamoDB component definitions not found"

print_subsection "All Component Definitions"
kubectl get componentdefinitions -n vela-system 2>/dev/null | head -20

# ============================================================================
# 5. CROSSPLANE PROVIDER CONFIG
# ============================================================================
print_section "5. CROSSPLANE PROVIDER CONFIGURATION"

print_subsection "ProviderConfig (Cluster-scope)"
kubectl get providerconfig -A 2>/dev/null || print_error "Cannot list ProviderConfig"

print_subsection "ProviderConfig Details (default/default)"
kubectl get providerconfig default -o yaml 2>/dev/null | grep -A 20 "spec:" || print_warning "Cannot get ProviderConfig details"

# ============================================================================
# 6. KRO RESOURCE GRAPH DEFINITION
# ============================================================================
print_section "6. KRO RESOURCE GRAPH DEFINITION"

print_subsection "ResourceGraphDefinitions"
kubectl get resourcegraphdefinitions -A 2>/dev/null || print_warning "No ResourceGraphDefinitions found"

print_subsection "RGD Details"
kubectl get resourcegraphdefinitions -A -o wide 2>/dev/null || print_warning "Cannot get RGD details"

# ============================================================================
# 7. CONTROLLER LOGS (Last 30 lines)
# ============================================================================
print_section "7. CONTROLLER LOGS FOR ERRORS"

print_subsection "ACK DynamoDB Controller Logs"
echo "Last 30 lines of ACK controller:"
kubectl logs -n ack-system -l app=ack-dynamodb-controller --tail=30 2>/dev/null | tail -30 || print_warning "Cannot get ACK controller logs"

print_subsection "Crossplane Controller Logs"
echo "Last 30 lines of Crossplane controller:"
kubectl logs -n crossplane-system -l app=crossplane --tail=30 2>/dev/null | tail -30 || print_warning "Cannot get Crossplane controller logs"

print_subsection "KRO Controller Logs"
echo "Last 30 lines of KRO controller:"
kubectl logs -n kro-system -l app.kubernetes.io/instance=kro --tail=30 2>/dev/null | tail -30 || print_warning "Cannot get KRO controller logs"

print_subsection "KubeVela Controller Logs"
echo "Last 30 lines of KubeVela controller:"
kubectl logs -n vela-system -l app.kubernetes.io/name=vela-core --tail=30 2>/dev/null | tail -30 || print_warning "Cannot get KubeVela controller logs"

# ============================================================================
# 8. APPLICATION DETAILED STATUS
# ============================================================================
print_section "8. APPLICATION DETAILED STATUS"

print_subsection "Session API KRO Application"
kubectl get application session-api-app-kro -n default -o yaml 2>/dev/null | grep -A 50 "status:" || print_warning "Cannot get session-api-app-kro status"

print_subsection "Session API XP Application"
kubectl get application session-api-app-xp -n default -o yaml 2>/dev/null | grep -A 50 "status:" || print_warning "Cannot get session-api-app-xp status"

# ============================================================================
# 9. VELA APPLICATION COMMAND OUTPUT
# ============================================================================
print_section "9. VELA CLI STATUS"

print_subsection "All Applications (vela ls -A)"
KUBECONFIG="$KUBECONFIG" vela ls -A 2>/dev/null || print_warning "Cannot run vela ls -A"

print_subsection "KRO Application Status (vela status)"
KUBECONFIG="$KUBECONFIG" vela status session-api-app-kro 2>/dev/null || print_warning "Cannot get KRO app status"

print_subsection "XP Application Status (vela status)"
KUBECONFIG="$KUBECONFIG" vela status session-api-app-xp 2>/dev/null || print_warning "Cannot get XP app status"

# ============================================================================
# 10. LOCALSTACK CONNECTIVITY
# ============================================================================
print_section "10. LOCALSTACK CONNECTIVITY TEST"

print_subsection "LocalStack Service"
kubectl get svc -n localstack-system localstack -o yaml 2>/dev/null | grep -E "name:|port:|clusterIP:" || print_warning "Cannot get LocalStack service details"

print_subsection "Test: List DynamoDB Tables via kubectl exec"
echo "Running: aws dynamodb list-tables --endpoint-url=http://localhost:4566 --region=us-west-2"
kubectl exec -n localstack-system $(kubectl get pod -n localstack-system -l app.kubernetes.io/name=localstack -o jsonpath='{.items[0].metadata.name}') -- \
  bash -c "aws dynamodb list-tables --endpoint-url=http://localhost:4566 --region=us-west-2 2>/dev/null" 2>/dev/null || {
    print_warning "Cannot run AWS CLI command in LocalStack pod"
    echo "Trying alternative method..."
}

# ============================================================================
# 11. SUMMARY AND RECOMMENDATIONS
# ============================================================================
print_section "11. SUMMARY AND NEXT STEPS"

echo ""
echo "To diagnose the issue, check the following in order:"
echo ""
echo "1. SimpleDynamoDB Resources:"
echo "   → Run: kubectl get simpledynamodb -A"
echo "   → If NONE exist, VeLa components aren't being created"
echo "   → Check: vela status session-api-app-kro"
echo ""
echo "2. ACK Table Resources:"
echo "   → Run: kubectl get table.dynamodb.services.k8s.aws -A"
echo "   → If NONE exist, KRO isn't watching SimpleDynamoDB"
echo "   → Check: kubectl logs -n kro-system -l app.kubernetes.io/instance=kro | grep -i simple"
echo ""
echo "3. Crossplane Table Resources:"
echo "   → Run: kubectl get table.dynamodb.aws.upbound.io -A"
echo "   → If NONE exist, Crossplane component isn't being created"
echo "   → Check: vela status session-api-app-xp"
echo ""
echo "4. Controller Errors:"
echo "   → Check ACK logs: kubectl logs -n ack-system -l app=ack-dynamodb-controller | grep -i error"
echo "   → Check Crossplane logs: kubectl logs -n crossplane-system -l app=crossplane | grep -i error"
echo ""
echo "5. Manual Table Creation Test:"
echo "   → Run a test table creation via KRO or Crossplane to see actual error"
echo "   → Check: ./test-manual-table-creation.sh (see next section)"
echo ""

print_section "Additional Debugging"

echo ""
echo "To manually test table creation:"
echo ""
echo "KRO SimpleDynamoDB Test:"
echo "  kubectl apply -f - <<'EOF'"
echo "apiVersion: kro.run/v1alpha1"
echo "kind: SimpleDynamoDB"
echo "metadata:"
echo "  name: test-kro-table"
echo "  namespace: default"
echo "spec:"
echo "  tableName: test-kro-manual"
echo "  region: us-west-2"
echo "EOF"
echo ""
echo "Then check:"
echo "  kubectl get simpledynamodb test-kro-table -o yaml | grep -A 20 'status:'"
echo "  kubectl get table.dynamodb.services.k8s.aws -A"
echo ""
echo "Crossplane Table Test:"
echo "  kubectl apply -f - <<'EOF'"
echo "apiVersion: dynamodb.aws.upbound.io/v1beta1"
echo "kind: Table"
echo "metadata:"
echo "  name: test-xp-table"
echo "  namespace: default"
echo "spec:"
echo "  forProvider:"
echo "    region: us-west-2"
echo "    attribute:"
echo "      - name: id"
echo "        type: S"
echo "    hashKey: id"
echo "    billingMode: PAY_PER_REQUEST"
echo "  providerConfigRef:"
echo "    name: default"
echo "EOF"
echo ""
echo "Then check:"
echo "  kubectl get table test-xp-table -o yaml | grep -A 20 'status:'"
echo "  kubectl logs -n crossplane-system -l app=crossplane | tail -50"
echo ""

echo -e "\n${BLUE}Diagnostic complete!${NC}"
