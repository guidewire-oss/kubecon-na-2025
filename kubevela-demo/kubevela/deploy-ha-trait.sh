#!/bin/bash
set -e

echo "=== Deploying High Availability Trait ==="
echo ""

# Step 1: Create namespaces
echo "Step 1: Creating namespaces..."
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -
echo "✓ Namespaces created"
echo ""

# Step 2: Apply TraitDefinition
echo "Step 2: Applying TraitDefinition..."
kubectl apply -f high-availability-traitdef.yaml
echo "✓ TraitDefinition applied"
echo ""

# Step 3: Wait for trait to be ready
echo "Step 3: Waiting for trait to be ready..."
sleep 5

# Verify trait is available
if vela traits | grep -q "high-availability"; then
    echo "✓ Trait registered successfully"
else
    echo "⚠ Trait not found in vela traits list"
fi
echo ""

# Step 4: Display trait information
echo "Step 4: Trait Information"
echo ""
vela show high-availability 2>/dev/null || echo "Use 'vela show high-availability' to view trait details"
echo ""

# Step 5: Detect environment type
echo "Step 5: Detecting environment..."
echo ""

# Check if this is a single-node local cluster
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
HAS_ZONE_LABELS=$(kubectl get nodes -o jsonpath='{.items[*].metadata.labels.topology\.kubernetes\.io/zone}' | wc -w)

if [ "$NODE_COUNT" -eq 1 ] || [ "$HAS_ZONE_LABELS" -eq 0 ]; then
    echo "⚠ Detected local development environment:"
    echo "  - Nodes: $NODE_COUNT"
    echo "  - Nodes with zone labels: $HAS_ZONE_LABELS"
    echo ""
    echo "📝 Recommendation: Use 'prod-local' level for production-like HA in local clusters"
    echo ""
    echo "   traits:"
    echo "     - type: high-availability"
    echo "       properties:"
    echo "         level: prod-local  # Use this for local dev instead of 'prod'"
    echo ""
    LOCAL_ENV="true"
else
    echo "✓ Detected multi-node cluster with zone labels"
    echo "  You can use 'prod' level for full topology spread"
    echo ""
    LOCAL_ENV="false"
fi

echo "=== Deployment Complete! ==="
echo ""
echo "📝 Next Steps:"
echo ""

if [ "$LOCAL_ENV" = "true" ]; then
    echo "  For local development, use ha-example-app.yaml with prod-local:"
    echo "  1. Update the override-prod policy to use 'prod-local':"
    echo ""
    echo "     - name: override-prod"
    echo "       type: override"
    echo "       properties:"
    echo "         components:"
    echo "           - name: web-service"
    echo "             traits:"
    echo "               - type: high-availability"
    echo "                 properties:"
    echo "                   level: prod-local  # Changed from 'prod'"
    echo ""
    echo "  2. Deploy the application:"
    echo "     vela up -f ha-example-app.yaml"
    echo ""
else
    echo "  1. Deploy the example application:"
    echo "     vela up -f ha-example-app.yaml"
    echo ""
fi

if [ "$LOCAL_ENV" = "true" ]; then
    echo "  3. Check HPA in each environment:"
else
    echo "  2. Check HPA in each environment:"
fi
echo "     kubectl get hpa -n dev"
echo "     kubectl get hpa -n staging"
echo "     kubectl get hpa -n prod"
echo ""

if [ "$LOCAL_ENV" = "true" ]; then
    echo "  4. Check PDB in staging/prod:"
else
    echo "  3. Check PDB in staging/prod:"
fi
echo "     kubectl get pdb -n staging"
echo "     kubectl get pdb -n prod"
echo ""

if [ "$LOCAL_ENV" = "true" ]; then
    echo "  5. View pod distribution:"
else
    echo "  4. View pod distribution:"
fi
echo "     kubectl get pods -n prod -o wide"
echo ""
echo "📊 Configuration Levels:"
echo "  • dev         - 1-2 replicas, no HA features (fast iteration)"
echo "  • staging     - 1-3 replicas, 50% PDB, preferred anti-affinity"
echo "  • prod        - 3-6 replicas, full HA with 3-zone topology (requires labeled nodes)"
echo "  • prod-local  - 3-6 replicas, full HA without topology constraints (for local dev)"
echo ""
echo "📚 See HIGH_AVAILABILITY_TRAIT.md for full documentation"
echo ""
