# Traditional vs KubeVela Comparison

## Quick Summary

| Aspect | Traditional | KubeVela | Improvement |
|--------|-------------|----------|-------------|
| **Files per app** | 6 | 1 | 83% fewer |
| **Lines per app** | 498 | 255 | 49% less |
| **Tools** | Terraform + K8s + Dagger | KubeVela | Unified |
| **Workflow** | External (310 lines) | Built-in with functional tests | Integrated |
| **Infrastructure** | Separate Terraform | Components | Reusable |
| **API Testing** | Imperative Go code | Declarative YAML | Built-in |

## Traditional Approach

**Structure:**
```
terraform/     # 223 lines (one-time)
  - S3 bucket: tenant-atlantis-product-images-traditional
  - IAM: Role ARN configured via ServiceAccount annotation

k8s/          # 188 lines (per-app)
  - ServiceAccount, ConfigMap, Deployment, Service, HPA
  - Image: product-catalog-api:v1.0.0-traditional

dagger/       # 310 lines (per-app)
  - main.go: CI/CD pipeline in Go with functional API tests
  - Portable across CI systems

deploy-local.sh  # Local deployment script
```

**Deployment:**
```bash
./deploy-local.sh --cleanup dev
```

**Key Points:**
- Manual coordination between Terraform, Docker, and K8s
- Separate files for each concern
- Environment-specific values require manual updates or templating

## KubeVela Approach

**Structure:**
```
crossplane/    # 269 lines (one-time)
  - XRD and Composition for S3

components/    # 76 lines (one-time)
  - ComponentDefinition for simple-s3

application.yaml  # 255 lines (per-app)
  - Components: webservice + simple-s3
  - Traits: HPA, SecurityContext, Resources
  - Workflow: dev → staging → prod with functional API tests
  - Policies: Environment-specific overrides
  - Functional testing: POST create + GET verify between environments
```

**Deployment:**
```bash
vela up -f application.yaml
```

**Key Points:**
- Single file defines everything
- Built-in workflow with approval gates and functional tests
- Policy-driven environment configuration
- Infrastructure as application components
- **Automated functional API testing** - tests actual business logic (POST/GET)

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

**Traditional (dagger/main.go):** 310 lines
- Terraform operations
- Docker build
- Deploy to dev with functional API tests (POST + GET)
- Deploy to staging (if needed)
- Deploy to prod (if needed)
- **Implementation**: Go code with http.Post() and http.Get() for testing

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
- Both approaches test the same functionality (POST + GET)
- Traditional: Imperative Go code (124 lines for testAPI + waitForAPI)
- KubeVela: Declarative YAML (12 lines per environment test)
- KubeVela advantage: Less code, no programming required

## Resource Naming

To avoid conflicts, the traditional approach uses different names:

| Resource | Traditional | KubeVela |
|----------|-------------|----------|
| S3 Bucket | `tenant-atlantis-product-images-traditional` | `tenant-atlantis-product-images` |
| Image Tag | `v1.0.0-traditional` | `v1.0.0` |
| IAM Role | Role ARN placeholder (injected at deploy) | Crossplane-managed |

## Key Advantages of KubeVela

1. **Single Source of Truth**: One file for app, infrastructure, and deployment
2. **No External CI/CD**: Built-in workflow engine with functional API tests
3. **Declarative Testing**: YAML-based tests vs Go code (12 vs 124 lines per test)
4. **Data Flow Between Steps**: Captures response data and passes to next step
5. **No Programming Required**: Platform teams define capabilities, devs just configure
6. **Reusable Components**: Infrastructure as platform capabilities
7. **Policy-Driven**: DRY principle for multi-environment configs
8. **Kubernetes-Native**: Uses K8s as control plane and state store

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
