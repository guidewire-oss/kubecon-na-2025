#!/bin/bash
# Test LocalStack deployment and connectivity
# Works in any environment: DevContainer, Host, CI/CD

set -e

# Source common test utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Setup test environment
setup_test_environment || {
    print_error "Failed to setup test environment"
    exit 1
}

print_test "LocalStack Connectivity Tests"

# Get kubeconfig
KUBECONFIG=$(get_kubeconfig)
ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"
REGION="us-west-2"

print_test "Test 1: LocalStack pod is running"
kubectl --kubeconfig="$KUBECONFIG" get pods -n localstack-system -l app.kubernetes.io/name=localstack
print_success "LocalStack pod found"

print_test "Test 2: LocalStack service is accessible"
if [ "$TEST_ENDPOINT_MODE" = "cluster" ]; then
    kubectl --kubeconfig="$KUBECONFIG" run test-connectivity --image=amazon/aws-cli --rm -it --restart=Never -- \
      --endpoint-url="$ENDPOINT" --region="$REGION" dynamodb list-tables
else
    verify_endpoint_accessible "$ENDPOINT" || {
        print_error "LocalStack endpoint not accessible"
        exit 1
    }
fi
print_success "LocalStack is accessible"

print_test "Test 3: Can create table in LocalStack"
create_test_table "test-table"
print_success "Table creation request sent"

print_test "Test 4: Can list tables"
list_dynamodb_tables
print_success "Table listing successful"

print_success "✓ All LocalStack tests passed"

# Cleanup
teardown_test_environment
