# CLAUDE.md - LocalStack Demo Developer Guide

Quick reference for developing with the LocalStack KubeVela + KRO + Crossplane demo.

This guide is for developers and contributors. For project overview, see **README.md**. For system architecture, see **ARCHITECTURE.md**. For troubleshooting, see **DEBUGGING.md**.

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

### Check DynamoDB Tables in LocalStack

Use the helper script to check if DynamoDB tables have been created:

```bash
# Run on host machine (auto-detects your environment)
./check-dynamodb-tables.sh
```

This script will:
- ✓ List all DynamoDB tables created in LocalStack
- ✓ Show application deployment status
- ✓ Provide helpful debugging commands
- ✓ Test LocalStack connectivity

The script uses two methods:
1. **kubectl exec** - Direct access via LocalStack pod (works in any environment)
2. **Port-forward** - Localhost access for host machines (if AWS CLI installed)

## Debugging Tables Not Being Created

If `./check-dynamodb-tables.sh` shows no tables despite successful setup, use the debugging tools:

### Quick Diagnostics
```bash
# See full resource state and controller logs
./debug-resources.sh

# Manually test table creation (isolates KRO vs Crossplane)
./test-manual-table-creation.sh
```

### Detailed Debugging Guide
See `DEBUGGING.md` for a complete troubleshooting workflow including:
- Decision tree for identifying which component is failing
- Common issues and fixes
- Manual testing steps
- Real-time log viewing
- Useful kubectl commands

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

### KRO + ACK Setup Issues (Fixed)

The KRO + ACK integration required several fixes:

1. **RBAC Permissions** - Applied `kro:controller:dynamic-resources` ClusterRole to allow KRO to manage SimpleDynamoDB resources
2. **ACK CRD Installation** - Installed `dynamodb.services.k8s.aws/v1alpha1/Table` CRD from GitHub (image pull issues prevented Helm installation)
3. **RGD Configuration** - Created proper ResourceGraphDefinition with correct status field mapping
4. **SimpleDynamoDB CRD** - Created the custom resource definition to bridge KRO and ACK

These are automatically applied by `./setup.sh` - no manual intervention needed.

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

## File & Script Reference

### Setup & Configuration Scripts
- `setup.sh` - Full automated setup (9 phases) - **START HERE**
- `clean.sh` - Cleanup cluster and all resources
- `create-kubeconfig.sh` - Generate kubeconfig for DevContainer (run after cluster restart)
- `install-ack.sh` - Manual ACK controller installation (fallback if Phase 6 fails)

### Utility & Diagnostic Scripts
- `check-dynamodb-tables.sh` - List DynamoDB tables and verify table creation
- `debug-resources.sh` - Full system diagnostics (shows all resources and controller logs)
- `test-manual-table-creation.sh` - Manual integration test (isolates KRO vs Crossplane issues)

### Automation Configuration Files
- `.env.devcontainer` - DevContainer environment (auto-detected)
- `.env.host` - Host machine environment (auto-detected)
- `.env.ci` - CI/CD environment (auto-detected)
- `.env` - User overrides (GITIGNORED)
- `config/detect-env.sh` - Environment auto-detection logic
- `config/port-forward-helpers.sh` - Port-forward utilities

### Component Definitions (KubeVela)
- `definitions/components/aws-dynamodb-simple-kro.cue` - KRO simple table component
- `definitions/components/aws-dynamodb-simple-xp.cue` - Crossplane simple table component

### Infrastructure as Code (KRO)
- `definitions/kro/simple-dynamodb-rgd.yaml` - KRO ResourceGraphDefinition for SimpleDynamoDB

### Example Applications (KubeVela Applications)
- `definitions/examples/session-api-app-kro.yaml` - KRO session API (table + Flask) - **START HERE**
- `definitions/examples/session-api-app-xp.yaml` - Crossplane session API (table + Flask)
- `definitions/examples/dynamodb-kro/` - Simple KRO examples
- `definitions/examples/dynamodb-xp/` - Simple Crossplane examples

### Demo Application (Flask Session API)
- `app/session-api.py` - Flask REST API implementation
- `app/Dockerfile` - Docker image for session API
- `app/requirements.txt` - Python dependencies

### Testing Scripts
- `tests/common.sh` - Shared test utilities
- `tests/test_localstack.sh` - Comprehensive LocalStack connectivity test
- `tests/test_localstack-simple.sh` - Simple LocalStack test
- `tests/test_kro_integration.sh` - KRO + ACK integration test

### Documentation
- `README.md` - Project overview, quick start, multi-cloud comparison
- `ARCHITECTURE.md` - System design, component chains, data flow
- `DEBUGGING.md` - Troubleshooting guide and decision trees
- `CLAUDE.md` - Developer guide (this file)
- `app/README.md` - Session API documentation

### Generated Files (not in git)
- `kubeconfig-internal` - DevContainer kubeconfig (generated by `create-kubeconfig.sh`)
- `localstack-values.yaml` - LocalStack Helm deployment values
- `kro-rbac-fix.yaml` - KRO RBAC permissions (applied during setup)

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

## Crossplane XP Application

### Current Status
- ✅ **KRO Application**: Fully functional and tested
- 🟡 **Crossplane Application**: Deployed but requires credentials setup (optional)

### Crossplane Deployment
The Crossplane XP application is deployed by default. However, the Crossplane Table resource may remain in `runningWorkflow` state because Crossplane's AWS provider requires specific credential handling when connecting to LocalStack.

The test/test credentials work for KRO + ACK (native Kubernetes), but Crossplane's Terraform-based provider uses a different credential flow that LocalStack doesn't fully recognize by default.

### To Skip Crossplane Deployment
```bash
export DEPLOY_CROSSPLANE_APP=false
./setup.sh
```

### To Debug Crossplane Issues
Check the Table resource status:
```bash
kubectl describe table.dynamodb.aws.upbound.io sessions-table -n default
```

The primary focus of this demo is KRO, which works perfectly with LocalStack. Crossplane support is provided for comparison.

## Additional Resources

- **README.md** - Overview and quick start
- **app/README.md** - Session API documentation
- **https://kubevela.io** - KubeVela documentation
- **https://crossplane.io** - Crossplane documentation
- **https://kubernetes-sigs.github.io/kro/** - KRO documentation
- **https://localstack.cloud** - LocalStack documentation
