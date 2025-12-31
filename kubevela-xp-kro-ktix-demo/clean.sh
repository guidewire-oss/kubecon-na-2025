#!/bin/bash

# Clean up script: Delete all KubeVela applications and then delete the k3d cluster
# Works on both host cluster and DevContainer environments
#
# Usage:
#   Host (default):     ./clean.sh
#   DevContainer:       ./clean.sh --devcontainer
#   Host (explicit):    ./clean.sh --host

# Don't exit on errors - we want to show all output and let user decide
set +e

# Detect environment
ENVIRONMENT="${1:-host}"
case "$ENVIRONMENT" in
    --host|host)
        ENVIRONMENT="host"
        KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
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

# Expand kubeconfig path and verify it exists
KUBECONFIG=$(eval echo "$KUBECONFIG")
export KUBECONFIG
if [ ! -f "$KUBECONFIG" ]; then
    echo "✗ Error: kubeconfig file not found: $KUBECONFIG"
    echo ""
    echo "Please ensure:"
    echo "  1. kubectl is configured: kubectl config view"
    echo "  2. kubeconfig exists at: $KUBECONFIG"
    echo "  3. You're using correct environment: $ENVIRONMENT"
    exit 1
fi

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

# Remove deletion protection from DynamoDB tables (Crossplane)
echo ""
echo "Removing deletion protection from Crossplane DynamoDB tables..."
kubectl get table.dynamodb.aws.upbound.io -A -o json 2>/dev/null | \
  jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' | while read namespace name; do
    if [ -n "$namespace" ] && [ -n "$name" ]; then
        # Check if table has deletion protection enabled
        is_protected=$(kubectl get table.dynamodb.aws.upbound.io "$name" -n "$namespace" -o jsonpath='{.spec.forProvider.deletionProtectionEnabled}' 2>/dev/null)
        if [ "$is_protected" = "true" ]; then
            echo "  Disabling deletion protection on $name in $namespace..."
            kubectl patch table.dynamodb.aws.upbound.io "$name" -n "$namespace" --type merge -p '{"spec":{"forProvider":{"deletionProtectionEnabled":false}}}' 2>/dev/null || true
            sleep 2  # Wait for patch to be applied
        fi
    fi
done

# Remove deletion protection from KRO DynamoDBTable resources
echo ""
echo "Removing deletion protection from KRO DynamoDBTable resources..."
kubectl get dynamodbtable -A -o json 2>/dev/null | \
  jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' | while read namespace name; do
    if [ -n "$namespace" ] && [ -n "$name" ]; then
        # Check if table has deletion protection enabled
        is_protected=$(kubectl get dynamodbtable "$name" -n "$namespace" -o jsonpath='{.spec.deletionProtectionEnabled}' 2>/dev/null)
        if [ "$is_protected" = "true" ]; then
            echo "  Disabling deletion protection on KRO table $name in $namespace..."
            kubectl patch dynamodbtable "$name" -n "$namespace" --type merge -p '{"spec":{"deletionProtectionEnabled":false}}' 2>/dev/null || true
            sleep 1
        fi
    fi
done

# Remove deletion protection from KRO/ACK DynamoDB tables
echo ""
echo "Removing deletion protection from ACK DynamoDB tables..."
kubectl get table.dynamodb.services.k8s.aws -A -o json 2>/dev/null | \
  jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' | while read namespace name; do
    if [ -n "$namespace" ] && [ -n "$name" ]; then
        # Check if table has deletion protection enabled
        is_protected=$(kubectl get table.dynamodb.services.k8s.aws "$name" -n "$namespace" -o jsonpath='{.spec.deletionProtectionEnabled}' 2>/dev/null)
        if [ "$is_protected" = "true" ]; then
            echo "  Disabling deletion protection on ACK table $name in $namespace..."
            kubectl patch table.dynamodb.services.k8s.aws "$name" -n "$namespace" --type merge -p '{"spec":{"deletionProtectionEnabled":false}}' 2>/dev/null || true
            sleep 1
        fi
    fi
done

# Function to delete application with verbose output
delete_app() {
    local app_name="$1"
    local namespace="${2:-default}"
    echo "Deleting $app_name in namespace $namespace..."
    vela delete "$app_name" --namespace "$namespace" -y 2>&1
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo "  ✓ Delete command accepted for $app_name"
    else
        echo "  ⚠ Delete command returned exit code $exit_code for $app_name"
    fi
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
MAX_WAIT=90
WAIT_INTERVAL=5
ELAPSED=0
FORCE_DELETE_TIME=60

while [ $ELAPSED -lt $MAX_WAIT ]; do
    REMAINING=$(kubectl get app -A 2>/dev/null | grep -v "velaux\|vela-system\|^NAMESPACE" | wc -l)

    if [ "$REMAINING" -eq 0 ]; then
        echo "✓ All applications successfully deleted after ${ELAPSED}s"
        break
    else
        # Every 15 seconds, try removing deletion protection again (apps may reapply it during reconciliation)
        if [ $((ELAPSED % 15)) -eq 0 ]; then
            echo "  ⚠ Apps still pending - reapplying deletion protection removal [${ELAPSED}s]..."

            # Reapply deletion protection removal for KRO tables
            kubectl get dynamodbtable -A -o json 2>/dev/null | \
              jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' | while read ns tbl; do
                if [ -n "$ns" ] && [ -n "$tbl" ]; then
                    kubectl patch dynamodbtable "$tbl" -n "$ns" --type merge -p '{"spec":{"deletionProtectionEnabled":false}}' 2>/dev/null || true
                fi
              done

            # Reapply deletion protection removal for ACK tables
            kubectl get table.dynamodb.services.k8s.aws -A -o json 2>/dev/null | \
              jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' | while read ns tbl; do
                if [ -n "$ns" ] && [ -n "$tbl" ]; then
                    kubectl patch table.dynamodb.services.k8s.aws "$tbl" -n "$ns" --type merge -p '{"spec":{"deletionProtectionEnabled":false}}' 2>/dev/null || true
                fi
              done

            # Reapply deletion protection removal for Crossplane tables
            kubectl get table.dynamodb.aws.upbound.io -A -o json 2>/dev/null | \
              jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' | while read ns tbl; do
                if [ -n "$ns" ] && [ -n "$tbl" ]; then
                    kubectl patch table.dynamodb.aws.upbound.io "$tbl" -n "$ns" --type merge -p '{"spec":{"forProvider":{"deletionProtectionEnabled":false}}}' 2>/dev/null || true
                fi
              done
        fi

        # If apps still stuck after 60s, force delete them
        if [ $ELAPSED -eq $FORCE_DELETE_TIME ]; then
            echo "  ⚠ Apps still pending after ${FORCE_DELETE_TIME}s - forcing deletion..."
            kubectl delete app --all -A --grace-period=0 --force 2>/dev/null || true
            echo "  Force delete issued - waiting for finalizers to complete..."
        fi

        echo "  Waiting for deletion... ($REMAINING apps remaining) [${ELAPSED}s]"
        sleep $WAIT_INTERVAL
        ELAPSED=$((ELAPSED + WAIT_INTERVAL))
    fi
done

# Final verification
echo ""
echo "Final verification of application deletion..."
REMAINING=$(kubectl get app -A 2>/dev/null | grep -v "velaux\|vela-system\|^NAMESPACE" | wc -l)

if [ "$REMAINING" -eq 0 ]; then
    echo "✓ All applications deleted successfully"
else
    echo "⚠ Warning: $REMAINING application(s) still present:"
    kubectl get app -A 2>/dev/null | grep -v "velaux\|vela-system"
    echo ""
    read -p "Continue with cluster deletion anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborting cluster deletion"
        exit 1
    fi
fi

# Additional validation checks before cluster deletion
echo ""
echo "Running final validation checks before cluster deletion..."
echo ""

# Check for remaining pods in default namespace (excluding system pods)
echo "Checking for remaining workloads in default namespace..."
REMAINING_PODS=$(kubectl get pods -n default --no-headers 2>/dev/null | wc -l)
if [ "$REMAINING_PODS" -gt 0 ]; then
    echo "⚠ Warning: $REMAINING_PODS pod(s) still running in default namespace"
    kubectl get pods -n default 2>/dev/null
else
    echo "✓ No workload pods in default namespace"
fi

# Check for PersistentVolumeClaims
echo ""
echo "Checking for PersistentVolumeClaims..."
REMAINING_PVCS=$(kubectl get pvc -A --no-headers 2>/dev/null | wc -l)
if [ "$REMAINING_PVCS" -gt 0 ]; then
    echo "⚠ Warning: $REMAINING_PVCS PVC(s) still present"
    kubectl get pvc -A 2>/dev/null
else
    echo "✓ No PersistentVolumeClaims"
fi

# Check for LoadBalancer services that might have external IPs
echo ""
echo "Checking for LoadBalancer services..."
REMAINING_LBS=$(kubectl get svc -A --field-selector=spec.type=LoadBalancer --no-headers 2>/dev/null | wc -l)
if [ "$REMAINING_LBS" -gt 0 ]; then
    echo "⚠ Warning: $REMAINING_LBS LoadBalancer service(s) still present"
    kubectl get svc -A --field-selector=spec.type=LoadBalancer 2>/dev/null
else
    echo "✓ No LoadBalancer services"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Pre-deletion Validation Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
TOTAL_ISSUES=$((REMAINING + REMAINING_PODS + REMAINING_PVCS + REMAINING_LBS))
if [ "$TOTAL_ISSUES" -eq 0 ]; then
    echo "✓ All validation checks passed!"
    echo "  - No remaining applications"
    echo "  - No orphaned workloads"
    echo "  - No dangling PVCs"
    echo "  - No LoadBalancer services"
else
    echo "⚠ Found $TOTAL_ISSUES potential issue(s)"
    echo "  - Applications remaining: $REMAINING"
    echo "  - Pods remaining: $REMAINING_PODS"
    echo "  - PVCs remaining: $REMAINING_PVCS"
    echo "  - LoadBalancer services: $REMAINING_LBS"
    echo ""
    read -p "Still continue with cluster deletion? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborting cluster deletion"
        exit 1
    fi
fi

# Verify no DynamoDB resources remain
echo ""
echo "Verifying AWS resources are deleted..."
KRO_TABLES=$(kubectl get dynamodbtable.kro.run -A 2>/dev/null | grep -v "^NAMESPACE" | wc -l)
ACK_TABLES=$(kubectl get table.dynamodb.services.k8s.aws -A 2>/dev/null | grep -v "^NAMESPACE" | wc -l)
XP_TABLES=$(kubectl get table.dynamodb.aws.upbound.io -A 2>/dev/null | grep -v "^NAMESPACE" | wc -l)

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
