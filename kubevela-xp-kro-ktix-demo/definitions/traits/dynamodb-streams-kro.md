# DynamoDB Streams Trait (KRO)

## Overview

The `dynamodb-streams-kro` trait enables DynamoDB Streams on a table, allowing you to capture item-level changes for change data capture (CDC), event-driven architectures, and real-time analytics.

## Applies To

- Components of type: `aws-dynamodb-kro`
- Workload type: `kro.run/DynamoDBTable`

## Use Cases

- **Lambda Triggers**: Automatically invoke Lambda functions on table changes
- **Real-time Analytics**: Stream changes to analytics pipelines
- **Cross-Region Replication**: Replicate data across regions
- **Audit Logging**: Track all changes to items
- **Search Index Updates**: Keep Elasticsearch/OpenSearch in sync
- **Cache Invalidation**: Invalidate caches when data changes

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `enabled` | boolean | No | `true` | Enable or disable streams |
| `viewType` | string | No | `NEW_AND_OLD_IMAGES` | What data to include in stream records |

### Stream View Types

- **`KEYS_ONLY`**: Only the key attributes of the modified item
  - Use for: Minimal overhead, only need to know what changed
  - Stream size: Smallest

- **`NEW_IMAGE`**: The entire item as it appears after modification
  - Use for: Processing new state, cache updates
  - Stream size: Medium

- **`OLD_IMAGE`**: The entire item as it appeared before modification
  - Use for: Audit logs, rollback capabilities
  - Stream size: Medium

- **`NEW_AND_OLD_IMAGES`**: Both the new and old images
  - Use for: Full change tracking, diff calculation
  - Stream size: Largest (recommended default)

## Examples

### Basic Usage

Enable streams with default settings (captures full before/after images):

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: user-table-with-streams
spec:
  components:
    - name: user-table
      type: aws-dynamodb-kro
      properties:
        tableName: users-table
        region: us-east-1
        attributeDefinitions:
          - attributeName: userId
            attributeType: S
        keySchema:
          - attributeName: userId
            keyType: HASH
      traits:
        - type: dynamodb-streams-kro
```

### Keys Only

Stream only key attributes (minimal overhead):

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: user-table-keys-only
spec:
  components:
    - name: user-table
      type: aws-dynamodb-kro
      properties:
        tableName: users-table
        region: us-east-1
        attributeDefinitions:
          - attributeName: userId
            attributeType: S
        keySchema:
          - attributeName: userId
            keyType: HASH
      traits:
        - type: dynamodb-streams-kro
          properties:
            enabled: true
            viewType: KEYS_ONLY
```

### New Image Only

Stream the new state of items (good for cache updates):

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: orders-table
spec:
  components:
    - name: orders
      type: aws-dynamodb-kro
      properties:
        tableName: orders-table
        region: us-east-1
        attributeDefinitions:
          - attributeName: orderId
            attributeType: S
        keySchema:
          - attributeName: orderId
            keyType: HASH
      traits:
        - type: dynamodb-streams-kro
          properties:
            viewType: NEW_IMAGE
```

### Full Change Tracking

Capture both old and new images for complete audit trail:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: audit-table
spec:
  components:
    - name: transactions
      type: aws-dynamodb-kro
      properties:
        tableName: transactions
        region: us-east-1
        attributeDefinitions:
          - attributeName: txId
            attributeType: S
        keySchema:
          - attributeName: txId
            keyType: HASH
      traits:
        - type: dynamodb-streams-kro
          properties:
            enabled: true
            viewType: NEW_AND_OLD_IMAGES
```

## Stream Record Structure

Each stream record contains:

```json
{
  "eventID": "unique-event-id",
  "eventName": "INSERT|MODIFY|REMOVE",
  "eventVersion": "1.1",
  "eventSource": "aws:dynamodb",
  "awsRegion": "us-east-1",
  "dynamodb": {
    "Keys": { "userId": { "S": "user123" } },
    "NewImage": { /* new item state */ },
    "OldImage": { /* old item state */ },
    "SequenceNumber": "123456789",
    "SizeBytes": 1234,
    "StreamViewType": "NEW_AND_OLD_IMAGES"
  }
}
```

## Consuming Streams

### With Lambda

```yaml
apiVersion: lambda.services.k8s.aws/v1alpha1
kind: EventSourceMapping
metadata:
  name: user-table-stream
spec:
  eventSourceArn: ${user-table.status.latestStreamArn}
  functionName: process-user-changes
  startingPosition: LATEST
  batchSize: 100
```

### With Kinesis Client Library (KCL)

```python
from dynamodb_streams_client import DynamoDBStreamsClient

client = DynamoDBStreamsClient()
stream_arn = "arn:aws:dynamodb:us-east-1:123456789012:table/users/stream/..."
client.process_stream(stream_arn)
```

## Performance Considerations

- **Latency**: Stream records typically available within 1 second
- **Retention**: Records retained for 24 hours
- **Ordering**: Records within the same partition are strictly ordered
- **Throughput**: Scales automatically with table throughput

### View Type Impact

| View Type | Network Cost | Processing Cost | Use Case |
|-----------|--------------|-----------------|----------|
| KEYS_ONLY | Low | Low | Simple notifications |
| NEW_IMAGE | Medium | Medium | Cache updates |
| OLD_IMAGE | Medium | Medium | Audit logs |
| NEW_AND_OLD_IMAGES | High | High | Full CDC, diffs |

## Best Practices

1. **Choose the right view type**
   - Use KEYS_ONLY if you'll fetch full items anyway
   - Use NEW_IMAGE for most event-driven use cases
   - Use NEW_AND_OLD_IMAGES only when you need diffs

2. **Handle duplicates**
   - Stream records may be delivered more than once
   - Implement idempotent processing

3. **Process efficiently**
   - Use batch processing (Lambda batch size)
   - Handle errors gracefully (DLQ for Lambda)
   - Monitor consumer lag

4. **Monitor streams**
   - CloudWatch metrics: IteratorAge, ProcessedRecords
   - Set up alarms for consumer lag
   - Track processing errors

5. **Security**
   - Stream ARN is sensitive information
   - Use IAM policies to control access
   - Encrypt stream data in transit

## Combining with Other Traits

### Streams + Protection

```yaml
traits:
  - type: dynamodb-streams-kro
    properties:
      viewType: NEW_AND_OLD_IMAGES
  - type: dynamodb-protection-kro
    properties:
      deletionProtection: true
      pointInTimeRecovery: true
```

### Streams + Encryption

```yaml
traits:
  - type: dynamodb-streams-kro
    properties:
      enabled: true
  - type: dynamodb-encryption-kro
    properties:
      enabled: true
      kmsKeyId: arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012
```

## Troubleshooting

### Streams not appearing

Check the table status:
```bash
kubectl get dynamodbtable user-table -o jsonpath='{.status.latestStreamArn}'
```

### Lambda not triggering

1. Verify stream is enabled
2. Check EventSourceMapping status
3. Verify Lambda has DynamoDB streams permissions
4. Check CloudWatch logs

### High consumer lag

1. Increase Lambda concurrency
2. Optimize processing logic
3. Consider smaller batch sizes
4. Check for throttling

## References

- [DynamoDB Streams](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Streams.html)
- [Lambda and DynamoDB Streams](https://docs.aws.amazon.com/lambda/latest/dg/with-ddb.html)
- [Stream Record Structure](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Streams.html#Streams.DataModel)

## Related Traits

- `dynamodb-protection-kro` - Data protection features
- `dynamodb-encryption-kro` - Server-side encryption
