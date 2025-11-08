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

### Recommended: Dagger Pipeline (via deploy.sh wrapper)

```bash
cd /workspaces/workspace/kubecon-NA-2025/kubevela-demo/imperative

# Deploy to dev (default)
./deploy.sh dev v1.0.0-imperative

# Deploy to other environments
./deploy.sh staging v1.0.0-imperative
./deploy.sh prod v1.0.0-imperative
```

**What it does:**
1. Loads AWS credentials from `../../.env.aws`
2. Runs Dagger pipeline (Go-based workflow) that:
   - Executes Terraform to create S3 bucket (`tenant-atlantis-product-images-imperative`)
   - Builds and pushes Docker image (`v1.0.0-imperative`)
   - Deploys K8s manifests (Deployment, Service, HPA)
   - Runs functional API tests (POST + GET)

**Benefits:**
- Portable: runs locally or in any CI system
- Code-based: Go workflow (310 lines) instead of bash scripts
- Container-based: reproducible builds
- Automated testing: validates deployment with actual API calls

### Alternative: Direct Dagger Execution

```bash
# Run Dagger directly (without wrapper)
cd /workspaces/workspace/kubecon-NA-2025/kubevela-demo/imperative
export ENVIRONMENT=dev IMAGE_TAG=v1.0.0-imperative
source ../../.env.aws  # Load credentials
cd dagger && go run main.go
```

### Manual Steps

```bash
cd /workspaces/workspace/kubecon-NA-2025/kubevela-demo/imperative

# 1. Terraform
cd terraform && terraform init && terraform apply -auto-approve && cd ..

# 2. Build image
cd ../app
DOCKER_BUILDKIT=0 docker build -t imp-product-catalog:v1.0.0-imperative .
docker tag imp-product-catalog:v1.0.0-imperative localhost:5000/imp-product-catalog:v1.0.0-imperative
docker push localhost:5000/imp-product-catalog:v1.0.0-imperative
cd ../imperative

# 3. Deploy K8s
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/ -n dev

# 4. Verify
kubectl get pods,svc,hpa -n dev
kubectl rollout status deployment/imp-product-catalog -n dev
```

## Verification

```bash
kubectl get pods,svc,hpa -n dev
kubectl logs -n dev deployment/imp-product-catalog --tail=20
aws s3 ls | grep imperative
```

## Troubleshooting

**Image pull error:**
```bash
curl http://localhost:5000/v2/imp-product-catalog/tags/list
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
# Complete cleanup (K8s + AWS resources)
./cleanup.sh

# Or manual cleanup
kubectl delete namespace dev staging prod
cd terraform && terraform destroy -auto-approve
```

## Comparison

**Traditional**: 746 lines across 6 files
- Terraform (244 lines) + K8s manifests (196 lines) + Dagger pipeline (306 lines Go)
- Tools: Terraform + K8s + Dagger
- Workflow: Imperative Go code

**KubeVela**: 258 lines in 1 file
- Single unified application definition
- Tools: KubeVela only
- Workflow: Declarative YAML

**Result**: 65% less code, 83% fewer files with KubeVela

See main [README.md](../README.md) for detailed comparison.
