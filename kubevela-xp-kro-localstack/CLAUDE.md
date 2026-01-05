# CLAUDE.md - LocalStack Demo Developer Guide

This file provides guidance for working on the **LocalStack version** of the KubeVela DynamoDB demo (not the AWS version in `kubevela-xp-kro-ktix-demo`).

## Quick Context

- **Purpose**: Crossplane vs KRO comparison using **LocalStack** (not real AWS)
- **Location**: `/workspaces/workspace/kubecon-na-2025/kubevela-xp-kro-localstack/`
- **AWS Required**: NO - completely local development
- **Table Prefixes**: NO - use simple names like `sessions`, not `tenant-atlantis-sessions`
- **Costs**: FREE - LocalStack runs in your cluster

## DevContainer & Kubeconfig Management

### Simple Solution: Create a Fresh kubeconfig-devcontainer

The simplest approach for DevContainer access is to create a fresh kubeconfig that points to the host cluster using port mapping.

#### One-Command Setup

```bash
# Get the current mapped port and create a new kubeconfig for devcontainer
docker exec k3d-kubevela-demo-server-0 cat /etc/rancher/k3s/k3s.yaml | \
  sed 's|server: https://127.0.0.1:6443|server: https://host.docker.internal:'$(docker port k3d-kubevela-demo-server-0 | grep 6443 | awk '{print $3}' | cut -d: -f2)'|' > kubeconfig-devcontainer

# Verify it works
KUBECONFIG=./kubeconfig-devcontainer kubectl get nodes
KUBECONFIG=./kubeconfig-devcontainer vela ls -A
```

#### What This Does

1. Extracts the kubeconfig from the running k3d server
2. Replaces the `127.0.0.1:6443` (internal k3s port) with `host.docker.internal:<mapped-port>` (DevContainer→Host connection)
3. Creates `kubeconfig-devcontainer` in the project directory
4. Automatically handles TLS certificates and insecure verification

#### Key Points About kubeconfig-devcontainer

- **host.docker.internal** - Special Docker hostname for DevContainer→Host connection
- **Mapped port** - Automatically derived from current `docker port` mapping (changes on cluster restart)
- **Simplified config** - Only includes what's needed, no certificate authority data
- **Works immediately** - No manual editing required after cluster restart

### Legacy Solution: Update kubeconfig-internal Port

If you prefer to keep the existing `kubeconfig-internal` file, you can update just the port:

#### Quick Fix (After Cluster Restart)

```bash
# Get new port and update kubeconfig in one command
NEW_PORT=$(docker port k3d-kubevela-demo-server-0 | grep 6443 | awk '{print $3}' | cut -d: -f2) && \
sed -i "s|server: https://host.docker.internal:[0-9]*$|server: https://host.docker.internal:$NEW_PORT|" kubeconfig-internal && \
KUBECONFIG=./kubeconfig-internal kubectl get nodes
```

#### Manual Fix (3 Steps)

1. Find new port: `docker port k3d-kubevela-demo-server-0 | grep 6443`
2. Edit `kubeconfig-internal` - update the `server:` line with new port
3. Verify: `KUBECONFIG=./kubeconfig-internal kubectl get nodes`

### When to Update Kubeconfig

After cluster restart (from `./setup.sh` or manual `k3d stop/start`):
- If using `kubeconfig-devcontainer`: Re-run the one-command setup
- If using `kubeconfig-internal`: Run the quick fix above
- If you see: `connection refused` or `dial tcp [::1]:8080` errors

### How to Verify It's Working

```bash
KUBECONFIG=./kubeconfig-devcontainer kubectl get nodes
KUBECONFIG=./kubeconfig-devcontainer vela ls -A
KUBECONFIG=./kubeconfig-devcontainer kubectl get pod -A
```

All commands should return without errors.


## Project Context

### Demo Purpose

This project demonstrates Crossplane vs KRO (Kube Resource Orchestrator) for managing DynamoDB tables through KubeVela's OAM abstraction layer, using **LocalStack for local development** instead of AWS.

### Key Components

- **KubeVela** - Application platform with OAM abstractions
- **Crossplane** - Infrastructure provisioning (Upbound AWS provider)
- **KRO** - Kubernetes-native resource orchestration
- **ACK** - AWS Controllers for Kubernetes (manages resources via KRO)
- **LocalStack** - Local AWS emulation (runs in cluster, endpoint: `http://localstack.localstack-system.svc.cluster.local:4566`)
- **k3d** - Kubernetes in Docker (runs on host machine)
- **DevContainer** - Development environment (runs in separate container)

### Important Files

- `kubeconfig-internal` - Local kubeconfig for DevContainer→k3d connection (only update port)
- `setup.sh` - Automated setup script that creates everything
- `definitions/components/` - KubeVela component definitions
- `definitions/examples/` - Sample applications demonstrating features
- `README.md` - Main documentation

## Component Definitions to Know

### Crossplane Components

- **aws-dynamodb-simple-xp.cue** - Simplified Crossplane DynamoDB component
  - Uses Crossplane Upbound AWS provider
  - Table name set via `crossplane.io/external-name` annotation
  - **NO prefix** - uses simple names like `user-sessions`
  - Pre-configured with basic settings (partition key `id`, PAY_PER_REQUEST)
  - Default region: `us-west-2`

### KRO Components

- **aws-dynamodb-simple-kro.cue** - Simplified KRO DynamoDB component
  - Uses KRO + ACK for resource management via LocalStack
  - **NO prefix** - uses simple names like `user-sessions`
  - ResourceGraphDefinition: `simple-dynamodb-rgd.yaml`
  - Pre-configured with basic settings (partition key `id`, PAY_PER_REQUEST)
  - Default region: `us-west-2`

## LocalStack Table Naming: Simple Names (No Prefix)

**✨ KEY DIFFERENCE FROM AWS DEMO**: Table names in LocalStack do **NOT** require `tenant-atlantis-` prefix!

### Why No Prefix?

LocalStack is a local development environment - no IAM policy constraints. You can use simple, clean table names:
- ✅ `user-sessions` instead of `tenant-atlantis-user-sessions`
- ✅ `orders` instead of `tenant-atlantis-orders`
- ✅ `products` instead of `tenant-atlantis-products`

This makes LocalStack demo **community-friendly** and prefix-free!

### Table Naming in LocalStack Demo

| Component Type | Table Name | Example |
|---|---|---|
| **Crossplane Simple** | Component name (via external-name) | Component named `user-sessions` → Table: `user-sessions` |
| **KRO Simple** | tableName parameter | Pass `tableName: sessions` → Table: `sessions` |

### In Application YAML

```yaml
# Simple table name - no prefix needed!
- name: user-sessions
  type: aws-dynamodb-simple-kro
  properties:
    tableName: user-sessions  # ← Just "user-sessions", not "tenant-atlantis-user-sessions"
    region: us-west-2
```

### In Application Code

Environment variables also use simple names:

```yaml
env:
  - name: DYNAMODB_TABLE_NAME
    value: "user-sessions"  # ← No prefix needed!
  - name: AWS_REGION
    value: "us-west-2"
  - name: LOCALSTACK_ENDPOINT
    value: "http://localstack.localstack-system.svc.cluster.local:4566"
```

### Verification

Check created tables:

```bash
# List SimpleDynamoDB KRO resources
KUBECONFIG=./kubeconfig-internal kubectl get simpledynamodb.kro.run -A
# Shows: user-sessions, orders, etc. (no prefix)

# List Crossplane resources
KUBECONFIG=./kubeconfig-internal kubectl get table.dynamodb.aws.upbound.io -A
# Shows: user-sessions-table, etc. (no prefix)
```

### Accessing LocalStack Tables

Tables are accessible via LocalStack endpoint (set in controllers):

```bash
# List tables in LocalStack
kubectl run aws-cli --image=amazon/aws-cli --rm -it --restart=Never -- \
  --endpoint-url=http://localstack.localstack-system.svc.cluster.local:4566 \
  --region=us-west-2 \
  dynamodb list-tables
```

## Common Issues and Solutions

### Issue: LocalStack tables not created or not accessible

**Problem**: Pod can't connect to DynamoDB table

**Root Cause**: Either LocalStack not running or endpoint not configured in controller

**Verify LocalStack is running**:
```bash
KUBECONFIG=./kubeconfig-internal kubectl get pods -n localstack-system -l app.kubernetes.io/name=localstack
# Should show 1 running pod
```

**Check LocalStack logs**:
```bash
KUBECONFIG=./kubeconfig-internal kubectl logs -n localstack-system -l app.kubernetes.io/name=localstack
```

**Fix**:
1. Ensure setup.sh completed Phase 2.5 (LocalStack installation)
2. Verify ACK controller has LocalStack endpoint: `--set aws.endpoint_url=http://localstack...`
3. Verify Crossplane ProviderConfig has LocalStack endpoint
4. Wait 30 seconds after table creation (status eventually becomes ACTIVE)

### Issue: Pod not reaching ready state

**Problem**: Application pod shows `Ready: 0/1`

**Root Cause**: Can't connect to DynamoDB table (LocalStack not running, table not created, or endpoint wrong)

**Check logs**:
```bash
KUBECONFIG=./kubeconfig-internal kubectl logs -n default <pod-name>
# Look for connection errors or table not found
```

**Checklist**:
1. Is LocalStack pod running? `kubectl get pods -n localstack-system`
2. Is DynamoDB table created? `kubectl get simpledynamodb -A` or `kubectl get table.dynamodb.aws.upbound.io -A`
3. Does pod have LOCALSTACK_ENDPOINT env var set?
4. Is table name correct (matches DYNAMODB_TABLE_NAME)?

**Fix**:
```bash
# Wait a bit for table creation
sleep 10

# Check table status
KUBECONFIG=./kubeconfig-internal kubectl describe simpledynamodb <table-name> -n default

# Check ACK table status
KUBECONFIG=./kubeconfig-internal kubectl describe table <table-name>.dynamodb.services.k8s.aws -n default
```

### Issue: kubectl doesn't work after setup.sh

**Fix**: Update kubeconfig-internal port (see "Quick Fix" section at top of file)

### Issue: LocalStack credentials errors

**Problem**: Pods get authentication errors even though `test`/`test` credentials are set

**Root Cause**: Credentials not propagated to pod environment or controller config

**Check controller config**:
```bash
# For ACK
KUBECONFIG=./kubeconfig-internal kubectl get deployment -n ack-system
KUBECONFIG=./kubeconfig-internal kubectl describe deployment ack-dynamodb-controller -n ack-system
# Look for aws_access_key_id and aws_secret_access_key in env

# For Crossplane
KUBECONFIG=./kubeconfig-internal kubectl get providerconfigusage -A
```

**Fix**: Credentials should be `test`/`test` (hardcoded for LocalStack). If getting auth errors, check:
1. setup.sh Phase 5.4 completed (LocalStack credentials created)
2. ACK controller has `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` env vars
3. Application has `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` env vars

## When Working With This Project

### Before Starting Any Task

1. Check if cluster is running: `docker ps | grep k3d`
2. If not running or after setup.sh: Fix kubeconfig-internal using quick fix
3. Verify: `KUBECONFIG=./kubeconfig-internal kubectl get nodes`

### Using kubectl or vela

Always use full kubeconfig path:
```bash
# Good
KUBECONFIG=./kubeconfig-internal kubectl get nodes
KUBECONFIG=./kubeconfig-internal vela ls -A

# Bad (won't work in DevContainer)
kubectl get nodes
vela ls -A
```

### Checking Application Status

```bash
# All applications
KUBECONFIG=./kubeconfig-internal vela ls -A

# Single application
KUBECONFIG=./kubeconfig-internal vela status <app-name>

# Kubernetes resources
KUBECONFIG=./kubeconfig-internal kubectl get pods -A
```

### Deploying Applications

```bash
# Deploy from YAML
KUBECONFIG=./kubeconfig-internal vela up -f definitions/examples/my-app.yaml

# Delete application
KUBECONFIG=./kubeconfig-internal vela delete <app-name> --namespace default -y
```

## MCP Server Usage

Follow the global CLAUDE.md rules:
- Use DeepWiki for KubeVela, Crossplane, KRO, ACK questions
- Use Context7 for code generation and documentation
- Start with actual code implementation, not documentation

## Project-Specific Patterns

### Component Definition Pattern

```cue
// 1. Define the component interface
"component-name": {
  type: "component"
  description: "..."
  attributes: {
    workload: {...}
    status: {...}
  }
}

// 2. Define the template
template: {
  output: {
    // What Kubernetes resource to create
  }
  parameter: {
    // What users specify in Application
  }
}
```

### Application Deployment Pattern

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: my-app
spec:
  components:
    - name: resource-name
      type: component-type
      properties: {...}
    - name: api-service
      type: webservice
      properties: {...}
      traits:
        - type: trait-type
```

### Testing Pattern

After deploying an application:
```bash
1. Check component status: KUBECONFIG=./kubeconfig-internal vela status <app-name>
2. Check Kubernetes resources: KUBECONFIG=./kubeconfig-internal kubectl get <resource-type>
3. Check logs: KUBECONFIG=./kubeconfig-internal kubectl logs -n default <pod-name>
4. Test connectivity: KUBECONFIG=./kubeconfig-internal kubectl port-forward ...
```

## Documentation Structure

- **README.md** - Main project overview and demo architecture
- **CLAUDE.md** - This file: AI assistant guidance and operational reference
- **CHANGELOG.md** - Historical record of changes and fixes
- **IAM_POLICY.md** - AWS IAM policy requirements and scoping
- **app/README.md** - Session management API application documentation
- **definitions/components/*.md** - Component definition reference
- **definitions/examples/*/README.md** - Executable example walkthroughs
- **definitions/traits/DYNAMODB-KRO-TRAITS-README.md** - Traits overview

## Important Notes

- ✅ The setup is fully functional and tested
- ✅ All applications are currently healthy
- ✅ All tables have correct `tenant-atlantis-` prefix
- ✅ Kubeconfig works when port is correct
- ⚠️ Only the port number needs updating after restart
- ⚠️ Don't regenerate kubeconfig from scratch (just update port)
- ⚠️ Don't edit client certificates or auth sections

## Future Improvements (Documented for Reference)

If working on improvements:
- Document any kubeconfig-related fixes in CLAUDE.md
- Update component definitions if prefix logic changes
- Update applications if table naming changes
- Update tests if resource creation patterns change

---

**Last Updated**: December 30, 2025
**Tested With**: DevContainer, k3d, Docker Desktop, Kubernetes v1.28
**Status**: Production-ready with full DevContainer support documented
