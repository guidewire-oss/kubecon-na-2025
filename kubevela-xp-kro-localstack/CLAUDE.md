# CLAUDE.md - LocalStack Demo Developer Guide

Quick reference for developing with the LocalStack KubeVela demo.

## ⚙️ Multi-Environment Configuration

This demo automatically detects your runtime environment and configures image URIs and endpoints accordingly.

### Supported Environments

- **DevContainer** (VS Code Container): Local development with in-cluster access
- **Host Machine** (WSL, macOS, Linux): Local development with port-forward access
- **CI/CD** (GitHub Actions, GitLab CI): Automated testing and deployment

### Setup & Access

#### Automatic Setup (Recommended)
```bash
./setup.sh                   # Auto-detects environment + builds + installs everything
./setup.sh --skip-install    # Build only, skip component installation
./setup.sh --skip-build      # Skip Docker build, only install components
```

The setup script will:
1. Detect your environment (DevContainer, Host, or CI/CD)
2. Build the session-api Docker image
3. Import image to k3d (host only)
4. Install LocalStack, KubeVela, Crossplane, KRO, ACK
5. Deploy component definitions

#### Configuration Files

Auto-generated based on environment:
- **DevContainer**: `.env.devcontainer` (in-cluster access)
- **Host Machine**: `.env.host` (port-forward access)
- **CI/CD**: `.env.ci` (in-cluster access)

To manually override:
```bash
# Copy and edit specific environment config
cp .env.host .env
# Edit .env as needed
./setup.sh
```

#### Manual Kubeconfig (if needed)
```bash
./create-kubeconfig.sh              # Creates kubeconfig-internal
./create-kubeconfig.sh output-file  # Creates output-file
```

### Installation Phases

Phase 0: Environment detection and configuration
Phase 1: Cluster creation (if needed)
Phase 2: LocalStack installation (http://localstack.localstack-system.svc.cluster.local:4566)
Phase 2B: Docker image build and import
Phase 3: KubeVela installation
Phase 4: Crossplane installation
Phase 5: KRO installation
Phase 6: ACK DynamoDB installation
Phase 7: Deploy component definitions
Phase 8: Finalize and verify
Phase 9: Wait for infrastructure and deploy applications (automatic)

## Working with Applications

### Applications Are Auto-Deployed!

**Both KRO and Crossplane applications are automatically deployed during Phase 9 of setup.sh**

After running `./setup.sh`, both applications are ready to use:
- `session-api-app-kro` - KRO-based DynamoDB with session API
- `session-api-app-xp` - Crossplane-based DynamoDB with session API

To re-deploy an application manually:
```bash
# Deploy KRO-based session API
KUBECONFIG=./kubeconfig-internal vela up -f definitions/examples/session-api-app-kro.yaml

# Deploy Crossplane-based session API
KUBECONFIG=./kubeconfig-internal vela up -f definitions/examples/session-api-app-xp.yaml
```

### Check Status
```bash
KUBECONFIG=./kubeconfig-internal vela ls -A                    # All apps
KUBECONFIG=./kubeconfig-internal vela status <app-name>        # Single app
KUBECONFIG=./kubeconfig-internal kubectl get pods -n default   # Pods
```

### View Logs
```bash
KUBECONFIG=./kubeconfig-internal kubectl logs -n default <pod-name>
```

## Available Examples

### Complete Applications (Table + Webservice)

- `session-api-app-kro.yaml` - KRO-based session API (table + Flask API) - **START HERE**
- `session-api-app-xp.yaml` - Crossplane-based session API (table + Flask API)

### Simple Table Examples

- `dynamodb-kro/simple-basic.yaml` - Simple table only (KRO)
- `dynamodb-kro/basic.yaml` - Basic KRO example
- `dynamodb-xp/basic.yaml` - Basic Crossplane example

## LocalStack Configuration

**Endpoint:** http://localstack.localstack-system.svc.cluster.local:4566
**Region:** us-west-2
**Credentials:** test/test (dummy, no AWS account needed)

DynamoDB is the only LocalStack service enabled. Other services unavailable.

## Component Types Available

- `aws-dynamodb-simple-kro` - Simple KRO table (partition key only)
- `aws-dynamodb-simple-xp` - Simple Crossplane table

## Troubleshooting

### Environment Detection Issues

```bash
# Check detected environment
source config/detect-env.sh
echo "Environment: $ENV_TYPE"
echo "Image Registry: $IMAGE_REGISTRY"
echo "LocalStack Endpoint: $LOCALSTACK_ENDPOINT"
echo "Kubeconfig: $KUBECONFIG"
```

### DevContainer-Specific

| Issue | Solution |
|-------|----------|
| kubectl connection refused | Regenerate kubeconfig: `./create-kubeconfig.sh` |
| Port changes after restart | Always run `./create-kubeconfig.sh` after cluster restarts |
| Image not found | Already in local registry, no import needed |

### Host Machine-Specific

| Issue | Solution |
|-------|----------|
| Image import fails | Ensure k3d is running: `k3d cluster list` |
| Port-forward errors | Ports may be in use: `netstat -tuln \| grep 4566` |
| Endpoint not accessible | Run port-forward manually: `kubectl port-forward -n localstack-system svc/localstack 4566:4566` |
| Test failures | Check if port-forwards are running: `ps aux \| grep port-forward` |

### CI/CD-Specific

| Issue | Solution |
|-------|----------|
| Image pull fails | Ensure image is pushed to accessible registry |
| Service discovery fails | Verify in-cluster DNS: `kubectl run -it --rm debug --image=busybox -- nslookup localstack.localstack-system` |

### General Issues

| Issue | Solution |
|-------|----------|
| Application pending | Check table creation: `kubectl get tables.dynamodb.aws.upbound.io -A` |
| LocalStack not responding | Verify pod: `kubectl get pods -n localstack-system` |
| Components not showing | Run `./setup.sh --skip-install` to redeploy definitions |
| Docker build fails | Disable BuildKit: `DOCKER_BUILDKIT=0 ./setup.sh` |

## Directory Structure

```
.
├── config/
│   ├── detect-env.sh                 # Environment detection and configuration
│   └── port-forward-helpers.sh       # Port-forward utilities
├── .env.devcontainer                 # DevContainer configuration
├── .env.host                         # Host machine configuration
├── .env.ci                           # CI/CD configuration
├── .env                              # GITIGNORED: User overrides
├── create-kubeconfig.sh              # Kubeconfig generator (run after cluster restart)
├── setup.sh                          # Full setup automation
├── clean.sh                          # Cleanup script (deletes cluster and all resources)
├── kubeconfig-internal               # Generated kubeconfig for DevContainer
├── localstack-values.yaml            # LocalStack Helm values
├── definitions/
│   ├── components/
│   │   ├── aws-dynamodb-simple-kro.cue    # KRO simple table component
│   │   └── aws-dynamodb-simple-xp.cue     # Crossplane simple table component
│   ├── kro/
│   │   └── simple-dynamodb-rgd.yaml       # KRO ResourceGraphDefinition
│   └── examples/
│       ├── session-api-app-kro.yaml       # KRO session API (table + Flask) - START HERE
│       ├── session-api-app-xp.yaml        # Crossplane session API (table + Flask)
│       ├── dynamodb-kro/
│       │   ├── basic.yaml                 # KRO basic example
│       │   └── simple-basic.yaml          # KRO simple example
│       └── dynamodb-xp/
│           └── basic.yaml                 # Crossplane basic example
├── app/
│   ├── README.md                    # Session API documentation
│   ├── session-api.py               # Flask API implementation
│   └── Dockerfile                   # Docker image definition
├── tests/
│   ├── common.sh                    # Common test utilities and environment setup
│   ├── test_localstack-simple.sh    # Simple LocalStack connectivity test
│   ├── test_localstack.sh           # Comprehensive LocalStack test (with env detection)
│   └── test_kro_integration.sh      # KRO integration test
├── README.md                        # Project overview
└── CLAUDE.md                        # This file
```

## Testing

All tests automatically detect your environment and configure endpoints accordingly.

```bash
# LocalStack connectivity test (works in any environment)
bash tests/test_localstack.sh

# KRO integration test (requires full setup)
bash tests/test_kro_integration.sh

# Simple LocalStack test
bash tests/test_localstack-simple.sh
```

### How Tests Work

Tests use the environment detection system to:
1. Auto-detect DevContainer vs Host vs CI/CD
2. Set appropriate endpoints (cluster DNS or localhost)
3. Auto-setup port-forwards if needed (host machine)
4. Clean up port-forwards after tests

No manual kubeconfig or endpoint configuration needed!

## Key Points

- ✅ No AWS account required - everything runs locally via LocalStack
- ✅ Table names have NO prefix (unlike AWS demo with tenant-atlantis-)
- ✅ Use simple names: `user-sessions`, `orders`, `products`
- ✅ Kubeconfig needs regeneration after cluster restart (port changes)
- ✅ All components auto-configured to use LocalStack endpoint
- ⚠️ ACK controller optional - KRO+RGD sufficient for table management

## Additional Resources

- **README.md** - Overview and quick start
- **app/README.md** - Session API documentation
- **https://kubevela.io** - KubeVela documentation
- **https://crossplane.io** - Crossplane documentation
- **https://kubernetes-sigs.github.io/kro/** - KRO documentation
- **https://localstack.cloud** - LocalStack documentation
