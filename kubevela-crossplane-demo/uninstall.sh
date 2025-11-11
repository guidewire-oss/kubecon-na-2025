#!/bin/bash

set -e

echo "🗑️ Uninstalling Crossplane via KubeVela workflow..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if vela CLI is available
if ! command -v vela &> /dev/null; then
    echo "❌ vela CLI not found. Please install KubeVela CLI first."
    exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Delete any existing uninstall WorkflowRun to avoid conflicts
echo "🔄 Cleaning up any existing uninstall WorkflowRun..."
kubectl delete workflowrun uninstall -n vela-system --ignore-not-found=true

# Apply the uninstall workflow
echo "📋 Applying uninstall workflow..."
kubectl apply -f "${SCRIPT_DIR}/workflows/uninstall.yaml"

echo "⏳ Waiting for workflow to start..."
sleep 2

# Show workflow status
echo "📊 Uninstall workflow started! You can monitor progress with:"
echo "   vela workflow logs uninstall -n vela-system"
echo "   kubectl get workflowrun uninstall -n vela-system"
echo ""

echo "✅ Crossplane uninstall workflow started!"
echo ""
echo "🔍 You can verify uninstall status with:"
echo "   kubectl get pods -n crossplane-system"
echo "   vela addon status crossplane"