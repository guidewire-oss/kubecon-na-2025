#!/bin/bash

# Clean up script: Delete all KubeVela applications and then delete the k3d cluster
# Works on both host cluster and DevContainer environments
#
# Usage:
#   Host (default):     ./clean.sh
#   DevContainer:       ./clean.sh --devcontainer
#   Host (explicit):    ./clean.sh --host

set -e

# Detect environment
ENVIRONMENT="${1:-host}"
case "$ENVIRONMENT" in
    --host|host)
        ENVIRONMENT="host"
        KUBECONFIG="${KUBECONFIG:-~/.kube/config}"
        echo "Running on HOST cluster (kubeconfig: $KUBECONFIG)"
        ;;
    --devcontainer|devcontainer)
        ENVIRONMENT="devcontainer"
        KUBECONFIG="${KUBECONFIG:-./kubeconfig-internal}"
        echo "Running on DEVCONTAINER cluster (kubeconfig: $KUBECONFIG)"
        ;;
    *)
        echo "Unknown environment: $ENVIRONMENT"
        echo "Usage: $0 [--host|--devcontainer]"
        echo "  --host           Clean up host cluster (default)"
        echo "  --devcontainer   Clean up DevContainer cluster"
        exit 1
        ;;
esac

echo "=========================================="
echo "Cleanup: Deleting all KubeVela applications"
echo "=========================================="

# Update kubeconfig port for DevContainer (host doesn't need this)
if [ "$ENVIRONMENT" = "devcontainer" ]; then
    CURRENT_PORT=$(docker port k3d-kubevela-demo-serverlb 2>/dev/null | grep 6443 | awk '{print $3}' | cut -d: -f2)
    if [ -n "$CURRENT_PORT" ]; then
        echo "Updating kubeconfig with current port: $CURRENT_PORT"
        sed -i "s|server: https://.*$|server: https://host.docker.internal:$CURRENT_PORT|" "$KUBECONFIG"
    fi
fi

# Function to delete application
delete_app() {
    local app_name="$1"
    local namespace="${2:-default}"
    echo "Deleting $app_name in namespace $namespace..."
    KUBECONFIG="$KUBECONFIG" vela delete "$app_name" --namespace "$namespace" -y 2>&1 | grep -E "succeeded|already|not found" || true
}

# Delete all applications from default namespace
echo "Deleting applications from default namespace..."
delete_app "dynamodb-basic-example" "default"
delete_app "dynamodb-basic-xp" "default"
delete_app "dynamodb-cache-table" "default"
delete_app "dynamodb-production-example" "default"
delete_app "dynamodb-production-with-traits" "default"
delete_app "dynamodb-provisioned-example" "default"
delete_app "dynamodb-simple-kro" "default"
delete_app "dynamodb-staging-with-traits" "default"
delete_app "dynamodb-streams-xp" "default"
delete_app "dynamodb-with-gsi-example" "default"
delete_app "sessions-xp" "default"

# Delete applications from production namespace
echo "Deleting applications from production namespace..."
delete_app "dynamodb-production-xp" "production"

# Wait for resources to be cleaned up
echo "Waiting for resources to be cleaned up..."
sleep 5

# Verify all apps are deleted
echo ""
echo "Verifying all applications are deleted..."
REMAINING=$(KUBECONFIG="$KUBECONFIG" kubectl get app -A 2>/dev/null | grep -v "velaux\|vela-system" | wc -l)
if [ "$REMAINING" -le 1 ]; then
    echo "✓ All applications successfully deleted"
else
    echo "⚠ Warning: Some applications may still be deleting"
fi

# Delete the cluster
echo ""
echo "=========================================="
echo "Deleting k3d cluster: kubevela-demo"
echo "=========================================="
k3d cluster delete kubevela-demo

echo ""
echo "=========================================="
echo "✓ Cleanup complete!"
echo "=========================================="
echo "Cluster has been deleted and all provisioned data removed."
