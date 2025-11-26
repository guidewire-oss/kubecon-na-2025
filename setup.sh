#!/bin/bash
set -e  # Exit on error

# KubeCon North America 2025 - Complete Demo Setup
# This script orchestrates all existing setup scripts to configure:
# 1. Kubernetes cluster with KubeVela and Crossplane
# 2. Initial KubeVela demo (basic application)
# 3. Advanced demo with parameter passing
# 4. Observability stack (Prometheus, Grafana, Loki)
# 5. High-availability trait and sample application

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║   KubeCon North America 2025 - Complete Demo Setup            ║"
echo "║   KubeVela + Crossplane + Observability + HA Traits           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_step() {
    echo ""
    echo "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo "${BLUE}$1${NC}"
    echo "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_success() {
    echo "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo "${RED}✗ $1${NC}"
}

# Check if running from correct directory
if [ ! -f "README.md" ] || [ ! -d "component-contributor-demo" ]; then
    print_error "Error: This script must be run from the kubecon-na-2025 repository root"
    exit 1
fi

# Store the repository root
REPO_ROOT=$(pwd)

# =============================================================================
# PHASE 0: Prerequisites Check
# =============================================================================
print_step "Phase 0: Checking Prerequisites"

echo "Checking required tools..."
all_tools_ok=true

required_tools="python3 k3d kubectl helm docker vela"
for tool in $required_tools; do
    if command -v $tool &>/dev/null; then
        print_success "$tool is installed"
    else
        print_error "$tool is NOT installed"
        all_tools_ok=false
    fi
done

if [ "$all_tools_ok" = false ]; then
    print_error "Some required tools are missing. Please install them first:"
    echo ""
    echo "  brew install python@3.12 k3d kubectl helm docker"
    echo "  curl -fsSl https://kubevela.io/script/install.sh | bash"
    echo ""
    exit 1
fi

print_success "All required tools are installed"

# Check if Python virtual environment exists
if [ ! -d ".venv" ]; then
    print_warning "Python virtual environment not found. Creating..."
    python3 -m venv .venv
    source .venv/bin/activate
    pip install --upgrade pip
    pip install -r component-contributor-demo/requirements.txt
    pip install -r kubevela-demo/app/requirements.txt
    print_success "Virtual environment created and dependencies installed"
else
    print_success "Virtual environment found"
    source .venv/bin/activate
fi

# =============================================================================
# PHASE 1: Cluster Setup (from component-contributor-demo)
# =============================================================================
print_step "Phase 1: Setting up Kubernetes Cluster with Crossplane and KubeVela"

echo "Running component-contributor-demo/setup.sh..."
cd "$REPO_ROOT/component-contributor-demo"

# Make sure setup.sh is executable
chmod +x setup.sh

# Run the existing setup script
if ./setup.sh; then
    print_success "Kubernetes cluster with Crossplane and KubeVela is ready"
else
    print_error "Cluster setup failed"
    exit 1
fi

cd "$REPO_ROOT"

# Verify cluster is ready
echo ""
echo "Verifying cluster status..."
kubectl cluster-info
kubectl get nodes
echo ""

# =============================================================================
# PHASE 2: Basic KubeVela Demo
# =============================================================================
print_step "Phase 2: Deploying Basic KubeVela Application"

echo "This demo showcases KubeVela's unified application delivery model"
echo "with a Product Catalog API deployed across dev/staging/prod environments"
echo ""

cd "$REPO_ROOT/kubevela-demo/kubevela"

# Build and push application image using existing script
if [ -f "step1-build-images.sh" ]; then
    chmod +x step1-build-images.sh
    echo "Building application images..."
    ./step1-build-images.sh
    print_success "Application images built and pushed"
else
    print_warning "step1-build-images.sh not found, skipping image build"
fi

# Deploy basic application using existing script
if [ -f "step3-deploy.sh" ]; then
    chmod +x step3-deploy.sh
    echo ""
    echo "Deploying basic KubeVela application..."
    ./step3-deploy.sh
    print_success "Basic application deployed"
else
    print_error "step3-deploy.sh not found"
    exit 1
fi

cd "$REPO_ROOT"

# =============================================================================
# PHASE 3: Advanced Demo with Parameter Passing
# =============================================================================
print_step "Phase 3: Deploying Advanced Demo with Parameter Passing"

echo "This demo showcases advanced parameter passing between components,"
echo "workflow variables, and dynamic S3 bucket provisioning"
echo ""

cd "$REPO_ROOT/kubevela-demo/kubevela"

# Deploy S3 app with parameter passing using existing script
if [ -f "deploy-s3-app.sh" ]; then
    chmod +x deploy-s3-app.sh
    echo "Running S3 app deployment (with parameter passing)..."
    if ./deploy-s3-app.sh; then
        print_success "Advanced demo with parameter passing deployed"
    else
        print_warning "S3 app deployment encountered issues (may be expected if AWS not configured)"
    fi
    echo ""
    echo "The S3 app demonstrates:"
    echo "  - Component output/input parameter passing"
    echo "  - Workflow step variable passing"
    echo "  - Environment-specific overrides"
else
    print_warning "deploy-s3-app.sh not found, skipping S3 app deployment"
fi

cd "$REPO_ROOT"

# =============================================================================
# PHASE 4: Observability Stack
# =============================================================================
print_step "Phase 4: Setting up Observability (Prometheus + Grafana + Loki)"

echo "Installing observability addon with KubeVela metrics enabled..."
echo ""

cd "$REPO_ROOT/kubevela-demo/kubevela"

if [ -f "setup-observability.sh" ]; then
    chmod +x setup-observability.sh
    # Run observability setup using existing script
    if ./setup-observability.sh; then
        print_success "Observability stack installed"
        echo ""
        print_success "Grafana: http://localhost:3000"
        print_success "Prometheus: http://localhost:9090"
        echo ""
        echo "Pre-built dashboards available:"
        echo "  - kubevela-dashboard.json - Platform metrics"
        echo "  - s3-storage-app-dashboard.json - Application metrics"
        echo ""
        echo "Import dashboards: Dashboards → Import → Upload JSON file"
    else
        print_warning "Observability setup encountered issues"
    fi
else
    print_warning "setup-observability.sh not found, skipping observability setup"
fi

cd "$REPO_ROOT"

# =============================================================================
# PHASE 5: High-Availability Trait
# =============================================================================
print_step "Phase 5: Deploying High-Availability Trait"

echo "Installing HA trait with environment-specific configurations..."
echo ""

cd "$REPO_ROOT/kubevela-demo/kubevela"

if [ -f "deploy-ha-trait.sh" ]; then
    chmod +x deploy-ha-trait.sh
    # Run HA trait deployment using existing script
    if ./deploy-ha-trait.sh; then
        print_success "High-Availability trait deployed"
    else
        print_warning "HA trait deployment encountered issues"
    fi
    echo ""

    # Deploy HA example app
    echo "Deploying HA example application..."
    echo ""

    # Check if we're in a local environment
    NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
    HAS_ZONE_LABELS=$(kubectl get nodes -o jsonpath='{.items[*].metadata.labels.topology\.kubernetes\.io/zone}' | wc -w)

    if [ "$NODE_COUNT" -eq 1 ] || [ "$HAS_ZONE_LABELS" -eq 0 ]; then
        print_warning "Detected local development environment"
        echo "Using ha-example-app-local.yaml (optimized for local clusters)"
        if [ -f "ha-example-app-local.yaml" ]; then
            vela up -f ha-example-app-local.yaml
            print_success "HA example app deployed with prod-local configuration"
        else
            print_warning "ha-example-app-local.yaml not found"
        fi
    else
        print_success "Detected multi-node cluster with zone labels"
        echo "Using ha-example-app.yaml (full production configuration)"
        if [ -f "ha-example-app.yaml" ]; then
            vela up -f ha-example-app.yaml
            print_success "HA example app deployed with full production configuration"
        else
            print_warning "ha-example-app.yaml not found"
        fi
    fi
else
    print_warning "deploy-ha-trait.sh not found, skipping HA trait setup"
fi

cd "$REPO_ROOT"

# =============================================================================
# COMPLETION SUMMARY
# =============================================================================
print_step "Setup Complete! 🎉"

echo "Your KubeCon NA 2025 demo environment is ready!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 QUICK REFERENCE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🔹 Basic Demo Commands:"
echo "   vela status kv-product-catalog"
echo "   vela workflow resume kv-product-catalog"
echo "   kubectl get pods,hpa -n dev"
echo ""
echo "🔹 S3 App with Parameter Passing:"
echo "   vela status s3-storage-app"
echo "   kubectl get xs3bucket -A"
echo ""
echo "🔹 Observability:"
echo "   Grafana:    http://localhost:3000 (admin / check terminal for password)"
echo "   Prometheus: http://localhost:9090"
echo ""
echo "   Dashboards: kubevela-demo/kubevela/kubevela-dashboard.json"
echo "               kubevela-demo/kubevela/s3-storage-app-dashboard.json"
echo ""
echo "🔹 High-Availability Trait:"
echo "   vela status ha-demo-app"
echo "   kubectl get hpa,pdb -n dev"
echo "   kubectl get hpa,pdb -n staging"
echo "   kubectl get hpa,pdb -n prod"
echo "   kubectl get pods -n prod -o wide  # View pod distribution"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📚 DOCUMENTATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📖 README.md                - Repository overview"
echo "📖 README_ADVANCED.md       - Advanced features guide"
echo ""
echo "   Parameter Passing        - README_ADVANCED.md#parameter-passing"
echo "   Observability            - README_ADVANCED.md#observability"
echo "   High-Availability        - README_ADVANCED.md#high-availability-traits"
echo ""
echo "   Complete Guides:"
echo "   • kubevela-demo/kubevela/OBSERVABILITY.md"
echo "   • kubevela-demo/kubevela/HIGH_AVAILABILITY_TRAIT.md"
echo "   • kubevela-demo/COMPARISON.md"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 KEY METRICS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "   Code Reduction:    65% (746 lines → 258 lines)"
echo "   File Reduction:    83% (15 files → 3 files)"
echo "   Single Deployment: dev + staging + prod"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "${GREEN}Happy demoing! 🚀${NC}"
echo ""
