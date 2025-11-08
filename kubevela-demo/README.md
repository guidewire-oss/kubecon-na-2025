# KubeVela Power Demo - KubeCon NA 2025

This demo showcases KubeVela's unified application delivery model compared to traditional approaches using a real-world Product Catalog API with S3 integration.

## What's Included

**Sample Application:** Python Flask + boto3 Product Catalog API with S3 storage for product images.

**Two Complete Implementations:**

| Approach | Files | Lines | Tools |
|----------|-------|-------|-------|
| **Traditional** | 6 files | 746 lines | Terraform + K8s + Dagger (Go) |
| **KubeVela** | 1 file | 258 lines | KubeVela only |
| **Improvement** | 83% fewer | 65% less | Unified |

**Traditional:**
- Terraform (244 lines) - Infrastructure as Code
- K8s manifests (196 lines) - Application deployment
- **Dagger pipeline (306 lines Go)** - Workflow & testing (portable CI/CD)
- Total: 746 lines across infrastructure, deployment, and workflow

**KubeVela:** Single application.yaml with app + infrastructure + workflow + functional tests

## Quick Start

### Prerequisites

- k3d cluster with local registry
- Crossplane with AWS provider configured
- KubeVela installed
- AWS credentials configured (see component-contributor-demo for setup)

### Demo Flow

#### 1. Build Application Images

```bash
cd app
DOCKER_BUILDKIT=0 docker build -t kv-product-cat-api:v1.0.0 .
docker tag kv-product-cat-api:v1.0.0 localhost:5000/kv-product-cat-api:v1.0.0
docker push localhost:5000/kv-product-cat-api:v1.0.0
```

#### 2. Traditional Approach (Optional)

```bash
cd imperative
./deploy.sh dev v1.0.0-imperative
kubectl get pods,svc,hpa -n dev
```

See [`imperative/DEMO_STEPS.md`](imperative/DEMO_STEPS.md) for details.

#### 3. KubeVela Approach

```bash
cd kubevela
./step3-deploy.sh

# Check status
vela status kv-product-catalog
kubectl get pods,hpa -n dev
```

**Progressive Delivery:**

```bash
# Deploy to staging
vela workflow resume kv-product-catalog && sleep 30
kubectl get pods,hpa -n staging

# Deploy to production
vela workflow resume kv-product-catalog && sleep 60
kubectl get pods,hpa -n prod
```

## Key Takeaways

| Benefit | Traditional | KubeVela | Impact |
|---------|-------------|----------|--------|
| **Files per app** | 6 files | 1 file | 83% fewer |
| **Lines per app** | 746 lines | 258 lines | 65% less |
| **Tools** | Terraform + K8s + Dagger (Go) | KubeVela only | Unified |
| **Workflow** | Dagger (306 lines Go) | Built-in YAML | Imperative vs Declarative |
| **Testing** | In-cluster test pod | Built-in request steps (36 lines) | Simpler |
| **Multi-env** | Code logic in Dagger | Policy overrides | DRY |
| **Programming** | Requires Go skills | YAML configuration | Lower barrier |

**Key Advantages:**
- Single source of truth (app + infra + workflow + tests)
- Built-in progressive delivery with approval gates
- Automated functional API testing
- Policy-based environment configuration

## Documentation

- [DEMO_PLAN.md](DEMO_PLAN.md) - Demo plan and architecture details
- [COMPARISON.md](COMPARISON.md) - Detailed side-by-side comparison
- [app/README.md](app/README.md) - Application documentation

## Troubleshooting

- **Workflow Resume:** `vela workflow resume kv-product-catalog`
- **Image Pull:** Verify with `curl http://localhost:5000/v2/_catalog`

## Cleanup

**KubeVela:**
```bash
vela delete kv-product-catalog
kubectl delete namespace dev staging prod
```

**Traditional:**
```bash
cd imperative
./cleanup.sh
```
