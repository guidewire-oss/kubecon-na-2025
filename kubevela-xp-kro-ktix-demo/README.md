# KubeVela DynamoDB Demo: Crossplane vs KRO

A comprehensive demonstration comparing Crossplane and KRO (Kube Resource Orchestrator) for managing AWS DynamoDB tables through KubeVela's OAM abstraction layer.

## Overview

This demo showcases two infrastructure engines for provisioning and managing AWS DynamoDB tables in Kubernetes:

1. **Crossplane** - Mature, multi-cloud infrastructure provisioning
2. **KRO + ACK** - Kubernetes-native AWS resource orchestration

Both approaches are wrapped in KubeVela component definitions, providing a consistent developer experience regardless of the underlying infrastructure engine.

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
- Table names must start with `tenant-atlantis-` prefix
- Permissions scoped to `us-west-2` region
- Includes: CreateTable, DescribeTable, UpdateTable, DeleteTable, and feature-specific actions
- See [IAM_POLICY.md](IAM_POLICY.md) for full policy and setup instructions

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
| **Maturity** | Production-ready | Experimental | Experimental |
| **Cloud Support** | Multi-cloud | AWS-specific | AWS-specific |
| **API Style** | Minimal/opinionated | Full AWS API | Minimal/opinionated |
| **Configuration** | Traits only | Inline or traits | Traits only |
| **Resource Management** | Provider-managed | ACK-managed | ACK-managed |
| **Traits Support** | Yes (7 traits) | Yes (7 traits) | Yes (7 traits) |
| **Type Safety** | ✅ Strict enums | ⚠️ Looser types | ✅ Strict enums |
| **Learning Curve** | Moderate | Requires K8s + AWS knowledge | Moderate |
| **Best For** | Multi-cloud, abstraction | AWS-native, direct control | XP-to-KRO migration |

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

### Issue: Applications not showing in VelaUX UI

**VelaUX may not show all applications immediately:**
- VelaUX was designed to show applications created through its API/UI
- Applications created with `vela up` or `kubectl apply` exist in Kubernetes
- Use `vela ls -A` to see ALL applications regardless of VelaUX
- VelaUX caching or project filtering may hide some applications
- All applications are fully functional even if not visible in VelaUX UI

## Documentation

### Component Documentation
- **[aws-dynamodb-xp.md](definitions/components/aws-dynamodb-xp.md)** - Crossplane component guide
- **[aws-dynamodb-kro.md](definitions/components/aws-dynamodb-kro.md)** - KRO full component guide
- **[aws-dynamodb-kro-simplified.md](definitions/components/aws-dynamodb-kro-simplified.md)** - 🆕 KRO simplified component guide

### General Documentation
- **[CHANGELOG.md](CHANGELOG.md)** - Version history and fixes (includes 2025-12-29 fix)
- **[definitions/DYNAMODB-COMPONENTS-SUMMARY.md](definitions/DYNAMODB-COMPONENTS-SUMMARY.md)** - Component comparison guide
- **[definitions/DYNAMODB-KRO-SUMMARY.md](definitions/DYNAMODB-KRO-SUMMARY.md)** - KRO architecture details
- **[definitions/traits/DYNAMODB-KRO-TRAITS-README.md](definitions/traits/DYNAMODB-KRO-TRAITS-README.md)** - Trait usage guide
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

**Status**: ✅ Production-Ready Demo
**Last Updated**: 2025-12-29
**KubeCon**: North America 2025
