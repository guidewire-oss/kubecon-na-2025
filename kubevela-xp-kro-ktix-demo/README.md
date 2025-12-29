# KubeVela DynamoDB Demo: Crossplane vs KRO

A comprehensive demonstration comparing Crossplane and KRO (Kube Resource Orchestrator) for managing AWS DynamoDB tables through KubeVela's OAM abstraction layer.

## Overview

This demo showcases two approaches for provisioning and managing AWS DynamoDB tables in Kubernetes:

1. **Crossplane** - Mature, multi-cloud infrastructure provisioning
2. **KRO + ACK** - Kubernetes-native AWS resource orchestration

Both approaches are wrapped in KubeVela component definitions, providing a consistent developer experience regardless of the underlying infrastructure engine.

## What's Included

### Infrastructure Components

- **k3d Kubernetes Cluster** (1 server, 2 agents)
- **KubeVela** - Application platform with OAM
- **Crossplane** + AWS DynamoDB Provider
- **KRO** (Kube Resource Orchestrator) + RBAC fixes
- **ACK** (AWS Controllers for Kubernetes) DynamoDB controller
- **2 ResourceGraphDefinitions** for KRO (advanced + simple)

### Component Definitions

1. **aws-dynamodb-xp** - Crossplane-based DynamoDB component
2. **aws-dynamodb-kro** - KRO-based advanced component (with traits)
3. **aws-dynamodb-simple-kro** - KRO-based basic component (simple tables)

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

**Note**: The IAM user must have permissions to create DynamoDB tables. For the session management app, table names must start with `tenant-atlantis-` (or adjust the table name prefix in the app YAMLs).

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

| Feature | Crossplane | KRO + ACK |
|---------|-----------|-----------|
| **Maturity** | Production-ready | Experimental |
| **Cloud Support** | Multi-cloud | AWS-specific |
| **API Style** | Abstract/opinionated | 1:1 with AWS API |
| **Resource Management** | Provider-managed | ACK-managed |
| **Traits Support** | Yes (6 traits) | Yes (5 traits) |
| **Learning Curve** | Moderate | Requires K8s + AWS knowledge |
| **Best For** | Multi-cloud, abstraction | AWS-native, direct control |

## Component Comparison

### Crossplane Component (aws-dynamodb-xp)

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
spec:
  components:
    - name: my-table
      type: aws-dynamodb-xp
      properties:
        tableName: my-table
        region: us-west-2
        attributeDefinitions:
          - attributeName: id
            attributeType: "S"
        keySchema:
          - attributeName: id
            keyType: HASH
        billingMode: PAY_PER_REQUEST
```

### KRO Component (aws-dynamodb-simple-kro)

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

**Note**: KRO simple component creates a table with a default `id` (String) partition key and PAY_PER_REQUEST billing.

## Verification Commands

```bash
# Check applications
kubectl get applications.core.oam.dev
vela status dynamodb-basic-xp
vela status dynamodb-basic-example

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

### KRO Traits

- `dynamodb-ttl-kro` - Time-to-Live configuration
- `dynamodb-streams-kro` - DynamoDB Streams
- `dynamodb-encryption-kro` - Server-side encryption
- `dynamodb-protection-kro` - Deletion protection + PITR
- `dynamodb-provisioned-capacity-kro` - Provisioned billing mode

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

## Documentation

- **[CHANGELOG.md](CHANGELOG.md)** - Version history and fixes
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
│   │   ├── aws-dynamodb-kro.cue      # KRO advanced component
│   │   └── aws-dynamodb-simple-kro.cue # KRO simple component
│   ├── traits/                       # Trait definitions
│   │   ├── *-xp.cue                  # Crossplane traits
│   │   └── *-kro.cue                 # KRO traits
│   ├── kro/                          # KRO ResourceGraphDefinitions
│   │   ├── dynamodb-rgd.yaml         # Advanced RGD
│   │   └── simple-dynamodb-rgd.yaml  # Simple RGD
│   └── examples/
│       ├── dynamodb-table/           # Crossplane examples
│       ├── dynamodb-kro/             # KRO examples
│       ├── session-management-app.yaml     # KRO app
│       └── session-management-app-xp.yaml  # Crossplane app
└── README.md                         # This file
```

## Contributing

This is a demo project for KubeCon NA 2025. For issues or suggestions, please create an issue or pull request.

## License

This project is provided as-is for educational and demonstration purposes.

---

**Status**: ✅ Production-Ready Demo
**Last Updated**: 2025-12-24
**KubeCon**: North America 2025
