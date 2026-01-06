#!/bin/bash
# Common Test Utilities
# Provides shared functions and environment setup for all tests

set -e

# Script directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_ROOT="$(cd "${TEST_DIR}/.." && pwd)"

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ============================================================================
# OUTPUT FUNCTIONS
# ============================================================================

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_test() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}TEST: $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ============================================================================
# ENVIRONMENT SETUP
# ============================================================================

# Source environment detection
source "${DEMO_ROOT}/config/detect-env.sh"

# Source port-forward helpers
source "${DEMO_ROOT}/config/port-forward-helpers.sh"

# ============================================================================
# KUBERNETES UTILITIES
# ============================================================================

# Get kubeconfig path
get_kubeconfig() {
    if [ -n "$KUBECONFIG" ]; then
        echo "$KUBECONFIG"
    elif [ -f "${DEMO_ROOT}/kubeconfig-internal" ]; then
        echo "${DEMO_ROOT}/kubeconfig-internal"
    elif [ -f "${DEMO_ROOT}/kubeconfig-host" ]; then
        echo "${DEMO_ROOT}/kubeconfig-host"
    else
        echo ""
    fi
}

# Export kubeconfig for use in tests
export KUBECONFIG=$(get_kubeconfig)

# Verify kubeconfig is available
verify_kubeconfig() {
    local kubeconfig=$(get_kubeconfig)

    if [ -z "$kubeconfig" ]; then
        print_error "No kubeconfig found"
        return 1
    fi

    if ! kubectl --kubeconfig="$kubeconfig" cluster-info &> /dev/null; then
        print_error "Kubeconfig is not valid or cluster not accessible"
        return 1
    fi

    print_success "Kubeconfig verified: $kubeconfig"
    return 0
}

# Wait for pod to be ready
wait_for_pod() {
    local pod=$1
    local namespace=${2:-default}
    local kubeconfig=$(get_kubeconfig)
    local max_attempts=60

    print_info "Waiting for pod $namespace/$pod to be ready..."

    for ((i = 0; i < max_attempts; i++)); do
        if kubectl --kubeconfig="$kubeconfig" get pod -n "$namespace" "$pod" 2>/dev/null | grep -q "Running"; then
            print_success "Pod ready: $pod"
            return 0
        fi
        sleep 1
    done

    print_error "Pod did not become ready: $pod"
    return 1
}

# Get pod logs
get_pod_logs() {
    local pod=$1
    local namespace=${2:-default}
    local kubeconfig=$(get_kubeconfig)

    kubectl --kubeconfig="$kubeconfig" logs -n "$namespace" "$pod" --tail=50
}

# ============================================================================
# LOCALSTACK UTILITIES
# ============================================================================

# Verify LocalStack is accessible
verify_localstack() {
    local endpoint=${LOCALSTACK_ENDPOINT:-"http://localhost:4566"}

    print_info "Verifying LocalStack endpoint: $endpoint"

    if verify_endpoint_accessible "$endpoint" 5; then
        return 0
    else
        print_error "LocalStack not accessible at $endpoint"
        return 1
    fi
}

# List DynamoDB tables
list_dynamodb_tables() {
    local endpoint=${LOCALSTACK_ENDPOINT:-"http://localhost:4566"}
    local region=${AWS_REGION:-"us-west-2"}

    print_info "Listing DynamoDB tables from: $endpoint"

    # Use AWS CLI if available, otherwise kubectl run
    if command -v aws &> /dev/null; then
        aws dynamodb list-tables \
            --endpoint-url="$endpoint" \
            --region="$region" \
            2>/dev/null || echo "[]"
    else
        kubectl run aws-cli-test --image=amazon/aws-cli --rm -it --restart=Never -- \
            --endpoint-url="$endpoint" \
            --region="$region" \
            dynamodb list-tables 2>/dev/null || echo "[]"
    fi
}

# Create test table
create_test_table() {
    local table_name=$1
    local endpoint=${LOCALSTACK_ENDPOINT:-"http://localhost:4566"}
    local region=${AWS_REGION:-"us-west-2"}

    print_info "Creating test table: $table_name"

    if command -v aws &> /dev/null; then
        aws dynamodb create-table \
            --endpoint-url="$endpoint" \
            --region="$region" \
            --table-name "$table_name" \
            --attribute-definitions AttributeName=id,AttributeType=S \
            --key-schema AttributeName=id,KeyType=HASH \
            --billing-mode PAY_PER_REQUEST 2>/dev/null || true
    else
        kubectl run create-table-test --image=amazon/aws-cli --rm -it --restart=Never -- \
            --endpoint-url="$endpoint" \
            --region="$region" \
            dynamodb create-table \
            --table-name "$table_name" \
            --attribute-definitions AttributeName=id,AttributeType=S \
            --key-schema AttributeName=id,KeyType=HASH \
            --billing-mode PAY_PER_REQUEST 2>/dev/null || true
    fi

    print_success "Table creation request sent: $table_name"
}

# ============================================================================
# WEBSERVICE UTILITIES
# ============================================================================

# Test webservice health endpoint
test_health_endpoint() {
    local service=$1
    local port=${2:-8080}
    local url="http://localhost:$port/health"

    print_info "Testing health endpoint: $url"

    if curl -s "$url" | grep -q "healthy"; then
        print_success "Health check passed for $service"
        return 0
    else
        print_error "Health check failed for $service at $url"
        return 1
    fi
}

# Test webservice ready endpoint
test_ready_endpoint() {
    local service=$1
    local port=${2:-8080}
    local url="http://localhost:$port/ready"

    print_info "Testing ready endpoint: $url"

    if curl -s "$url" | grep -q "ready"; then
        print_success "Ready check passed for $service"
        return 0
    else
        print_error "Ready check failed for $service at $url"
        return 1
    fi
}

# ============================================================================
# TEST SETUP/TEARDOWN
# ============================================================================

setup_test_environment() {
    print_info "Setting up test environment for: $ENV_TYPE"

    # Verify kubeconfig
    verify_kubeconfig || return 1

    # Setup port-forwards if needed
    if [ "$TEST_ENDPOINT_MODE" = "portforward" ]; then
        setup_cleanup_trap
        setup_all_port_forwards
    fi

    # Verify LocalStack is accessible
    verify_localstack || return 1

    print_success "Test environment ready"
    return 0
}

teardown_test_environment() {
    print_info "Tearing down test environment"
    cleanup_port_forwards
}

# ============================================================================
# ASSERTION UTILITIES
# ============================================================================

assert_equals() {
    local actual=$1
    local expected=$2
    local message=$3

    if [ "$actual" = "$expected" ]; then
        print_success "Assertion passed: $message"
        return 0
    else
        print_error "Assertion failed: $message"
        print_error "  Expected: $expected"
        print_error "  Actual: $actual"
        return 1
    fi
}

assert_not_empty() {
    local value=$1
    local message=$2

    if [ -n "$value" ]; then
        print_success "Assertion passed: $message (not empty)"
        return 0
    else
        print_error "Assertion failed: $message (value is empty)"
        return 1
    fi
}

assert_contains() {
    local haystack=$1
    local needle=$2
    local message=$3

    if echo "$haystack" | grep -q "$needle"; then
        print_success "Assertion passed: $message"
        return 0
    else
        print_error "Assertion failed: $message"
        print_error "  Looking for: $needle"
        print_error "  In: $haystack"
        return 1
    fi
}

# ============================================================================
# EXPORT FOR USE IN TEST SCRIPTS
# ============================================================================

export -f print_info
export -f print_success
export -f print_warning
export -f print_error
export -f print_test
export -f verify_kubeconfig
export -f wait_for_pod
export -f get_pod_logs
export -f verify_localstack
export -f list_dynamodb_tables
export -f create_test_table
export -f test_health_endpoint
export -f test_ready_endpoint
export -f setup_test_environment
export -f teardown_test_environment
export -f assert_equals
export -f assert_not_empty
export -f assert_contains
