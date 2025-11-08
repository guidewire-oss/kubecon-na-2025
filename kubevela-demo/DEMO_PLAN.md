# KubeVela Power Demo - Plan & Architecture

## Executive Summary

This demo showcases the power and simplicity of KubeVela's unified application delivery model compared to traditional approaches. We'll demonstrate a real-world application deployment that includes:
- Kubernetes resources (Deployment, Service)
- AWS infrastructure (S3 bucket)
- Application lifecycle management (workflow, policies, traits)

## Demo Scenario: "Product Catalog Service"

A microservice that:
1. Runs a containerized API (K8s Deployment + Service)
2. Stores product images in S3
3. Requires multi-stage deployment (dev → staging → prod)
4. Needs auto-scaling and monitoring

## Comparison Matrix

| Aspect | Traditional Approach | KubeVela Approach |
|--------|---------------------|-------------------|
| **K8s Resources** | Raw YAML manifests (188 lines) | Component definitions with sensible defaults |
| **Infrastructure** | Separate Terraform files + state management | S3 component in same application.yaml |
| **Orchestration** | External CI/CD pipeline (Dagger) | Built-in workflow in application.yaml |
| **Configuration** | Multiple config files, hard-coded values | Traits for cross-cutting concerns |
| **Developer Experience** | Must understand K8s, Terraform, Dagger | Focus on business requirements |

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│              KubeVela Application                       │
├─────────────────────────────────────────────────────────┤
│                                                          │


│  Components:                                            │
│    ├─ kv-product-cat-api (webservice)                  │
│    └─ kv-prodcat-images (simple-s3)                    │
│                                                          │
│  Traits:                                                │
│    ├─ hpa (horizontal pod autoscaler)                  │
│    ├─ security-context (pod security settings)         │
│    └─ resource (CPU/memory limits & requests)          │
│                                                          │
│  Workflow:                                              │
│    ├─ deploy-dev                                        │
│    ├─ manual-approval                                   │
│    ├─ deploy-staging                                    │
│    ├─ health-check                                      │
│    └─ deploy-prod                                       │
│                                                          │
│  Policy:                                                │
│    └─ topology (multi-cluster)                         │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## Detailed Comparison Scenarios

### Scenario 1: Traditional Approach - Kubernetes + Terraform + Dagger

**What you need:**

**A. Kubernetes Manifests:**
- deployment.yaml (104 lines)
  - Container specs, replicas, labels
  - Environment variables, volume mounts
- service.yaml (17 lines)
- hpa.yaml (44 lines)
  - Min/max replicas, target CPU
- serviceaccount.yaml (11 lines)
  - IAM role annotation
- configmap.yaml (12 lines)
- Total: 188 lines across 5 YAML files

**B. Terraform Files (HCL):**
- **provider.tf** (25 lines)
  ```hcl
  terraform {
    required_version = "1.5.7"
    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = "~> 5.0"
      }
    }
    backend "s3" {
      # State management configuration
      bucket = "terraform-state-bucket"
      key    = "kv-product-catalog/terraform.tfstate"
      region = "us-west-2"
    }
  }

  provider "aws" {
    region = var.aws_region
  }
  ```

- **main.tf** (101 lines)
  ```hcl
  # S3 Bucket for product images
  resource "aws_s3_bucket" "product_images" {
    bucket = "tenant-atlantis-kv-prodcat-images"

    tags = {
      "gwcp:v1:dept"                            = "000"
      "gwcp:v1:provisioned-resource:created-by" = "kubecon-NA25"
      "gwcp:v1:quadrant:name"                   = "dev"
      "gwcp:v1:resource-type:managed-by"        = "pod-atlantis"
      "gwcp:v1:resource-type:managed-tool"      = "terraform"
      "gwcp:v1:star-system:name"                = "kubecon"
      "gwcp:v1:tenant:name"                     = "atlantis"
      "gwcp:v1:tenant:app-name"                 = "kv-product-catalog"
    }
  }

  # IAM Role for pod
  resource "aws_iam_role" "product_api_role" {
    name = "tenant-atlantis-kv-product-cat-api-role"
    # ... assume role policy
  }

  # IAM Policy for S3 access
  resource "aws_iam_policy" "s3_access" {
    # ... S3 bucket permissions
  }
  ```

- **variables.tf** (68 lines)
- **outputs.tf** (29 lines)
- **terraform.tfvars** (20 lines)
- Total: 223 lines across 4 .tf files (243 including .tfvars)

**C. CI/CD Pipeline (Dagger):**
- **dagger/main.go** (310 lines - includes functional API tests)
  ```go
  // Dagger pipeline that orchestrates:
  // 1. Terraform operations (init, plan, apply)
  // 2. Docker image build
  // 3. Kubernetes deployments
  // 4. Multi-environment rollout
  // 5. Functional API testing (POST + GET)
  // 6. Verification and health checks

  // Written in Go, runs in containers
  // Portable across CI systems and local development
  // Implements http.Post() and http.Get() for testing
  ```

**Total: 721 lines across 10 files in 3 different tools** (223 Terraform + 188 K8s + 310 Dagger)

**Pain points:**
- Context switching between K8s YAML, HCL, and Go (Dagger)
- Terraform state management complexity
- Pipeline code complexity (310 lines of Go, including 124 for API testing)
- Credential management across tools (AWS creds + kubeconfig)
- Manual coordination between infrastructure and application
- No unified view of application
- Separate HPA, SecurityContext, and Resource manifests to manage
- Manual orchestration of multi-stage deployments
- Testing requires programming skills (Go)

### Scenario 2: KubeVela (The Better Way)

**What you need:**
- application.yaml (255 lines including functional API tests)
- Component definitions (reusable, platform-provided)
- **Total: 255 lines in 1 file**

**Benefits:**
- Single source of truth
- Built-in workflow orchestration with automated functional testing
- Infrastructure as components
- Business-focused configuration
- Platform defaults applied automatically
- Unified observability
- **Automated functional API testing** - tests actual business logic (POST + GET)

## Sample Microservice Application

### Python3 Boto3 Application
To make the demo as local as possible, we'll use a simple Python3 Flask + boto3 application:

**Application: Product Catalog API**
- **Language**: Python 3.11+
- **Framework**: Flask (lightweight REST API)
- **AWS SDK**: boto3 (for S3 operations)
- **Container Registry**: Local registry in k3d cluster (localhost:5000)
- **Features**:
  - `GET /products` - List products (reads from local DB)
  - `POST /products` - Create product with image upload (stores image in S3)
  - `GET /products/{id}` - Get product with S3 signed URL for image
  - Health check endpoint

**Docker Setup:**
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
CMD ["python", "app.py"]
```

**Local Registry in k3d:**
```bash
# k3d cluster already includes registry
# Push to: localhost:5000/kv-product-cat-api:v1.0.0
docker build -t localhost:5000/kv-product-cat-api:v1.0.0 .
docker push localhost:5000/kv-product-cat-api:v1.0.0
```

**AWS Resources (Only External Dependencies):**
- S3 bucket for product images
- IAM role/policy for S3 access (via IRSA - IAM Roles for Service Accounts)

**Everything else runs locally:**
- Application pods in k3d
- Database (optional: local PostgreSQL or in-memory)
- No external CI/CD services

## Demo Flow

### Part 1: The Traditional Way (Show the Pain)

**Show the complete traditional stack** (10 files, 597 lines):

1. **Terraform Infrastructure** (HCL files)
   - provider.tf with version constraints
   - main.tf with S3 bucket and IAM resources
   - variables.tf, outputs.tf, terraform.tfvars
   - Highlight: State management, AWS credentials, resource tagging

2. **Kubernetes Manifests** (multiple YAML files)
   - deployment.yaml with container specs
   - service.yaml
   - hpa.yaml (separate auto-scaling config)
   - security-context patches
   - resource limits/requests
   - Highlight: Scattered configuration, repetition, manual coordination

3. **CI/CD Pipeline** (GitHub Actions YAML)
   - terraform init/plan/apply
   - kubectl apply commands
   - manual approval gates
   - Highlight: Pipeline complexity, credential management

**Key pain points to emphasize:**
- Three different languages/tools (HCL, K8s YAML, GitHub Actions YAML)
- Terraform state file management
- Manual coordination between infra and app deployment
- No unified view of the entire application

### Part 2: The KubeVela Way (Show the Power)

1. **Show single application.yaml** (1 file, 255 lines vs 6 files, 498 lines)
   - Clean, business-focused
   - Components with defaults
   - Built-in workflow with functional API tests
   - Infrastructure included
   - Automated functional testing between environments (POST + GET)
   - Declarative YAML vs imperative Go code

2. **Live demo:**
   ```bash
   vela up -f application.yaml
   vela workflow suspend my-app --step manual-approval
   vela workflow resume my-app
   vela status my-app
   ```

3. **Show what happened behind the scenes:**
   - S3 bucket created via Crossplane
   - Deployment scaled automatically
   - Multi-stage workflow executed with functional API tests
   - Product created via POST, retrieved via GET in each environment
   - Data passed between workflow steps (product ID from POST to GET)
   - Workflow automatically halts on failure
   - All from one file!

## Key Talking Points

### 1. Abstraction Done Right
- Developers don't need to be K8s experts
- Platform team provides components with sensible defaults
- Business requirements, not technical details

### 2. Infrastructure as Components
- S3 bucket is just another component
- No Terraform state to manage
- No separate infrastructure pipeline
- Unified with application lifecycle
- **All AWS resources must include proper tagging** for governance and cost tracking (see 01_OAM-contrib.ipynb for tag structure)

### 3. Built-in Workflow vs External CI/CD
- No separate pipeline configuration
- Workflow is part of the application definition
- Portable across environments
- Version controlled with the app

### 4. Traits for Cross-Cutting Concerns
- HPA (Horizontal Pod Autoscaler) for auto-scaling
- Security Context for pod security settings
- Resource limits and requests for resource management
- Applied declaratively
- Reusable across applications
- No manual coordination

### 5. Progressive Delivery Built-in
- Multi-stage deployment
- Manual approval gates
- Health checks
- Rollback capabilities

## Demo Artifacts to Create

### 1. Sample Application (`/app/`)
- `app.py` - Flask application with boto3 S3 integration
- `requirements.txt` - Python dependencies (flask, boto3, etc.)
- `Dockerfile` - Container image definition
- `README.md` - Application documentation
- `test_api.sh` - Simple test script

### 2. Traditional Approach (`/comparison/traditional/`)

#### a. Terraform Infrastructure (`terraform/`)
- `provider.tf` - Terraform and AWS provider configuration with version 1.5.7
- `main.tf` - S3 bucket, IAM role, IAM policy with proper tags
- `variables.tf` - Input variables (bucket name, region, tags)
- `outputs.tf` - Output values (bucket ARN, IAM role ARN)
- `terraform.tfvars` - Variable values
- `backend.tf` - S3 backend for state management

#### b. Kubernetes Manifests (`k8s/`)
- `deployment.yaml` - Application deployment with volume mounts, env vars
- `service.yaml` - ClusterIP service
- `hpa.yaml` - Horizontal Pod Autoscaler (min: 2, max: 10)
- `resources.yaml` - ResourceQuota and LimitRange
- `security-context.yaml` - PodSecurityPolicy or SecurityContext patches
- `serviceaccount.yaml` - ServiceAccount with IAM role annotation
- `configmap.yaml` - Application configuration

#### c. CI/CD Pipeline (`.github/workflows/`)
- `deploy.yml` - Complete deployment pipeline
  - Terraform plan/apply
  - Docker build and push to registry
  - kubectl apply K8s resources
  - Manual approval gates
  - Multi-environment deployment (dev → staging → prod)

#### d. Documentation
- `README.md` - Setup instructions, prerequisites, deployment steps

### 3. KubeVela Approach (`/kubevela/`)

#### a. Crossplane S3 Component (`crossplane/s3/`)
- `xrd.yaml` - CompositeResourceDefinition for S3 bucket
  - Define simple Experience API (bucket name, region, tags)
  - Use Crossplane v2 API with Cluster scope
- `composition.yaml` - Composition using Pipeline mode
  - Create aws_s3_bucket resource
  - Create aws_iam_role for IRSA
  - Create aws_iam_policy with S3 permissions
  - Patch tenant-atlantis prefix
  - Apply standard tags automatically
  - Use function-patch-and-transform

#### b. KubeVela ComponentDefinition (`components/`)
- `s3/s3-bucket.cue` - ComponentDefinition for simple-s3
  - Wraps Crossplane XRD
  - Adds health policy
  - Adds custom status
  - Enforces naming convention and tags
- `webservice/webservice.cue` (if not using built-in)
  - Standard webservice component
  - With HPA, SecurityContext, Resource traits applied

#### c. Application Definition
- `application.yaml` - **The star of the show!**
  - Components: kv-product-cat-api (webservice), kv-prodcat-images (simple-s3)
  - Traits: hpa, security-context, resource
  - Workflow: deploy-dev → approval → deploy-staging → approval → deploy-prod
  - Policy: topology for multi-namespace deployment

#### d. Local Development Setup
- `local-setup.sh` - Script to build and push app to local registry
- `test-local.sh` - Test the deployed application

#### e. Documentation
- `README.md` - Usage guide and comparison
- `DEMO_SCRIPT.md` - Step-by-step demo presentation

### 4. Documentation (`/docs/`)
- `COMPARISON.md` - Side-by-side feature comparison table
- `CROSSPLANE_DETAILS.md` - Deep dive on XRD and Composition
- `WALKTHROUGH.md` - Complete demo walkthrough script
- `ARCHITECTURE.md` - Technical architecture diagrams

## Success Criteria

By the end of the demo, the audience should understand:

1. ✅ KubeVela reduces complexity (1 file vs 6 files per app, 83% fewer files, 49% less code)
2. ✅ Infrastructure can be treated as components
3. ✅ Workflows eliminate external CI/CD for deployments
4. ✅ Built-in functional API tests validate actual business logic (POST + GET)
5. ✅ Declarative testing: YAML vs Go code (12 vs 124 lines per test)
6. ✅ Data flows between workflow steps (outputs → inputs)
7. ✅ Traits provide reusable cross-cutting concerns
8. ✅ Developers focus on business value, not K8s details or programming
9. ✅ Platform teams provide opinionated, secure defaults

## Technical Requirements

### Prerequisites
- k3d cluster running
- Crossplane installed with AWS Provider
- KubeVela installed
- Terraform v1.5.7
- AWS credentials configured

### New Components to Create
1. **S3 Component** (similar to DynamoDB example in 01_OAM-contrib.ipynb)
   - XRD for S3 bucket
   - Composition with sensible defaults
   - ComponentDefinition in CUE
   - **IMPORTANT**: Must include AWS resource tags following the pattern from DynamoDB example:
     ```yaml
     tags:
       "gwcp:v1:dept": "000"
       "gwcp:v1:provisioned-resource:created-by": "kubecon-demo"
       "gwcp:v1:quadrant:name": "dev"
       "gwcp:v1:resource-type:managed-by": "pod-atlantis"
       "gwcp:v1:resource-type:managed-tool": "crossplane"
       "gwcp:v1:star-system:name": "kubecon"
       "gwcp:v1:tenant:name": "atlantis"
       "gwcp:v1:tenant:app-name": context.appName
     ```
   - Resource naming convention: `tenant-atlantis-{name}` prefix

2. **Webservice Component** (may already exist)
   - Standard deployment + service pattern
   - With configurable replicas, image, ports

### Workflow Steps to Demonstrate
1. Deploy to dev namespace
2. Run integration tests (simulated)
3. Manual approval gate
4. Deploy to staging namespace
5. Health check validation
6. Deploy to prod namespace

### Traits to Use
1. `hpa` - Horizontal Pod Autoscaler trait
   - Auto-scaling based on CPU/memory metrics
   - Min/max replica configuration

2. `security-context` - Pod/Container security settings trait
   - Run as non-root user
   - Read-only root filesystem
   - Drop capabilities
   - Security best practices

3. `resource` - Resource limits and requests trait
   - CPU limits and requests
   - Memory limits and requests
   - Resource quotas

## Demo Execution Notes

### Prerequisites
- Terraform v1.5.7 installed
- AWS credentials configured
- k3d cluster with local registry
- KubeVela and Crossplane installed

### Key Demo Points
- Show code reduction: 641 lines → 258 lines (60% less)
- Highlight single file vs 7 files (86% fewer)
- Emphasize built-in workflow with functional tests
- Demonstrate progressive delivery across environments
