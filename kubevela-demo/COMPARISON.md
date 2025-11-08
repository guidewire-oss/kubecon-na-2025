# Imperative vs KubeVela Comparison

## Quick Summary

| Aspect | Imperative | KubeVela | Improvement |
|--------|-------------|----------|-------------|
| **Files per app** | 6 | 1 | 83% fewer |
| **Lines per app** | 746 | 258 | 65% less |
| **Tools** | Terraform + K8s + Dagger (Go) | KubeVela only | Unified |
| **Workflow** | Dagger (306 lines Go) | Built-in YAML | Imperative vs Declarative |
| **Infrastructure** | Separate Terraform (244 lines) | Components | Reusable |
| **API Testing** | In-cluster test pod | Declarative YAML (36 lines) | Simpler |
| **Programming** | Requires Go skills | YAML configuration | Lower barrier |

## Imperative Approach

**Structure:**
```
terraform/           # 244 lines (one-time infrastructure)
  - S3 bucket: tenant-atlantis-product-images-imperative
  - IAM: Role ARN configured via ServiceAccount annotation

k8s/                # 196 lines (per-app deployment)
  - Kubernetes manifests across 5 files

dagger/main.go      # 306 lines (per-app workflow - PRIMARY)
  - Terraform execution
  - Docker build & push
  - Kubernetes deployment
  - Functional API tests (POST + GET in-cluster)
  - Written in Go (imperative code)

deploy.sh           # 40 lines (wrapper with Docker build)
  - Builds and pushes Docker image
  - Loads credentials
  - Calls Dagger pipeline

Total per-app: 746 lines (244 Terraform + 196 K8s + 306 Dagger)
```

**Key Points:**
- Dagger provides portable CI/CD (Go-based imperative workflow)
- Manual coordination between Terraform, K8s, and Dagger
- Separate tools for each concern

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
```

**Key Points:**
- Single unified file (258 lines vs 746 lines traditional = 65% reduction)
- Built-in workflow with approval gates and functional API tests
- Policy-driven environment configuration
- Infrastructure as application components

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

**Traditional:** Duplicate manifests, complex templating (Helm/Kustomize), or CI/CD variables

**KubeVela:** Policy-based overrides
```yaml
policies:
  - name: override-dev
    type: override
    properties:
      components:
        - name: kv-product-cat-api
          traits:
            - type: hpa
              properties:
                minReplicas: 1
                maxReplicas: 3
```

### Workflow and Functional API Testing

**Imperative Approach: Dagger Pipeline**

**dagger/main.go** (306 lines Go) - **PRIMARY workflow solution**
- Full CI/CD pipeline in Go
- Terraform execution
- Docker build & push (coordinated via deploy.sh)
- Kubernetes deployment
- Functional API tests (POST + GET via in-cluster test pod)
- **Implementation**: Test pod with ConfigMap-mounted shell script
- **Testing approach**: kubectl run with script execution inside cluster
- **Requires**: Go programming skills, Dagger CLI

**deploy.sh** (40 lines) - Wrapper with Docker build
- Builds and pushes Docker image to k3d registry
- Loads AWS credentials
- Calls `go run main.go`

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
        url: "http://kv-product-cat-api.dev.svc.cluster.local:8080/products"
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
        url: "http://kv-product-cat-api.dev.svc.cluster.local:8080/products/{{ inputs.productId }}"
        method: "GET"

    # Only proceeds if functional tests pass
    - name: approval-staging
      type: suspend
      dependsOn: ["verify-test-product-dev"]

    # Similar pattern for staging and production...
```

**Comparison:**
- Both test core functionality (POST create + GET verify)
- **Imperative (Dagger)**: In-cluster test pod (Go code)
- **KubeVela**: 36 lines YAML across 3 environments (declarative)
- Workflow halts automatically on failure (status code > 400)

## Resource Naming

To avoid conflicts, the imperative approach uses different names:

| Resource | Imperative | KubeVela |
|----------|-------------|----------|
| S3 Bucket | `tenant-atlantis-product-images-imperative` | `tenant-atlantis-kv-prodcat-images` |
| Image Tag | `v1.0.0-imperative` | `v1.0.0` |
| Deployment | `imp-product-catalog` | `kv-product-cat-api` |
| IAM Role | Role ARN placeholder (injected at deploy) | Crossplane-managed |

## Key Advantages of KubeVela

1. **65% Less Code**: 258 lines vs 746 lines per application
2. **83% Fewer Files**: 1 file vs 6 files to manage per application
3. **Single Source of Truth**: One file for app, infrastructure, deployment, and tests
4. **No External CI/CD**: Built-in workflow engine (no Dagger, no Go code)
5. **Declarative Testing**: YAML-based tests (36 lines) - built-in workflow steps
6. **Data Flow Between Steps**: Captures response data and passes to next step
7. **No Programming Required**: YAML configuration vs Go programming
8. **Reusable Components**: Infrastructure as platform capabilities
9. **Policy-Driven**: DRY principle for multi-environment configs
10. **Kubernetes-Native**: Uses K8s as control plane and state store

## Detailed Line Count Breakdown

### Imperative Approach (Per Application)
- Terraform HCL: 244 lines (infrastructure)
- K8s Manifests: 196 lines (5 files, deployment)
- **Dagger Pipeline: 306 lines** (Go code, workflow & testing)
- Wrapper Scripts: 40 lines (deploy.sh with Docker build)
- **Total: 746 lines** (6 files)

### KubeVela Approach (Per Application)
- Application Definition: 258 lines (1 file, includes everything)
- **Total: 258 lines**

### Code Reduction
- **Lines saved**: 488 lines (65% reduction)
- **Files reduced**: From 6 to 1 (83% reduction)
- **Testing approach**: Built-in workflow steps vs custom test infrastructure
- **Programming**: 0 lines code (KubeVela) vs 306 lines Go (Imperative)

## When to Use Each

**Imperative:** Deep Terraform investment, explicit state management, code-based CI/CD preference

**KubeVela:** Platform engineering, multi-environment progressive delivery, reduced tooling complexity, Kubernetes-native declarative approach

## Cleanup

**Imperative:** `./cleanup.sh` - Custom script (~110 lines) with manual bucket emptying

**KubeVela:** `vela delete kv-product-catalog` - Automatic cleanup via Crossplane
