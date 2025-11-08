# Dagger Pipeline for Imperative Approach

Modern CI/CD pipeline written in Go that replaces bash scripts with portable, testable code.

## Quick Start

```bash
# Run from imperative/ directory (easiest - includes Docker build)
cd /workspaces/workspace/kubecon-na-2025/kubevela-demo/imperative
./deploy.sh dev v1.0.0-imperative

# Or run Dagger directly (requires Docker image to be built separately)
cd /workspaces/workspace/kubecon-na-2025/kubevela-demo/imperative
export ENVIRONMENT=dev IMAGE_TAG=v1.0.0-imperative
cd dagger && go run main.go
```

## What It Does

1. **Infrastructure**: Provisions S3 bucket with Terraform
2. **Build**: Docker image (handled by deploy.sh wrapper)
3. **Deploy**: Applies Kubernetes manifests (deployment, service, HPA, configmap, serviceaccount)
4. **Test**: Functional API tests (creates and retrieves product to verify S3 integration)

## Pipeline Steps

### Step 1: Terraform Infrastructure
- Creates S3 bucket for product images
- Configures bucket versioning and public access blocks
- Optionally creates IAM roles (disabled for local k3d)

### Step 2: Docker Image
- Handled by deploy.sh wrapper script
- Builds Python Flask API image
- Pushes to k3d local registry

### Step 3: Kubernetes Deployment
- Creates namespace if needed
- Applies manifests with cache-busting to prevent stale Dagger caches
- Waits for deployment rollout to complete
- Uses kubeconfig with insecure-skip-tls-verify for k3d

### Step 4: Functional Testing
- Runs test pod inside cluster network (can access cluster DNS)
- Waits for API health endpoint
- Creates test product (POST /products)
- Retrieves product by ID (GET /products/{id})
- Verifies end-to-end flow including S3 storage

## Why Dagger?

- **Portable**: Runs identically locally and in CI/CD
- **Type-safe**: Go code with compile-time checks (not YAML)
- **Container-based**: Reproducible, isolated builds
- **Testable**: Run full pipeline locally before committing
- **Fast**: Intelligent caching at every layer
- **Observable**: Real-time logs and debugging

## Comparison with KubeVela

| Aspect | Imperative (Dagger) | Declarative (KubeVela) |
|--------|---------------------|------------------------|
| Definition | Go code | YAML Application |
| Orchestration | Procedural steps | Workflow DAG |
| Testing | In-cluster test pod | HTTP request steps |
| Portability | Runs anywhere | Requires KubeVela |
| Complexity | 303 lines Go | 258 lines YAML |
| Multi-env | Manual ENV var | Built-in policies |
| Approvals | Not built-in | Suspend steps |
