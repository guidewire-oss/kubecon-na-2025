# CLAUDE.md - LocalStack Demo Developer Guide

Quick reference for developing with the LocalStack KubeVela demo.

## Setup & Access

### Generate/Update Kubeconfig
```bash
./create-kubeconfig.sh              # Creates kubeconfig-internal
./create-kubeconfig.sh output-file  # Creates output-file
```

**After cluster restart, always regenerate kubeconfig** - port mapping changes.

### Run Full Setup
```bash
./setup.sh                  # Install all components + deploy definitions
./setup.sh --skip-install   # Deploy only definitions (cluster already ready)
```

Components installed in order:
1. LocalStack (Phase 2) - http://localstack.localstack-system.svc.cluster.local:4566
2. KubeVela (Phase 3)
3. Crossplane (Phase 4)
4. KRO (Phase 5)
5. ACK (Phase 6) - optional, may fail on Helm repo issues

## Working with Applications

### Deploy Application
```bash
KUBECONFIG=./kubeconfig-internal vela up -f definitions/examples/session-api-app.yaml
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

- `session-api-app.yaml` - DynamoDB table + Flask API (KRO) - **START HERE**
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

## Quick Troubleshooting

| Issue | Solution |
|-------|----------|
| kubectl connection refused | Run `./create-kubeconfig.sh` |
| Application pending | Check table creation: `kubectl get tables.dynamodb.aws.upbound.io -A` |
| LocalStack not responding | Verify pod: `kubectl get pods -n localstack-system` |
| Components not showing | Run `./setup.sh --skip-install` to redeploy definitions |

## Directory Structure

```
.
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
│       ├── session-api-app.yaml           # Complete app (table + API) - START HERE
│       ├── dynamodb-kro/
│       │   ├── basic.yaml                 # KRO basic example
│       │   └── simple-basic.yaml          # KRO simple example
│       └── dynamodb-xp/
│           └── basic.yaml                 # Crossplane basic example
├── app/
│   ├── README.md                    # Session API documentation
│   └── session-api.py               # Flask API implementation
├── tests/
│   ├── test_localstack-simple.sh    # LocalStack connectivity test
│   ├── test_localstack.sh           # LocalStack with aws-cli test
│   └── test_kro_integration.sh      # KRO integration test
├── README.md                        # Project overview
└── CLAUDE.md                        # This file
```

## Testing

```bash
# LocalStack connectivity
KUBECONFIG=./kubeconfig-internal bash tests/test_localstack-simple.sh

# KRO integration (requires full setup)
KUBECONFIG=./kubeconfig-internal bash tests/test_kro_integration.sh
```

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
