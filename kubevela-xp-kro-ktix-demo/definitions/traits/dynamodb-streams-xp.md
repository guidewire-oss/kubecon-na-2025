# DynamoDB Streams Trait

## Overview

The `dynamodb-streams` trait enables DynamoDB Streams for change data capture (CDC). Streams capture all modifications to table items in near real-time, enabling event-driven architectures, data replication, analytics pipelines, and Lambda triggers.

## Use Cases

- **Event-driven architectures** with Lambda triggers
- **Real-time analytics** and data pipelines
- **Data replication** across tables or systems
- **Audit logging** of all data changes
- **Cache invalidation** when data changes
- **Search index updates** (sync to Elasticsearch)
- **Cross-region replication** for global tables
- **Material views** and derived data computation

### When NOT to Use

- No need for change tracking → Avoid unnecessary costs
- Batch processing sufficient → Use scheduled exports instead
- Simple queries → Streams add complexity
- Cost-sensitive applications → Streams incur read costs

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| enabled | bool | No | `true` | Enable DynamoDB Streams |
| viewType | string | No | `NEW_AND_OLD_IMAGES` | Stream view type |

### Parameter Details

#### `enabled`
- **Type**: `bool`
- **Default**: `true`
- **Description**: Enable or disable DynamoDB Streams
- **Example**: `true`

#### `viewType`
- **Type**: `string`
- **Default**: `NEW_AND_OLD_IMAGES`
- **Options**:
  - `KEYS_ONLY`: Only key attributes
  - `NEW_IMAGE`: Entire item after modification
  - `OLD_IMAGE`: Entire item before modification
  - `NEW_AND_OLD_IMAGES`: Both before and after images
- **Description**: Information written to stream for each change

## Stream View Types

### KEYS_ONLY 💰 (Cheapest)

**Contains**: Only partition and sort keys
**Use cases**:
- Simple notifications that item changed
- Trigger Lambda to fetch full item
- Minimal stream data storage

**Example record**:
```json
{
  "Keys": {
    "userId": {"S": "user123"}
  }
}
```

### NEW_IMAGE 💰

**Contains**: Entire item after modification
**Use cases**:
- Forward latest state to downstream systems
- Update search indexes
- Cache invalidation with new data

**Example record**:
```json
{
  "Keys": {"userId": {"S": "user123"}},
  "NewImage": {
    "userId": {"S": "user123"},
    "name": {"S": "John Doe"},
    "email": {"S": "john@example.com"}
  }
}
```

### OLD_IMAGE 💰

**Contains**: Entire item before modification
**Use cases**:
- Audit trails (what was deleted/changed)
- Undo operations
- Historical data tracking

**Example record**:
```json
{
  "Keys": {"userId": {"S": "user123"}},
  "OldImage": {
    "userId": {"S": "user123"},
    "name": {"S": "Jane Doe"},
    "email": {"S": "jane@example.com"}
  }
}
```

### NEW_AND_OLD_IMAGES 💰💰 (Most Complete)

**Contains**: Both before and after images
**Use cases**:
- Full change tracking
- Diff-based processing
- Comprehensive audit logs
- Complex event processing

**Example record**:
```json
{
  "Keys": {"userId": {"S": "user123"}},
  "OldImage": {
    "userId": {"S": "user123"},
    "name": {"S": "Jane Doe"},
    "status": {"S": "active"}
  },
  "NewImage": {
    "userId": {"S": "user123"},
    "name": {"S": "John Doe"},
    "status": {"S": "inactive"}
  }
}
```

## Cost Implications

### 💰 Medium Cost

**Stream Read Requests**:
- **Pricing**: $0.02 per 100,000 read request units
- **1 read request unit**: Up to 4KB of data
- **Example**: 1M stream records at 2KB = 500K read units = $0.10

**Data Transfer**:
- **Same region**: Free
- **Cross-region**: Standard AWS data transfer rates

**Lambda Costs** (if using triggers):
- Lambda invocation costs
- Lambda execution time costs

**Example Monthly Costs** (1M writes/day):
- **Table writes**: 30M writes = ~$37.50 (on-demand)
- **Stream reads**: 30M reads × 2KB = 15M read units = **$3.00**
- **Lambda**: Depends on function complexity

**Cost Optimization**:
- Use `KEYS_ONLY` view type when possible
- Batch stream processing in Lambda
- Filter stream records before processing
- Monitor stream read costs in Cost Explorer

## Examples

### Basic Streams Configuration

Enable streams with default settings:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: user-events
  namespace: default
spec:
  components:
    - name: users-table
      type: dynamodb-table
      properties:
        region: us-east-1
        attributeDefinitions:
          - attributeName: userId
            attributeType: S
        keySchema:
          - attributeName: userId
            keyType: HASH
      traits:
        - type: dynamodb-streams
          properties:
            enabled: true
            viewType: NEW_AND_OLD_IMAGES
```

### Minimal Stream Configuration (Cost-Optimized)

Keys-only for simple notifications:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: notification-table
  namespace: default
spec:
  components:
    - name: notifications-table
      type: dynamodb-table
      properties:
        region: us-west-2
        attributeDefinitions:
          - attributeName: notificationId
            attributeType: S
        keySchema:
          - attributeName: notificationId
            keyType: HASH
      traits:
        - type: dynamodb-streams
          properties:
            enabled: true
            viewType: KEYS_ONLY  # Minimal data
```

### Audit Log Configuration

Full change tracking for compliance:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: financial-transactions
  namespace: finance
spec:
  components:
    - name: transactions-table
      type: dynamodb-table
      properties:
        region: us-east-1
        attributeDefinitions:
          - attributeName: transactionId
            attributeType: S
        keySchema:
          - attributeName: transactionId
            keyType: HASH
        tags:
          - key: Compliance
            value: SOX
      traits:
        # Full audit trail
        - type: dynamodb-streams
          properties:
            enabled: true
            viewType: NEW_AND_OLD_IMAGES  # Full history

        # Data protection
        - type: dynamodb-protection
          properties:
            deletionProtection: true
            pointInTimeRecovery: true
```

### Event-Driven Architecture

Streams with Lambda trigger (conceptual):

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: order-processing
  namespace: default
spec:
  components:
    - name: orders-table
      type: dynamodb-table
      properties:
        region: us-east-1
        attributeDefinitions:
          - attributeName: orderId
            attributeType: S
        keySchema:
          - attributeName: orderId
            keyType: HASH
      traits:
        - type: dynamodb-streams
          properties:
            enabled: true
            viewType: NEW_IMAGE  # Forward new state

# Note: Lambda trigger configuration separate (via AWS Lambda EventSourceMapping)
```

## Stream Processing Patterns

### Pattern 1: Lambda Event Source Mapping

**Most common**: Direct Lambda trigger

```python
# Lambda function receives batches of stream records
def lambda_handler(event, context):
    for record in event['Records']:
        if record['eventName'] == 'INSERT':
            new_image = record['dynamodb']['NewImage']
            # Process new item
        elif record['eventName'] == 'MODIFY':
            old_image = record['dynamodb']['OldImage']
            new_image = record['dynamodb']['NewImage']
            # Process update
        elif record['eventName'] == 'REMOVE':
            old_image = record['dynamodb']['OldImage']
            # Process deletion
```

### Pattern 2: Kinesis Data Streams

**For high throughput**: DynamoDB Streams → Kinesis → Consumers

### Pattern 3: Cross-Region Replication

**Global tables**: Automatic replication via streams

## Stream Record Structure

```json
{
  "Records": [
    {
      "eventID": "1",
      "eventName": "INSERT|MODIFY|REMOVE",
      "eventVersion": "1.1",
      "eventSource": "aws:dynamodb",
      "awsRegion": "us-east-1",
      "dynamodb": {
        "ApproximateCreationDateTime": 1678901234,
        "Keys": {
          "userId": {"S": "user123"}
        },
        "NewImage": { /* if applicable */ },
        "OldImage": { /* if applicable */ },
        "SequenceNumber": "12345678901234567890",
        "SizeBytes": 123,
        "StreamViewType": "NEW_AND_OLD_IMAGES"
      }
    }
  ]
}
```

## Best Practices

1. **Choose view type carefully**: Balance data needs vs costs
2. **Filter early**: Use Lambda event filtering to reduce invocations
3. **Batch processing**: Process multiple records per Lambda invocation
4. **Error handling**: Implement DLQ for failed records
5. **Idempotency**: Handle duplicate records gracefully
6. **Monitoring**: Track stream read metrics and Lambda errors
7. **Retention**: Stream records retained for 24 hours

## Stream Retention

- **Retention period**: 24 hours
- **After 24 hours**: Records automatically deleted
- **Cannot modify**: Retention is fixed at 24 hours
- **Long-term storage**: Process and store externally if needed

## Troubleshooting

### Issue: Lambda Not Triggered

**Symptoms**: Stream enabled but Lambda not receiving events
**Cause**: Event source mapping not configured
**Solution**:
- Create Lambda event source mapping
- Verify Lambda execution role has `dynamodb:GetRecords` permission
- Check Lambda function logs for errors

### Issue: High Stream Costs

**Symptoms**: Unexpected stream read costs
**Cause**: Inefficient stream processing or large view type
**Solution**:
- Switch to `KEYS_ONLY` if full data not needed
- Optimize Lambda batch size
- Use stream filtering to reduce processed records
- Monitor read request units in CloudWatch

### Issue: Stream Records Lost

**Symptoms**: Missing change events
**Cause**: 24-hour retention window exceeded
**Solution**:
- Ensure consumers process within 24 hours
- Implement retry logic with exponential backoff
- Monitor stream iterator age metric
- Consider Kinesis Data Streams for longer retention

### Issue: Lambda Throttling

**Symptoms**: `IteratorAgeMilliseconds` increasing
**Cause**: Lambda concurrency limit reached
**Solution**:
- Increase Lambda reserved concurrency
- Optimize Lambda function performance
- Use Kinesis Data Streams for fan-out
- Scale stream shard count (via Kinesis)

## Monitoring

### Key CloudWatch Metrics

- **UserErrors**: Application-level read errors
- **SystemErrors**: Service-level errors
- **GetRecords.IteratorAgeMilliseconds**: Stream processing lag
- **ReturnedRecordsCount**: Records returned per read

### Alarms

```yaml
# Monitor stream lag
IteratorAge > 60000ms (1 minute)

# Monitor read errors
UserErrors > 10 per 5 minutes
```

## Compliance

### Audit Requirements
- ✅ Capture all data modifications
- ✅ 24-hour retention minimum
- ✅ Change tracking for compliance
- ✅ Integration with SIEM systems

### Data Governance
- ✅ Track data lineage
- ✅ Monitor data access patterns
- ✅ Audit trail via CloudTrail
- ✅ Real-time alerting

## Related Traits

- **dynamodb-protection**: Combine for comprehensive data governance
- **dynamodb-table**: Base component

## Version History

- **v1.0.0**: Initial release

## Sources

- [DynamoDB Streams](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Streams.html)
- [Lambda with DynamoDB Streams](https://docs.aws.amazon.com/lambda/latest/dg/with-ddb.html)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
