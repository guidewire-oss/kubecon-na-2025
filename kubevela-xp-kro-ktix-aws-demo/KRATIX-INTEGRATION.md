# Kratix Promise Integration with KubeVela

This document describes the Kratix Promise integration in the KubeCon NA 2025 DynamoDB Demo.

## Overview

Kratix is a platform framework that allows platform teams to define **Promises** - abstract interfaces that hide infrastructure complexity from end users. This demo integrates Kratix promises into the KubeVela application platform, demonstrating how to deploy and use Kratix promises through KubeVela's OAM abstraction layer.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│           KubeVela Application Platform                 │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │  kratix-platform (KubeVela Application)         │   │
│  │                                                  │   │
│  │  - Deploys Kratix Promise Deployer component    │   │
│  │  - Creates DynamoDB Promise instance            │   │
│  │  - Manages lifecycle of Kratix promises         │   │
│  └──────────────────────────────────────────────────┘   │
│                          │                              │
└──────────────────────────┼──────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│         Kratix Promise Framework                        │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │  aws-dynamodb-kratix (Promise)                   │   │
│  │  - Validates DynamoDB table requests            │   │
│  │  - Provisions tables on cluster                 │   │
│  │  - Manages table lifecycle                      │   │
│  └──────────────────────────────────────────────────┘   │
│                          │                              │
│  ┌──────────────────────────────────────────────────┐   │
│  │  DynamoDBRequest CRD                             │   │
│  │  - User-friendly API for table creation         │   │
│  │  - Auto-discovers promise requirements          │   │
│  └──────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│            AWS DynamoDB Service                         │
└─────────────────────────────────────────────────────────┘
```

## Components

### 1. Kratix Promise Deployer Component (`kratix-promise-deployer.cue`)

**Type:** KubeVela ComponentDefinition

A reusable component for deploying Kratix promises. This component abstracts away the complexity of the Promise API and provides a simplified interface for users.

**Features:**
- Deploys individual Kratix promises to the cluster
- Configures promise metadata (version, platform, service)
- Sets destination selectors for where promises execute
- Manages promise lifecycle

**Usage:**
```yaml
- name: dynamodb-promise
  type: kratix-promise-deployer
  properties:
    version: "0.1.0"
    platform: "aws"
    service: "dynamodb"
    api: { ... }
    destinationSelectors:
      - matchLabels:
          cluster-role: "master"
```

### 2. AWS DynamoDB Kratix Component (`aws-dynamodb-kratix.cue`)

**Type:** KubeVela ComponentDefinition

A specialized component for creating DynamoDB tables through the Kratix promise.

**Features:**
- Creates `DynamoDBRequest` resources (promise API)
- Supports all DynamoDB table configurations
- Flexible billing modes (PAY_PER_REQUEST or PROVISIONED)
- Configurable throughput for provisioned tables

**Properties:**
- `tableName`: Name of the DynamoDB table
- `region`: AWS region (us-east-1, us-west-2, eu-west-1, etc.)
- `billingMode`: PAY_PER_REQUEST (default) or PROVISIONED
- `attributeDefinitions`: Attributes for the table
- `keySchema`: Partition and sort key configuration
- `provisioned`: Read/write capacity units (if PROVISIONED mode)

**Example:**
```yaml
- name: user-sessions-table
  type: aws-dynamodb-kratix
  properties:
    tableName: "user-sessions"
    region: "us-west-2"
    billingMode: "PAY_PER_REQUEST"
    attributeDefinitions:
      - name: "sessionId"
        type: "S"
    keySchema:
      - attributeName: "sessionId"
        keyType: "HASH"
```

### 3. Kratix Platform Application (`kratix-platform-app.yaml`)

**Type:** KubeVela Application

A complete application that deploys the Kratix promise framework and demonstrates its usage.

**Components:**
- **dynamodb-promise**: Deploys the aws-dynamodb-kratix promise
- **example-dynamodb-table**: Creates a sample DynamoDB table using the promise

**Lifecycle:**
1. Application is submitted to KubeVela
2. KubeVela creates the Kratix promise in the cluster
3. Kratix promise becomes available for end users
4. Example DynamoDB table is created to demonstrate usage

## Deployment Flow

### Phase 2.5: Kratix Deployment (in Setup.sh)

The setup script automatically deploys Kratix as part of the installation process:

```bash
# 1. Deploy Kratix Promise Deployer component definition
vela def apply definitions/components/kratix-promise-deployer.cue

# 2. Deploy KubeVela application with Kratix promise
vela up -f definitions/examples/kratix-platform-app.yaml

# This creates:
# - Kratix promise in the cluster
# - Example DynamoDB table
```

## Using Kratix Promises

### Creating DynamoDB Tables via Kratix

Once the Kratix promise is deployed, users can create tables by creating DynamoDBRequest resources:

```yaml
apiVersion: dynamodb.kratix.io/v1alpha1
kind: DynamoDBRequest
metadata:
  name: my-table
spec:
  name: user-data
  region: us-west-2
  billingMode: PAY_PER_REQUEST
  attributeDefinitions:
    - name: userId
      type: S
  keySchema:
    - attributeName: userId
      keyType: HASH
```

### Checking Promise Status

```bash
# List deployed promises
kubectl get promise.platform.kratix.io -A

# List DynamoDB requests (tables)
kubectl get dynamodbrequests.dynamodb.kratix.io -A

# Check Kratix platform application status
vela status kratix-platform
```

## File Structure

```
definitions/
├── components/
│   ├── kratix-promise-deployer.cue     # Promise deployer component
│   ├── aws-dynamodb-kratix.cue         # DynamoDB component
│   ├── kratix-installer.cue            # Kratix platform installer (optional)
│   └── ...
├── examples/
│   ├── kratix-platform-app.yaml        # Kratix platform application
│   └── ...
└── promises/
    └── aws-dynamodb-kratix/
        ├── promise.yaml                # Kratix promise definition
        ├── workflow.py                 # Promise workflow (implementation)
        ├── test-request-example.yaml   # Example DynamoDB request
        └── ...
```

## Key Features

### 1. KubeVela Integration

Kratix promises are deployed and managed through KubeVela applications:
- Single source of truth for infrastructure abstractions
- Unified application deployment experience
- Traits can be applied to promises
- Labels and annotations for organization

### 2. Promise Abstraction

Promises hide implementation details:
- Users create simple `DynamoDBRequest` resources
- Kratix handles table provisioning
- No need to understand DynamoDB API complexity
- Platform team controls implementation

### 3. Flexibility

Supports both simple and advanced configurations:
- Basic tables (partition key only)
- Tables with sort keys
- Provisioned vs on-demand billing
- Optional advanced features

## Comparison with Other Approaches

| Feature | Kratix | Crossplane | KRO |
|---------|--------|-----------|-----|
| **Abstraction** | Promise (custom API) | Composite resources | ResourceGraph |
| **KubeVela** | Native (this demo) | Via component | Via component |
| **User API** | Simple custom CRD | Crossplane XRD | AWS API directly |
| **Implementation** | Workflow-based | Python/Go provider | ACK + KRO |
| **Learning Curve** | Medium | Medium | Low (AWS-native) |

## Advanced Topics

### Customizing Promises

To extend the DynamoDB promise with additional features:

1. **Edit** `definitions/promises/aws-dynamodb-kratix/promise.yaml`
2. **Add** new fields to the CRD schema
3. **Update** `workflow.py` to handle new fields
4. **Test** with example requests

### Promise Workflow

The promise workflow (`workflow.py`) handles:
- Request validation
- Table provisioning logic
- Status updates
- Error handling

### Monitoring and Observability

Track promise requests:

```bash
# Watch all DynamoDB requests
watch kubectl get dynamodbrequests.dynamodb.kratix.io -A

# Check specific request details
kubectl describe dynamodbrequest <name>

# View request status and conditions
kubectl get dynamodbrequests.dynamodb.kratix.io -o jsonpath='{.items[*].status}'
```

## Troubleshooting

### Promise Not Appearing

```bash
# Check if promise was deployed
kubectl get promise.platform.kratix.io -n kratix

# Check application status
vela status kratix-platform

# View application details
vela status kratix-platform --detail
```

### DynamoDB Requests Not Provisioning

```bash
# Check request status
kubectl describe dynamodbrequest <name>

# Check promise logs
kubectl logs -n kratix -l app=aws-dynamodb-kratix-promise

# Verify AWS credentials are configured
kubectl get secret ack-dynamodb-user-secrets -A
```

### Kratix Promise Component Errors

```bash
# Verify component definition is registered
vela components | grep kratix

# Apply the component definition
vela def apply definitions/components/kratix-promise-deployer.cue

# Check application events
kubectl describe app kratix-platform
```

## References

- [Kratix Documentation](https://kratix.io/)
- [KubeVela Documentation](https://kubevela.io/)
- [Open Application Model](https://oam.dev/)
- [AWS DynamoDB API](https://docs.aws.amazon.com/dynamodb/)

## Next Steps

1. **Deploy the environment** using `./Setup.sh`
2. **Create DynamoDB tables** using the Kratix promise
3. **Compare implementations** across Kratix, Crossplane, and KRO
4. **Extend the promise** with additional DynamoDB features
5. **Build custom promises** for your platform needs

## Architecture Diagram

```
User Application
    │
    ▼
KubeVela Application (kratix-platform)
    │
    ├─> kratix-promise-deployer component
    │   └─> Deploys Promise
    │
    └─> aws-dynamodb-kratix component
        └─> Creates DynamoDBRequest
            │
            ▼
        Kratix Promise (aws-dynamodb-kratix)
            │
            ▼
        Promise Workflow (workflow.py)
            │
            ▼
        ACK DynamoDB Controller
            │
            ▼
        AWS DynamoDB Table (Actual Resource)
```

---

**Last Updated:** January 16, 2026
**Status:** Production Ready
**Demo Version:** 1.0
