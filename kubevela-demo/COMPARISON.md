# Traditional vs KubeVela Comparison

## Quick Summary

| Aspect | Traditional | KubeVela | Improvement |
|--------|-------------|----------|-------------|
| **Files per app** | 7 | 1 | 86% fewer |
| **Lines per app** | 641 | 258 | 60% less |
| **Tools** | Terraform + K8s + Bash | KubeVela | Unified |
| **Workflow** | External (260 lines bash) | Built-in with functional tests | Integrated |
| **Infrastructure** | Separate Terraform (243 lines) | Components | Reusable |
| **API Testing** | Bash script (193 lines) | Declarative YAML (12 lines/env) | Built-in |

## Traditional Approach

**Structure:**
```
terraform/           # 243 lines (one-time)
  - S3 bucket: tenant-atlantis-product-images-traditional
  - IAM: Role ARN configured via ServiceAccount annotation

k8s/                # 188 lines (per-app)
  - deployment.yaml: 104 lines
  - hpa.yaml: 44 lines
  - service.yaml: 17 lines
  - configmap.yaml: 12 lines
  - serviceaccount.yaml: 11 lines

deploy-local.sh     # 260 lines (per-app)
  - Deployment automation with integrated API tests
  - POST create + GET verify functional tests

test-api.sh         # 193 lines (per-app)
  - Standalone acceptance test suite
  - 7 comprehensive API tests (health, CRUD operations)

Total per-app: 641 lines (188 K8s + 260 deploy + 193 test)
Optional: 310 lines additional (dagger/main.go for CI/CD pipeline)
```

**Deployment:**
```bash
cd traditional
./deploy-local.sh --cleanup dev
```

**Key Points:**
- Manual coordination between Terraform, Docker, and K8s
- Separate files for each concern
- Environment-specific values require manual updates or templating

## KubeVela Approach

**Structure:**
```
crossplane/          # 192 lines (one-time)
  - composition.yaml: 141 lines
  - xrd.yaml: 51 lines
  - XRD and Composition for S3

components/          # 76 lines (one-time)
  - s3-bucket.cue: 76 lines
  - ComponentDefinition for simple-s3

application.yaml     # 258 lines (per-app)
  - Components: webservice + simple-s3
  - Traits: HPA, SecurityContext, Resources
  - Workflow: dev → staging → prod with functional API tests
  - Policies: Environment-specific overrides
  - Functional testing: POST create + GET verify for each environment
  - 3 test cycles (dev/staging/prod): 12 lines each = 36 lines total testing

Total per-app: 258 lines (everything in one file)
Total one-time: 268 lines (192 Crossplane + 76 ComponentDefinition)
```

**Deployment:**
```bash
vela up -f application.yaml
```

**Key Points:**
- Single file defines everything (258 lines vs 641 lines traditional)
- Built-in workflow with approval gates and functional tests
- Policy-driven environment configuration
- Infrastructure as application components
- **Automated functional API testing** - tests actual business logic (POST/GET)
- 60% less code per application
- 86% fewer files to manage

## Code Examples

### Security Context

**Traditional (k8s/deployment.yaml):**
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault
containers:
  - name: api
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      runAsUser: 1000
      capabilities:
        drop: [ALL]
```

**KubeVela (application.yaml):**
```yaml
traits:
  - type: podsecuritycontext
    properties:
      runAsNonRoot: true
      runAsUser: 1000
      fsGroup: 1000
      seccompProfile:
        type: RuntimeDefault
```

### Multi-Environment Configuration

**Traditional:**
- Duplicate K8s manifests per environment, OR
- Complex templating with Helm/Kustomize, OR
- CI/CD variables and conditionals

**KubeVela:**
```yaml
policies:
  - name: topology-dev
    type: topology
    properties:
      namespace: dev
  - name: override-dev
    type: override
    properties:
      components:
        - name: product-api
          traits:
            - type: hpa
              properties:
                minReplicas: 1
                maxReplicas: 3
```

### Workflow and Functional API Testing

**Traditional Approach Options:**

**Option 1: deploy-local.sh** (260 lines bash)
- Terraform operations
- Docker build
- Deploy to Kubernetes
- Functional API tests (POST + GET)
- **Implementation**: Bash with kubectl + curl

**Option 2: test-api.sh** (193 lines bash)
- Standalone acceptance test suite
- 7 comprehensive tests: health, readiness, list, create, retrieve, delete, verify
- **Implementation**: Bash with kubectl run + curl containers

**Option 3: dagger/main.go** (310 lines Go)
- Full CI/CD pipeline
- Terraform, Docker, Deploy, Test
- **Implementation**: Go code with http.Post() and http.Get()

**KubeVela (application.yaml):** Built-in functional API testing
```yaml
workflow:
  steps:
    - name: deploy-dev
      type: deploy
      properties:
        policies: ["topology-dev", "override-dev"]

    # Test: Create a product via POST
    - name: create-test-product-dev
      type: request
      dependsOn: ["deploy-dev"]
      timeout: "60s"
      properties:
        url: "http://product-api.dev.svc.cluster.local:8080/products"
        method: "POST"
        body:
          name: "workflow-test-product"
          description: "Automated workflow validation test"
          price: 99.99
      outputs:
        - name: productId
          valueFrom: "response.id"  # Capture product ID from response

    # Test: Retrieve the product via GET
    - name: verify-test-product-dev
      type: request
      dependsOn: ["create-test-product-dev"]
      timeout: "60s"
      inputs:
        - from: productId
          parameterKey: ""
      properties:
        url: "http://product-api.dev.svc.cluster.local:8080/products/{{ inputs.productId }}"
        method: "GET"

    # Only proceeds if functional tests pass
    - name: approval-staging
      type: suspend
      dependsOn: ["verify-test-product-dev"]

    # Similar pattern for staging and production...
```

**How it works:**
- Uses built-in `request` workflow step type
- **Tests actual business logic** - not just health endpoints
- POST creates a product, GET retrieves it back
- Validates full CRUD workflow (create + read)
- Passes data between steps using `outputs` and `inputs`
- Workflow **automatically halts** if status code > 400
- **Declarative approach**: Test logic defined in YAML, not code

**Comparison:**
- All approaches test the same core functionality (POST create + GET verify)
- Traditional Bash: 50+ lines per test cycle (imperative)
- Traditional Go: 124 lines for testAPI + waitForAPI (imperative)
- KubeVela: 12 lines per environment test cycle (declarative YAML)
- **KubeVela advantage**: 60% less code, no programming required, declarative approach

## Resource Naming

To avoid conflicts, the traditional approach uses different names:

| Resource | Traditional | KubeVela |
|----------|-------------|----------|
| S3 Bucket | `tenant-atlantis-product-images-traditional` | `tenant-atlantis-product-images` |
| Image Tag | `v1.0.0-traditional` | `v1.0.0` |
| IAM Role | Role ARN placeholder (injected at deploy) | Crossplane-managed |

## Key Advantages of KubeVela

1. **60% Less Code**: 258 lines vs 641 lines per application
2. **86% Fewer Files**: 1 file vs 7 files to manage per application
3. **Single Source of Truth**: One file for app, infrastructure, deployment, and tests
4. **No External CI/CD**: Built-in workflow engine with functional API tests
5. **Declarative Testing**: YAML-based tests vs Bash code (12 vs 50+ lines per test)
6. **Data Flow Between Steps**: Captures response data and passes to next step
7. **No Programming Required**: Platform teams define capabilities, devs just configure
8. **Reusable Components**: Infrastructure as platform capabilities
9. **Policy-Driven**: DRY principle for multi-environment configs
10. **Kubernetes-Native**: Uses K8s as control plane and state store

## Detailed Line Count Breakdown

### Traditional Approach (Per Application)
- K8s Manifests: 188 lines (5 files)
- Deployment Script: 260 lines (deploy-local.sh with tests)
- Test Suite: 193 lines (test-api.sh standalone)
- **Total: 641 lines** (7 files)
- Optional: 310 lines additional (dagger/main.go for CI/CD)

### KubeVela Approach (Per Application)
- Application Definition: 258 lines (1 file, includes everything)
- **Total: 258 lines**

### Code Reduction
- **Lines saved**: 383 lines (60% reduction)
- **Files reduced**: From 7 to 1 (86% reduction)
- **Testing code**: 36 lines (KubeVela) vs 193 lines (Traditional)

## When to Use Each

**Traditional Approach:**
- Team already deeply invested in Terraform
- Need explicit state file management
- Prefer code-based CI/CD (Dagger)
- Simple single-environment deployments

**KubeVela Approach:**
- Platform engineering teams building internal developer platforms
- Multi-environment deployments with progressive delivery
- Want to reduce tooling complexity
- Kubernetes-native workflows preferred

## Cleanup Comparison

### Traditional Approach

**Complete cleanup:**
```bash
cd traditional
./cleanup.sh
```

**What it does:**
- Deletes K8s resources from all environments (dev, staging, prod)
- Empties S3 bucket (required before deletion)
- Runs `terraform destroy` to delete AWS resources
- Removes local Docker images

**Requires:**
- Custom cleanup script (~110 lines)
- AWS CLI to empty bucket
- Terraform for infrastructure deletion
- Manual kubectl commands for K8s cleanup

### KubeVela Approach

**Complete cleanup:**
```bash
vela delete product-catalog
kubectl delete namespace dev staging prod
```

**What it does:**
- Deletes application (all K8s resources automatically)
- Crossplane automatically deletes S3 bucket (even with objects)
- No manual bucket emptying required
- No separate infrastructure cleanup

**Requires:**
- Built-in vela command (0 additional lines)
- Crossplane handles AWS cleanup automatically

### Cleanup Comparison Summary

| Aspect | Traditional | KubeVela | Winner |
|--------|-------------|----------|--------|
| **Command** | `./cleanup.sh` | `vela delete product-catalog` | Tie |
| **Script Required** | Yes (~110 lines) | No (built-in) | **KubeVela** |
| **Bucket Emptying** | Manual (AWS CLI) | Automatic | **KubeVela** |
| **Multi-Environment** | One script handles all | One command handles all | Tie |
| **Error Handling** | Custom logic needed | Built-in | **KubeVela** |
| **Declarative** | Imperative script | Declarative | **KubeVela** |
