#!/bin/bash
set -e

# KubeCon NA 2025 Demo - Cleanup Script
# This script tears down the demo environment and cleans up all resources

echo "=== KubeCon NA 2025 Demo - Cleanup ==="
echo ""

# Load configuration
CLUSTER_NAME="kubecon-NA25"

if [ -f "config.yaml" ]; then
    echo "Loading configuration from config.yaml..."
    CLUSTER_NAME=$(python3 -c "import yaml; print(yaml.safe_load(open('config.yaml'))['cluster']['name'])")
    echo "Configuration loaded: Will delete cluster '$CLUSTER_NAME'"
else
    echo "Config file not found, using default cluster name: '$CLUSTER_NAME'"
fi

echo ""
echo "⚠️  WARNING: This will delete all cluster data!"
echo "Cluster to be deleted: $CLUSTER_NAME"
echo ""

# Step 1: Check Current Cluster Status
echo "=== Step 1: Current k3d Clusters ==="
k3d cluster list

echo ""
echo "=== Current kubectl context ==="
kubectl config current-context 2>/dev/null || echo "No active context"
echo ""

# Step 2: Delete the k3d Cluster
echo "=== Step 2: Deleting k3d Cluster and Registry: $CLUSTER_NAME ==="
echo ""

# Check if cluster exists
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "Found cluster '$CLUSTER_NAME', deleting..."

    if k3d cluster delete "$CLUSTER_NAME"; then
        echo "✓ Cluster '$CLUSTER_NAME' deleted successfully"
    else
        echo "✗ Failed to delete cluster"
        exit 1
    fi
else
    echo "⚠ Cluster '$CLUSTER_NAME' not found (may already be deleted)"
fi

# Delete registry if it exists
echo ""
echo "Deleting local registry..."
if k3d registry list | grep -q "registry.localhost"; then
    if k3d registry delete registry.localhost; then
        echo "✓ Registry deleted successfully"
    else
        echo "⚠ Failed to delete registry"
    fi
else
    echo "⚠ Registry not found (may already be deleted)"
fi

echo ""
echo "Remaining k3d clusters:"
k3d cluster list

echo ""
echo "Remaining k3d registries:"
k3d registry list
echo ""

# Step 3: Clean Up kubectl Context
echo "=== Step 3: Cleaning up kubectl context ==="
echo ""

CONTEXT_NAME="k3d-$CLUSTER_NAME"

# Delete context if it exists
if kubectl config get-contexts "$CONTEXT_NAME" &>/dev/null; then
    kubectl config delete-context "$CONTEXT_NAME" 2>/dev/null || true
    echo "✓ Context '$CONTEXT_NAME' removed"
else
    echo "⚠ Context '$CONTEXT_NAME' not found"
fi

# Delete cluster entry if it exists
if kubectl config get-clusters | grep -q "$CONTEXT_NAME"; then
    kubectl config delete-cluster "$CONTEXT_NAME" 2>/dev/null || true
    echo "✓ Cluster entry '$CONTEXT_NAME' removed"
fi

echo ""
echo "Current kubectl contexts:"
kubectl config get-contexts || echo "No contexts available"
echo ""

# Step 4: Verification
echo "=== Step 4: Cleanup Verification ==="
echo ""

echo "k3d clusters:"
k3d cluster list
echo ""

echo "kubectl contexts:"
kubectl config get-contexts 2>/dev/null || echo "No contexts"
echo ""

echo "Docker containers (k3d related):"
docker ps -a --filter "name=k3d" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || echo "No k3d containers"
echo ""

echo "✓ Cleanup verification complete"
echo ""

# Summary
echo "=== Cleanup Complete! ==="
echo ""
echo "The demo environment has been successfully torn down."
echo ""
echo "What was cleaned up:"
echo "  ✓ k3d cluster deleted"
echo "  ✓ Local registry deleted"
echo "  ✓ kubectl context removed"
echo "  ✓ Docker containers stopped and removed"
echo ""
echo "To start fresh:"
echo "  Run ./setup.sh to recreate the environment"
echo ""
echo "Remaining artifacts (kept for reuse):"
echo "  - Configuration files (config.yaml)"
echo "  - Setup manifests (setup/ directory)"
echo "  - Python environment and packages"
echo ""
