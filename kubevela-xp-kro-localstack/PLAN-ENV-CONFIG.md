# Multi-Environment Configuration Plan

## Problem Statement

The LocalStack demo needs to work from multiple environments with different image URIs and endpoint configurations:

### Current Issues

1. **Image References**
   - Applications hardcode: `image: session-api:latest`
   - Works in DevContainer (local k3d registry accessible)
   - May fail on Host machine (needs k3d-specific URI or localhost port)
   - CI/CD might need full registry path

2. **Endpoint References**
   - LocalStack: `http://localstack.localstack-system.svc.cluster.local:4566`
   - Works for pod-to-pod communication (inside cluster)
   - Fails for tests running on host (outside cluster)
   - Tests and docs assume specific k3d access patterns

3. **Kubeconfig Variations**
   - `create-kubeconfig.sh` generates environment-specific kubeconfig
   - Port mappings change after cluster restart
   - Access method differs (DevContainer vs Host)

### Environments to Support

| Environment | Image Access | Endpoint Access | Kubeconfig |
|---|---|---|---|
| **DevContainer** | `session-api:latest` (local) | Cluster DNS | `kubeconfig-internal` |
| **Host Machine** | `localhost:PORT/session-api:latest` | Port-forward needed | Dynamic kubeconfig |
| **CI/CD** | Registry URL | Cluster DNS | In-cluster auth |

---

## Proposed Solution: Three-Layer Configuration System

### Layer 1: Environment Detection (config/detect-env.sh)

Automatically detect the runtime environment and set configuration:

```bash
#!/bin/bash
# Detect environment and set defaults

if [ -f /.dockerenv ]; then
    export ENV_TYPE="devcontainer"
    export IMAGE_REGISTRY="localhost:5000"  # k3d local registry
    export LOCALSTACK_ENDPOINT="http://localstack.localstack-system.svc.cluster.local:4566"
    export KUBECONFIG_PATH="./kubeconfig-internal"
elif command -v k3d &> /dev/null; then
    export ENV_TYPE="host"
    export IMAGE_REGISTRY="localhost:$(get_k3d_registry_port)"
    export LOCALSTACK_ENDPOINT="http://localhost:4566"  # via port-forward
    export KUBECONFIG_PATH="./kubeconfig-host"
else
    export ENV_TYPE="unknown"
    export IMAGE_REGISTRY="docker.io"
fi

export ENV_FILE=".env.${ENV_TYPE}"
```

### Layer 2: Environment Variables (.env-* files)

Store environment-specific configuration:

#### .env.devcontainer
```bash
# DevContainer Configuration
ENV_TYPE=devcontainer
IMAGE_REGISTRY=localhost:5000
IMAGE_NAME=session-api:latest
LOCALSTACK_ENDPOINT=http://localstack.localstack-system.svc.cluster.local:4566
KUBECONFIG_PATH=./kubeconfig-internal
VELA_NAMESPACE=default
TEST_ENDPOINT_MODE=cluster
```

#### .env.host
```bash
# Host Machine Configuration
ENV_TYPE=host
IMAGE_REGISTRY=localhost:32500
IMAGE_NAME=session-api:latest
LOCALSTACK_ENDPOINT=http://localhost:4566
KUBECONFIG_PATH=./kubeconfig-host
VELA_NAMESPACE=default
TEST_ENDPOINT_MODE=portforward
PORT_FORWARD_LOCALSTACK=4566:4566
PORT_FORWARD_SESSION_API_KRO=9080:8080
PORT_FORWARD_SESSION_API_XP=9081:8080
```

#### .env.ci
```bash
# CI/CD Configuration
ENV_TYPE=ci
IMAGE_REGISTRY=registry.example.com
IMAGE_NAME=my-org/session-api:latest
LOCALSTACK_ENDPOINT=http://localstack.localstack-system.svc.cluster.local:4566
KUBECONFIG_PATH=/var/run/secrets/kubernetes.io/serviceaccount
VELA_NAMESPACE=default
TEST_ENDPOINT_MODE=cluster
```

### Layer 3: Application Template System

Replace hardcoded values with template variables:

#### definitions/examples/session-api-app-kro.yaml.template
```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: session-api-app-kro
  namespace: ${VELA_NAMESPACE}
spec:
  components:
    - name: sessions-table-kro
      type: aws-dynamodb-simple-kro
      properties:
        tableName: api-sessions-kro
        region: us-west-2

    - name: session-api-kro
      type: webservice
      properties:
        image: ${IMAGE_NAME}
        imagePullPolicy: IfNotPresent
        ports:
          - port: 8080
            expose: true
        env:
          - name: DYNAMODB_TABLE_NAME
            value: "api-sessions-kro"
          - name: AWS_REGION
            value: "us-west-2"
          - name: LOCALSTACK_ENDPOINT
            value: "${LOCALSTACK_ENDPOINT}"
          - name: AWS_ACCESS_KEY_ID
            value: "test"
          - name: AWS_SECRET_ACCESS_KEY
            value: "test"
          # ... rest of config
```

Processing:
```bash
# Generate environment-specific yaml
envsubst < definitions/examples/session-api-app-kro.yaml.template \
    > definitions/examples/session-api-app-kro.yaml
```

---

## Implementation Plan

### Phase 1: Create Configuration Infrastructure

**1.1 Create config/ directory**
```
config/
├── detect-env.sh           # Auto-detect environment
├── init-env.sh             # Initialize environment
└── port-forward-helpers.sh # Port-forward utilities
```

**1.2 Create environment files**
- `.env.devcontainer`
- `.env.host`
- `.env.ci`
- `.env` (gitignored, auto-generated or user-custom)

**1.3 Create config/detect-env.sh**
- Detect DevContainer vs Host vs CI
- Set IMAGE_REGISTRY, LOCALSTACK_ENDPOINT, KUBECONFIG_PATH
- Source appropriate .env file

### Phase 2: Update setup.sh

**2.1 Initialize environment at startup**
```bash
#!/bin/bash
# At top of setup.sh
source config/detect-env.sh
source "${ENV_FILE}" || true
```

**2.2 Add build and import step**
```bash
# Phase 1: Build and load Docker image
print_step "Phase 1: Building and importing session-api Docker image"

cd "${DEMO_ROOT}/app"
docker build -t session-api:latest .

if [ "$ENV_TYPE" = "host" ]; then
    print_info "Importing image to k3d cluster..."
    k3d image import session-api:latest -c kubevela-demo
fi

cd "${DEMO_ROOT}"
```

**2.3 Generate application manifests from templates**
```bash
# After setup completes
print_step "Generating environment-specific application manifests"

for template in definitions/examples/*.yaml.template; do
    output="${template%.template}"
    envsubst < "$template" > "$output"
    print_success "Generated: $output"
done
```

### Phase 3: Update Documentation

**3.1 Update README.md**
- Add "Environment Setup" section
- Document each environment's requirements
- Show how to manually set environment

**3.2 Update CLAUDE.md**
- Add "Configuration" section
- Explain automatic vs manual env setup
- Document port-forward commands

**3.3 Update tests/**
- Modify tests to source .env file
- Use ${LOCALSTACK_ENDPOINT} instead of hardcoded URL
- Auto-detect test environment

### Phase 4: Update Tests

**4.1 Create tests/common.sh**
```bash
#!/bin/bash
# Common test utilities

source "$(dirname "$0")/../config/detect-env.sh"
source "$(dirname "$0")/../${ENV_FILE}" || true

# Verify endpoint is accessible
ensure_endpoint_accessible() {
    local endpoint=$1
    local max_attempts=5
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if curl -s "$endpoint" > /dev/null 2>&1; then
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done

    return 1
}

export LOCALSTACK_ENDPOINT
export KUBECONFIG="${KUBECONFIG_PATH}"
```

**4.2 Update individual tests**
```bash
#!/bin/bash
source "$(dirname "$0")/common.sh"

# Tests now use ${LOCALSTACK_ENDPOINT} automatically
kubectl run test-table --image=amazon/aws-cli --rm -it -- \
    --endpoint-url="${LOCALSTACK_ENDPOINT}" \
    --region=us-west-2 dynamodb list-tables
```

### Phase 5: Backwards Compatibility

**5.1 Keep existing application files**
- Keep `session-api-app-kro.yaml` (don't require templates)
- Templates are optional (for users who want env-specific config)
- Default behavior unchanged

**5.2 Graceful fallback**
- If templates don't exist, use original yaml files
- setup.sh checks for templates, falls back to yaml
- No breaking changes for existing users

---

## File Structure After Implementation

```
kubevela-xp-kro-localstack/
├── config/
│   ├── detect-env.sh           # NEW: Environment detection
│   ├── init-env.sh             # NEW: Environment initialization
│   └── port-forward-helpers.sh # NEW: Port-forward utilities
├── .env.devcontainer           # NEW: DevContainer config
├── .env.host                   # NEW: Host config
├── .env.ci                     # NEW: CI/CD config
├── .env                        # GITIGNORED: Auto-generated or user custom
├── setup.sh                    # UPDATED: Source config, generate manifests
├── CLAUDE.md                   # UPDATED: Add configuration section
├── README.md                   # UPDATED: Add environment setup
├── definitions/
│   ├── examples/
│   │   ├── session-api-app-kro.yaml              # EXISTING: Keep as-is
│   │   ├── session-api-app-kro.yaml.template     # NEW: Optional template
│   │   ├── session-api-app-xp.yaml               # EXISTING: Keep as-is
│   │   ├── session-api-app-xp.yaml.template      # NEW: Optional template
│   │   └── ...
│   └── ...
├── tests/
│   ├── common.sh               # NEW: Common test utilities
│   ├── test_localstack.sh      # UPDATED: Use common.sh
│   ├── test_localstack-simple.sh # UPDATED: Use common.sh
│   └── test_kro_integration.sh # UPDATED: Use common.sh
└── ...
```

---

## Usage Examples

### DevContainer (automatic)
```bash
./setup.sh
# Automatically detects DevContainer environment
# Uses .env.devcontainer settings
# All endpoints work automatically
```

### Host Machine (with manual setup)
```bash
# Option 1: Automatic detection (if k3d installed)
./setup.sh

# Option 2: Explicit environment
ENV_TYPE=host ./setup.sh

# Option 3: Custom .env
cp .env.host .env
# Edit .env as needed
./setup.sh --use-env .env
```

### CI/CD
```bash
ENV_TYPE=ci ./setup.sh
# Uses in-cluster service discovery
```

---

## Benefits

✅ **Environment Agnostic**: Works from DevContainer, Host, or CI/CD without changes
✅ **Auto-Detection**: Automatically detects runtime environment
✅ **Backwards Compatible**: Existing yaml files still work
✅ **Flexible**: Users can override with custom .env
✅ **Testable**: All tests work in any environment
✅ **Documented**: Clear configuration documentation
✅ **Reproducible**: Consistent configuration across environments

---

## Implementation Priority

**Phase 1 (CRITICAL)**: Config infrastructure + setup.sh updates
**Phase 2 (HIGH)**: Environment detection + .env files
**Phase 3 (MEDIUM)**: Tests updates
**Phase 4 (LOW)**: Template system + full documentation
**Phase 5 (ONGOING)**: Extend to more environments as needed
