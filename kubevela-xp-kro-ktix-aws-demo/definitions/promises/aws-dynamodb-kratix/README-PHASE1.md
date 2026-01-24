# DynamoDB Kratix Promise - Phase 1 Development

## Overview

This is a Kratix Promise implementation for AWS DynamoDB, enabling platform teams to provide DynamoDB table provisioning as a self-service API through Kratix.

## Files in This Directory

### promise.yaml
The main Kratix Promise definition containing:
- **spec.api**: Defines the CRD schema for user requests (DynamoDBRequest)
- **spec.dependencies**: Kubernetes resources required (ACK controller, RBAC)
- **spec.workflows**: Promise and resource-level workflows
- **spec.destinationSelectors**: Routes for request scheduling

### Dockerfile
Container image for the `resource.configure` workflow that:
- Base image: python:3.11-slim
- Installs Python dependencies (pyyaml, kubernetes, requests)
- Runs workflow.py to generate ACK Table manifests

### workflow.py
Python script executed during resource.configure workflow that:
- Validates the DynamoDB request parameters
- Generates an ACK (AWS Controllers for Kubernetes) Table manifest
- Writes the manifest to Kratix's state store
- Includes comprehensive error handling and validation

## Implementation Details

### API Schema (DynamoDBRequest)

**Required Fields:**
- `name` (string): DynamoDB table name (3-255 chars, alphanumeric + . _ -)
- `region` (string): AWS region (us-east-1, eu-west-1, etc.)
- `attributeDefinitions` (array): Table attributes with name and type (S/N/B)
- `keySchema` (array): Partition and optional sort key definition

**Optional Fields:**
- `billingMode` (string): PAY_PER_REQUEST (default) or PROVISIONED
- `provisioned` (object): Read/write capacity units (required for PROVISIONED mode)
  - `readCapacity` (integer): 1-40000, default 5
  - `writeCapacity` (integer): 1-40000, default 5

### Workflow Execution Flow

```
User creates DynamoDBRequest
    ↓
Kratix detects new request
    ↓
resource.configure workflow executes (workflow.py in container)
    ↓
workflow.py validates request parameters
    ↓
workflow.py generates ACK Table manifest
    ↓
Manifest written to state store
    ↓
Kratix applies manifest to cluster
    ↓
ACK controller receives Table resource
    ↓
ACK interacts with AWS API to create table
    ↓
DynamoDB table created in AWS
```

### Error Handling

The workflow.py script validates:
- Table name format and length
- Region is in allowed list
- Attribute types are valid (S/N/B)
- Key schema references defined attributes
- Key schema has exactly one HASH key
- Capacity units are within AWS limits (1-40000)
- Billing mode and capacity settings are consistent

All validation errors include clear messages for troubleshooting.

## Building the Workflow Image

The Dockerfile is ready to build:

```bash
cd .development/promises/aws-dynamodb-kratix/
docker build -t kratix/dynamodb-resource-configure:0.1.0 .
```

Then push to a registry accessible to your Kratix cluster:

```bash
docker push kratix/dynamodb-resource-configure:0.1.0
```

## Installing the Promise

Once the workflow image is built and available:

```bash
kubectl apply -f promise.yaml
```

Verify installation:

```bash
kubectl get promises
kubectl get crds | grep dynamodb
```

## Using the Promise

Create a DynamoDBRequest:

```yaml
apiVersion: dynamodb.kratix.io/v1alpha1
kind: DynamoDBRequest
metadata:
  name: my-users-table
  namespace: default
spec:
  name: users-table
  region: us-east-1
  billingMode: PAY_PER_REQUEST
  attributeDefinitions:
    - name: userId
      type: S
    - name: email
      type: S
  keySchema:
    - attributeName: userId
      keyType: HASH
```

Check status:

```bash
kubectl get dynamodbrequests
kubectl get dynamodbrequests my-users-table -o yaml
```

Once the Promise is installed and ACK controller is running, the request will trigger table creation.

## KubeVela Integration

The ComponentDefinition (`aws-dynamodb-kratix.cue`) allows KubeVela users to provision DynamoDB tables:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: my-app
spec:
  components:
    - name: my-table
      type: aws-dynamodb-kratix
      properties:
        tableName: my-users-table
        region: us-east-1
        attributeDefinitions:
          - name: userId
            type: S
        keySchema:
          - attributeName: userId
            keyType: HASH
```

## Testing

### Manual Testing

1. Build workflow image
2. Push to registry
3. Install Promise
4. Create a test DynamoDBRequest
5. Monitor ACK controller logs: `kubectl logs -n ack-system -l app=dynamodb-controller`
6. Verify table in AWS console

### Test Request Example

```yaml
apiVersion: dynamodb.kratix.io/v1alpha1
kind: DynamoDBRequest
metadata:
  name: test-table
  namespace: default
spec:
  name: test-dynamodb-table
  region: us-east-1
  billingMode: PROVISIONED
  attributeDefinitions:
    - name: pk
      type: S
    - name: sk
      type: N
  keySchema:
    - attributeName: pk
      keyType: HASH
    - attributeName: sk
      keyType: RANGE
  provisioned:
    readCapacity: 10
    writeCapacity: 10
```

## Next Steps (Phase 2+)

Future enhancements:
- Add support for GSI and LSI
- Add support for streams
- Add encryption support
- Add TTL configuration
- Create example manifests
- Add comprehensive documentation
- Build slash commands for Promise management

## Notes

- This is Phase 1: minimal scope with core functionality
- Workflow image path is placeholder and must be updated before deployment
- ACK controller must be installed separately or via dependencies
- Table status updates depend on ACK controller's status reporting
