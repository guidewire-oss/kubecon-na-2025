# Traditional Approach Demo

## Prerequisites

```bash
# Verify setup
docker ps
kubectl get nodes
echo $AWS_ACCESS_KEY_ID

# If credentials not set
cd /workspaces/workspace/kubecon-NA-2025
source .env.aws
```

## Deployment

### Bash Script (Recommended)

```bash
cd /workspaces/workspace/kubecon-NA-2025/kubevela-demo/traditional

# Deploy with cleanup
./deploy-local.sh --cleanup dev

# Deploy to other environments
./deploy-local.sh staging
./deploy-local.sh prod
```

**What it does:**
1. Terraform creates S3 bucket (`tenant-atlantis-product-images-traditional`)
2. Docker builds and pushes image (`v1.0.0-traditional`)
3. Kubectl applies K8s manifests (Deployment, Service, HPA)

### Dagger (Portable CI/CD)

```bash
# Install Dagger
curl -L https://dl.dagger.io/dagger/install.sh | sudo sh

# Run from traditional/ directory
cd /workspaces/workspace/kubecon-NA-2025/kubevela-demo/traditional
export ENVIRONMENT=dev IMAGE_TAG=v1.0.0-traditional
cd dagger && go mod download && go run main.go
```

**Benefits:**
- Portable: runs locally or in any CI system
- Code-based: Go instead of YAML
- Container-based: reproducible builds

### Manual Steps

```bash
cd /workspaces/workspace/kubecon-NA-2025/kubevela-demo/traditional

# 1. Terraform
cd terraform && terraform init && terraform apply -auto-approve && cd ..

# 2. Build image
cd ../app
DOCKER_BUILDKIT=0 docker build -t product-catalog-api:v1.0.0-traditional .
docker tag product-catalog-api:v1.0.0-traditional localhost:5000/product-catalog-api:v1.0.0-traditional
docker push localhost:5000/product-catalog-api:v1.0.0-traditional
cd ../traditional

# 3. Deploy K8s
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/ -n dev

# 4. Verify
kubectl get pods,svc,hpa -n dev
kubectl rollout status deployment/product-catalog-api -n dev
```

## Verification

```bash
kubectl get pods,svc,hpa -n dev
kubectl logs -n dev deployment/product-catalog-api --tail=20
aws s3 ls | grep traditional
```

## Troubleshooting

**Image pull error:**
```bash
curl http://localhost:5000/v2/product-catalog-api/tags/list
# Rebuild if needed
```

**AWS credentials:**
```bash
source ../../../.env.aws
```

**Terraform state:**
```bash
cd terraform && rm -rf .terraform && terraform init
```

## Cleanup

```bash
./deploy-local.sh --cleanup dev
kubectl delete namespace dev staging prod
```

## Comparison

**Traditional**: 3 separate tools (Terraform, K8s, Dagger), 10 files (597 lines)
**KubeVela**: 1 unified tool, 1 file (171 lines), automatic workflow

See main [README.md](../../README.md) for detailed comparison.
