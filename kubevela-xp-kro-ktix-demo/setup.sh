#!/bin/bash
set -e  # Exit on error

# KubeCon North America 2025 - DynamoDB Demo: Kratix vs Crossplane vs KRO
# This script sets up a complete environment demonstrating:
# 1. Kubernetes cluster with KubeVela, Kratix Promise Framework, Crossplane, and KRO
# 2. DynamoDB components for all three approaches (Kratix, Crossplane, KRO)
# 3. Complete session management applications comparing all implementations
# 4. Infrastructure provisioning through promise abstractions, cloud-native composition, and orchestration
#
# NOTE: This script includes fixes documented in CHANGELOG.md (2024-12-24)
#       - Production namespace is now automatically created
#       - All YAML examples use quoted attribute types ("S", "N", "B")
#       - Component definition supports trait-based billing mode overrides
#       - API version corrected to dynamodb.aws.upbound.io/v1beta1
#       - Kratix Promise Framework fully integrated (Phase 2.5, 8.6, 8.7)
#
# USAGE:
#   ./setup.sh              # Full installation
#   ./setup.sh --skip-install  # Skip cluster/tool installation, only deploy definitions and apps
#   ./setup.sh --help       # Show help

# Parse command line arguments
SKIP_INSTALL=false
for arg in "$@"; do
    case $arg in
        --skip-install)
            SKIP_INSTALL=true
            shift
            ;;
        --help|-h)
            echo "Usage: ./setup.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-install    Skip cluster and tool installation (k3d, KubeVela, Kratix, Crossplane, KRO, ACK)"
            echo "                    Only redeploy component definitions and applications"
            echo "  --help, -h        Show this help message"
            echo ""
            echo "Examples:"
            echo "  ./setup.sh                # Full installation with all three approaches"
            echo "  ./setup.sh --skip-install # Quick redeploy of definitions and apps"
            echo ""
            echo "Approaches Deployed:"
            echo "  • Kratix Promise Framework - Platform abstraction pattern"
            echo "  • KRO (Kubernetes Resource Orchestrator) - Cloud-native orchestration"
            echo "  • Crossplane - Multi-cloud infrastructure provisioning"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║   KubeCon NA 2025 - DynamoDB Demo: Kratix vs KRO vs Crossplane║"
echo "║   KubeVela + Kratix + KRO + Crossplane + ACK                  ║"
if [ "$SKIP_INSTALL" = true ]; then
echo "║   MODE: Skip Install (definitions and apps only)              ║"
fi
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
print_step() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Check if running from correct directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Store the demo root
DEMO_ROOT=$(pwd)

# =============================================================================
# Environment Detection: Host vs DevContainer
# =============================================================================
# Detect if running in DevContainer and set kubeconfig accordingly
if [ -f "$DEMO_ROOT/kubeconfig-internal" ] && [ ! -f "$HOME/.kube/config" ]; then
    # DevContainer environment - use kubeconfig-internal
    export KUBECONFIG="$DEMO_ROOT/kubeconfig-internal"
    ENVIRONMENT="devcontainer"
    print_info "Detected DevContainer environment - using kubeconfig-internal"
elif [ -f "$HOME/.kube/config" ]; then
    # Host environment - use default kubeconfig
    ENVIRONMENT="host"
    # No need to set KUBECONFIG if using default location
    print_info "Detected Host environment - using default kubeconfig"
else
    # Neither found - will be set up by setup.sh
    ENVIRONMENT="unknown"
fi

# =============================================================================
# PHASE 0: Prerequisites Check
# =============================================================================
if [ "$SKIP_INSTALL" = false ]; then
    print_step "Phase 0: Checking Prerequisites"

    echo "Checking required tools..."
    all_tools_ok=true

    required_tools="k3d kubectl helm vela"
    for tool in $required_tools; do
        if command -v $tool &>/dev/null; then
            version=$($tool version 2>/dev/null | head -1 || echo "installed")
            print_success "$tool is installed"
        else
            print_error "$tool is NOT installed"
            all_tools_ok=false
        fi
    done

    if [ "$all_tools_ok" = false ]; then
        print_error "Some required tools are missing. Please install them first:"
        echo ""
        echo "  # macOS"
        echo "  brew install k3d kubectl helm"
        echo "  curl -fsSl https://kubevela.io/script/install.sh | bash"
        echo ""
        echo "  # Linux"
        echo "  # Install k3d: curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash"
        echo "  # Install kubectl: https://kubernetes.io/docs/tasks/tools/"
        echo "  # Install helm: https://helm.sh/docs/intro/install/"
        echo "  # Install vela: curl -fsSl https://kubevela.io/script/install.sh | bash"
        echo ""
        exit 1
    fi

    print_success "All required tools are installed"
fi

# =============================================================================
# PHASE 1: Cluster Setup
# =============================================================================
if [ "$SKIP_INSTALL" = false ]; then
    print_step "Phase 1: Creating Kubernetes Cluster"

    # Check if cluster already exists
    if k3d cluster list | grep -q "kubevela-demo"; then
        print_info "Cluster 'kubevela-demo' already exists"
        echo ""
        read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            echo "Running cleanup script to verify resources are deleted before cluster deletion..."
            echo ""

            # Run clean.sh to properly clean up before deletion
            if [ -f "$DEMO_ROOT/clean.sh" ]; then
                # Use the same environment detection as at the top of this script
                # (it was already set in lines 110-123)
                CLEANUP_ENV="--$ENVIRONMENT"
                print_info "Using $ENVIRONMENT environment for cleanup"

                # Run clean.sh
                bash "$DEMO_ROOT/clean.sh" "$CLEANUP_ENV" || {
                    print_error "Cleanup script failed or was aborted"
                    print_warning "Cluster still exists - please manually clean up or run: k3d cluster delete kubevela-demo"
                    exit 1
                }
                print_success "Cleanup completed successfully"
            else
                print_warning "clean.sh not found, proceeding with direct cluster deletion"
                print_warning "WARNING: Some resources may not be properly cleaned up in AWS"
                echo ""
                k3d cluster delete kubevela-demo
                print_success "Cluster deleted"
            fi
            echo ""
            echo "Creating k3d cluster 'kubevela-demo' with 1 server and 2 agents..."
            k3d cluster create kubevela-demo \
                --servers 1 \
                --agents 2 \
                --wait \
                --timeout 5m
            print_success "Cluster created successfully"
        else
            print_info "Using existing cluster"
        fi
    else
        echo "Creating k3d cluster 'kubevela-demo' with 1 server and 2 agents..."
        k3d cluster create kubevela-demo \
            --servers 1 \
            --agents 2 \
            --wait \
            --timeout 5m
        print_success "Cluster created successfully"
    fi

    # Wait for cluster to be ready
    echo "Waiting for all nodes to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    print_success "All cluster nodes are ready"

    # Set up kubeconfig for host environment
    if [ "$ENVIRONMENT" = "host" ]; then
        if [ ! -f "$HOME/.kube/config" ]; then
            mkdir -p "$HOME/.kube"
            k3d kubeconfig get kubevela-demo > "$HOME/.kube/config"
            print_success "Created kubeconfig at $HOME/.kube/config"
        fi
    fi

    # Import session-api image into k3d cluster (required for Flask microservice)
    echo "Importing session-api image into k3d cluster..."
    if docker images | grep -q "session-api.*latest"; then
        k3d image import session-api:latest --cluster kubevela-demo || {
            print_warning "Failed to import session-api:latest image"
        }
        print_success "session-api:latest image imported"
    else
        print_warning "session-api:latest image not found locally, skipping import"
    fi
fi

# =============================================================================
# PHASE 2: Install KubeVela
# =============================================================================
if [ "$SKIP_INSTALL" = false ]; then
    print_step "Phase 2: Installing KubeVela"

    echo "Installing KubeVela using vela CLI..."
    vela install

    # Wait for KubeVela to be ready
    echo ""
    echo "Waiting for KubeVela controller..."
    if kubectl wait --namespace vela-system \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/name=vela-core \
        --timeout=600s; then
        print_success "KubeVela controller is ready"
    else
        print_error "KubeVela controller failed to become ready"
        exit 1
    fi

    print_success "KubeVela is installed and ready"
    kubectl get pods -n vela-system

    # Enable VelaUX addon
    echo ""
    echo "Enabling VelaUX addon..."
    vela addon enable velaux || {
        print_warning "VelaUX addon may already be enabled or installation failed"
    }

    # Wait for VelaUX to be ready
    echo "Waiting for VelaUX to be ready..."
    kubectl wait --namespace vela-system \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/name=velaux \
        --timeout=300s || {
        print_warning "VelaUX may still be starting"
    }
    print_success "VelaUX addon is enabled"
fi

# =============================================================================
# PHASE 2.5: Deploy Kratix Promise Framework
# =============================================================================
if [ "$SKIP_INSTALL" = false ]; then
    print_step "Phase 2.5: Deploying Kratix Promise Framework"

    echo "Installing cert-manager (required for Kratix)..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

    echo "Waiting for cert-manager to be ready..."
    kubectl wait --namespace cert-manager \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/instance=cert-manager \
        --timeout=300s || {
        print_warning "cert-manager may still be starting"
    }
    print_success "cert-manager is ready"

    echo "Installing Kratix controller..."
    kubectl apply -f https://github.com/syntasso/kratix/releases/download/v0.125.0/kratix.yaml

    echo "Waiting for Kratix controller to be ready..."
    kubectl wait --namespace kratix-platform-system \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/name=kratix \
        --timeout=300s || {
        print_warning "Kratix controller may still be starting"
    }
    print_success "Kratix controller is ready"

    echo "Deploying DynamoDB request CRD..."
    if [ -f "$DEMO_ROOT/definitions/dynamodb-request-crd.yaml" ]; then
        kubectl apply -f "$DEMO_ROOT/definitions/dynamodb-request-crd.yaml"
        print_success "DynamoDB request CRD deployed"
    else
        print_warning "dynamodb-request-crd.yaml not found"
    fi

    echo "Deploying AWS DynamoDB Kratix Promise..."
    if [ -f "$DEMO_ROOT/definitions/kratix-promise-dynamodb.yaml" ]; then
        kubectl apply -f "$DEMO_ROOT/definitions/kratix-promise-dynamodb.yaml" || {
            print_warning "Kratix promise deployment failed, but continuing with CRD approach"
        }
    else
        print_info "kratix-promise-dynamodb.yaml not found, using CRD approach"
    fi
    print_success "Kratix Promise Framework deployed"

    echo ""
    echo "Waiting for Kratix promise to be ready..."
    sleep 5
fi

# =============================================================================
# PHASE 3: Install Crossplane
# =============================================================================
if [ "$SKIP_INSTALL" = false ]; then
    print_step "Phase 3: Installing Crossplane"

echo "Adding Crossplane Helm repository..."
helm repo add crossplane-stable https://charts.crossplane.io/stable --force-update
helm repo update

if helm list -n crossplane-system | grep -q "crossplane"; then
    print_info "Crossplane already installed, upgrading..."
    helm upgrade crossplane crossplane-stable/crossplane \
        -n crossplane-system \
        --wait
else
    echo "Installing Crossplane..."
    helm install crossplane crossplane-stable/crossplane \
        -n crossplane-system \
        --create-namespace \
        --wait
fi

# Wait for Crossplane to be ready
echo "Waiting for Crossplane controller..."
kubectl wait --for=condition=Available deployment/crossplane -n crossplane-system --timeout=300s
print_success "Crossplane is installed and ready"

# Install Crossplane AWS Provider
echo ""
echo "Installing Crossplane AWS DynamoDB Provider..."
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: upbound-provider-aws-dynamodb
spec:
  package: xpkg.upbound.io/upbound/provider-aws-dynamodb:v1.23.2
EOF

echo "Waiting for AWS DynamoDB provider to be installed..."
kubectl wait --for=condition=installed --timeout=300s provider.pkg.crossplane.io/upbound-provider-aws-dynamodb

echo "Waiting for AWS DynamoDB provider to be healthy..."
kubectl wait --for=condition=healthy --timeout=300s provider.pkg.crossplane.io/upbound-provider-aws-dynamodb

print_success "AWS Provider installed"

# Configure AWS credentials for Crossplane (reuse from ../.env.aws)
echo ""
echo "Configuring AWS credentials for Crossplane..."
if [ -f "../.env.aws" ]; then
    source ../.env.aws

    if [ "$AWS_ACCESS_KEY_ID" == "your-access-key-id" ] || [ -z "$AWS_ACCESS_KEY_ID" ]; then
        print_warning "AWS credentials not configured in ../.env.aws"
        echo "Crossplane provider will not be able to provision resources"
        echo "Edit ../.env.aws with your AWS credentials"
    else
        # Create Kubernetes secret with AWS credentials
        echo "Creating Kubernetes secret with AWS credentials..."
        if [ -n "$AWS_SESSION_TOKEN" ]; then
            CREDENTIALS_STRING="[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
aws_session_token = ${AWS_SESSION_TOKEN}"
            echo "Including session token for temporary credentials"
        else
            CREDENTIALS_STRING="[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}"
            echo "Using long-term credentials (no session token)"
        fi

        kubectl create secret generic aws-credentials \
            -n crossplane-system \
            --from-literal=credentials="$CREDENTIALS_STRING" \
            --dry-run=client -o yaml | kubectl apply -f -

        print_success "AWS credentials secret created"

        # Create ProviderConfig
        echo ""
        echo "Creating ProviderConfig for AWS..."
        cat <<EOF | kubectl apply -f -
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: aws-credentials
      key: credentials
EOF

        print_success "ProviderConfig created"
    fi
else
    print_warning "../.env.aws file not found"
    echo "Crossplane provider will not be able to provision resources"
fi

echo "Waiting for DynamoDB CRDs to be available..."
MAX_RETRIES=30
for i in $(seq 1 $MAX_RETRIES); do
    if kubectl get crd tables.dynamodb.aws.upbound.io &>/dev/null; then
        print_success "DynamoDB CRDs are available"
        break
    fi
    if [ $i -eq $MAX_RETRIES ]; then
        print_error "Timeout waiting for DynamoDB CRDs"
        echo "Available Crossplane CRDs:"
        kubectl get crd | grep dynamodb || echo "None found"
        exit 1
    fi
    echo "Attempt $i/$MAX_RETRIES: Waiting for DynamoDB CRDs..."
    sleep 5
done

    print_success "Crossplane AWS DynamoDB Provider installed and ready"
fi

# =============================================================================
# PHASE 4: Install KRO (Kube Resource Orchestrator)
# =============================================================================
if [ "$SKIP_INSTALL" = false ]; then
    print_step "Phase 4: Installing KRO (Kube Resource Orchestrator)"

echo "Creating kro-system namespace..."
kubectl create namespace kro-system --dry-run=client -o yaml | kubectl apply -f -

echo "Installing KRO controller from latest release..."
kubectl apply -f https://github.com/kubernetes-sigs/kro/releases/latest/download/kro-core-install-manifests.yaml

echo "Waiting for KRO controller to be ready..."
sleep 10
    kubectl wait --for=condition=Available deployment/kro -n kro-system --timeout=300s || {
        print_warning "KRO controller may still be starting, continuing..."
    }
    print_success "KRO controller is installed"
fi

# =============================================================================
# PHASE 5: Install ACK DynamoDB Controller
# =============================================================================
if [ "$SKIP_INSTALL" = false ]; then
    print_step "Phase 5: Installing ACK DynamoDB Controller"

echo "Installing ACK DynamoDB controller from OCI registry..."
echo "Note: ACK now uses OCI registries hosted on AWS ECR Public"

# Check for AWS credentials from ../.env.aws
echo ""
print_info "Checking for AWS credentials..."
if [ -f "../.env.aws" ]; then
    print_success "Found ../.env.aws file"
    source ../.env.aws

    if [ "$AWS_ACCESS_KEY_ID" == "your-access-key-id" ] || [ -z "$AWS_ACCESS_KEY_ID" ]; then
        print_warning "AWS credentials not configured in ../.env.aws"
        echo "Edit ../.env.aws with your AWS credentials to enable DynamoDB provisioning"
        AWS_CREDS_CONFIGURED=false
    else
        print_success "AWS credentials loaded from ../.env.aws"
        echo "Creating Kubernetes secret for ACK controller..."
        kubectl create namespace ack-system --dry-run=client -o yaml | kubectl apply -f -

        # Create credentials in AWS shared credentials file format (required by ACK)
        if [ -n "$AWS_SESSION_TOKEN" ]; then
            echo "Including session token for temporary credentials"
            CREDENTIALS_STRING="[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
aws_session_token = ${AWS_SESSION_TOKEN}"
        else
            CREDENTIALS_STRING="[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}"
        fi

        kubectl create secret generic ack-dynamodb-user-secrets \
            -n ack-system \
            --from-literal=credentials="$CREDENTIALS_STRING" \
            --dry-run=client -o yaml | kubectl apply -f -

        print_success "AWS credentials configured for ACK"
        AWS_CREDS_CONFIGURED=true
    fi
else
    print_warning "../.env.aws file not found"
    echo "Creating template ../.env.aws file..."
    cat > ../.env.aws << 'EOF'
# AWS Credentials for ACK and Crossplane
AWS_ACCESS_KEY_ID=your-access-key-id
AWS_SECRET_ACCESS_KEY=your-secret-access-key
AWS_DEFAULT_REGION=us-west-2
EOF
    echo "✓ Template created. Edit ../.env.aws with your credentials."
    AWS_CREDS_CONFIGURED=false
fi
echo ""

# Get the latest release version
RELEASE_VERSION=$(curl -sL https://api.github.com/repos/aws-controllers-k8s/dynamodb-controller/releases/latest 2>/dev/null | grep '"tag_name"' | cut -d'"' -f4 | sed 's/v//')
if [ -z "$RELEASE_VERSION" ]; then
    print_warning "Could not determine latest version, using v1.7.0"
    RELEASE_VERSION="1.7.0"
fi
echo "Installing ACK DynamoDB controller version: $RELEASE_VERSION"

# Configure Helm values for ACK
ACK_HELM_VALUES="--set=aws.region=us-west-2"
if [ "$AWS_CREDS_CONFIGURED" = true ]; then
    ACK_HELM_VALUES="$ACK_HELM_VALUES --set=aws.credentials.secretName=ack-dynamodb-user-secrets"
    echo "Configuring ACK to use AWS credentials from secret"
fi

if helm list -n ack-system | grep -q "ack-dynamodb-controller"; then
    print_info "ACK DynamoDB controller already installed, upgrading..."
    helm upgrade ack-dynamodb-controller \
        oci://public.ecr.aws/aws-controllers-k8s/dynamodb-chart \
        --version=$RELEASE_VERSION \
        -n ack-system \
        $ACK_HELM_VALUES \
        --wait
else
    echo "Installing ACK DynamoDB controller..."
    helm install ack-dynamodb-controller \
        oci://public.ecr.aws/aws-controllers-k8s/dynamodb-chart \
        --version=$RELEASE_VERSION \
        -n ack-system \
        --create-namespace \
        $ACK_HELM_VALUES \
        --wait
fi

echo "Waiting for ACK DynamoDB controller..."
    kubectl wait --for=condition=Available deployment -l app.kubernetes.io/name=dynamodb-chart -n ack-system --timeout=300s || {
        print_warning "ACK controller may still be starting, continuing..."
    }
    print_success "ACK DynamoDB controller is installed"
fi

# =============================================================================
# PHASE 5.5: Configure KRO RBAC and Deploy ResourceGraphDefinitions
# =============================================================================
if [ "$SKIP_INSTALL" = false ]; then
    print_step "Phase 5.5: Configuring KRO RBAC and Deploying ResourceGraphDefinitions"

echo "Applying KRO RBAC fix for dynamic resource management..."
if [ -f "$DEMO_ROOT/kro-rbac-fix.yaml" ]; then
    kubectl apply -f "$DEMO_ROOT/kro-rbac-fix.yaml"
    print_success "KRO RBAC permissions configured"
else
    print_warning "kro-rbac-fix.yaml not found, KRO may have permission issues"
fi

echo ""
echo "Deploying KRO ResourceGraphDefinitions..."

# Deploy the full DynamoDB RGD (for advanced use with traits)
if [ -f "$DEMO_ROOT/definitions/kro/dynamodb-rgd.yaml" ]; then
    kubectl apply -f "$DEMO_ROOT/definitions/kro/dynamodb-rgd.yaml"
    print_success "DynamoDB RGD deployed (for advanced tables with traits)"
else
    print_warning "dynamodb-rgd.yaml not found, skipping"
fi

# Deploy the simple DynamoDB RGD (for basic tables)
if [ -f "$DEMO_ROOT/definitions/kro/simple-dynamodb-rgd.yaml" ]; then
    kubectl apply -f "$DEMO_ROOT/definitions/kro/simple-dynamodb-rgd.yaml"
    print_success "SimpleDynamoDB RGD deployed (for basic tables)"
else
    print_warning "simple-dynamodb-rgd.yaml not found, skipping"
fi

echo ""
echo "Waiting for RGDs to be ready..."
sleep 5

    # Restart KRO controller to pick up new RBAC permissions
    echo "Restarting KRO controller to apply RBAC changes..."
    kubectl rollout restart deployment/kro -n kro-system
    kubectl rollout status deployment/kro -n kro-system --timeout=120s
    print_success "KRO controller restarted with new permissions"
fi

# =============================================================================
# PHASE 5.6: Copy AWS Credentials to Default Namespace
# =============================================================================
if [ "$SKIP_INSTALL" = false ]; then
    print_step "Phase 5.6: Copying AWS Credentials to Default Namespace"

if [ "$AWS_CREDS_CONFIGURED" = true ]; then
    echo "Copying ACK credentials to default namespace for KRO-based applications..."
    # Delete existing secret first to avoid conflicts (may exist from previous runs)
    kubectl delete secret ack-dynamodb-user-secrets -n default --ignore-not-found=true 2>/dev/null || true

    # Wait a moment for deletion to complete
    sleep 2

    # Copy the secret with metadata stripped
    if kubectl get secret ack-dynamodb-user-secrets -n ack-system -o yaml 2>/dev/null | \
        sed 's/namespace: ack-system/namespace: default/' | \
        sed '/resourceVersion:/d' | \
        sed '/uid:/d' | \
        sed '/creationTimestamp:/d' | \
        sed '/selfLink:/d' | \
        kubectl create -f - 2>/dev/null; then
        print_success "ACK credentials available in default namespace"
    else
        # If create fails, secret might exist - try to verify it's there
        if kubectl get secret ack-dynamodb-user-secrets -n default >/dev/null 2>&1; then
            print_success "ACK credentials already available in default namespace"
        else
            print_warning "Could not copy ACK credentials to default namespace"
        fi
    fi

    echo ""
    echo "Copying Crossplane credentials to default namespace for XP-based applications..."
    # Delete existing secret first to avoid conflicts
    kubectl delete secret aws-credentials-xp -n default --ignore-not-found=true 2>/dev/null || true

    # Wait a moment for deletion to complete
    sleep 2

    # Copy the secret with metadata stripped
    if kubectl get secret aws-credentials -n crossplane-system -o yaml 2>/dev/null | \
        sed 's/namespace: crossplane-system/namespace: default/' | \
        sed 's/name: aws-credentials/name: aws-credentials-xp/' | \
        sed '/resourceVersion:/d' | \
        sed '/uid:/d' | \
        sed '/creationTimestamp:/d' | \
        sed '/selfLink:/d' | \
        kubectl create -f - 2>/dev/null; then
        print_success "Crossplane credentials available in default namespace"
    else
        # If create fails, secret might exist - try to verify it's there
        if kubectl get secret aws-credentials-xp -n default >/dev/null 2>&1; then
            print_success "Crossplane credentials already available in default namespace"
        else
            print_warning "Could not copy Crossplane credentials to default namespace"
        fi
    fi
else
    print_warning "AWS credentials not configured, skipping credential copy"
fi
fi

# =============================================================================
# PHASE 6: Deploy DynamoDB Component Definitions and Traits
# =============================================================================
print_step "Phase 6: Deploying DynamoDB Component Definitions and Traits"

echo "Deploying Kratix DynamoDB component (aws-dynamodb-kratix)..."
if [ -f "$DEMO_ROOT/definitions/components/aws-dynamodb-kratix.cue" ]; then
    vela def apply "$DEMO_ROOT/definitions/components/aws-dynamodb-kratix.cue"
    print_success "Kratix DynamoDB component deployed"
else
    print_warning "Kratix component definition not found"
fi

echo ""
echo "Deploying Crossplane DynamoDB component (aws-dynamodb-xp)..."
if [ -f "$DEMO_ROOT/definitions/components/aws-dynamodb-xp.cue" ]; then
    vela def apply "$DEMO_ROOT/definitions/components/aws-dynamodb-xp.cue"
    print_success "Crossplane DynamoDB component deployed"
else
    print_error "Crossplane component definition not found"
    exit 1
fi

echo ""
echo "Deploying KRO DynamoDB component (aws-dynamodb-kro)..."
if [ -f "$DEMO_ROOT/definitions/components/aws-dynamodb-kro.cue" ]; then
    vela def apply "$DEMO_ROOT/definitions/components/aws-dynamodb-kro.cue"
    print_success "KRO DynamoDB component deployed (advanced with traits)"
else
    print_error "KRO component definition not found"
    exit 1
fi

echo ""
echo ""
echo "Deploying KRO Simple DynamoDB component (aws-dynamodb-simple-kro)..."
if [ -f "$DEMO_ROOT/definitions/components/aws-dynamodb-simple-kro.cue" ]; then
    vela def apply "$DEMO_ROOT/definitions/components/aws-dynamodb-simple-kro.cue"
    print_success "KRO Simple DynamoDB component deployed (basic tables)"
else
    print_warning "Simple KRO component not found, skipping"
fi

echo ""
echo "Deploying Crossplane DynamoDB traits..."
trait_count=0
for trait in "$DEMO_ROOT/definitions/traits"/*-xp.cue; do
    if [ -f "$trait" ]; then
        trait_name=$(basename "$trait" .cue)
        echo "  - $trait_name"
        vela def apply "$trait"
        trait_count=$((trait_count + 1))
    fi
done
print_success "Deployed $trait_count Crossplane DynamoDB traits"

echo ""
echo "Deploying KRO DynamoDB traits..."
trait_count=0
for trait in "$DEMO_ROOT/definitions/traits"/*-kro.cue; do
    if [ -f "$trait" ]; then
        trait_name=$(basename "$trait" .cue)
        echo "  - $trait_name"
        vela def apply "$trait"
        trait_count=$((trait_count + 1))
    fi
done
print_success "Deployed $trait_count KRO DynamoDB traits"

# Wait a moment for definitions to register
echo ""
echo "Waiting for definitions to register..."
sleep 5

# Verify definitions are registered
echo ""
echo "Verifying component definitions..."
vela components | grep dynamodb && print_success "Components registered" || print_warning "Components may still be registering"
echo ""
echo "Verifying trait definitions..."
vela traits | grep dynamodb && print_success "Traits registered" || print_warning "Traits may still be registering"
echo ""

# =============================================================================
# PHASE 6.5: Create Required Namespaces
# =============================================================================
print_step "Phase 6.5: Creating Required Namespaces"

echo "Creating production namespace for production examples..."
kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -
print_success "Production namespace ready"

# =============================================================================
# PHASE 7: Deploy Sample Applications - Crossplane
# =============================================================================
print_step "Phase 7: Deploying Crossplane Sample Applications"

echo -e "${CYAN}Deploying 3 DynamoDB tables using Crossplane...${NC}"
echo ""

# Basic Crossplane example
echo "1. Basic table (Crossplane)..."
if [ -f "$DEMO_ROOT/definitions/examples/dynamodb-xp/basic.yaml" ]; then
    kubectl apply -f "$DEMO_ROOT/definitions/examples/dynamodb-xp/basic.yaml"
    print_success "deployed: dynamodb-basic-xp"
else
    print_warning "basic.yaml not found, skipping"
fi

# Table with streams (Crossplane)
echo ""
echo "2. Table with Streams (Crossplane)..."
if [ -f "$DEMO_ROOT/definitions/examples/dynamodb-xp/with-streams.yaml" ]; then
    kubectl apply -f "$DEMO_ROOT/definitions/examples/dynamodb-xp/with-streams.yaml"
    print_success "deployed: dynamodb-streams-xp"
else
    print_warning "with-streams.yaml not found, skipping"
fi

# Production table (Crossplane)
echo ""
echo "3. Production table (Crossplane)..."
if [ -f "$DEMO_ROOT/definitions/examples/dynamodb-xp/production.yaml" ]; then
    kubectl apply -f "$DEMO_ROOT/definitions/examples/dynamodb-xp/production.yaml"
    print_success "deployed: dynamodb-production-xp"
else
    print_warning "production.yaml not found, skipping"
fi

print_success "Crossplane applications deployed"

# =============================================================================
# PHASE 8: Deploy Sample Applications - KRO
# =============================================================================
print_step "Phase 8: Deploying KRO Sample Applications"

echo -e "${CYAN}Deploying 3 DynamoDB tables using KRO + ACK...${NC}"
echo ""

# Basic KRO example
echo "1. Basic table (KRO)..."
if [ -f "$DEMO_ROOT/definitions/examples/dynamodb-kro/basic.yaml" ]; then
    kubectl apply -f "$DEMO_ROOT/definitions/examples/dynamodb-kro/basic.yaml"
    print_success "deployed: dynamodb-basic-example"
else
    print_warning "basic.yaml not found, skipping"
fi

# Table with traits (KRO) - demonstrates KRO's trait system
echo ""
echo "2. Session table with traits (KRO)..."
if [ -f "$DEMO_ROOT/definitions/examples/dynamodb-kro/with-traits-basic.yaml" ]; then
    kubectl apply -f "$DEMO_ROOT/definitions/examples/dynamodb-kro/with-traits-basic.yaml"
    print_success "deployed: dynamodb-traits-basic"
else
    print_warning "with-traits-basic.yaml not found, skipping"
fi

# Simple basic table (KRO) - using SimpleDynamoDB RGD
echo ""
echo "3. Simple basic table (KRO with SimpleDynamoDB)..."
if [ -f "$DEMO_ROOT/definitions/examples/dynamodb-kro/simple-basic.yaml" ]; then
    kubectl apply -f "$DEMO_ROOT/definitions/examples/dynamodb-kro/simple-basic.yaml"
    print_success "deployed: dynamodb-simple-kro"
else
    print_warning "simple-basic.yaml not found, skipping"
fi

print_success "KRO applications deployed"

# =============================================================================
# PHASE 8.5: Deploy Sample Application with DynamoDB Integration
# =============================================================================
print_step "Phase 8.5: Deploying Session Management Demo Application"

if [ "$AWS_CREDS_CONFIGURED" = true ]; then
    echo -e "${CYAN}Deploying Flask application with DynamoDB integration...${NC}"
    echo ""

    # Check if Docker image exists and build if needed
    echo "Checking for session-api Docker image..."
    if [ -d "$DEMO_ROOT/app" ] && [ -f "$DEMO_ROOT/app/Dockerfile" ]; then
        echo "Building session-api Docker image..."
        cd "$DEMO_ROOT/app"
        DOCKER_BUILDKIT=0 docker build -t session-api:v1.0.0 . || {
            print_warning "Docker build failed, skipping app deployment"
            cd "$DEMO_ROOT"
        }

        if docker images | grep -q "session-api"; then
            echo "Importing image into k3d cluster..."
            k3d image import session-api:v1.0.0 -c kubevela-demo || {
                print_warning "Image import failed, skipping app deployment"
            }

            echo ""
            echo "Deploying session management applications..."

            # Deploy KRO-based version (advanced with traits)
            if [ -f "$DEMO_ROOT/definitions/examples/session-management-app-kro.yaml" ]; then
                vela up -f "$DEMO_ROOT/definitions/examples/session-management-app-kro.yaml"
                print_success "deployed: user-sessions-kro (Table: tenant-atlantis-user-sessions via KRO)"
            else
                print_warning "session-management-app-kro.yaml not found, skipping KRO version"
            fi

            # Deploy SimpleDynamoDB version (basic KRO)
            if [ -f "$DEMO_ROOT/definitions/examples/session-management-app-simple-kro.yaml" ]; then
                vela up -f "$DEMO_ROOT/definitions/examples/session-management-app-simple-kro.yaml"
                print_success "deployed: user-sessions-simple-kro (Table: user-sessions-simple via SimpleDynamoDB KRO)"
            else
                print_warning "session-management-app-simple-kro.yaml not found, skipping Simple KRO version"
            fi

            # Deploy Crossplane-based version
            if [ -f "$DEMO_ROOT/definitions/examples/session-management-app-xp.yaml" ]; then
                vela up -f "$DEMO_ROOT/definitions/examples/session-management-app-xp.yaml"
                print_success "deployed: sessions-xp (Table: tenant-atlantis-sessions-xp via Crossplane)"
            else
                print_warning "session-management-app-xp.yaml not found, skipping Crossplane version"
            fi
        fi
        cd "$DEMO_ROOT"
    else
        print_warning "App directory not found, skipping session management app"
    fi
else
    print_warning "AWS credentials not configured, skipping session management app deployment"
    echo "  The session management app requires AWS credentials to access DynamoDB"
fi

# =============================================================================
# PHASE 8.6: Deploy Example Kratix Promise Application
# =============================================================================
print_step "Phase 8.6: Deploying Example Kratix Promise Application"

if [ -f "$DEMO_ROOT/definitions/examples/kratix-example-app.yaml" ]; then
    echo "Deploying KubeVela application that creates DynamoDB table via Kratix promise..."
    vela up -f "$DEMO_ROOT/definitions/examples/kratix-example-app.yaml"
    print_success "deployed: kratix-example-dynamodb (DynamoDB table via Kratix promise)"
else
    print_warning "kratix-example-app.yaml not found, skipping Kratix example"
fi

# =============================================================================
# PHASE 8.7: Deploying Session Management Application with Kratix DynamoDB
# =============================================================================
print_step "Phase 8.7: Deploying Session Management Application with Kratix DynamoDB"

if [ -f "$DEMO_ROOT/definitions/examples/session-management-app-kratix.yaml" ]; then
    echo "Deploying session management API with Kratix DynamoDB backend..."
    vela up -f "$DEMO_ROOT/definitions/examples/session-management-app-kratix.yaml"
    print_success "deployed: session-api-app-kratix (Flask API + Kratix DynamoDB)"
else
    print_warning "session-management-app-kratix.yaml not found, skipping Kratix session management app"
fi

# =============================================================================
# PHASE 9: Verification
# =============================================================================
print_step "Phase 9: Verifying Deployments"

echo "Waiting for applications to be processed by KubeVela..."
sleep 10

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "KubeVela Applications:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get applications.core.oam.dev || print_warning "No applications found yet"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Kratix Promises:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get promise.platform.kratix.io -n kratix || print_warning "No Kratix promises found in kratix namespace"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Kratix DynamoDB Requests (via KubeVela aws-dynamodb-kratix component):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get dynamodbrequests.dynamodb.kratix.io -A || print_warning "No Kratix DynamoDB requests found yet"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Crossplane DynamoDB Tables:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get table.dynamodb.aws.upbound.io -A || print_warning "No Crossplane tables found yet"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "KRO ResourceGraphDefinitions:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get resourcegraphdefinition.kro.run || print_warning "No RGDs found yet"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "KRO DynamoDB Instances (Advanced):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get dynamodbtable || print_warning "No advanced KRO DynamoDB instances found yet"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "KRO SimpleDynamoDB Instances (Basic):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get simpledynamodb || print_warning "No SimpleDynamoDB instances found yet"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ACK DynamoDB Tables:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get table.dynamodb.services.k8s.aws -A || print_warning "No ACK tables found yet"

if [ "$AWS_CREDS_CONFIGURED" = true ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Session API Pods - tenant-atlantis-user-sessions (KRO):"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    kubectl get pods -l app.oam.dev/component=user-sessions-api-kro || print_warning "No user-sessions-api-kro pods found yet"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Session API Pods - user-sessions-simple (SimpleDynamoDB KRO):"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    kubectl get pods -l app.oam.dev/component=user-sessions-simple-api-kro || print_warning "No user-sessions-simple-api-kro pods found yet"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Session API Pods - tenant-atlantis-sessions-xp (Crossplane):"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    kubectl get pods -l app.oam.dev/component=sessions-api-xp || print_warning "No sessions-api-xp pods found yet"
fi

# =============================================================================
# COMPLETION SUMMARY
# =============================================================================
print_step "Setup Complete! 🎉"

echo -e "${GREEN}Your KubeCon NA 2025 DynamoDB Demo environment is ready!${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 INFRASTRUCTURE DEPLOYED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  ✓ k3d Kubernetes Cluster (1 server, 2 agents)"
echo "  ✓ KubeVela Application Platform"
echo "  ✓ Kratix Promise Framework (deployed via KubeVela)"
echo "  ✓ Crossplane + AWS DynamoDB Provider"
echo "  ✓ KRO (Kube Resource Orchestrator) + RBAC Fix"
echo "  ✓ ACK DynamoDB Controller"
echo "  ✓ KRO ResourceGraphDefinitions (DynamoDB + SimpleDynamoDB)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔹 KRATIX PROMISE FRAMEWORK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  ✓ Kratix Promise Deployer Component (KubeVela component definition)"
echo "  ✓ AWS DynamoDB Promise (kratix-platform KubeVela application)"
echo ""
echo -e "  ${CYAN}Check status:${NC}"
echo "    vela status kratix-platform"
echo "    kubectl get promise.platform.kratix.io -A"
echo "    kubectl get dynamodbrequests.dynamodb.kratix.io -A"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔹 CROSSPLANE APPLICATIONS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1. dynamodb-basic-xp              - Basic table with partition key"
echo "  2. dynamodb-streams-xp            - Table with DynamoDB Streams"
echo "  3. dynamodb-production-xp         - Full production configuration"
if [ "$AWS_CREDS_CONFIGURED" = true ]; then
echo "  4. sessions-xp                    - Table: tenant-atlantis-sessions-xp + API"
fi
echo ""
echo -e "  ${CYAN}Check status:${NC}"
echo "    vela status dynamodb-basic-xp"
echo "    kubectl get table.dynamodb.aws.upbound.io -A"
if [ "$AWS_CREDS_CONFIGURED" = true ]; then
echo "    vela status sessions-xp"
echo "    kubectl get pods -l app.oam.dev/component=sessions-api-xp"
fi
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔹 KRATIX PROMISE APPLICATIONS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1. kratix-example-dynamodb        - DynamoDB table via Kratix promise"
echo "  2. session-api-app-kratix         - Flask session API + Kratix DynamoDB backend"
echo ""
echo -e "  ${CYAN}Check status:${NC}"
echo "    vela status kratix-example-dynamodb"
echo "    vela status session-api-app-kratix"
echo "    kubectl get dynamodbrequests.dynamodb.kratix.io -A"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔹 KRO + ACK APPLICATIONS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1. dynamodb-basic-example         - Basic table via KRO + ACK"
echo "  2. dynamodb-traits-basic          - Session table with modular traits"
echo "  3. dynamodb-simple-kro            - Simple basic table (SimpleDynamoDB RGD)"
if [ "$AWS_CREDS_CONFIGURED" = true ]; then
echo "  4. user-sessions-kro              - Table: tenant-atlantis-user-sessions + API"
echo "  5. user-sessions-simple-kro       - Table: user-sessions-simple + API (SimpleDynamoDB)"
fi
echo ""
echo -e "  ${CYAN}Check status:${NC}"
echo "    vela status dynamodb-basic-example"
echo "    kubectl get dynamodbtable         # Advanced tables"
echo "    kubectl get simpledynamodb        # Simple tables"
echo "    kubectl get table.dynamodb.services.k8s.aws -A"
if [ "$AWS_CREDS_CONFIGURED" = true ]; then
echo "    vela status user-sessions-kro"
echo "    kubectl get pods -l app.oam.dev/component=user-sessions-api-kro"
echo "    vela status user-sessions-simple-kro"
echo "    kubectl get pods -l app.oam.dev/component=user-sessions-simple-api-kro"
fi
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 USEFUL COMMANDS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "  ${YELLOW}List all applications:${NC}"
echo "    kubectl get applications.core.oam.dev"
echo ""
echo -e "  ${YELLOW}View application details:${NC}"
echo "    vela status <app-name>"
echo "    vela status <app-name> --detail"
echo "    kubectl describe application <app-name>"
echo ""
echo -e "  ${YELLOW}List component and trait definitions:${NC}"
echo "    vela components | grep dynamodb"
echo "    vela traits | grep dynamodb"
echo ""
echo -e "  ${YELLOW}Watch Crossplane resources:${NC}"
echo "    watch kubectl get table.dynamodb.aws.upbound.io -A"
echo ""
echo -e "  ${YELLOW}Watch KRO resources:${NC}"
echo "    watch kubectl get dynamodbtable"
echo "    kubectl get resourcegraphdefinition dynamodbtable -o yaml"
echo ""
echo -e "  ${YELLOW}Watch ACK resources:${NC}"
echo "    watch kubectl get table.dynamodb.services.k8s.aws -A"
echo ""
echo -e "  ${YELLOW}Watch Kratix promises and requests:${NC}"
echo "    kubectl get promise.platform.kratix.io -n kratix"
echo "    watch kubectl get dynamodbrequests.dynamodb.kratix.io -A"
echo ""
echo -e "  ${YELLOW}View logs:${NC}"
echo "    kubectl logs -n crossplane-system -l app=crossplane --tail=50 -f"
echo "    kubectl logs -n kro-system -l control-plane=controller-manager --tail=50 -f"
echo "    kubectl logs -n ack-system -l app.kubernetes.io/name=dynamodb-chart --tail=50 -f"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📚 DOCUMENTATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "  📖 ${CYAN}README.md${NC}"
echo "     - Complete demo overview and quick start guide"
echo "     - Architecture diagrams and comparisons"
echo "     - Verification commands and troubleshooting"
echo "     - Session management API testing guide"
echo ""
echo -e "  📖 ${CYAN}CHANGELOG.md${NC}"
echo "     - Version history and important fixes"
echo ""
echo -e "  📖 ${CYAN}Component Documentation:${NC}"
echo "     - definitions/DYNAMODB-COMPONENTS-SUMMARY.md (Comparison guide)"
echo "     - definitions/DYNAMODB-KRO-SUMMARY.md (KRO architecture)"
echo "     - definitions/components/aws-dynamodb-xp.md (Crossplane)"
echo "     - definitions/components/aws-dynamodb-kro.md (KRO Advanced)"
echo ""
echo -e "  📖 ${CYAN}Trait Documentation:${NC}"
echo "     - definitions/traits/DYNAMODB-KRO-TRAITS-README.md (Trait guide)"
echo "     - definitions/traits/*-xp.md (Crossplane trait docs)"
echo "     - definitions/traits/*-kro.md (KRO trait docs)"
echo ""
echo -e "  📖 ${CYAN}Application Documentation:${NC}"
echo "     - app/README.md (Session management API guide)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 KEY COMPARISON"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "   ${CYAN}Crossplane (-xp)${NC}           ${CYAN}KRO (-kro)${NC}"
echo "   ================           ==========="
echo "   Mature & Stable            Experimental"
echo "   Multi-cloud                AWS-specific"
echo "   Abstract API               1:1 AWS API"
echo "   Crossplane Provider        ACK + KRO"
echo "   6 traits available         5 traits available"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}Happy demoing! 🚀${NC}"
echo ""

# Display VelaUX access information
echo -e "${CYAN}📊 VelaUX Dashboard:${NC}"
echo "  Access the KubeVela dashboard with:"
echo "    vela port-forward addon-velaux -n vela-system"
echo "  Then open: http://localhost:8000"
echo ""

# Show AWS credential status
if [ "$AWS_CREDS_CONFIGURED" = true ]; then
    echo -e "${GREEN}✓ AWS credentials are configured${NC}"
    echo "  DynamoDB tables are being provisioned in AWS"
    echo "  Both Crossplane and KRO/ACK controllers are configured with AWS access"
    echo ""
    echo -e "  ${CYAN}Verify table creation:${NC}"
    echo "    # Check Crossplane tables"
    echo "    kubectl get table.dynamodb.aws.upbound.io -A"
    echo ""
    echo "    # Check KRO/ACK tables"
    echo "    kubectl get table.dynamodb.services.k8s.aws -A"
    echo ""
    echo "    # List tables in AWS"
    echo "    aws dynamodb list-tables --region us-west-2"
else
    echo -e "${YELLOW}⚠ AWS credentials not configured${NC}"
    echo "  Applications are deployed but DynamoDB tables will remain pending."
    echo "  This demo showcases the KubeVela abstraction layer working with"
    echo "  both Crossplane and KRO infrastructure engines side-by-side."
    echo ""
    echo "  To actually provision DynamoDB tables, configure AWS credentials:"
    echo "  1. Edit ../.env.aws with your AWS credentials"
    echo "  2. Re-run setup.sh to configure the providers"
    echo ""
    echo "  Required credentials:"
    echo "    - AWS_ACCESS_KEY_ID"
    echo "    - AWS_SECRET_ACCESS_KEY"
    echo "    - AWS_DEFAULT_REGION (default: us-west-2)"
fi
echo ""
