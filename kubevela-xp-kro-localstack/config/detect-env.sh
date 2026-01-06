#!/bin/bash
# Environment Detection Script
# Automatically detects runtime environment (DevContainer, Host, CI/CD)
# Sets configuration variables for subsequent use

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Color codes for output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# ============================================================================
# ENVIRONMENT DETECTION
# ============================================================================

detect_environment() {
    local env_type="unknown"
    local reason=""

    # Check if running in DevContainer
    if [ -f /.dockerenv ] && [ -f /.devcontainer/devcontainer.json ] 2>/dev/null || [ -n "$DEVCONTAINER" ]; then
        env_type="devcontainer"
        reason="DevContainer detected (/.dockerenv and/or DEVCONTAINER env var)"

    # Check if running in Docker but not DevContainer
    elif [ -f /.dockerenv ]; then
        env_type="docker"
        reason="Docker detected (/.dockerenv exists)"

    # Check if k3d is available
    elif command -v k3d &> /dev/null; then
        env_type="host"
        reason="Host machine (k3d command available)"

    # Check if kubectl is available
    elif command -v kubectl &> /dev/null; then
        env_type="host"
        reason="Host machine (kubectl available, no k3d)"

    # Check for CI environments
    elif [ -n "$GITHUB_ACTIONS" ]; then
        env_type="ci"
        reason="GitHub Actions CI detected"

    elif [ -n "$GITLAB_CI" ]; then
        env_type="ci"
        reason="GitLab CI detected"

    elif [ -n "$CI" ]; then
        env_type="ci"
        reason="Generic CI environment detected"

    else
        # Default to host if we have docker
        if command -v docker &> /dev/null; then
            env_type="host"
            reason="Docker available, assuming host machine"
        fi
    fi

    export ENV_TYPE="$env_type"
    print_info "Environment detected: $env_type ($reason)"
}

# ============================================================================
# CONFIGURATION SETUP
# ============================================================================

setup_environment_config() {
    case "$ENV_TYPE" in
        devcontainer)
            setup_devcontainer_config
            ;;
        docker)
            setup_docker_config
            ;;
        host)
            setup_host_config
            ;;
        ci)
            setup_ci_config
            ;;
        *)
            print_warning "Unknown environment type, using default configuration"
            setup_default_config
            ;;
    esac
}

setup_devcontainer_config() {
    print_info "Setting up DevContainer configuration"

    export IMAGE_NAME="session-api:latest"
    export IMAGE_REGISTRY="localhost:5000"  # k3d default registry port
    export LOCALSTACK_ENDPOINT="http://localstack.localstack-system.svc.cluster.local:4566"
    export KUBECONFIG_PATH="${DEMO_ROOT}/kubeconfig-internal"
    export KUBECONFIG="${KUBECONFIG_PATH}"
    export VELA_NAMESPACE="default"
    export TEST_ENDPOINT_MODE="cluster"
    export ENV_FILE="${DEMO_ROOT}/.env.devcontainer"

    print_success "DevContainer config: local registry, in-cluster endpoints"
}

setup_docker_config() {
    print_info "Setting up Docker (non-DevContainer) configuration"

    export IMAGE_NAME="session-api:latest"
    export IMAGE_REGISTRY="localhost:5000"
    export LOCALSTACK_ENDPOINT="http://localhost:4566"
    export KUBECONFIG_PATH="${DEMO_ROOT}/kubeconfig-internal"
    export KUBECONFIG="${KUBECONFIG_PATH}"
    export VELA_NAMESPACE="default"
    export TEST_ENDPOINT_MODE="localhost"
    export ENV_FILE="${DEMO_ROOT}/.env.docker"

    print_warning "Docker detected: may need port-forward for endpoint access"
}

setup_host_config() {
    print_info "Setting up Host machine configuration"

    # Try to detect k3d registry port
    local k3d_registry_port="5000"
    if command -v k3d &> /dev/null; then
        # Try to get registry port from k3d
        if k3d registry list 2>/dev/null | grep -q "kubevela-demo"; then
            k3d_registry_port=$(k3d registry list -o json 2>/dev/null | grep -o '"port":[0-9]*' | head -1 | grep -o '[0-9]*' || echo "5000")
        fi
    fi

    # Use standard kubeconfig location on host
    local kubeconfig_host="${HOME}/.kube/config"
    if [ ! -f "$kubeconfig_host" ]; then
        kubeconfig_host="${DEMO_ROOT}/kubeconfig-host"
    fi

    export IMAGE_NAME="session-api:latest"
    export IMAGE_REGISTRY="localhost:${k3d_registry_port}"
    export LOCALSTACK_ENDPOINT="http://localhost:4566"
    export KUBECONFIG_PATH="$kubeconfig_host"
    export KUBECONFIG="${KUBECONFIG_PATH}"
    export VELA_NAMESPACE="default"
    export TEST_ENDPOINT_MODE="portforward"
    export PORT_FORWARD_LOCALSTACK="4566:4566"
    export PORT_FORWARD_SESSION_API_KRO="9080:8080"
    export PORT_FORWARD_SESSION_API_XP="9081:8080"
    export ENV_FILE="${DEMO_ROOT}/.env.host"

    print_success "Host config: localhost endpoints, port-forward mode"
}

setup_ci_config() {
    print_info "Setting up CI/CD configuration"

    export IMAGE_NAME="session-api:latest"
    export IMAGE_REGISTRY="gcr.io/example"  # Example - override in CI
    export LOCALSTACK_ENDPOINT="http://localstack.localstack-system.svc.cluster.local:4566"
    export KUBECONFIG_PATH="${KUBECONFIG_PATH:-.}"
    export KUBECONFIG="${KUBECONFIG_PATH}"
    export VELA_NAMESPACE="default"
    export TEST_ENDPOINT_MODE="cluster"
    export ENV_FILE="${DEMO_ROOT}/.env.ci"

    print_success "CI/CD config: in-cluster endpoints"
}

setup_default_config() {
    print_warning "Using default configuration (may need adjustments)"

    export IMAGE_NAME="session-api:latest"
    export IMAGE_REGISTRY="localhost:5000"
    export LOCALSTACK_ENDPOINT="http://localhost:4566"
    export KUBECONFIG_PATH="${DEMO_ROOT}/kubeconfig-internal"
    export KUBECONFIG="${KUBECONFIG_PATH}"
    export VELA_NAMESPACE="default"
    export TEST_ENDPOINT_MODE="localhost"
    export ENV_FILE="${DEMO_ROOT}/.env"
}

# ============================================================================
# ENV FILE MANAGEMENT
# ============================================================================

load_env_file() {
    if [ -f "$ENV_FILE" ]; then
        print_info "Loading environment from: $ENV_FILE"
        set -a
        source "$ENV_FILE"
        set +a
    elif [ -f "${DEMO_ROOT}/.env" ]; then
        print_info "Loading environment from: ${DEMO_ROOT}/.env"
        set -a
        source "${DEMO_ROOT}/.env"
        set +a
    else
        print_info "No .env file found, using auto-detected values"
    fi
}

# ============================================================================
# VERIFICATION
# ============================================================================

verify_configuration() {
    print_info "Verifying environment configuration:"
    echo "  ENV_TYPE: $ENV_TYPE"
    echo "  IMAGE_NAME: $IMAGE_NAME"
    echo "  IMAGE_REGISTRY: $IMAGE_REGISTRY"
    echo "  LOCALSTACK_ENDPOINT: $LOCALSTACK_ENDPOINT"
    echo "  KUBECONFIG: $KUBECONFIG"
    echo "  TEST_ENDPOINT_MODE: $TEST_ENDPOINT_MODE"
}

# ============================================================================
# MAIN
# ============================================================================

# Run all detection and setup
detect_environment
setup_environment_config
load_env_file
verify_configuration

print_success "Environment detection complete"
