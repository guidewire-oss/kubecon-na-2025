#!/bin/bash
# Port Forward Helper Functions
# Provides utilities for setting up and managing port-forwards

set -e

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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

# ============================================================================
# PORT FORWARD MANAGEMENT
# ============================================================================

# Create a port-forward with automatic cleanup
setup_port_forward() {
    local local_port=$1
    local remote_port=$2
    local service=$3
    local namespace=${4:-default}
    local kubeconfig=${KUBECONFIG:-.}

    print_info "Setting up port-forward: localhost:$local_port -> $service:$remote_port"

    # Check if port is already in use
    if netstat -tuln 2>/dev/null | grep -q ":$local_port "; then
        print_warning "Port $local_port already in use, trying to reuse..."
    fi

    # Start port-forward in background
    kubectl --kubeconfig="$kubeconfig" port-forward -n "$namespace" "svc/$service" "$local_port:$remote_port" \
        > /dev/null 2>&1 &

    local pf_pid=$!
    echo $pf_pid

    # Wait for port to become available
    local max_attempts=10
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if nc -z localhost "$local_port" 2>/dev/null; then
            print_success "Port-forward ready: localhost:$local_port"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 1
    done

    print_warning "Port-forward setup but connection check failed"
    return 1
}

# Setup all necessary port-forwards based on environment
setup_all_port_forwards() {
    local kubeconfig=${KUBECONFIG:-.}
    local pf_pids=()

    print_info "Setting up port-forwards for $TEST_ENDPOINT_MODE mode"

    if [ "$TEST_ENDPOINT_MODE" = "portforward" ]; then
        # LocalStack port-forward
        if [ -n "$PORT_FORWARD_LOCALSTACK" ]; then
            local local_port=$(echo "$PORT_FORWARD_LOCALSTACK" | cut -d: -f1)
            local remote_port=$(echo "$PORT_FORWARD_LOCALSTACK" | cut -d: -f2)
            setup_port_forward "$local_port" "$remote_port" "localstack" "localstack-system"
            pf_pids+=($!)
        fi

        # Session API KRO port-forward
        if [ -n "$PORT_FORWARD_SESSION_API_KRO" ]; then
            local local_port=$(echo "$PORT_FORWARD_SESSION_API_KRO" | cut -d: -f1)
            local remote_port=$(echo "$PORT_FORWARD_SESSION_API_KRO" | cut -d: -f2)
            setup_port_forward "$local_port" "$remote_port" "session-api-kro" "default"
            pf_pids+=($!)
        fi

        # Session API XP port-forward
        if [ -n "$PORT_FORWARD_SESSION_API_XP" ]; then
            local local_port=$(echo "$PORT_FORWARD_SESSION_API_XP" | cut -d: -f1)
            local remote_port=$(echo "$PORT_FORWARD_SESSION_API_XP" | cut -d: -f2)
            setup_port_forward "$local_port" "$remote_port" "session-api-xp" "default"
            pf_pids+=($!)
        fi

        # Save PIDs for cleanup
        echo "${pf_pids[@]}" > /tmp/port-forward-pids.txt
        print_success "All port-forwards configured"
    else
        print_info "Cluster mode: port-forwards not needed"
    fi
}

# Cleanup port-forwards
cleanup_port_forwards() {
    if [ -f /tmp/port-forward-pids.txt ]; then
        local pids=$(cat /tmp/port-forward-pids.txt)
        print_info "Cleaning up port-forwards: $pids"
        for pid in $pids; do
            if kill "$pid" 2>/dev/null; then
                print_success "Killed port-forward process: $pid"
            fi
        done
        rm -f /tmp/port-forward-pids.txt
    fi
}

# Verify port is accessible
verify_port_accessible() {
    local host=$1
    local port=$2
    local max_attempts=${3:-10}
    local attempt=0

    print_info "Verifying $host:$port is accessible"

    while [ $attempt -lt $max_attempts ]; do
        if nc -z "$host" "$port" 2>/dev/null; then
            print_success "Port $host:$port is accessible"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 1
    done

    print_error "Port $host:$port is not accessible after $max_attempts attempts"
    return 1
}

# Verify endpoint accessibility
verify_endpoint_accessible() {
    local endpoint=$1
    local max_attempts=${2:-10}
    local attempt=0

    print_info "Verifying endpoint: $endpoint"

    while [ $attempt -lt $max_attempts ]; do
        if curl -s "$endpoint" > /dev/null 2>&1; then
            print_success "Endpoint is accessible: $endpoint"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 1
    done

    print_error "Endpoint not accessible after $max_attempts attempts: $endpoint"
    return 1
}

# ============================================================================
# SETUP TRAP FOR CLEANUP
# ============================================================================

setup_cleanup_trap() {
    trap cleanup_port_forwards EXIT INT TERM
}

# Export functions
export -f setup_port_forward
export -f setup_all_port_forwards
export -f cleanup_port_forwards
export -f verify_port_accessible
export -f verify_endpoint_accessible
export -f setup_cleanup_trap
