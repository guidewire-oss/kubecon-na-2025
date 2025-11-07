# KubeVela Power Demo - KubeCon NA 2025

This demo showcases the power and simplicity of KubeVela's unified application delivery model compared to traditional approaches.

## What's Included

### Sample Application
A Python Flask + boto3 Product Catalog API that stores product images in S3:
- REST API endpoints for product management
- S3 integration for image storage
- Health and readiness checks
- Containerized with security best practices

### Two Complete Implementations

#### 1. Traditional Approach (`/traditional/`)
The conventional way using multiple tools:
- **Terraform** (4 files, 223 lines) - Infrastructure as Code (one-time)
- **Kubernetes Manifests** (5 files, 188 lines) - Application deployment (per-app)
- **Dagger Pipeline** (1 file, 310 lines) - CI/CD automation with functional API tests (per-app)
- **Total**: 10 files, 721 lines (223 one-time + 498 per-app)

**CI/CD Approach:**
- Dagger for portable, container-based CI/CD pipelines (see `dagger/` directory)
- Can run locally or in any CI system (GitHub Actions, GitLab CI, Jenkins, etc.)

#### 2. KubeVela Approach (`/kubevela/`)
The modern unified approach:
- **Crossplane Components** (2 files, 193 lines) - Infrastructure definition (one-time)
- **ComponentDefinition** (1 file, 76 lines) - Reusable S3 component (one-time)
- **Application** (1 file, 255 lines) - Complete application with workflow + functional API tests (per-app)
- **Total**: 4 files, 524 lines (269 one-time + 255 per-app)

## Quick Start

### Prerequisites

Run the environment setup notebook to create the complete demo environment:

```bash
# Run the Jupyter notebook to set up:
# - k3d cluster with local registry
# - Crossplane with AWS provider
# - KubeVela
# - AWS credentials configuration

jupyter notebook 00_Env-setup.ipynb
```

See `00_Env-setup.ipynb` for detailed setup instructions.

### Demo Flow

#### Step 1: Build Application Images

```bash
cd app

# Build KubeVela version
DOCKER_BUILDKIT=0 docker build -t product-catalog-api:v1.0.0 .
docker tag product-catalog-api:v1.0.0 localhost:5000/product-catalog-api:v1.0.0
docker push localhost:5000/product-catalog-api:v1.0.0

# Build Traditional version (optional, only if testing traditional approach)
docker tag product-catalog-api:v1.0.0 product-catalog-api:v1.0.0-traditional
docker tag product-catalog-api:v1.0.0-traditional localhost:5000/product-catalog-api:v1.0.0-traditional
docker push localhost:5000/product-catalog-api:v1.0.0-traditional
```

#### Step 2: Traditional Approach (Optional)

```bash
cd comparison/traditional

# Deploy with automatic cleanup and setup
./deploy-local.sh --cleanup dev

# Verify deployment
kubectl get pods,svc,hpa -n dev
```

**Key Points:**
- Separate tools: Terraform (infrastructure), K8s manifests (app), bash script (orchestration)
- Uses different resources: `tenant-atlantis-product-images-traditional` bucket, `v1.0.0-traditional` image tag
- IAM role ARN injected via placeholder in ServiceAccount annotation

See [`comparison/traditional/DEMO_STEPS.md`](comparison/traditional/DEMO_STEPS.md) for details.

#### Step 3: KubeVela Approach

```bash
cd kubevela

# One-time: Install Crossplane S3 component
kubectl apply -f crossplane/s3/xrd.yaml
kubectl apply -f crossplane/s3/composition.yaml
vela def apply components/s3/s3-bucket.cue

# Setup AWS credentials
cd .. && ./scripts/setup-aws-credentials.sh && cd kubevela

# Deploy everything with one command
vela up -f application.yaml

# Check status
vela status product-catalog
kubectl get pods,hpa -n dev
```

**Progressive Delivery:**

```bash
# Deploy to staging (resumes after dev health checks pass)
vela workflow resume product-catalog && sleep 30
kubectl get pods,hpa -n staging

# Deploy to production (resumes after staging health checks pass)
vela workflow resume product-catalog && sleep 60
kubectl get pods,hpa -n prod

# View complete status with health check results
vela status product-catalog
```

**Key Advantages:**
- Single file for app + infrastructure + workflow + functional tests
- Built-in traits (HPA, SecurityContext, Resources)
- Policy-based environment overrides (dev: 1-3 pods, staging: 2-5, prod: 3-10)
- Progressive delivery with approval gates
- **Automated functional API testing** - creates product via POST, retrieves via GET
- Tests actual business logic, not just health endpoints
- Workflow halts if API tests fail (status code > 400)

## Key Comparison Metrics

### One-Time Platform Setup

| Metric | Traditional | KubeVela | Notes |
|--------|-------------|----------|-------|
| Infrastructure Setup | 223 lines (4 Terraform files) | 269 lines (3 files) | Both are one-time setup |
| State Management | Terraform state files | None | KubeVela uses K8s as state store |

### Per-Application Deployment

| Metric | Traditional | KubeVela | Improvement |
|--------|-------------|----------|-------------|
| Files | 6 | 1 | 83% fewer |
| Lines of Code | 498 | 255 | 49% fewer |
| Tools | 2 (K8s, Dagger) | 1 (KubeVela) | 50% fewer |
| Configuration Overhead | K8s manifests + Dagger | Single application.yaml | Unified |
| Workflow | External (310 lines Dagger) | Built-in with functional tests | No external CI/CD |
| Multi-Environment | Duplicate pipeline stages | Policy overrides | DRY principle |
| API Testing | Implemented in Dagger Go code | Built-in functional tests | Declarative vs imperative |

## Key Takeaways

1. **83% fewer files per app**: Traditional (6 files) vs KubeVela (1 file)
2. **49% less code per app**: Traditional (498 lines) vs KubeVela (255 lines)
3. **Unified model**: Single file for app + infrastructure + workflow + functional tests
4. **No external CI/CD**: Built-in progressive delivery with approval gates
5. **Declarative API testing**: YAML-based functional tests vs imperative Go code
6. **Policy-driven config**: Environment-specific overrides without duplication

## Documentation

- [DEMO_PLAN.md](DEMO_PLAN.md) - Complete demo plan and architecture
- [docs/COMPARISON.md](docs/COMPARISON.md) - Detailed side-by-side comparison
- [app/README.md](app/README.md) - Application documentation

## Troubleshooting

### Workflow Resume

Always use the application name, not the step name:
```bash
# ✓ CORRECT
vela workflow resume product-catalog

# ✗ WRONG
vela workflow resume approval-staging
```

### AWS Credentials

If pods fail with `NoCredentialsError`, run:
```bash
./scripts/setup-aws-credentials.sh
```

### Image Pull Issues

If pods are in `ImagePullBackOff`:
```bash
# Verify registry and image
k3d registry list
curl http://localhost:5000/v2/_catalog

# Rebuild and push
cd app
DOCKER_BUILDKIT=0 docker build -t product-catalog-api:v1.0.0 .
docker tag product-catalog-api:v1.0.0 localhost:5000/product-catalog-api:v1.0.0
docker push localhost:5000/product-catalog-api:v1.0.0
```

## Cleanup

```bash
# KubeVela
vela delete product-catalog
kubectl delete namespace dev staging prod

# Traditional (if deployed)
cd comparison/traditional
./deploy-local.sh --cleanup dev
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│              KubeVela Application                       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Components:                                            │
│    ├─ product-api (webservice)                         │
│    │   - Flask + boto3                                 │
│    │   - Port 8080                                     │
│    └─ product-images (simple-s3)                       │
│        - S3 bucket for images                          │
│                                                          │
│  Traits:                                                │
│    ├─ hpa (min:2, max:10)                             │
│    ├─ security-context (non-root, read-only FS)       │
│    └─ resource (CPU/memory limits)                     │
│                                                          │
│  Workflow:                                              │
│    ├─ deploy-dev ──> test-dev ───┐                    │
│    ├─ approval-staging (suspend) │                     │
│    ├─ deploy-staging ──> verify  │                     │
│    ├─ approval-prod (suspend)    │                     │
│    └─ deploy-prod ──> verify     │                     │
│                                                          │
│  Policy:                                                │
│    ├─ multi-env (dev/staging/prod)                    │
│    └─ environment-specific overrides                   │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## Success Metrics

After this demo, the audience will understand:

1. ✅ KubeVela reduces complexity (83% fewer files per app)
2. ✅ Infrastructure can be treated as application components
3. ✅ Workflows eliminate external CI/CD complexity
4. ✅ Traits provide reusable cross-cutting concerns
5. ✅ Developers focus on business value, not infrastructure details
6. ✅ Platform teams can provide opinionated, secure defaults

## Contact

For questions or feedback about this demo, please open an issue in the repository.

## License

This demo is provided as-is for educational purposes.
