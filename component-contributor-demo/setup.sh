#!/bin/bash
set -e  # Exit on error

# KubeCon NA 2025 Demo - Environment Setup Script
# This script sets up a complete Kubernetes environment with Crossplane and KubeVela

echo "=== KubeCon NA 2025 Demo - Environment Setup ==="
echo ""

# Activate virtual environment if it exists
if [ -d "../.venv" ]; then
    echo "Activating virtual environment from ../.venv"
    source ../.venv/bin/activate
    echo "✓ Virtual environment activated"
    echo ""
fi

# Check Python packages
echo "=== Checking Prerequisites ==="
echo ""
echo "1. Checking Python packages..."
if python3 -c "import yaml" 2>/dev/null; then
    echo "   ✓ PyYAML is installed"
else
    echo "   ✗ PyYAML is NOT installed"
    echo "   Installing required packages from requirements.txt..."
    pip3 install -q -r requirements.txt
    echo "   ✓ Packages installed successfully"
fi

# Check if config.yaml exists
echo ""
echo "2. Checking configuration file..."
if [ ! -f "config.yaml" ]; then
    echo "   ✗ config.yaml NOT found"
    echo "   ERROR: config.yaml is missing. Please ensure it exists in the current directory."
    exit 1
fi
echo "   ✓ config.yaml found"

# Check command-line tools
echo ""
echo "3. Checking required tools..."
all_tools_ok=true

for tool in k3d kubectl helm vela; do
    if command -v $tool &>/dev/null; then
        echo "   ✓ $tool is installed"
    else
        echo "   ✗ $tool is NOT installed"
        all_tools_ok=false
    fi
done

if [ "$all_tools_ok" = false ]; then
    echo ""
    echo "⚠️  WARNING: Some tools are missing. Please install them before proceeding."
    echo "   - k3d: https://k3d.io/"
    echo "   - kubectl: https://kubernetes.io/docs/tasks/tools/"
    echo "   - helm: https://helm.sh/docs/intro/install/"
    echo "   - vela: https://kubevela.io/docs/installation/kubernetes/#install-vela-cli"
    exit 1
fi

echo ""
echo "✓ All prerequisites are satisfied!"
echo ""

# Load configuration from config.yaml
echo "=== Loading Configuration ==="
python3 << 'PYEOF'
import yaml
import os

with open('config.yaml', 'r') as f:
    config = yaml.safe_load(f)

cluster_name = config['cluster']['name']
api_port = config['cluster']['api_port']
http_port = config['cluster']['http_port']
crossplane_namespace = config['crossplane']['namespace']
min_crds = config['crossplane']['min_crds']
setup_dir = config['setup']['manifests_dir']

# Write to shell file
with open('.env.sh', 'w') as f:
    f.write(f'export CLUSTER_NAME="{cluster_name}"\n')
    f.write(f'export API_PORT="{api_port}"\n')
    f.write(f'export HTTP_PORT="{http_port}"\n')
    f.write(f'export CROSSPLANE_NAMESPACE="{crossplane_namespace}"\n')
    f.write(f'export MIN_CRDS="{min_crds}"\n')
    f.write(f'export SETUP_DIR="{setup_dir}"\n')

print(f"Configuration loaded successfully:")
print(f"  Cluster name: {cluster_name}")
print(f"  API port: {api_port}")
print(f"  HTTP port: {http_port}")
print(f"  Crossplane namespace: {crossplane_namespace}")
print(f"  Minimum CRDs: {min_crds}")
print(f"  Setup directory: {setup_dir}")
PYEOF

source .env.sh
echo ""

# Step 1: Create k3d Cluster
echo "=== Step 1: Creating k3d cluster with local registry ==="
echo ""

# Delete existing cluster if it exists
echo "Cleaning up any existing cluster..."
k3d cluster delete $CLUSTER_NAME 2>/dev/null || echo "No existing cluster to delete"

# Delete existing registry if it exists
echo "Cleaning up any existing registry..."
k3d registry delete registry.localhost 2>/dev/null || echo "No existing registry to delete"

# Create registry first
echo ""
echo "Creating local Docker registry..."
if k3d registry create registry.localhost --port 0.0.0.0:5000; then
    echo "✓ Registry created successfully at localhost:5000"
else
    echo "✗ Failed to create registry"
    exit 1
fi

# Create cluster and connect it to the registry
echo ""
echo "Creating k3d cluster: $CLUSTER_NAME"
if k3d cluster create $CLUSTER_NAME \
    --api-port $API_PORT \
    -p "${HTTP_PORT}:80@loadbalancer" \
    --k3s-arg="--kubelet-arg=max-open-files=1000000@server:*" \
    --registry-use k3d-registry.localhost:5000 \
    --wait; then
    echo "✓ Cluster created successfully"
else
    echo "✗ Failed to create cluster"
    exit 1
fi

# Set kubectl context to the new cluster
echo ""
echo "Setting kubectl context to k3d-$CLUSTER_NAME..."
kubectl config use-context "k3d-$CLUSTER_NAME"

# Verify cluster is accessible
echo "Verifying cluster access..."
if kubectl cluster-info &>/dev/null; then
    echo "✓ Cluster is accessible"
    echo "Current context: $(kubectl config current-context)"
    kubectl get nodes
else
    echo "✗ Cannot access cluster"
    exit 1
fi

# Verify registry
echo ""
echo "=== Registry Setup Complete ==="
echo "Registry URL: localhost:5000"
echo "Registry status:"
k3d registry list
echo ""
echo "To push images: docker tag <image> localhost:5000/<image>:<tag>"
echo "                docker push localhost:5000/<image>:<tag>"
echo ""
echo "In k3d cluster, use: k3d-registry.localhost:5000/<image>:<tag>"
echo ""

# Step 2: Install Crossplane
echo "=== Step 2: Installing Crossplane ==="
echo ""

# Add and update helm repo
echo "Adding Crossplane helm repository..."
helm repo add crossplane-stable https://charts.crossplane.io/stable 2>/dev/null || echo "Repository already exists"
helm repo update

# Check if Crossplane is already installed
if helm list -n $CROSSPLANE_NAMESPACE | grep -q crossplane; then
    echo "⚠ Crossplane is already installed. Upgrading..."
    HELM_CMD="upgrade"
else
    echo "Installing Crossplane..."
    HELM_CMD="install"
fi

# Install or upgrade Crossplane
if helm $HELM_CMD crossplane crossplane-stable/crossplane \
    --namespace $CROSSPLANE_NAMESPACE \
    --create-namespace \
    --wait \
    --timeout 10m; then
    echo "✓ Crossplane helm chart $HELM_CMD completed"
else
    echo "✗ Failed to $HELM_CMD Crossplane"
    exit 1
fi

# Wait for pods to be ready
echo "Waiting for Crossplane pods to be ready..."
if kubectl wait --namespace $CROSSPLANE_NAMESPACE \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=cloud-infrastructure-controller \
    --timeout=1200s; then
    echo "✓ Crossplane controller is ready"
else
    echo "✗ Crossplane controller failed to become ready"
    exit 1
fi

echo "Crossplane installation complete!"
kubectl get pods -n $CROSSPLANE_NAMESPACE
echo ""

# Step 3: Wait for Crossplane CRDs
echo "=== Step 3: Waiting for Crossplane CRDs ==="
echo ""

MAX_RETRIES=60
RETRY_DELAY=5

echo "Waiting for at least $MIN_CRDS Crossplane CRDs to be installed..."

for i in $(seq 1 $MAX_RETRIES); do
    CRD_COUNT=$(kubectl api-resources | grep crossplane | wc -l)
    echo "Attempt $i/$MAX_RETRIES: Found $CRD_COUNT Crossplane CRDs"

    if [ $CRD_COUNT -ge $MIN_CRDS ]; then
        echo "✓ Sufficient CRDs are available ($CRD_COUNT >= $MIN_CRDS)"
        break
    fi

    if [ $i -eq $MAX_RETRIES ]; then
        echo "✗ Timeout: Only $CRD_COUNT CRDs found after ${MAX_RETRIES} attempts"
        exit 1
    fi

    sleep $RETRY_DELAY
done

echo ""
echo "Current Crossplane pods:"
kubectl get pods -n $CROSSPLANE_NAMESPACE

echo ""
echo "Sample Crossplane CRDs:"
kubectl api-resources | grep crossplane | head -10
echo ""

# Step 3.5: Configure AWS Provider (optional)
echo "=== Step 3.5: Configuring AWS Provider (Optional) ==="
echo ""

# Check if .env.aws file exists
if [ ! -f "../.env.aws" ]; then
    echo "⚠ Warning: .env.aws file not found"
    echo "Creating template .env.aws file..."
    cat > ../.env.aws << 'EOF'
# AWS Credentials for Crossplane
AWS_ACCESS_KEY_ID=your-access-key-id
AWS_SECRET_ACCESS_KEY=your-secret-access-key
AWS_DEFAULT_REGION=us-west-2
EOF
    echo "✓ Template created. Edit .env.aws with your credentials if you need AWS resources."
    echo "Skipping AWS provider configuration..."
else
    # Source AWS credentials
    source ../.env.aws

    # Check if credentials are set
    if [ "$AWS_ACCESS_KEY_ID" == "your-access-key-id" ] || [ -z "$AWS_ACCESS_KEY_ID" ]; then
        echo "⚠ Warning: AWS credentials not configured in .env.aws"
        echo "Skipping AWS provider configuration..."
    else
        echo "AWS credentials found, configuring Crossplane..."

        # Install AWS Provider
        echo "1. Installing Crossplane AWS Provider..."
        cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: upbound-provider-aws-dynamodb
spec:
  package: xpkg.upbound.io/upbound/provider-aws-dynamodb:v1.23.2
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: upbound-provider-aws-s3
spec:
  package: xpkg.upbound.io/upbound/provider-aws-s3:v1.23.2
EOF

        echo "   Waiting for provider to be installed..."
        kubectl wait --for=condition=installed --timeout=300s provider.pkg.crossplane.io/upbound-provider-aws-dynamodb
        kubectl wait --for=condition=installed --timeout=300s provider.pkg.crossplane.io/upbound-provider-aws-s3

        echo "   Waiting for provider to be healthy..."
        kubectl wait --for=condition=healthy --timeout=300s provider.pkg.crossplane.io/upbound-provider-aws-dynamodb
        kubectl wait --for=condition=healthy --timeout=300s provider.pkg.crossplane.io/upbound-provider-aws-s3

        echo "✓ AWS Provider installed"

        # Create Kubernetes secret with AWS credentials
        echo ""
        echo "2. Creating Kubernetes secret with AWS credentials..."
        # Create credentials string with session token if available
        if [ -n "$AWS_SESSION_TOKEN" ]; then
            CREDENTIALS_STRING="[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
aws_session_token = ${AWS_SESSION_TOKEN}"
            echo "   Including session token for temporary credentials"
        else
            CREDENTIALS_STRING="[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}"
            echo "   Using long-term credentials (no session token)"
        fi

        kubectl create secret generic aws-credentials \
            -n $CROSSPLANE_NAMESPACE \
            --from-literal=credentials="$CREDENTIALS_STRING" \
            --dry-run=client -o yaml | kubectl apply -f -

        echo "✓ AWS credentials secret created"

        # Create ProviderConfig
        echo ""
        echo "3. Creating ProviderConfig for AWS..."
        cat <<EOF | kubectl apply -f -
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: $CROSSPLANE_NAMESPACE
      name: aws-credentials
      key: credentials
EOF

        echo "✓ ProviderConfig created"

        echo ""
        echo "=== AWS Provider Configuration Complete ==="
        echo "✓ Provider: provider-aws-dynamodb"
        echo "✓ Credentials: Configured from .env.aws"
        echo "✓ Region: ${AWS_DEFAULT_REGION}"
    fi
fi
echo ""

# Step 4: Apply Setup Manifests
echo "=== Step 4: Applying Setup Manifests ==="
echo ""

# Check if setup directory exists
if [ ! -d "$SETUP_DIR" ]; then
    echo "⚠ Warning: Setup directory '$SETUP_DIR' not found"
    echo "Creating placeholder directory..."
    mkdir -p "$SETUP_DIR"
    echo "Skipping manifest application"
else
    # Check if directory has any yaml files
    if [ -z "$(find $SETUP_DIR -maxdepth 1 -name "*.yaml" -o -name "*.yml" 2>/dev/null)" ]; then
        echo "⚠ Warning: No YAML files found in '$SETUP_DIR' directory"
        echo "Skipping manifest application"
    else
        # Apply manifests
        echo "Applying manifests from $SETUP_DIR..."
        if kubectl apply -f $SETUP_DIR/; then
            echo "✓ Initial manifests applied"
        else
            echo "⚠ Some manifests may have failed to apply (CRDs might not be ready yet)"
        fi

        # Wait for provider configs CRD to be available
        echo ""
        echo "Waiting for providerconfigs CRD to be available..."
        MAX_RETRIES=60
        for i in $(seq 1 $MAX_RETRIES); do
            if kubectl api-resources | grep crossplane | grep -q providerconfigs; then
                echo "✓ ProviderConfigs CRD is available"
                break
            fi

            if [ $i -eq $MAX_RETRIES ]; then
                echo "⚠ Warning: providerconfigs CRD not found, but continuing..."
                break
            fi

            sleep 5
        done

        # Wait for function pods
        echo ""
        echo "Waiting for Crossplane function pods..."
        if kubectl wait --namespace $CROSSPLANE_NAMESPACE \
            --for=condition=ready pod \
            --selector=pkg.crossplane.io/function=function-patch-and-transform \
            --timeout=1200s 2>/dev/null; then
            echo "✓ Function pods are ready"
        else
            echo "⚠ Function pods not found or not ready yet (may not be installed)"
        fi

        # Wait for provider pods
        echo ""
        echo "Waiting for Crossplane provider pods..."
        if kubectl wait --namespace $CROSSPLANE_NAMESPACE \
            --for=condition=ready pod \
            --selector=pkg.crossplane.io/provider=provider-kubernetes \
            --timeout=1200s 2>/dev/null; then
            echo "✓ Provider pods are ready"
        else
            echo "⚠ Provider pods not found or not ready yet (may not be installed)"
        fi

        # Re-apply manifests to ensure everything is configured
        echo ""
        echo "Re-applying manifests to ensure configuration..."
        kubectl apply -f $SETUP_DIR/ 2>/dev/null || echo "⚠ Some resources may already exist"

        echo ""
        echo "✓ Crossplane setup complete!"
    fi
fi
echo ""

# Step 5: Install KubeVela
echo "=== Step 5: Installing KubeVela ==="
echo ""

vela install

echo ""
echo "Waiting for KubeVela pods to be ready..."
if kubectl wait --namespace vela-system \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/name=vela-core \
    --timeout=600s; then
    echo "✓ KubeVela controller is ready"
else
    echo "✗ KubeVela controller failed to become ready"
    exit 1
fi

echo ""
echo "KubeVela installation complete!"
kubectl get pods -n vela-system

echo ""
echo "Checking KubeVela version..."
kubectl get deployment -n vela-system kubevela-vela-core -o jsonpath='{.spec.template.spec.containers[0].image}'
echo ""

echo ""
echo "Installing velaux addon..."
vela addon enable velaux
echo ""

# Port forward velaux
echo "Starting port-forward for VelaUX..."
nohup vela port-forward -n vela-system addon-velaux 8000:8000 > /dev/null 2>&1 &
echo "✓ VelaUX will be available at http://localhost:8000"
echo ""

# Step 6: Create OAM Component (DynamoDB Example)
echo "=== Step 6: Creating OAM Component (DynamoDB Example) ==="
echo ""

# Create directories
echo "Creating directory structure..."
mkdir -p crossplane/dynamodb
mkdir -p kubevela/components/dynamodb
mkdir -p test

# Step 6.1: Create XRD
echo "1. Creating Crossplane XRD (CompositeResourceDefinition)..."
cat > crossplane/dynamodb/xrd.yaml << 'EOF'
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata:
  name: xdynamodbtables.demo.kubecon.io
spec:
  scope: Cluster
  group: demo.kubecon.io
  names:
    kind: XDynamoDBTable
    plural: xdynamodbtables
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                name:
                  type: string
                  description: "Name of the DynamoDB table"
                region:
                  type: string
                  description: "AWS region"
                hashKey:
                  type: string
                  description: "Hash (partition) key attribute name"
                attributes:
                  type: array
                  description: "Attribute definitions"
                  items:
                    type: object
                    properties:
                      name:
                        type: string
                      type:
                        type: string
                        enum: ["S", "N", "B"]
                tags:
                  type: object
                  additionalProperties:
                    type: string
                  description: "AWS resource tags"
              required:
                - name
                - region
                - hashKey
                - attributes
            status:
              type: object
              properties:
                tableArn:
                  type: string
                tableId:
                  type: string
EOF

kubectl apply -f crossplane/dynamodb/xrd.yaml
echo "   Waiting for XRD to be established..."
sleep 3
echo "✓ XRD created and applied"
echo ""

# Step 6.2: Create Composition
echo "2. Creating Crossplane Composition..."
cat > crossplane/dynamodb/composition.yaml << 'EOF'
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: dynamodb-table.demo.kubecon.io
spec:
  compositeTypeRef:
    apiVersion: demo.kubecon.io/v1alpha1
    kind: XDynamoDBTable

  mode: Pipeline
  pipeline:
    - step: create-table
      functionRef:
        name: function-patch-and-transform
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources:
          - name: table
            base:
              apiVersion: dynamodb.aws.upbound.io/v1beta1
              kind: Table
              spec:
                forProvider:
                  billingMode: PAY_PER_REQUEST

            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: spec.name
                toFieldPath: metadata.name

              - type: FromCompositeFieldPath
                fromFieldPath: spec.region
                toFieldPath: spec.forProvider.region

              - type: FromCompositeFieldPath
                fromFieldPath: spec.hashKey
                toFieldPath: spec.forProvider.hashKey

              - type: FromCompositeFieldPath
                fromFieldPath: spec.attributes
                toFieldPath: spec.forProvider.attribute

              - type: FromCompositeFieldPath
                fromFieldPath: spec.tags
                toFieldPath: spec.forProvider.tags

              - type: ToCompositeFieldPath
                fromFieldPath: status.atProvider.arn
                toFieldPath: status.tableArn

              - type: ToCompositeFieldPath
                fromFieldPath: status.atProvider.id
                toFieldPath: status.tableId
EOF

kubectl apply -f crossplane/dynamodb/composition.yaml
echo "   Waiting for Composition to be ready..."
sleep 3
echo "✓ Composition created and applied"
echo ""

# Step 6.3: Create KubeVela ComponentDefinition
echo "3. Creating KubeVela ComponentDefinition (CUE)..."
cat > kubevela/components/dynamodb/dynamodb.cue << 'EOF'
"simple-dynamodb": {
    type: "component"
    description: "A basic DynamoDB table component for KubeCon NA 2025."
    attributes: {
        workload: definition: {
            apiVersion: "demo.kubecon.io/v1alpha1"
            kind:       "XDynamoDBTable"
        }
        status: {
            healthPolicy: #"""
                isHealth: bool | *false
                if context.output.status != _|_ {
                    if context.output.status.conditions != _|_ {
                        for c in context.output.status.conditions {
                            if c.type == "Ready" && c.status == "True" {
                                isHealth: true
                            }
                        }
                    }
                }
                """#
            customStatus: #"""
                message: string | *"Provisioning table..."
                if context.output.status != _|_ {
                    if context.output.status.tableArn != _|_ {
                        message: "Table ARN: " + context.output.status.tableArn
                    }
                }
                """#
        }
    }
}

template: {
    output: {
        apiVersion: "demo.kubecon.io/v1alpha1"
        kind:       "XDynamoDBTable"
        metadata: {
            name:      "tenant-atlantis-" + parameter.name
            namespace: context.namespace
        }
        spec: {
            name:       "tenant-atlantis-" + parameter.name
            region:     parameter.region
            hashKey:    parameter.hashKey
            attributes: parameter.attributes
            tags: {
                "gwcp:v1:dept":                            "000"
                "gwcp:v1:provisioned-resource:created-by": "kubecon-NA25"
                "gwcp:v1:quadrant:name":                   "dev"
                "gwcp:v1:resource-type:managed-by":        "pod-atlantis"
                "gwcp:v1:resource-type:managed-tool":      "crossplane"
                "gwcp:v1:star-system:name":                "kubecon"
                "gwcp:v1:tenant:name":                     "atlantis"
                "gwcp:v1:tenant:app-name":                 context.appName
            }
            crossplane: {
                compositionRef: {
                    name: "dynamodb-table.demo.kubecon.io"
                }
            }
        }
    }

    parameter: {
        // +usage=Name of the DynamoDB table (will be prefixed with tenant-atlantis-)
        name: string

        // +usage=AWS region default to us-west-2
        region: *"us-west-2" | string

        // +usage=Hash key attribute name
        hashKey: string

        // +usage=Attribute definitions
        attributes: [...{
            // +usage=Attribute name
            name: string
            // +usage=Attribute type (S=String, N=Number, B=Binary)
            type: "S" | "N" | "B"
        }]
    }
}
EOF

cd kubevela/components/dynamodb
vela def apply dynamodb.cue
cd ../../..
echo "✓ ComponentDefinition created and applied"
echo ""

# Step 6.4: Create test application manifest
echo "4. Creating test application manifest..."
cat > test/app.yaml << 'EOF'
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: my-dynamodb-app
  namespace: default
spec:
  components:
    - name: users-table
      type: simple-dynamodb
      properties:
        name: users-table
        hashKey: userId
        region: us-west-2
        attributes:
          - name: userId
            type: "S"
EOF

echo "✓ Test application manifest created"
echo ""

# Step 6.5: Deploy the application
echo "5. Deploying KubeVela application..."
if kubectl get componentdefinition simple-dynamodb -n vela-system &>/dev/null; then
    vela up -f test/app.yaml

    echo ""
    sleep 3

    echo "✓ Application deployed. Checking status:"
    vela status my-dynamodb-app
    echo ""
else
    echo "⚠ ComponentDefinition not found. Skipping application deployment."
fi

# Step 6.6: Verify all resources
echo "6. Verifying all OAM component resources..."
echo ""
echo "   XRD:"
kubectl get xrd xdynamodbtables.demo.kubecon.io
echo ""
echo "   Composition:"
kubectl get composition dynamodb-table.demo.kubecon.io
echo ""
echo "   Composite Resources:"
kubectl get xdynamodbtables -A
echo ""
echo "   DynamoDB Tables (Managed Resources):"
kubectl get table -A 2>/dev/null || echo "   No tables found (AWS provider may not be configured)"
echo ""
echo "   ComponentDefinition:"
kubectl get componentdefinition simple-dynamodb -n vela-system 2>/dev/null || echo "   Not found"
echo ""
echo "   KubeVela Applications:"
vela ls -A 2>/dev/null || echo "   No applications"
echo ""

# Step 6.7: Start vela show web interface
echo "7. Starting vela show web interface for component documentation..."
nohup vela show --web simple-dynamodb > /dev/null 2>&1 &
echo "✓ Component documentation will be available (vela show --web simple-dynamodb)"
echo ""

echo "✓ OAM Component setup complete!"
echo ""

echo "=== Setup Complete! ==="
echo ""
echo "Your KubeCon demo environment is now ready:"
echo "  ✓ k3d cluster: $CLUSTER_NAME"
echo "  ✓ Crossplane: Installed in $CROSSPLANE_NAMESPACE namespace"
echo "  ✓ KubeVela: Installed in vela-system namespace"
echo "  ✓ VelaUX: http://localhost:8000"
echo "  ✓ OAM Component: simple-dynamodb (DynamoDB table)"
echo ""
echo "Next steps:"
echo "  - Check cluster status: kubectl get pods -A"
echo "  - View Crossplane resources: kubectl get crossplane"
echo "  - View KubeVela applications: kubectl get applications -A"
echo "  - Deploy test app: vela up -f test/app.yaml"
echo "  - Access VelaUX UI: http://localhost:8000"
echo "  - When finished, run ./cleanup.sh to tear down the environment"
echo ""
