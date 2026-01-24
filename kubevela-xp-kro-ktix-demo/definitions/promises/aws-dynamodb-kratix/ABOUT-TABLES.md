# About DynamoDB Tables in Kratix Promise vs LocalStack Demo

## Why `check-dynamodb-tables.sh` Doesn't See Our Promise Tables

The script in `kubecon-na-2025/kubevela-xp-kro-localstack/` is designed specifically for that demo project, not for the Kratix Promise.

### Key Differences

| Aspect | LocalStack Demo | Kratix Promise |
|--------|-----------------|----------------|
| **Cluster** | kubecon-na-2025 cluster with LocalStack | kubevela-devex k3d cluster |
| **Table Location** | LocalStack (mock AWS) | Not yet created (pending Kratix operator) |
| **Creation Method** | KRO/Crossplane controllers | Kratix workflows + ACK |
| **Script Endpoint** | localhost:4566 (LocalStack) | N/A (no actual tables yet) |
| **Billing** | LocalStack mock DynamoDB | Real AWS (when connected) |

## Current State of Kratix Promise DynamoDB Tables

### ✅ What Exists Now

1. **Promise Definition** - Fully installed in cluster
   ```bash
   kubectl get promise aws-dynamodb-kratix
   ```

2. **DynamoDBRequest CRD** - Available for users to create requests
   ```bash
   kubectl get crd dynamodbrequests.dynamodb.kratix.io
   ```

3. **5 Test Requests** - Created and validated
   ```bash
   kubectl get dynamodbrequests -A
   ```
   - simple-users-table
   - production-orders-table
   - timeseries-metrics-table
   - test-orders-table
   - test-users-table

4. **Full Validation** - All CRD schemas enforced
   - Table name validation (3-255 chars)
   - Region whitelisting (9 AWS regions)
   - Attribute type validation (S/N/B)
   - Key schema constraints
   - Billing mode enforcement

### ❌ What's NOT Happening Yet

**No Actual DynamoDB Tables Created** because:

1. **Kratix Operator Not Running**
   - We only installed the Promise CRD
   - The full Kratix operator would execute the workflows
   - Currently no process monitoring requests for conversion

2. **ACK Manifests Not Generated**
   - The `resource.configure` workflow hasn't executed
   - `workflow.py` hasn't converted requests to ACK Table resources
   - No ACK Table manifests exist yet

3. **ACK Controller Not Processing**
   - Even if manifests were created, ACK needs AWS credentials
   - Tables wouldn't be created in AWS without ACK controller

### Resource Chain (What Would Happen)

```
DynamoDBRequest (created ✅)
    ↓
Kratix Operator detects request (❌ operator not running)
    ↓
resource.configure workflow executes (❌ workflow not running)
    ↓
workflow.py validates and generates manifest (❌ not invoked)
    ↓
ACK Table resource created (❌ not created yet)
    ↓
ACK DynamoDB Controller processes Table (❌ no controller action)
    ↓
AWS DynamoDB table created (❌ no actual table)
```

## What's Needed to Actually Create Tables

### Option 1: Full Kratix Stack (Recommended)

Install the complete Kratix operator and get full Promise functionality:

```bash
# 1. Install Kratix Operator
kubectl apply -f https://github.com/syntasso/kratix/releases/download/v0.4.0/kratix.yaml

# 2. Mark cluster as destination for Promise
kubectl label node --all kratix=enabled

# 3. Mark cluster as ACK-enabled destination
kubectl label node --all cloud=aws ack-enabled=true

# 4. Promises will now automatically execute workflows
# Requests will be converted to ACK Tables and tables created in AWS
```

### Option 2: Manual Workflow Execution (For Testing)

You can manually test the workflow by:

```bash
# 1. Run the workflow script manually on a request
kubectl exec <request-pod> -- python /app/workflow.py

# 2. Inspect the generated ACK manifest
kubectl get tables.dynamodb.services.k8s.aws

# 3. Monitor table creation
kubectl describe table <table-name>
```

### Option 3: Use KubeVela Integration

The Promise is also integrated with KubeVela via ComponentDefinition:

```bash
# Deploy the component definition
kubectl apply -f .development/definitions/components/aws-dynamodb-kratix.cue

# Create tables via KubeVela Application
vela up -f application.yaml
```

## Comparing to LocalStack Demo

The LocalStack demo (`kubecon-na-2025/kubevela-xp-kro-localstack/`) uses:

1. **KRO (Kubernetes Resource Model)**
   - Directly deploys ResourceGraphDefinition
   - KRO watches resources and creates Kubernetes manifestations
   - ACK controller creates tables in LocalStack

2. **Crossplane**
   - Uses Terraform-based AWS provider
   - Creates tables in LocalStack with dummy credentials
   - Different from Kratix (Promise-based platform pattern)

3. **LocalStack**
   - Mock AWS service running in cluster
   - No actual AWS account needed
   - Table data persists in pod

The Kratix Promise uses a different architecture:
- **Promise-based** - Platform-as-product model
- **Workflow-driven** - Explicit workflow steps for configuration
- **Destination-aware** - Routes requests to appropriate clusters
- **Declarative pipelines** - Clear setup/teardown workflows

## Checking Your Tables

### On Kratix Promise Cluster

```bash
# View all requests
docker exec k3d-kubevela-demo-server-0 kubectl get dynamodbrequests -A

# View detailed request
docker exec k3d-kubevela-demo-server-0 kubectl describe dynamodbrequest <name>

# View Promise definition
docker exec k3d-kubevela-demo-server-0 kubectl get promise aws-dynamodb-kratix -o yaml

# Use the helper script
./check-promise-requests.sh
```

### On LocalStack Demo Cluster

```bash
# View tables in LocalStack
./check-dynamodb-tables.sh

# View KRO/Crossplane resources
kubectl get tables -A

# View applications
vela ls -A
```

## Next Steps

To actually create DynamoDB tables with the Kratix Promise:

1. **Install Kratix Operator**
   - Enables workflow execution
   - Monitors requests for conversion
   - Routes requests to destinations

2. **Configure ACK Controller**
   - Provide AWS credentials
   - Enable actual table creation
   - Monitor table status

3. **Test End-to-End**
   - Create DynamoDBRequest
   - Monitor workflow execution
   - Verify table creation in AWS

4. **Deploy via KubeVela**
   - Use ComponentDefinition for abstraction
   - Create tables through Applications
   - Unified platform experience

## Summary

**Current State:** Kratix Promise is fully defined and requests are stored in Kubernetes. The infrastructure for converting requests to actual DynamoDB tables is ready, but requires the Kratix operator to execute the workflows.

**This is by design** - The Promise definition is separate from the operator that executes it, allowing the Promise to be shipped, versioned, and deployed independently.

To use the Promise for actual table creation, install the Kratix operator and configure ACK credentials.
