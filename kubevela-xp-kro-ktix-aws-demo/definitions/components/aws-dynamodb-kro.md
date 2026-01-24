# AWS DynamoDB Component (KRO)

## Overview

The `aws-dynamodb-kro` component enables you to provision and manage AWS DynamoDB tables using **KRO (Kube Resource Orchestrator)** and **ACK (AWS Controllers for Kubernetes)** instead of Crossplane. This component provides a KubeVela-native interface to DynamoDB while leveraging the power of KRO for resource orchestration and ACK for direct AWS API integration.

### Architecture

```
KubeVela Application
       ↓
ComponentDefinition (aws-dynamodb-kro)
       ↓
KRO ResourceGraphDefinition
       ↓
ACK DynamoDB Table CRD
       ↓
AWS DynamoDB Service
```

### Key Benefits

- **Native Kubernetes Integration**: Uses ACK controllers that directly interact with AWS APIs
- **Simplified Orchestration**: KRO handles resource dependencies and lifecycle
- **Status Propagation**: Automatic status updates from AWS resources to KubeVela
- **No External Operators**: No need for Crossplane infrastructure
- **Declarative Management**: Full GitOps compatibility

## Prerequisites

Before using this component, ensure you have:

1. **KRO installed** in your Kubernetes cluster
   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/kro/releases/latest/download/kro.yaml
   ```

2. **ACK DynamoDB Controller** installed
   ```bash
   export ACK_K8S_NAMESPACE=ack-system

   helm repo add aws-controllers-k8s https://aws-controllers-k8s.github.io/charts
   helm install dynamodb-chart aws-controllers-k8s/dynamodb-chart \
     --namespace $ACK_K8S_NAMESPACE \
     --create-namespace
   ```

3. **AWS Credentials** configured via IRSA, IAM roles, or AWS credentials
   - For EKS with IRSA (recommended):
     ```bash
     eksctl create iamserviceaccount \
       --name ack-dynamodb-controller \
       --namespace ack-system \
       --cluster my-cluster \
       --attach-policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess \
       --approve \
       --override-existing-serviceaccounts
     ```

4. **ComponentDefinition applied** to your cluster
   ```bash
   vela def apply .development/definitions/components/aws-dynamodb-kro.cue
   ```

## Usage

### Basic Example

Create a simple DynamoDB table with on-demand billing:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: user-table-app
  namespace: default
spec:
  components:
    - name: user-table
      type: aws-dynamodb-kro
      properties:
        tableName: users-table
        region: us-east-1
        billingMode: PAY_PER_REQUEST

        attributeDefinitions:
          - attributeName: userId
            attributeType: S

        keySchema:
          - attributeName: userId
            keyType: HASH
```

### With Global Secondary Index

Add a GSI for querying by email:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: user-table-with-gsi
  namespace: default
spec:
  components:
    - name: user-table
      type: aws-dynamodb-kro
      properties:
        tableName: users-table
        region: us-east-1
        billingMode: PAY_PER_REQUEST

        attributeDefinitions:
          - attributeName: userId
            attributeType: S
          - attributeName: email
            attributeType: S

        keySchema:
          - attributeName: userId
            keyType: HASH

        globalSecondaryIndexes:
          - indexName: email-index
            keySchema:
              - attributeName: email
                keyType: HASH
            projection:
              projectionType: ALL
```

### Production Configuration

Full-featured production table with all capabilities:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: production-table
  namespace: default
spec:
  components:
    - name: user-table
      type: aws-dynamodb-kro
      properties:
        tableName: users-prod
        region: us-east-1
        billingMode: PAY_PER_REQUEST

        attributeDefinitions:
          - attributeName: userId
            attributeType: S
          - attributeName: email
            attributeType: S
          - attributeName: createdAt
            attributeType: N

        keySchema:
          - attributeName: userId
            keyType: HASH
          - attributeName: createdAt
            keyType: RANGE

        globalSecondaryIndexes:
          - indexName: email-index
            keySchema:
              - attributeName: email
                keyType: HASH
            projection:
              projectionType: ALL

        # Enable streams for CDC
        streamEnabled: true
        streamViewType: NEW_AND_OLD_IMAGES

        # Enable backups
        pointInTimeRecoveryEnabled: true

        # Enable encryption
        sseEnabled: true
        sseType: AES256

        # Enable TTL
        ttlEnabled: true
        ttlAttributeName: expiresAt

        # Protect from accidental deletion
        deletionProtectionEnabled: true

        # Add tags
        tags:
          - key: Environment
            value: Production
          - key: Application
            value: UserService

        # Write connection details to secret
        writeConnectionSecretToRef:
          name: user-table-connection
          namespace: default
```

### Provisioned Billing Mode

For predictable workloads with fixed capacity:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: orders-table
  namespace: default
spec:
  components:
    - name: orders
      type: aws-dynamodb-kro
      properties:
        tableName: orders-table
        region: us-east-1
        billingMode: PROVISIONED

        attributeDefinitions:
          - attributeName: orderId
            attributeType: S

        keySchema:
          - attributeName: orderId
            keyType: HASH

        provisionedThroughput:
          readCapacityUnits: 10
          writeCapacityUnits: 5
```

## Parameters

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `tableName` | string | Name of the DynamoDB table |
| `region` | string | AWS region (e.g., us-east-1) |
| `attributeDefinitions` | array | Attribute definitions for keys and indexes |
| `keySchema` | array | Primary key schema (partition key and optional sort key) |

### Optional Parameters

#### Billing Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `billingMode` | string | `PAY_PER_REQUEST` | Billing mode: `PAY_PER_REQUEST` or `PROVISIONED` |
| `provisionedThroughput` | object | - | Required if `billingMode` is `PROVISIONED` |
| `provisionedThroughput.readCapacityUnits` | integer | - | Read capacity units |
| `provisionedThroughput.writeCapacityUnits` | integer | - | Write capacity units |

#### Secondary Indexes

| Parameter | Type | Description |
|-----------|------|-------------|
| `globalSecondaryIndexes` | array | Global secondary indexes (max 20) |
| `localSecondaryIndexes` | array | Local secondary indexes (max 5) |

Each index contains:
- `indexName`: Index name
- `keySchema`: Key schema for the index
- `projection`: Projection type (`ALL`, `KEYS_ONLY`, or `INCLUDE`)
- `provisionedThroughput`: (GSI only, if table is PROVISIONED)

#### Stream Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `streamEnabled` | boolean | `false` | Enable DynamoDB Streams |
| `streamViewType` | string | - | Stream view type: `KEYS_ONLY`, `NEW_IMAGE`, `OLD_IMAGE`, `NEW_AND_OLD_IMAGES` |

#### Data Protection

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `pointInTimeRecoveryEnabled` | boolean | `false` | Enable point-in-time recovery |
| `sseEnabled` | boolean | `false` | Enable server-side encryption |
| `sseType` | string | - | Encryption type: `AES256` or `KMS` |
| `kmsMasterKeyID` | string | - | KMS key ID (required if `sseType` is `KMS`) |
| `deletionProtectionEnabled` | boolean | `false` | Protect table from deletion |

#### Time To Live

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ttlEnabled` | boolean | `false` | Enable time to live |
| `ttlAttributeName` | string | - | Attribute name for TTL (Unix timestamp) |

#### Other Options

| Parameter | Type | Description |
|-----------|------|-------------|
| `tableClass` | string | Table class: `STANDARD` or `STANDARD_INFREQUENT_ACCESS` |
| `tags` | array | Resource tags (key-value pairs) |
| `providerConfigRef` | object | Reference to ACK provider configuration |
| `writeConnectionSecretToRef` | object | Write connection details to Kubernetes Secret |

## Attribute Definitions

Attributes must be defined for:
- Primary key (partition key and sort key)
- All key attributes in global secondary indexes
- All key attributes in local secondary indexes

### Attribute Types

- `S` - String
- `N` - Number
- `B` - Binary

Example:
```yaml
attributeDefinitions:
  - attributeName: userId
    attributeType: S
  - attributeName: createdAt
    attributeType: N
  - attributeName: email
    attributeType: S
```

## Key Schema

### Partition Key Only
```yaml
keySchema:
  - attributeName: userId
    keyType: HASH
```

### Partition Key + Sort Key
```yaml
keySchema:
  - attributeName: userId
    keyType: HASH
  - attributeName: createdAt
    keyType: RANGE
```

## Status Information

The component exposes DynamoDB table status through the KubeVela application status:

- `tableArn` - ARN of the DynamoDB table
- `tableStatus` - Current status (CREATING, ACTIVE, UPDATING, DELETING)
- `tableID` - Unique identifier for the table
- `latestStreamArn` - ARN of the streams (if enabled)
- `itemCount` - Approximate number of items
- `tableSizeBytes` - Approximate table size
- `creationDateTime` - Table creation timestamp
- `conditions` - Detailed condition information

Check status:
```bash
kubectl get app production-table -o yaml
```

## Connection Secrets

When you specify `writeConnectionSecretToRef`, ACK creates a Kubernetes Secret containing connection details:

```yaml
writeConnectionSecretToRef:
  name: user-table-connection
  namespace: default
```

The secret typically contains:
- Table name
- Table ARN
- Region
- Stream ARN (if streams enabled)

Access the secret:
```bash
kubectl get secret user-table-connection -o yaml
```

## Troubleshooting

### Check KRO ResourceGraphDefinition
```bash
kubectl get resourcegraphdefinition dynamodbtable -o yaml
```

### Check ACK DynamoDB Table
```bash
kubectl get table.dynamodb.services.k8s.aws -A
kubectl describe table.dynamodb.services.k8s.aws <table-name>
```

### Check ACK Controller Logs
```bash
kubectl logs -n ack-system -l app.kubernetes.io/name=dynamodb-chart
```

### Common Issues

**Table creation stuck in CREATING status:**
- Check ACK controller logs for AWS API errors
- Verify IAM permissions
- Ensure region is correct

**Status not updating:**
- Verify KRO controller is running
- Check ResourceGraphDefinition status

**Connection secret not created:**
- Ensure ACK controller has RBAC permissions to create secrets
- Check the namespace specified in `writeConnectionSecretToRef`

## Comparison with Crossplane

### Advantages of KRO + ACK

✅ **Direct AWS API Integration**: ACK controllers map 1:1 with AWS APIs
✅ **Simpler Architecture**: No Crossplane provider infrastructure needed
✅ **Faster Updates**: ACK releases track AWS API updates closely
✅ **Native Kubernetes**: Resources are native Kubernetes CRDs
✅ **Better Status Reporting**: Direct status mapping from AWS

### When to Use Crossplane

- Multi-cloud abstraction is critical
- You're already using Crossplane for other resources
- You need Crossplane's composition features

## Best Practices

1. **Use PAY_PER_REQUEST for variable workloads**: Saves costs and simplifies capacity planning
2. **Enable point-in-time recovery for production**: Critical for data protection
3. **Use encryption (SSE)**: Enable by default for sensitive data
4. **Enable deletion protection for production tables**: Prevent accidental deletion
5. **Use tags for cost allocation**: Tag all resources with Environment, Application, Team
6. **Configure TTL for ephemeral data**: Automatically expire old data
7. **Use streams for CDC patterns**: Enable for event-driven architectures
8. **Use IRSA for EKS**: Most secure way to provide AWS credentials
9. **Monitor with CloudWatch**: Set up alarms for consumed capacity and throttles

## Examples

See the `examples/dynamodb-kro/` directory for complete working examples:

- `basic.yaml` - Simple table with partition key
- `with-gsi.yaml` - Table with global secondary index
- `provisioned.yaml` - Table with provisioned capacity
- `production.yaml` - Full-featured production configuration

## References

- [KRO Documentation](https://kro.run/)
- [ACK DynamoDB Controller](https://aws-controllers-k8s.github.io/community/reference/dynamodb/)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [KubeVela ComponentDefinitions](https://kubevela.io/docs/platform-engineers/components/custom-component/)

## Sources

This component was created using information from:
- [KRO Documentation](https://kro.run/docs/getting-started/deploy-a-resource-graph-definition/)
- [AWS Controllers for Kubernetes](https://aws-controllers-k8s.github.io/docs/)
- [ACK DynamoDB Table CRD Reference](https://aws-controllers-k8s.github.io/community/reference/dynamodb/v1alpha1/table/)
- [KRO Examples](https://kro.run/examples/)
- [Building Self-Service AWS Infrastructure with KRO and ACK](https://medium.com/@tolghn/building-self-service-aws-infrastructure-with-kro-and-ack-5215631f08ce)

---

**Note**: This is an experimental component using KRO, which is still under active development. Test thoroughly before using in production environments.
