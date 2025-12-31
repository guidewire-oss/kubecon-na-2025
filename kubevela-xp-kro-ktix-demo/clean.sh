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

# Wait for resources to be cleaned up with retry logic
echo ""
echo "Waiting for all applications to be fully deleted..."
MAX_WAIT=120
WAIT_INTERVAL=5
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    REMAINING=$(KUBECONFIG="$KUBECONFIG" kubectl get app -A 2>/dev/null | grep -v "velaux\|vela-system\|^NAMESPACE" | wc -l)

    if [ "$REMAINING" -eq 0 ]; then
        echo "✓ All applications successfully deleted after ${ELAPSED}s"
        break
    else
        echo "  Waiting for deletion... ($REMAINING apps remaining) [${ELAPSED}s]"
        sleep $WAIT_INTERVAL
        ELAPSED=$((ELAPSED + WAIT_INTERVAL))
    fi
done

# Final verification
echo ""
echo "Final verification of application deletion..."
REMAINING=$(KUBECONFIG="$KUBECONFIG" kubectl get app -A 2>/dev/null | grep -v "velaux\|vela-system\|^NAMESPACE" | wc -l)

if [ "$REMAINING" -eq 0 ]; then
    echo "✓ All applications deleted successfully"
else
    echo "⚠ Warning: $REMAINING application(s) still present:"
    KUBECONFIG="$KUBECONFIG" kubectl get app -A 2>/dev/null | grep -v "velaux\|vela-system"
    echo ""
    read -p "Continue with cluster deletion anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborting cluster deletion"
        exit 1
    fi
fi

# Verify no DynamoDB resources remain
echo ""
echo "Verifying AWS resources are deleted..."
KRO_TABLES=$(KUBECONFIG="$KUBECONFIG" kubectl get dynamodbtable.kro.run -A 2>/dev/null | grep -v "^NAMESPACE" | wc -l)
ACK_TABLES=$(KUBECONFIG="$KUBECONFIG" kubectl get table.dynamodb.services.k8s.aws -A 2>/dev/null | grep -v "^NAMESPACE" | wc -l)
XP_TABLES=$(KUBECONFIG="$KUBECONFIG" kubectl get table.dynamodb.aws.upbound.io -A 2>/dev/null | grep -v "^NAMESPACE" | wc -l)

if [ "$KRO_TABLES" -eq 0 ] && [ "$ACK_TABLES" -eq 0 ] && [ "$XP_TABLES" -eq 0 ]; then
    echo "✓ All AWS DynamoDB resources cleaned up"
else
    echo "⚠ Warning: AWS resources may still exist"
    [ "$KRO_TABLES" -gt 0 ] && echo "  - $KRO_TABLES KRO DynamoDBTable(s)"
    [ "$ACK_TABLES" -gt 0 ] && echo "  - $ACK_TABLES ACK Table(s)"
    [ "$XP_TABLES" -gt 0 ] && echo "  - $XP_TABLES Crossplane Table(s)"
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
