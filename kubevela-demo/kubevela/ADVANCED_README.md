# Advanced KubeVela S3 Bucket Application

This directory demonstrates an advanced KubeVela application pattern that showcases:
- **Infrastructure-as-Code with Crossplane** for S3 bucket provisioning
- **Data passing between components** using outputs/inputs
- **Multi-environment deployment** with environment-specific overrides
- **Progressive delivery workflow** with approval gates

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  KubeVela Application                       │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐         ┌─────────────────────────┐  │
│  │  S3 Bucket       │ outputs │  Webservice             │  │
│  │  (simple-s3)     ├────────>│  (kv-product-cat-api)   │  │
│  │                  │ inputs  │                         │  │
│  │  - bucketArn     │────────>│  ENV: S3_BUCKET_ARN     │  │
│  │  - bucketName    │────────>│  ENV: S3_BUCKET_NAME    │  │
│  │  - bucketRegion  │────────>│  ENV: AWS_REGION        │  │
│  └──────────────────┘         └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
    ┌───▼────┐          ┌─────▼──────┐      ┌──────▼────┐
    │  dev   │          │  staging   │      │   prod    │
    │        │          │            │      │           │
    │ app-   │          │ app-       │      │ app-      │
    │ storage│          │ storage-   │      │ storage-  │
    │ -dev   │          │ staging    │      │ prod      │
    └────────┘          └────────────┘      └───────────┘
```

## Key Features

### 1. **Component Data Flow**

The S3 bucket component declares outputs that are automatically passed to the webservice:

```yaml
outputs:
  - name: bucketArn
    valueFrom: output.status.bucketArn

inputs:
  - from: bucketArn
    parameterKey: env[0].value  # Maps to S3_BUCKET_ARN env var
```

This ensures the application always receives the correct bucket information without hardcoding.

### 2. **Environment-Specific Overrides**

Each environment gets its own S3 bucket with different configurations:

| Environment | Bucket Name                        | Region    | Replicas | Versioning |
|-------------|-----------------------------------|-----------|----------|------------|
| dev         | tenant-atlantis-app-storage-dev   | us-west-2 | 1-3      | false      |
| staging     | tenant-atlantis-app-storage-staging| us-west-2 | 2-5      | false      |
| prod        | tenant-atlantis-app-storage-prod  | us-east-1 | 3-10     | true       |

Override policies modify component properties per environment without duplicating the entire application spec.

### 3. **Progressive Delivery Workflow**

The workflow orchestrates deployment across environments with dependencies:

```
┌─────────────────────────────────────────────────────────────┐
│ Dev Environment                                             │
├─────────────────────────────────────────────────────────────┤
│ 1. Deploy S3 Bucket (dev)                                   │
│ 2. Wait for bucket ready                                    │
│ 3. Deploy Application (dev) ◄── Bucket ARN passed via input│
│ 4. Health Check (dev)                                       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. Manual Approval Gate (staging) ⏸️                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ Staging Environment                                         │
├─────────────────────────────────────────────────────────────┤
│ 6. Deploy S3 Bucket (staging)                               │
│ 7. Wait for bucket ready                                    │
│ 8. Deploy Application (staging)                             │
│ 9. Health Check (staging)                                   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 10. Manual Approval Gate (prod) ⏸️                          │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ Production Environment                                      │
├─────────────────────────────────────────────────────────────┤
│ 11. Deploy S3 Bucket (prod)                                 │
│ 12. Wait for bucket ready                                   │
│ 13. Deploy Application (prod)                               │
│ 14. Health Check (prod)                                     │
└─────────────────────────────────────────────────────────────┘
```

**Key workflow features:**
- Buckets are created before applications in each environment
- Wait steps ensure buckets are ready before apps deploy
- Manual approval gates prevent automatic promotion
- Health checks validate each deployment

## Files

### Application Definition
- **`s3-bucket-app.yaml`** - Main KubeVela application with multi-environment configuration

### Crossplane Resources
- **`crossplane/s3/xrd.yaml`** - Custom Resource Definition for S3 buckets
- **`crossplane/s3/composition.yaml`** - Implementation of S3 bucket provisioning

### Component Definitions
- **`components/s3/s3-bucket-base.cue`** - Direct S3 component (Crossplane AWS provider)
- **`components/s3/s3-bucket.cue`** - `simple-s3` component (XRD-based, recommended)
- **`components/s3/s3-versioning-trait.cue`** - Trait to enable S3 versioning

### Deployment
- **`deploy-s3-app.sh`** - Automated deployment script

## Quick Start

### 1. Deploy the Application

```bash
./deploy-s3-app.sh
```

This script:
1. Builds and pushes the Docker image to k3d registry
2. Applies Crossplane XRD and Composition
3. Loads component and trait definitions
4. Creates environment namespaces (dev/staging/prod)
5. Deploys the application

### 2. Monitor Deployment

```bash
# Check application status
vela status s3-storage-app

# Check detailed workflow status
vela status s3-storage-app --detail

# Watch workflow progress
watch vela status s3-storage-app
```

### 3. Approve Staging Deployment

Once dev deployment succeeds and health checks pass:

```bash
vela workflow resume s3-storage-app --step approval-staging
```

### 4. Approve Production Deployment

Once staging deployment succeeds:

```bash
vela workflow resume s3-storage-app --step approval-prod
```

## Component Types

### `simple-s3` (Recommended)

Uses Crossplane XRD/Composition pattern for declarative S3 bucket management:

```yaml
- name: my-bucket
  type: simple-s3
  properties:
    name: my-app-data        # Prefixed with tenant-atlantis-
    region: us-west-2
    versioning: true
  outputs:
    - name: bucketArn
      valueFrom: output.status.bucketArn
```

**Advantages:**
- Declarative API with custom resource
- Automatic tenant prefixing
- Standardized tags and governance
- Works with limited IAM permissions

### `s3-bucket` (Direct)

Directly provisions S3 buckets via Crossplane AWS provider:

```yaml
- name: my-bucket
  type: s3-bucket
  properties:
    region: us-west-2
    bucketName: my-bucket
    providerConfigRef: default
```

**Use when:**
- You need direct access to all S3 API parameters
- You have full IAM permissions
- You want maximum flexibility

## Environment Overrides

Override policies modify components per environment:

```yaml
policies:
  - name: override-staging
    type: override
    properties:
      components:
        - name: app-storage-bucket
          properties:
            name: app-storage-staging  # Different bucket name
            region: us-west-2
        - name: storage-api
          traits:
            - type: hpa
              properties:
                min: 2
                max: 5
```

**Override capabilities:**
- Component properties (bucket names, regions, etc.)
- Trait configurations (HPA, resources, security)
- Environment-specific settings without duplication

## Troubleshooting

### Bucket Creation Fails

If using `s3-bucket` component:
```
Error: User is not authorized to perform: s3:CreateBucket
```

**Solution:** Use `simple-s3` component instead, which uses Crossplane Composition with proper IAM roles.

### Application Can't Find Bucket

Check that outputs/inputs are properly configured:

```bash
# Check if bucket exists
kubectl get xs3bucket -A

# Check component outputs
kubectl get application s3-storage-app -n default -o yaml | grep -A 10 outputs

# Check component status
kubectl get xs3bucket -n dev -o yaml
```

### Workflow Stuck on Approval

Resume the workflow manually:

```bash
# List suspended workflows
vela workflow suspend s3-storage-app

# Resume at specific step
vela workflow resume s3-storage-app --step approval-staging
```

## Advanced Patterns

### Adding More Environments

1. Add topology policy:
```yaml
- name: topology-qa
  type: topology
  properties:
    clusters: ["local"]
    namespace: qa
```

2. Add override policy:
```yaml
- name: override-qa
  type: override
  properties:
    components:
      - name: app-storage-bucket
        properties:
          name: app-storage-qa
```

3. Add workflow steps:
```yaml
- name: deploy-bucket-qa
  type: deploy
  properties:
    policies: ["topology-qa", "override-qa"]
```

### Multi-Region Deployment

Override the region in production:

```yaml
- name: override-prod
  type: override
  properties:
    components:
      - name: app-storage-bucket
        properties:
          name: app-storage-prod
          region: us-east-1  # Different region
```

### Custom Bucket Tags

Add environment-specific tags:

```yaml
- name: app-storage-bucket
  type: simple-s3
  properties:
    name: app-storage
    region: us-west-2
    tags:
      Environment: dev
      CostCenter: engineering
```

## Comparison with Simple Application

| Feature | Simple App (`application.yaml`) | Advanced App (`s3-bucket-app.yaml`) |
|---------|--------------------------------|-------------------------------------|
| S3 Creation | Pre-existing bucket | Dynamic per environment |
| Data Passing | Hardcoded bucket name | Outputs/Inputs pattern |
| Environments | 3 (dev/staging/prod) | 3 with different buckets |
| Bucket Config | Single shared bucket | Isolated per environment |
| Workflow | Progressive with tests | Progressive with infrastructure |
| Complexity | Moderate | Advanced |

## References

- [KubeVela Multi-Environment](https://kubevela.io/docs/case-studies/multi-cluster/)
- [Crossplane Compositions](https://docs.crossplane.io/latest/concepts/compositions/)
- [Component Outputs/Inputs](https://kubevela.io/docs/end-user/workflow/component-dependency-parameter/)
- [Override Policies](https://kubevela.io/docs/end-user/policies/references#override)
