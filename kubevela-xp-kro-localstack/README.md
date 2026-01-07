# KubeVela + Crossplane/KRO + LocalStack Demo

Simple DynamoDB demo using LocalStack - **No AWS account required!**

A practical demonstration using LocalStack (AWS emulation) to compare Crossplane and KRO (Kube Resource Orchestrator) for managing DynamoDB tables through KubeVela's OAM abstraction layer.

## Overview

This demo showcases two infrastructure engines for provisioning and managing DynamoDB tables locally via LocalStack:

1. **Crossplane** - Infrastructure-as-code via Upbound AWS provider
2. **KRO + ACK** - Kubernetes-native resource orchestration

Both work with LocalStack for development and testing - **no AWS credentials required!**

## Quick Start (3 Steps)

### 1. Run Setup
```bash
./setup.sh
```
Automatically sets up k3d cluster, KubeVela, Crossplane, KRO, ACK, and LocalStack.

### 2. Deploy Example App
```bash
KUBECONFIG=./kubeconfig-internal vela up -f definitions/examples/session-api-app-kro.yaml
```
Creates a DynamoDB table + Flask session API (KRO version). Use `session-api-app-xp.yaml` for Crossplane.

### 3. Check Status
```bash
./check-dynamodb-tables.sh
```

That's it! Your table is running in LocalStack. No AWS account needed.

## Troubleshooting Tables Not Created

If `./check-dynamodb-tables.sh` shows no tables despite successful setup:

### Quick Debugging (5 minutes)
```bash
# See complete system state and what's broken
./debug-resources.sh

# Test table creation manually
./test-manual-table-creation.sh
```

### Full Debugging Guide
See **`DEBUGGING.md`** for:
- 3-step debugging workflow
- Decision tree to identify issue
- Quick fixes for common scenarios
- Complete troubleshooting reference with all commands and logs
- System architecture and data flow in `ARCHITECTURE.md`

## Key Differences vs AWS Demo

| Feature | AWS Demo | LocalStack Demo |
|---------|----------|-----------------|
| AWS Account | Required | ❌ Not needed |
| Cost | $ per operation | Free |
| Table Names | `tenant-atlantis-*` prefix | Any name |
| Speed | API latency | Instant |

### 🌐 Multi-Cloud Landscape: KRO vs Crossplane

**KRO (Kube Resource Orchestrator)** is no longer AWS-only! As of December 2025, KRO supports multi-cloud infrastructure through integration with cloud-specific Kubernetes operators:

| Cloud Provider | Kubernetes Controller | KRO Support Status | Examples Available |
|----------------|----------------------|-------------------|-------------------|
| **AWS** | ACK (AWS Controllers for Kubernetes) | ✅ **Production Integration** | ✅ Yes (this demo) |
| **GCP** | KCC (Kubernetes Config Connector) | ✅ **Documented & Examples** | ✅ Yes ([kro.run/examples/gcp](https://kro.run/examples/gcp/gke-cluster/)) |
| **Azure** | ASO (Azure Service Operator) | ✅ **Documented & Examples** | ✅ Yes (GitOps patterns) |

**Key Insight**: KRO provides a **unified orchestration layer** that works with any Kubernetes CRDs, including those from ACK, KCC, ASO, or Crossplane itself. This makes KRO complementary to—not competitive with—these tools.

#### KRO's Multi-Cloud Architecture

KRO is a **collaboration between AWS, Google Cloud, and Microsoft** (announced January 2025), designed to be cloud-agnostic at the orchestration level:

- **KRO Layer**: Defines ResourceGraphDefinitions (abstractions) that orchestrate resources
- **Controller Layer**: Cloud-specific operators (ACK, KCC, ASO) that manage actual cloud resources
- **Result**: Unified developer experience across multiple clouds

#### Crossplane is Not the Only Game in Town Anymore

**Before KRO (2024)**:
- Crossplane was the dominant multi-cloud abstraction tool
- Single provider for unified cloud resource management
- Opinionated approach to infrastructure composition

**With KRO (December 2025)**:
- **Multiple orchestration options**: KRO provides an alternative approach
- **Different philosophy**: KRO orchestrates ANY Kubernetes resources (native + CRDs), while Crossplane focuses on cloud resources
- **Complementary tools**: KRO can orchestrate Crossplane resources too!
- **Status**: KRO still alpha (v1alpha1), Crossplane production-ready

**Current Reality**: Organizations now have choices:
1. **Crossplane alone** - Mature, production-ready, opinionated
2. **KRO + Cloud Operators** - Flexible, Kubernetes-native, multi-cloud (experimental)
3. **Both together** - KRO orchestrating Crossplane compositions (advanced pattern)

For production workloads today, Crossplane remains the safer choice. For innovation and Kubernetes-native approaches, KRO shows significant promise as it matures.

### 🎯 **NEW: Simplified KRO Component**

Now includes **`aws-dynamodb-kro-simplified`** - a trait-first component that matches the Crossplane interface exactly, making it easy to migrate between providers or maintain consistent interfaces across your infrastructure!

## What's Included

### Infrastructure Components

- **k3d Kubernetes Cluster** (1 server, 2 agents)
- **KubeVela** - Application platform with OAM
- **Crossplane** + AWS DynamoDB Provider
- **KRO** (Kube Resource Orchestrator) + RBAC fixes
- **ACK** (AWS Controllers for Kubernetes) DynamoDB controller
- **2 ResourceGraphDefinitions** for KRO (advanced + simple)

### Component Definitions

1. **aws-dynamodb-xp** - Crossplane-based DynamoDB component (minimal interface, traits for features)
2. **aws-dynamodb-kro** - KRO-based advanced component (full AWS API, inline or traits)
3. **aws-dynamodb-kro-simplified** - 🆕 KRO-based simplified component (matches Crossplane interface)
4. **aws-dynamodb-simple-kro** - KRO-based basic component (pre-configured simple tables)

### Sample Applications

**Crossplane Examples:**
- Basic table with partition key
- Table with DynamoDB Streams
- Production table with full configuration
- Session management API (Flask + Crossplane DynamoDB)

**KRO Examples:**
- Basic table via KRO + ACK
- Session table with modular traits
- Production table with full traits stack
- Cache table with TTL auto-expiration
- Simple basic table (SimpleDynamoDB RGD)
- 🆕 Simplified component examples (basic + with traits)
- Session management API (Flask + KRO DynamoDB)

### Demo Application

**Session Management API** - A Flask REST API for managing user sessions with automatic expiration:
- **Two versions**: One using KRO DynamoDB, one using Crossplane DynamoDB
- CRUD operations for sessions
- Automatic TTL-based expiration
- Health and readiness probes
- 2 replicas for high availability

## Quick Start

### Prerequisites

Required tools:
- `k3d` - Kubernetes in Docker
- `kubectl` - Kubernetes CLI
- `helm` - Helm package manager
- `vela` - KubeVela CLI
- `docker` - For building demo app

> **🔧 DevContainer Users**: After running `setup.sh` or restarting the cluster, you **must** update `kubeconfig-internal` with the new k3d API server port. See **[CLAUDE.md](CLAUDE.md)** section "Fix kubeconfig-internal After Cluster Restart" for the quick 30-second fix and full troubleshooting guide.

### One-Command Setup

```bash
./setup.sh
```

This automated script will:
1. Create k3d cluster
2. Install KubeVela
3. Install Crossplane + AWS Provider
4. Install KRO + ACK DynamoDB controller
5. Deploy KRO RBAC fixes and ResourceGraphDefinitions
6. Copy AWS credentials to default namespace
7. Deploy all component definitions and traits
8. Deploy sample applications (Crossplane + KRO)
9. Build and deploy session management apps

### AWS Credentials

Create `../.env.aws` with your credentials:

```bash
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_DEFAULT_REGION=us-west-2
```

**Important**: The IAM user must have specific DynamoDB permissions. See **[IAM_POLICY.md](IAM_POLICY.md)** for the complete minimal IAM policy required.

**Key Requirements**:
- Table names must start with `tenant-atlantis-` prefix (automatically added by components)
- Permissions scoped to `us-west-2` region
- Includes: CreateTable, DescribeTable, UpdateTable, DeleteTable, and feature-specific actions
- See [IAM_POLICY.md](IAM_POLICY.md) for full policy and setup instructions

**🔒 Automatic Table Name Prefix**: All component definitions automatically prepend `tenant-atlantis-` to table names for IAM policy compliance. You only need to specify the base table name.

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│ KubeVela Application (OAM)                               │
│ - Consistent API for developers                         │
│ - Component + Traits abstraction                        │
└───────────────────┬──────────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
        ▼                       ▼
┌──────────────┐        ┌──────────────┐
│ Crossplane   │        │ KRO + ACK    │
│ Provider     │        │ Controllers  │
└──────┬───────┘        └──────┬───────┘
       │                       │
       ▼                       ▼
┌──────────────────────────────────────┐
│ AWS DynamoDB Tables                  │
│ - Created and managed via K8s CRDs   │
│ - Declarative configuration          │
└──────────────────────────────────────┘
```

## Key Differences

| Feature | Crossplane | KRO + ACK | KRO Simplified 🆕 |
|---------|-----------|-----------|------------------|
| **Maturity** | Production-ready | Experimental (alpha) | Experimental (alpha) |
| **Cloud Support** | Multi-cloud (built-in) | Multi-cloud (via ACK/KCC/ASO) | Multi-cloud (via ACK/KCC/ASO) |
| **Resource Adoption** | ✅ managementPolicy | ✅ AdoptedResource CRD | ✅ AdoptedResource CRD |
| **API Style** | Minimal/opinionated | Full AWS API | Minimal/opinionated |
| **Configuration** | Traits only | Inline or traits | Traits only |
| **Resource Management** | Provider-managed | Operator-managed (ACK/KCC/ASO) | Operator-managed (ACK/KCC/ASO) |
| **Traits Support** | Yes (7 traits) | Yes (7 traits) | Yes (7 traits) |
| **Type Safety** | ✅ Strict enums | ⚠️ Looser types | ✅ Strict enums |
| **Learning Curve** | Moderate | Requires K8s + Cloud knowledge | Moderate |
| **Vendor Backing** | CNCF community | AWS + Google + Microsoft | AWS + Google + Microsoft |
| **Best For** | Production multi-cloud today | Kubernetes-native future, experimentation | XP-to-KRO migration path |

## Component Comparison

### 1. Crossplane Component (aws-dynamodb-xp)

**Interface:** Minimal - traits required for advanced features

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
spec:
  components:
    - name: my-table
      type: aws-dynamodb-xp
      properties:
        region: us-west-2
        attributeDefinitions:
          - attributeName: id
            attributeType: "S"
        keySchema:
          - attributeName: id
            keyType: HASH
```

### 2. KRO Simplified Component (aws-dynamodb-kro-simplified) 🆕

**Interface:** Minimal - matches Crossplane exactly, traits required for advanced features

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
spec:
  components:
    - name: my-table
      type: aws-dynamodb-kro-simplified
      properties:
        tableName: my-table
        region: us-west-2
        attributeDefinitions:
          - attributeName: id
            attributeType: "S"
        keySchema:
          - attributeName: id
            keyType: HASH
```

**Migration Tip:** Simply change `type: aws-dynamodb-xp` to `type: aws-dynamodb-kro-simplified` - parameters are identical!

### 3. KRO Full Component (aws-dynamodb-kro)

**Interface:** Complete - all AWS DynamoDB features available inline or via traits

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
spec:
  components:
    - name: my-table
      type: aws-dynamodb-kro
      properties:
        tableName: my-table
        region: us-west-2
        attributeDefinitions:
          - attributeName: id
            attributeType: "S"
        keySchema:
          - attributeName: id
            keyType: HASH
        # Can configure features inline
        ttlEnabled: true
        ttlAttributeName: expiresAt
        streamEnabled: true
        streamViewType: KEYS_ONLY
```

### 4. KRO Simple Component (aws-dynamodb-simple-kro)

**Interface:** Pre-configured - for quick table creation with sensible defaults

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
spec:
  components:
    - name: my-table
      type: aws-dynamodb-simple-kro
      properties:
        tableName: my-table
        region: us-west-2
```

**Note**: Creates a table with a default `id` (String) partition key and PAY_PER_REQUEST billing.

## Verification Commands

```bash
# Check all applications (recommended - shows all apps)
vela ls -A

# Check specific application status
vela status dynamodb-basic-xp
vela status session-management
vela status session-management-simple
vela status session-management-xp

# Check via kubectl
kubectl get applications.core.oam.dev -A

# Check Crossplane resources
kubectl get table.dynamodb.aws.upbound.io -A

# Check KRO resources
kubectl get resourcegraphdefinition
kubectl get dynamodbtable        # Advanced tables
kubectl get simpledynamodb       # Simple tables
kubectl get table.dynamodb.services.k8s.aws -A

# Check demo applications
vela status session-management       # KRO version
vela status session-management-xp    # Crossplane version
kubectl get pods -l app.oam.dev/component=session-api
kubectl get pods -l app.oam.dev/component=session-api-xp
```

## Testing the Demo Application

### Access the Session API (KRO version)

```bash
# Port forward to the service
kubectl port-forward svc/session-api 8080:8080

# Health check
curl http://localhost:8080/health

# Create a session
curl -X POST http://localhost:8080/sessions \
  -H 'Content-Type: application/json' \
  -d '{"userId":"user123","data":{"theme":"dark"}}'

# Get session
curl http://localhost:8080/sessions/SESSION_ID

# List all sessions
curl http://localhost:8080/sessions
```

### Access the Session API (Crossplane version)

```bash
# Port forward to the service
kubectl port-forward svc/session-api-xp 8081:8080

# Same API endpoints on port 8081
curl http://localhost:8081/health
```

## Available Traits

### Crossplane Traits

- `dynamodb-ttl-xp` - Time-to-Live configuration
- `dynamodb-streams-xp` - DynamoDB Streams
- `dynamodb-encryption-xp` - Server-side encryption
- `dynamodb-protection-xp` - Deletion protection + PITR
- `dynamodb-provisioned-capacity-xp` - Provisioned billing mode
- `dynamodb-global-index-xp` - Global secondary indexes
- `dynamodb-local-index-xp` - Local secondary indexes

### KRO Traits (works with both `aws-dynamodb-kro` and `aws-dynamodb-kro-simplified`)

- `dynamodb-ttl-kro` - Time-to-Live configuration
- `dynamodb-streams-kro` - DynamoDB Streams
- `dynamodb-encryption-kro` - Server-side encryption
- `dynamodb-protection-kro` - Deletion protection + PITR
- `dynamodb-provisioned-capacity-kro` - Provisioned billing mode
- `dynamodb-global-index-kro` - 🆕 Global secondary indexes
- `dynamodb-local-index-kro` - 🆕 Local secondary indexes

## Troubleshooting

### Issue: Applications stuck in "runningWorkflow"

**Check KRO controller logs:**
```bash
kubectl logs -n kro-system -l app.kubernetes.io/name=kro --tail=50
```

**Check ACK controller logs:**
```bash
kubectl logs -n ack-system -l app.kubernetes.io/name=dynamodb-chart --tail=50
```

### Issue: "Secret not found" errors for applications

**Verify credentials are copied to default namespace:**
```bash
kubectl get secret -n default | grep -E 'ack-dynamodb|aws-credentials'
```

**Re-run credential copy:**
```bash
# KRO credentials
kubectl get secret ack-dynamodb-user-secrets -n ack-system -o yaml | \
  sed 's/namespace: ack-system/namespace: default/' | \
  kubectl apply -f -

# Crossplane credentials
kubectl get secret aws-credentials -n crossplane-system -o yaml | \
  sed 's/namespace: crossplane-system/namespace: default/' | \
  sed 's/name: aws-credentials/name: aws-credentials-xp/' | \
  kubectl apply -f -
```

### Issue: KRO RBAC permissions

**KRO needs special permissions to manage dynamic CRDs:**
```bash
kubectl apply -f kro-rbac-fix.yaml
kubectl rollout restart deployment/kro -n kro-system
```

### Issue: Table names require specific prefix

**For the demo app, tables must start with `tenant-atlantis-`:**
- Edit the application YAML files
- Update `DYNAMODB_TABLE_NAME` environment variable
- Or adjust your IAM policy to allow the desired table names

### Issue: Kubeconfig no longer works after cluster restart (DevContainer)

**Problem**: After restarting the k3d cluster with `./setup.sh`, kubectl commands fail with connection errors like:
```
error: Unable to connect to the server: dial tcp [::1]:8080: connect: connection refused
```

**Root Cause**: When k3d recreates the cluster, the API server endpoint and port change, but the `kubeconfig-internal` file still contains old connection details.

**Solution for DevContainer Users**:

The `kubeconfig-internal` file is used to connect from the devcontainer to the k3d cluster running on the host. When the cluster restarts, you need to update these key fields in `kubeconfig-internal`:

#### Step 1: Check the new cluster endpoint

After rerunning `setup.sh`, the k3d cluster is recreated with a new API server port. Get the new port:

```bash
# Check which port k3d is using (usually in the 5xxxx range)
docker port k3d-kubevela-demo-server-0 | grep 6443
```

This will output something like: `6443/tcp -> 0.0.0.0:58991`

The number after `->` is your new port (e.g., `58991`).

#### Step 2: Update kubeconfig-internal

Edit `kubeconfig-internal` and update these fields:

```yaml
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://host.docker.internal:<NEW_PORT>  # ← Update the port number
  name: k3d-kubevela-demo
```

**Important**:
- Use `host.docker.internal` as the hostname (not localhost or IP addresses) - this resolves correctly from the devcontainer
- Always use `insecure-skip-tls-verify: true` - this prevents certificate validation issues
- Do NOT update the client certificates or keys - they are container-internal and don't need to change

#### Step 3: Verify connectivity

```bash
KUBECONFIG=/workspaces/workspace/kubecon-na-2025/kubevela-xp-kro-ktix-demo/kubeconfig-internal kubectl get nodes
```

If successful, you'll see the k3d cluster nodes.

#### Alternative: Regenerate kubeconfig from scratch

If updating the port doesn't work, regenerate the kubeconfig:

```bash
# Export kubeconfig from k3d with insecure mode
k3d kubeconfig get kubevela-demo > kubeconfig-internal-temp

# Manually edit to use host.docker.internal
sed -i 's/0\.0\.0\.0/host.docker.internal/g' kubeconfig-internal-temp

# Add insecure-skip-tls-verify flag
sed -i '/server: https/a\    insecure-skip-tls-verify: true' kubeconfig-internal-temp

# Replace the old file
mv kubeconfig-internal-temp kubeconfig-internal
```

#### Common Issues

**Issue**: `dial tcp: lookup host.docker.internal: no such host`
- **Solution**: You're not running in a devcontainer. Use `localhost` or the actual k3d server IP instead.

**Issue**: `certificate signed by unknown authority`
- **Solution**: Add `insecure-skip-tls-verify: true` to the cluster config in kubeconfig.

**Issue**: Connection times out
- **Solution**: Verify the port number is correct: `docker port k3d-kubevela-demo-server-0 | grep 6443`

### Issue: Applications not showing in VelaUX UI

**VelaUX may not show all applications immediately:**
- VelaUX was designed to show applications created through its API/UI
- Applications created with `vela up` or `kubectl apply` exist in Kubernetes
- Use `vela ls -A` to see ALL applications regardless of VelaUX
- VelaUX caching or project filtering may hide some applications
- All applications are fully functional even if not visible in VelaUX UI

## Documentation

### For AI Assistants

- **[CLAUDE.md](CLAUDE.md)** - Project-specific instructions for AI assistants (DevContainer setup, kubeconfig management, component patterns, common issues)

### DevContainer Setup (Important!)

**DevContainer users**: See **[CLAUDE.md](CLAUDE.md)** section "DevContainer & Kubeconfig Management" for:
- **Quick Fix** (30 seconds): One-liner to update kubeconfig after cluster restart
- **Complete Reference**: DevContainer setup, kubeconfig management, and troubleshooting

### Component & Trait Documentation
- **[aws-dynamodb-xp.md](definitions/components/aws-dynamodb-xp.md)** - Crossplane component reference
- **[aws-dynamodb-kro.md](definitions/components/aws-dynamodb-kro.md)** - KRO component reference
- **[definitions/traits/DYNAMODB-KRO-TRAITS-README.md](definitions/traits/DYNAMODB-KRO-TRAITS-README.md)** - Available traits and their usage

### Additional Documentation
- **[CHANGELOG.md](CHANGELOG.md)** - Version history and notable fixes
- **[IAM_POLICY.md](IAM_POLICY.md)** - AWS IAM policy requirements for the demo
- **[app/README.md](app/README.md)** - Session management API documentation

## Cleanup

```bash
# Delete all applications
kubectl delete applications.core.oam.dev --all

# Delete the cluster
k3d cluster delete kubevela-demo
```

## Project Structure

```
.
├── setup.sh                          # Automated setup script
├── kro-rbac-fix.yaml                 # KRO RBAC permissions fix
├── app/                              # Session management demo app
│   ├── session-api.py                # Flask application
│   ├── Dockerfile                    # Container definition
│   ├── requirements.txt              # Python dependencies
│   └── README.md                     # App documentation
├── definitions/
│   ├── components/                   # Component definitions
│   │   ├── aws-dynamodb-xp.cue       # Crossplane component
│   │   ├── aws-dynamodb-kro.cue      # KRO full component
│   │   ├── aws-dynamodb-kro-simplified.cue # 🆕 KRO simplified component
│   │   └── aws-dynamodb-simple-kro.cue # KRO simple component
│   ├── traits/                       # Trait definitions
│   │   ├── *-xp.cue                  # Crossplane traits (7 traits)
│   │   └── *-kro.cue                 # KRO traits (7 traits, 2 new)
│   ├── kro/                          # KRO ResourceGraphDefinitions
│   │   ├── dynamodb-rgd.yaml         # Advanced RGD
│   │   └── simple-dynamodb-rgd.yaml  # Simple RGD
│   └── examples/
│       ├── dynamodb-xp/              # Crossplane examples
│       ├── dynamodb-kro/             # KRO examples (includes simplified)
│       ├── session-management-app-kro.yaml     # KRO app
│       └── session-management-app-xp.yaml      # Crossplane app
└── README.md                         # This file
```

## Contributing

This is a demo project for KubeCon NA 2025. For issues or suggestions, please create an issue or pull request.

## License

This project is provided as-is for educational and demonstration purposes.

---

## Recent Updates

### 2025-12-29 🎉

**🔧 Critical Fixes for KRO + ACK Integration**
- **Fixed region configuration**: Changed from `kro.run/region` to `services.k8s.aws/region` annotation (ACK standard)
- **Fixed optional field handling**: Added CEL optional operator (`?`) for status fields that may not exist
- **Fixed AWS API validation**: Completely removed optional feature specifications when disabled (streams, encryption, PITR, TTL)
- **Fixed health checks**: Updated component definition to check for `state == "ACTIVE"` instead of `state == "Ready"`
- **Fixed IAM compatibility**: Updated all examples to use `us-west-2` region and `tenant-atlantis-` table name prefix
- **Removed secondary indexes from RGD**: KRO doesn't support complex nested arrays in schema

**✅ What's Working Now**
- ✅ AWS DynamoDB table creation via ACK
- ✅ KRO ResourceGraphDefinition creating custom DynamoDBTable CRD
- ✅ KubeVela component definitions with health checks
- ✅ KubeVela traits for DynamoDB features (TTL, Streams, Encryption)
- ✅ All applications showing as healthy with workflows completed

**⚠️ Known Limitations**
- KRO's `Ready` condition shows "Unknown" (KRO implementation detail, doesn't affect functionality)
- Global and local secondary indexes not supported in RGD (complex nested arrays)
- Traits must be used for all optional features to avoid AWS API validation errors

---

## Multi-Cloud Support Deep Dive

### KRO's Multi-Cloud Journey (2024-2025)

**Initial Release (2024)**: KRO started as an AWS-focused project with deep ACK integration.

**Major Milestone (January 2025)**: KRO became an **open collaboration** between AWS, Google Cloud, and Microsoft Azure, transitioning from `kubernetes-sigs/kro` repository.

**Current Status (December 2025)**:
- **Alpha Release**: v1alpha1 API (experimental, not production-ready)
- **Multi-Cloud Ready**: Documented integration patterns for AWS, GCP, and Azure
- **Active Development**: Real-time drift detection, improved validation, community growth

### Cloud Provider Integration Status

#### ✅ AWS (Production Integration)
- **Controller**: ACK (AWS Controllers for Kubernetes)
- **This Demo**: Complete DynamoDB implementation with traits
- **Examples**: VPC, EKS, S3, DynamoDB, IAM roles
- **Status**: Most mature integration, actively tested

#### ✅ GCP (Documented with Examples)
- **Controller**: KCC (Kubernetes Config Connector)
- **Official Examples**: [GKE Cluster](https://kro.run/examples/gcp/gke-cluster/), [GCS Bucket with Eventarc](https://kro.run/0.4.0/examples/gcp/eventarc/)
- **Resources**: IAMServiceAccount, IAMPolicyMember, ComputeNetwork
- **Status**: Examples available, community testing ongoing

#### ✅ Azure (Documented with Examples)
- **Controller**: ASO (Azure Service Operator v2)
- **Integration Pattern**: [GitOps with ASO & KRO](https://blog.devops.dev/gitops-infra-as-code-using-the-azure-service-operator-kro-1c5e7692e19d)
- **Deployment**: [Installing KRO on AKS with Terraform](https://carlos.mendible.com/2025/02/09/installing-kro-on-aks-with-terraform/)
- **Status**: Documented patterns, early adoption phase

### How KRO Achieves Multi-Cloud

KRO's architecture is **controller-agnostic** by design:

1. **ResourceGraphDefinition (RGD)**: Defines abstract resource graphs
2. **Controller Integration**: Works with ANY Kubernetes operator that provides CRDs
3. **Cloud Abstraction**: Platform teams create RGDs that hide cloud-specific details
4. **Unified Experience**: Developers use simple custom resources regardless of cloud

**Example Multi-Cloud Pattern**:
```yaml
# Platform team creates RGD for "Database" abstraction
apiVersion: kro.run/v1alpha1
kind: ResourceGraphDefinition
metadata:
  name: database
spec:
  schema:
    apiVersion: v1alpha1
    kind: Database
    spec:
      provider: string  # "aws" | "gcp" | "azure"
      size: string
  resources:
    - when: $.spec.provider == "aws"
      # Create ACK DynamoDB resources
    - when: $.spec.provider == "gcp"
      # Create KCC Cloud SQL resources
    - when: $.spec.provider == "azure"
      # Create ASO CosmosDB resources
```

### KRO vs Crossplane: Complementary Not Competitive

**Different Philosophies**:
- **Crossplane**: Cloud resource abstraction with opinionated compositions
- **KRO**: General-purpose Kubernetes resource orchestration (native + CRDs)

**KRO Can Orchestrate Crossplane**:
```yaml
# KRO RGD that includes Crossplane XRs
apiVersion: kro.run/v1alpha1
kind: ResourceGraphDefinition
spec:
  resources:
    - apiVersion: database.example.org/v1alpha1
      kind: PostgreSQL  # Crossplane XR
    - apiVersion: v1
      kind: Service     # Native K8s
    - apiVersion: apps/v1
      kind: Deployment  # Native K8s
```

**Use Cases for Each**:
- **Crossplane alone**: Mature multi-cloud control plane, production workloads today
- **KRO alone**: Kubernetes-native approach, full control, experimental
- **Both together**: KRO orchestrates Crossplane XRs + native K8s resources (advanced)

### References and Further Reading

**Official Announcements**:
- [Introducing Kube Resource Orchestrator | Google Cloud Blog](https://cloud.google.com/blog/products/containers-kubernetes/introducing-kube-resource-orchestrator) (Jan 2025)
- [Building Community with CRDs: KRO | AKS Engineering Blog](https://blog.aks.azure.com/2025/01/30/kube-resource-orchestrator) (Jan 2025)
- [Introducing kro | AWS Open Source Blog](https://aws.amazon.com/blogs/opensource/introducing-open-source-kro-kube-resource-orchestrator/) (Nov 2024)

**Multi-Cloud Integration Guides**:
- [KRO Official Documentation](https://kro.run/)
- [GCP Examples](https://kro.run/examples/gcp/gke-cluster/)
- [GitOps Infra-as-Code using ASO & KRO](https://blog.devops.dev/gitops-infra-as-code-using-the-azure-service-operator-kro-1c5e7692e19d)
- [Installing KRO on AKS with Terraform](https://carlos.mendible.com/2025/02/09/installing-kro-on-aks-with-terraform/)

**Technical Analysis**:
- [Cloud Giants Collaborate on New Kubernetes Resource Management Tool | InfoQ](https://www.infoq.com/news/2025/02/kube-resource-orchestrator/)
- [Kubernetes Gets a New Resource Orchestrator | The New Stack](https://thenewstack.io/kubernetes-gets-a-new-resource-orchestrator-in-the-form-of-kro/)
- [Building platforms using kro for composition | CNCF](https://www.cncf.io/blog/2025/12/15/building-platforms-using-kro-for-composition/)

**Source Code**:
- [KRO GitHub Repository](https://github.com/kubernetes-sigs/kro)
- [KRO Releases](https://github.com/kubernetes-sigs/kro/releases)

### The Bottom Line

As of **December 2025**, the multi-cloud Kubernetes orchestration landscape has evolved:

✅ **Crossplane remains production-ready** and battle-tested for multi-cloud infrastructure

✅ **KRO has emerged as a viable alternative** with backing from all three major cloud vendors

⚠️ **KRO is still alpha** and not recommended for production workloads yet

🚀 **The future is multi-tool**: Organizations may use both tools for different purposes, or KRO to orchestrate Crossplane resources alongside native Kubernetes objects

**Crossplane is no longer the only game in town** for multi-cloud Kubernetes resource management, but it remains the most mature option for production use cases today.

---

## Resource Adoption: Managing Existing Infrastructure

A critical capability for production adoption is the ability to **adopt existing cloud resources** without recreating them. This enables teams to migrate from tools like Terraform or CloudFormation to Kubernetes-native management without downtime.

### What is Resource Adoption?

**Resource Adoption** allows a Kubernetes controller to take management of cloud resources that were created outside its control, bringing them under declarative Kubernetes management without destroying and recreating them.

**Use Cases**:
- Migrating from Terraform/CloudFormation to Kubernetes-native tools
- Importing manually-created production resources
- Transitioning between infrastructure management tools
- Recovering from accidental resource deletion in Kubernetes

### Adoption Support: Crossplane vs KRO

Both Crossplane and KRO's underlying cloud controllers support resource adoption, but with different mechanisms:

#### Crossplane Resource Adoption

**Method**: `managementPolicy` field in Managed Resources

```yaml
apiVersion: s3.aws.upbound.io/v1beta1
kind: Bucket
metadata:
  name: existing-bucket
spec:
  forProvider:
    region: us-west-2
  managementPolicies: ["Observe"]  # Import existing resource
```

- **Built-in**: All Crossplane providers support `managementPolicy`
- **Policies**: `Observe` (read-only), `ObserveCreateUpdate`, `*` (full management)
- **Consistent**: Same pattern across all cloud providers

#### KRO Resource Adoption (Two Layers)

KRO adoption works at **two levels**:

##### 1. **KRO Layer** (Kubernetes Resources)

**Method**: `externalRef` field in ResourceGraphDefinitions

```yaml
apiVersion: kro.run/v1alpha1
kind: ResourceGraphDefinition
spec:
  resources:
    - id: projectConfig
      externalRef:
        apiVersion: corp.platform.com/v1
        kind: Project
        metadata:
          name: default-project
```

- **Purpose**: Reference existing Kubernetes resources in the cluster
- **Behavior**: KRO reads but doesn't create/delete the resource
- **Use Case**: Integrate pre-existing K8s resources into orchestration

##### 2. **Cloud Controller Layer** (AWS/GCP/Azure Resources)

Since KRO orchestrates cloud-specific controllers, adoption of actual cloud resources happens through ACK, KCC, or ASO:

### ✅ AWS - ACK (AWS Controllers for Kubernetes)

**Method**: `AdoptedResource` CRD

```yaml
apiVersion: services.k8s.aws/v1alpha1
kind: AdoptedResource
metadata:
  name: adopt-my-existing-bucket
spec:
  aws:
    nameOrID: example-bucket  # Existing AWS resource
  kubernetes:
    group: s3.services.k8s.aws
    kind: Bucket
    metadata:
      name: my-existing-bucket
      namespace: default
```

**Features**:
- ✅ All ACK controllers ship with AdoptedResource CRD
- ✅ Supports resources requiring multiple identifiers via `additionalKeys`
- ✅ Purpose-built for migrating from Terraform/CloudFormation
- ✅ Read-only resources available for step-wise migration

**Documentation**: [Adopting Existing AWS Resources - ACK](https://aws-controllers-k8s.github.io/community/docs/user-docs/adopted-resource/)

### ✅ GCP - KCC (Kubernetes Config Connector)

**Methods**: Three approaches for adoption

**1. Automatic Acquisition by Name**
```yaml
apiVersion: storage.cnrm.cloud.google.com/v1beta1
kind: StorageBucket
metadata:
  name: existing-bucket
spec:
  location: us-west2
  # If bucket exists with this name, KCC acquires it automatically
```

**2. Using `resourceID` Field**
```yaml
apiVersion: compute.cnrm.cloud.google.com/v1beta1
kind: ComputeInstance
metadata:
  name: my-vm
spec:
  resourceID: "1234567890"  # Service-generated ID
  # KCC assumes resource exists and acquires it
```

**3. Export/Import CLI**
```bash
# Export existing GCP resource to YAML
config-connector export \
  --project my-project \
  --resource-type storage.googleapis.com/Bucket \
  --resource-name my-bucket

# Bulk export for multiple resources
config-connector bulk-export \
  --project my-project \
  --output-dir ./resources
```

**Features**:
- ✅ Automatic acquisition by name (easiest approach)
- ✅ Service-generated ID support via `resourceID`
- ✅ CLI tools for exporting existing resources
- ✅ Bulk operations for migrating entire projects
- ✅ Actively maintained (updated December 2025)

**Documentation**:
- [Managing and deleting resources | Config Connector](https://cloud.google.com/config-connector/docs/how-to/managing-deleting-resources)
- [Export and import resources to Config Connector](https://cloud.google.com/config-connector/docs/how-to/import-export/export)
- [Bulk importing and exporting](https://cloud.google.com/config-connector/docs/how-to/import-export/bulk-export)

### ✅ Azure - ASO (Azure Service Operator)

**Methods**: Automatic adoption + CLI import

**1. Automatic Adoption (Default Behavior)**
```yaml
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
metadata:
  name: mystorageaccount
  namespace: default
spec:
  location: westus2
  # If StorageAccount exists with same name in same RG, ASO adopts it
```

**2. CLI Import Tool**
```bash
# Import existing Azure resource configuration
asoctl import azure-resource \
  /subscriptions/<sub-id>/resourceGroups/my-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/my-pg \
  --output aso.yaml

# Apply the generated YAML
kubectl apply -f aso.yaml
```

**Adoption Policies**:
```yaml
# Policy 1: Adopt and manage (default)
# Deleting in K8s deletes in Azure
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
metadata:
  name: mystorageaccount

# Policy 2: Adopt but don't delete
# Deleting in K8s detaches but keeps resource in Azure
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
metadata:
  name: mystorageaccount
  annotations:
    serviceoperator.azure.com/reconcile-policy: detach-on-delete
```

**Features**:
- ✅ **Best-in-class automatic adoption** - Just match name/RG/subscription
- ✅ `asoctl import` generates accurate YAML from existing resources
- ✅ Explicit adoption policies (manage vs. detach-on-delete)
- ✅ Manual adoption for precise control
- ✅ Comprehensive FAQ and adoption guide

**Documentation**:
- [Adopting existing Azure resources | Azure Service Operator](https://azure.github.io/azure-service-operator/guide/adoption/)
- [asoctl | Azure Service Operator](https://azure.github.io/azure-service-operator/tools/asoctl/)
- [Adoption Policy Design | ASO](https://azure.github.io/azure-service-operator/design/adr-2023-02-adoption-policy/)

### Adoption Comparison Matrix

| Feature | Crossplane | KRO + ACK | KRO + KCC | KRO + ASO |
|---------|-----------|-----------|-----------|-----------|
| **K8s Resource Adoption** | managementPolicy | externalRef | externalRef | externalRef |
| **Cloud Resource Adoption** | ✅ Built-in | ✅ AdoptedResource CRD | ✅ Auto + CLI | ✅ Auto + CLI |
| **Adoption Method** | Field-based | CRD-based | Multiple methods | Automatic |
| **Automatic by Name** | No | No | ✅ Yes | ✅ Yes |
| **CLI Tools** | Provider-specific | No | ✅ Yes (export/bulk) | ✅ Yes (asoctl) |
| **Bulk Import** | Provider-specific | No | ✅ Yes | ✅ Yes |
| **Adoption Policies** | managementPolicy | Not explicit | Not explicit | ✅ Explicit (2 modes) |
| **Service-Generated IDs** | Yes | ✅ additionalKeys | ✅ resourceID | Yes |
| **Migration from IaC** | ✅ Yes | ✅ Yes (documented) | ✅ Yes | ✅ Yes |
| **Documentation Quality** | ✅ Comprehensive | ✅ Good | ✅ Excellent | ✅ Excellent |

### Key Insights

**1. All Solutions Support Adoption**
- ✅ Crossplane: Built-in via `managementPolicy`
- ✅ KRO + ACK: Dedicated `AdoptedResource` CRD
- ✅ KRO + KCC: Multiple methods (auto, resourceID, CLI)
- ✅ KRO + ASO: Best automatic adoption experience

**2. Adoption Approaches Differ**
- **Crossplane**: Consistent field-based approach across all providers
- **KRO**: Varies by cloud controller, often with richer features

**3. KRO Cloud Controllers Shine**
- **KCC (GCP)**: Automatic acquisition by name (simplest)
- **ASO (Azure)**: Automatic + explicit policies (most flexible)
- **ACK (AWS)**: Dedicated CRD pattern (most explicit)

**4. Migration Support**
- All solutions explicitly support migrating from Terraform/CloudFormation
- KCC and ASO provide CLI tools for bulk operations
- ACK provides read-only mode for step-wise migration

### The Adoption Bottom Line

**For resource adoption, both Crossplane and KRO are production-ready:**

✅ **Crossplane**: Consistent adoption experience across all clouds via `managementPolicy`

✅ **KRO + Cloud Controllers**: Often more sophisticated adoption features:
- **ACK**: Explicit adoption CRD
- **KCC**: Automatic acquisition + bulk export tools
- **ASO**: Best-in-class automatic adoption with explicit policies

**Migration Scenarios**:
- **Terraform → Crossplane**: Use `managementPolicy: ["Observe"]` pattern
- **Terraform → KRO/ACK**: Use `AdoptedResource` CRD
- **Terraform → KRO/KCC**: Use automatic acquisition or `config-connector export`
- **Terraform → KRO/ASO**: Use automatic adoption or `asoctl import`

**Winner**: This is a **tie** - both approaches are production-ready for adoption. KRO's cloud controllers often provide more sophisticated tools (automatic adoption, bulk export), but Crossplane offers a more consistent experience across clouds.

---

**Status**: ✅ Production-Ready Demo
**Last Updated**: 2025-12-30
**KubeCon**: North America 2025
