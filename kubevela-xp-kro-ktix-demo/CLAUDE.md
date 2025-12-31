# CLAUDE.md - Project-Specific Instructions for AI Assistants

This file provides guidance to Claude Code and AI assistants working on this KubeVela DynamoDB demo project in a DevContainer environment.

## DevContainer & Kubeconfig Management

### Critical: Fix kubeconfig-internal After Cluster Restart

**When the user runs `./setup.sh` or restarts the k3d cluster:**

The k3d cluster gets a **new random API server port**. The `kubeconfig-internal` file has the **old port** and needs updating.

#### Quick Fix (Use This!)

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

#### Key Points About kubeconfig-internal

- **host.docker.internal** - Special Docker hostname for DevContainer→Host connection (don't change)
- **insecure-skip-tls-verify: true** - Required for k3d self-signed certificates (don't remove)
- **Port number** - This is the ONLY thing that changes (update it from new port)
- **Client certificates** - Don't need regeneration (they work across container boundary)

### When to Fix kubeconfig-internal

- After user runs `./setup.sh`
- After user restarts the cluster
- After `kubectl` commands fail with connection refused errors
- If you see: `dial tcp [::1]:8080: connect: connection refused`

### How to Verify It's Working

```bash
KUBECONFIG=./kubeconfig-internal kubectl get nodes
KUBECONFIG=./kubeconfig-internal vela ls -A
```

Both should work without errors.


## Project Context

### Demo Purpose

This project demonstrates Crossplane vs KRO (Kube Resource Orchestrator) for managing AWS DynamoDB tables through KubeVela's OAM abstraction layer.

### Key Components

- **KubeVela** - Application platform with OAM abstractions
- **Crossplane** - Multi-cloud infrastructure provisioning
- **KRO** - Kubernetes-native resource orchestration
- **ACK** - AWS Controllers for Kubernetes (manages actual AWS resources)
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

- **aws-dynamodb-xp.cue** - Crossplane-based DynamoDB component
  - Uses Crossplane Upbound provider
  - Table name set via `crossplane.io/external-name` annotation
  - All tables automatically prefixed with `tenant-atlantis-`

### KRO Components

- **aws-dynamodb-kro.cue** - Full-featured KRO DynamoDB component
  - Uses KRO + ACK for AWS resource management
  - Supports inline parameters + traits
  - Full AWS API available

- **aws-dynamodb-simple-kro.cue** - Simplified KRO component
  - Uses ResourceGraphDefinition that adds `tenant-atlantis-` prefix
  - Note: Component passes base name; RGD adds the prefix
  - Don't double-add the prefix in the component

## AWS Resource Naming: tenant-atlantis- Prefix (CRITICAL)

**⚠️ CRITICAL REQUIREMENT**: All AWS DynamoDB tables MUST be prefixed with `tenant-atlantis-` to comply with IAM policy constraints.

### Why This Matters

The AWS IAM policy for this demo is scoped to only allow DynamoDB operations on tables that:
- Start with `tenant-atlantis-` prefix
- Are in the `us-west-2` region

Any table created without this prefix will be **immediately blocked by IAM** with `AccessDeniedException`.

### How Prefix Is Applied (By Component Type)

| Component Type | Method | Example |
|---|---|---|
| **Crossplane (aws-dynamodb-xp)** | `crossplane.io/external-name` annotation | Annotation: `tenant-atlantis-sessions-table` |
| **KRO Simple (aws-dynamodb-simple-kro)** | RGD automatically adds prefix | Pass `sessions-simple` → Creates `tenant-atlantis-sessions-simple` |
| **KRO Full (aws-dynamodb-kro)** | Component template adds prefix | Pass `my-table` → Sends `tenant-atlantis-my-table` to KRO |

### In Application YAML

When defining a DynamoDB component:

```yaml
# User specifies BASE name (without prefix)
- name: my-sessions-table
  type: aws-dynamodb-simple-kro
  properties:
    tableName: sessions  # ← User provides just "sessions"
    region: us-west-2
```

The component/RGD creates the actual AWS table as: `tenant-atlantis-sessions`

### In Application Code

When the application accesses the table, it MUST use the full prefixed name:

```yaml
# Environment variable MUST include the prefix
env:
  - name: DYNAMODB_TABLE_NAME
    value: "tenant-atlantis-sessions"  # ← Application uses full name
  - name: AWS_REGION
    value: "us-west-2"
```

### Verification

To verify a table was created with the correct prefix:

```bash
# Check what tables exist in AWS
KUBECONFIG=./kubeconfig-internal kubectl get dynamodbtable.dynamodb.services.k8s.aws -A

# Check actual table name from KRO resource
KUBECONFIG=./kubeconfig-internal kubectl get simpledynamodb.kro.run -A
```

Both should show `tenant-atlantis-*` naming.

### Common Mistake: Double Prefix

**Problem**: If both component AND RGD add the prefix:
```
User passes: "sessions"
Component adds prefix: "tenant-atlantis-sessions"
RGD adds prefix again: "tenant-atlantis-tenant-atlantis-sessions" ← WRONG!
```

**Solution**: For KRO Simple components, pass only the base name; the RGD adds the prefix automatically.

### Common Mistake: Application Using Wrong Table Name

**Problem**: Application tries to access table without prefix:
```
Application tries: DYNAMODB_TABLE_NAME="sessions"
Actual table name: "tenant-atlantis-sessions"
Result: IAM AccessDeniedException
```

**Solution**: Always use full prefixed name in application configuration.

### Reference IAM Policy

The demo uses an IAM policy like:
```json
{
  "Effect": "Allow",
  "Action": ["dynamodb:*"],
  "Resource": "arn:aws:dynamodb:us-west-2:*:table/tenant-atlantis-*"
}
```

Only resources matching `tenant-atlantis-*` pattern are allowed.

## Table Naming Convention

All DynamoDB table names follow this pattern:
- **Pattern**: `tenant-atlantis-<base-name>`
- **Example**: `tenant-atlantis-sessions`, `tenant-atlantis-users`, `tenant-atlantis-orders`
- **Requirement**: Non-negotiable due to IAM policy scoping
- **Best Practice**: Design table names to be descriptive after the prefix

### How It Works Across Components

- **Crossplane**: Uses `crossplane.io/external-name` annotation with prefix
- **KRO (simple)**: RGD automatically adds prefix to tableName
- **KRO (full)**: Component explicitly adds prefix (no RGD auto-prefixing)

### In Applications

When an application references a table:
- If using simple KRO component: actual table is `tenant-atlantis-<base-name>`
- Application must use full name: `DYNAMODB_TABLE_NAME=tenant-atlantis-<base-name>`

## Common Issues and Solutions

### Issue: IAM AccessDeniedException on DynamoDB operations

**Problem**: Table operations fail with "User is not authorized to perform: dynamodb:* on resource: arn:aws:dynamodb:us-west-2:*:table/MY_TABLE_NAME"

**Root Cause**: Table name doesn't start with `tenant-atlantis-` prefix. IAM policy only allows tables matching `tenant-atlantis-*` pattern.

**Fix**:
1. Verify table name in AWS: `aws dynamodb list-tables --region us-west-2`
2. Check table name format: Should be `tenant-atlantis-<name>`
3. If table has wrong name: Delete and redeploy application
4. Verify application environment variable has full prefixed name

**Prevention**: Always ensure:
- Components add the prefix (Crossplane annotation, KRO template)
- Applications use the full prefixed table name in environment variables

### Issue: kubectl doesn't work after setup.sh

**Fix**: Update kubeconfig-internal port (see "Quick Fix" section at top of file)

### Issue: Crossplane tables failing with AccessDeniedException

**Check**: Are tables created with correct `tenant-atlantis-` prefix?

**Verify**:
```bash
KUBECONFIG=./kubeconfig-internal kubectl get table.dynamodb.aws.upbound.io -A
# Check the external-name annotation - should be tenant-atlantis-*
```

**Fix**: Ensure:
- Crossplane components use `crossplane.io/external-name` annotation with prefix
- Annotation value: `tenant-atlantis-<base-name>`
- Applications use correct full table names in environment variables

### Issue: KRO SimpleDynamoDB tables have double prefix

**Problem**: If component adds prefix AND RGD adds prefix → `tenant-atlantis-tenant-atlantis-*`

**Identify**:
```bash
KUBECONFIG=./kubeconfig-internal kubectl get simpledynamodb -A
# Check tableName - should be "tenant-atlantis-<base>" not "tenant-atlantis-tenant-atlantis-<base>"
```

**Fix**: Component should pass base name; RGD will add prefix automatically

**Correct Pattern**:
- User specifies: `tableName: sessions`
- Component passes to KRO: `tableName: sessions` (base name only)
- RGD adds prefix: `tenant-atlantis-sessions` (final AWS table name)

### Issue: Application pods not ready - ReadinessProbe failing

**Problem**: Pod shows `Ready:0/1`, logs show `AccessDeniedException`

**Root Cause**: Application is looking for table with wrong name

**Identify**:
```bash
KUBECONFIG=./kubeconfig-internal kubectl logs -n default <pod-name> | grep -i "arn:aws:dynamodb"
# Look for the table name being accessed
```

**Fix**: Update `DYNAMODB_TABLE_NAME` environment variable to full prefixed name:
```yaml
env:
  - name: DYNAMODB_TABLE_NAME
    value: "tenant-atlantis-sessions"  # ← Must include prefix
```

Then redeploy the application:
```bash
KUBECONFIG=./kubeconfig-internal vela delete <app-name> --namespace default -y
KUBECONFIG=./kubeconfig-internal vela up -f definitions/examples/<app>.yaml
```

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
