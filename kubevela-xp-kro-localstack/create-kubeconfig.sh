#!/bin/bash

# create-kubeconfig.sh - Generate kubeconfig for k3d cluster with DevContainer support
#
# This script creates a working kubeconfig that works from the DevContainer
# by using host.docker.internal to reach the k3d API server port.
#
# Usage:
#   ./create-kubeconfig.sh                    # Creates kubeconfig-internal
#   ./create-kubeconfig.sh kubeconfig-dev     # Creates kubeconfig-dev
#
# Requirements:
#   - k3d cluster named "kubevela-demo" must be running
#   - docker command available
#   - kubectl installed

set -e

CLUSTER_NAME="${CLUSTER_NAME:-kubevela-demo}"
OUTPUT_FILE="${1:-kubeconfig-internal}"

# Color output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if k3d cluster is running
if ! docker ps | grep -q "k3d-${CLUSTER_NAME}-serverlb"; then
    print_error "k3d cluster '${CLUSTER_NAME}' is not running"
    echo "Start it with: k3d cluster start ${CLUSTER_NAME}"
    exit 1
fi

print_info "Getting kubeconfig for cluster '${CLUSTER_NAME}'..."

# Get mapped port from loadbalancer (not server container)
if ! PORT=$(docker port "k3d-${CLUSTER_NAME}-serverlb" 2>/dev/null | grep 6443 | awk '{print $3}' | cut -d: -f2); then
    print_error "Could not determine API server port from loadbalancer"
    echo "Try: docker port k3d-${CLUSTER_NAME}-serverlb"
    exit 1
fi

print_info "API server port: ${PORT}"

# Generate kubeconfig from k3d
print_info "Generating kubeconfig from k3d..."
if ! KUBECONFIG=$(k3d kubeconfig get "${CLUSTER_NAME}" 2>/dev/null); then
    print_error "Failed to get kubeconfig from k3d"
    echo "Is k3d cluster '${CLUSTER_NAME}' running?"
    exit 1
fi

# Transform kubeconfig:
# 1. Replace 0.0.0.0:PORT with host.docker.internal:PORT (for DevContainer access)
# 2. Remove certificate-authority-data (conflicts with insecure-skip-tls-verify)
# 3. Add insecure-skip-tls-verify (needed because cert is for k3d-kubevela-demo-server-0, not host.docker.internal)

TRANSFORMED=$(echo "$KUBECONFIG" | \
    sed "s|server: https://0.0.0.0:${PORT}|server: https://host.docker.internal:${PORT}|" | \
    sed '/certificate-authority-data:/d' | \
    sed '/server:/a\    insecure-skip-tls-verify: true')

# Write kubeconfig
print_info "Writing kubeconfig to ${OUTPUT_FILE}..."
echo "$TRANSFORMED" > "${OUTPUT_FILE}"
chmod 600 "${OUTPUT_FILE}"

# Verify kubeconfig works
print_info "Verifying kubeconfig..."
if KUBECONFIG="./${OUTPUT_FILE}" kubectl get nodes &>/dev/null; then
    print_success "kubeconfig created and verified"
    print_success "File: ${OUTPUT_FILE}"
    echo ""
    echo "Use it with:"
    echo "  KUBECONFIG=./${OUTPUT_FILE} kubectl get nodes"
    echo "  KUBECONFIG=./${OUTPUT_FILE} vela ls -A"
else
    print_error "kubeconfig was created but verification failed"
    echo "Debug: Try running manually:"
    echo "  KUBECONFIG=./${OUTPUT_FILE} kubectl get nodes"
    exit 1
fi
