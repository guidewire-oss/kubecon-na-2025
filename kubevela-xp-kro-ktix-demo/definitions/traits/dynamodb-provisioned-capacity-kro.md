# DynamoDB Provisioned Capacity Trait (KRO)

## Overview

The `dynamodb-provisioned-capacity-kro` trait configures a DynamoDB table to use **provisioned billing mode** with fixed read and write capacity units. This provides predictable performance and cost for workloads with consistent traffic patterns.

## Applies To

- Components of type: `aws-dynamodb-kro`
- Workload type: `kro.run/DynamoDBTable`

## When to Use

### ✅ Use Provisioned Mode When:
- Traffic is **predictable and consistent**
- You can forecast capacity requirements
- Cost optimization is important (can be 60% cheaper than on-demand)
- You want to use **reserved capacity** for additional savings
- Using **Auto Scaling** to handle some variation
- **High throughput** workloads (provisioned can be cheaper at scale)

### ❌ Use On-Demand Mode When:
- Traffic is **unpredictable or spiky**
- New application with unknown patterns
- Development/testing environments
- Serverless applications with variable load
- Infrequent access patterns

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `readCapacityUnits` | integer | Yes | Read capacity units (RCU) |
| `writeCapacityUnits` | integer | Yes | Write capacity units (WCU) |

## Capacity Units Explained

### Read Capacity Units (RCU)

**1 RCU provides:**
- **1 strongly consistent read per second** for items up to 4 KB
- **2 eventually consistent reads per second** for items up to 4 KB

**Examples:**
- Read 10 items/sec (4KB each, strongly consistent) = **10 RCU**
- Read 20 items/sec (4KB each, eventually consistent) = **10 RCU**
- Read 5 items/sec (8KB each, strongly consistent) = **10 RCU** (8KB ÷ 4KB = 2, × 5 = 10)

### Write Capacity Units (WCU)

**1 WCU provides:**
- **1 write per second** for items up to 1 KB

**Examples:**
- Write 10 items/sec (1KB each) = **10 WCU**
- Write 5 items/sec (2KB each) = **10 WCU** (2KB ÷ 1KB = 2, × 5 = 10)
- Write 20 items/sec (500B each) = **20 WCU** (rounded up to 1KB per item)

## Examples

### Basic Provisioned Capacity

Configure fixed capacity for a table:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: provisioned-table
spec:
  components:
    - name: user-sessions
      type: aws-dynamodb-kro
      properties:
        tableName: user-sessions
        region: us-east-1
        attributeDefinitions:
          - attributeName: sessionId
            attributeType: S
        keySchema:
          - attributeName: sessionId
            keyType: HASH
      traits:
        - type: dynamodb-provisioned-capacity-kro
          properties:
            readCapacityUnits: 10
            writeCapacityUnits: 5
```

### High Throughput Table

For high-volume applications:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: analytics-table
spec:
  components:
    - name: events
      type: aws-dynamodb-kro
      properties:
        tableName: analytics-events
        region: us-east-1
        attributeDefinitions:
          - attributeName: eventId
            attributeType: S
        keySchema:
          - attributeName: eventId
            keyType: HASH
      traits:
        - type: dynamodb-provisioned-capacity-kro
          properties:
            readCapacityUnits: 1000
            writeCapacityUnits: 2000
```

### Production with Auto Scaling

Combine with Auto Scaling (configure separately in AWS):

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: production-table
spec:
  components:
    - name: orders
      type: aws-dynamodb-kro
      properties:
        tableName: orders-prod
        region: us-east-1
        attributeDefinitions:
          - attributeName: orderId
            attributeType: S
        keySchema:
          - attributeName: orderId
            keyType: HASH
      traits:
        - type: dynamodb-provisioned-capacity-kro
          properties:
            readCapacityUnits: 50    # Base capacity
            writeCapacityUnits: 25   # Auto Scaling adjusts from here
```

### Cost-Optimized Development

Minimal capacity for development:

```yaml
traits:
  - type: dynamodb-provisioned-capacity-kro
    properties:
      readCapacityUnits: 1
      writeCapacityUnits: 1
```

## Capacity Planning

### Calculate Required RCU

```
RCU = (items_per_second × item_size_KB ÷ 4KB) × consistency_factor

where:
  consistency_factor = 1 for strongly consistent
  consistency_factor = 0.5 for eventually consistent
```

**Example:**
- 100 reads/sec
- 8 KB items
- Eventually consistent

```
RCU = (100 × 8 ÷ 4) × 0.5 = 100 RCU
```

### Calculate Required WCU

```
WCU = items_per_second × ceiling(item_size_KB)
```

**Example:**
- 50 writes/sec
- 1.5 KB items

```
WCU = 50 × ceiling(1.5) = 50 × 2 = 100 WCU
```

## Cost Comparison

### Provisioned vs On-Demand

**Provisioned costs** (us-east-1, 2024):
- Write: $0.00065 per WCU-hour ($0.47 per WCU-month)
- Read: $0.00013 per RCU-hour ($0.09 per RCU-month)

**On-Demand costs** (us-east-1, 2024):
- Write: $1.25 per million write request units
- Read: $0.25 per million read request units

### Example Calculation

**Workload**: 10 RCU, 5 WCU, 24/7

**Provisioned**:
```
Read:  10 RCU × $0.09/month = $0.90/month
Write:  5 WCU × $0.47/month = $2.35/month
Total: $3.25/month
```

**On-Demand** (same throughput, 2.6M operations/month):
```
Reads:  1.3M × $0.25/M = $0.33/month
Writes: 1.3M × $1.25/M = $1.63/month
Total: $1.96/month
```

**Breakeven point**: Provisioned becomes cheaper at higher, consistent volumes.

## DynamoDB Auto Scaling

Auto Scaling automatically adjusts provisioned capacity based on load:

### Enable Auto Scaling (AWS CLI)

```bash
# Enable read auto scaling
aws application-autoscaling register-scalable-target \
  --service-namespace dynamodb \
  --resource-id "table/orders-prod" \
  --scalable-dimension "dynamodb:table:ReadCapacityUnits" \
  --min-capacity 50 \
  --max-capacity 500

aws application-autoscaling put-scaling-policy \
  --service-namespace dynamodb \
  --resource-id "table/orders-prod" \
  --scalable-dimension "dynamodb:table:ReadCapacityUnits" \
  --policy-name "orders-read-scaling-policy" \
  --policy-type "TargetTrackingScaling" \
  --target-tracking-scaling-policy-configuration file://read-scaling-config.json

# read-scaling-config.json
{
  "TargetValue": 70.0,
  "PredefinedMetricSpecification": {
    "PredefinedMetricType": "DynamoDBReadCapacityUtilization"
  }
}
```

### Auto Scaling Best Practices

1. **Set appropriate min/max values**
   - Min: Lowest expected load
   - Max: Budget limit or expected peak

2. **Target utilization: 70-80%**
   - Leaves headroom for burst traffic
   - Prevents constant scaling

3. **Scale up quickly, down slowly**
   - Default: scale up after 2 minutes
   - Default: scale down after 15 minutes

4. **Monitor scaling events**
   - CloudWatch alarms for max capacity reached
   - Track throttled requests

## Throttling

When you exceed provisioned capacity, DynamoDB returns `ProvisionedThroughputExceededException`.

### Handling Throttling

**In Application**:
```python
import boto3
from botocore.exceptions import ClientError
import time

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('orders-prod')

def put_item_with_retry(item, max_retries=3):
    for attempt in range(max_retries):
        try:
            table.put_item(Item=item)
            return True
        except ClientError as e:
            if e.response['Error']['Code'] == 'ProvisionedThroughputExceededException':
                if attempt < max_retries - 1:
                    time.sleep(2 ** attempt)  # Exponential backoff
                    continue
            raise
    return False
```

**Use AWS SDK Retry Logic**:
```python
import boto3
from botocore.config import Config

config = Config(
    retries={
        'max_attempts': 10,
        'mode': 'adaptive'
    }
)
dynamodb = boto3.resource('dynamodb', config=config)
```

## Reserved Capacity

Save up to 77% by committing to capacity for 1 or 3 years:

### Purchase Reserved Capacity

```bash
aws dynamodb purchase-reserved-capacity-offerings \
  --reserved-capacity-offerings-id <offering-id> \
  --reserved-capacity-offering-count 100
```

### When to Use Reserved Capacity

- ✅ Production workloads with stable traffic
- ✅ 24/7 operations
- ✅ Minimum 100 RCU or WCU
- ✅ 1-year or 3-year commitment acceptable

### Savings

| Term | Payment | Savings |
|------|---------|---------|
| 1 year | All upfront | ~43% |
| 1 year | No upfront | ~25% |
| 3 years | All upfront | ~77% |

## Monitoring

### Key CloudWatch Metrics

- **ConsumedReadCapacityUnits**: Actual RCU consumed
- **ConsumedWriteCapacityUnits**: Actual WCU consumed
- **ProvisionedReadCapacityUnits**: Provisioned RCU
- **ProvisionedWriteCapacityUnits**: Provisioned WCU
- **ReadThrottleEvents**: Number of throttled reads
- **WriteThrottleEvents**: Number of throttled writes
- **UserErrors**: Client-side errors

### Set Up Alarms

```bash
# Alarm for high read utilization
aws cloudwatch put-metric-alarm \
  --alarm-name "orders-high-read-utilization" \
  --alarm-description "Read utilization above 80%" \
  --metric-name ReadCapacityUtilization \
  --namespace AWS/DynamoDB \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=TableName,Value=orders-prod \
  --evaluation-periods 2
```

## Best Practices

1. **Start conservative, scale up**
   - Begin with lower capacity
   - Monitor and adjust based on metrics
   - Use Auto Scaling for automatic adjustments

2. **Enable burst capacity awareness**
   - DynamoDB provides burst capacity (300 seconds worth)
   - Don't rely on it for sustained load

3. **Distribute workload evenly**
   - Avoid hot partitions
   - Use random partition keys when possible
   - Monitor per-partition metrics

4. **Use eventually consistent reads**
   - 50% cheaper than strongly consistent
   - Acceptable for most use cases

5. **Batch operations**
   - Use BatchGetItem and BatchWriteItem
   - Up to 100 items per batch
   - More efficient use of capacity

6. **Monitor and optimize**
   - Review capacity utilization weekly
   - Right-size based on actual usage
   - Consider on-demand for unpredictable workloads

## Switching Billing Modes

### From On-Demand to Provisioned

```yaml
# Add the trait
traits:
  - type: dynamodb-provisioned-capacity-kro
    properties:
      readCapacityUnits: 10
      writeCapacityUnits: 5
```

### From Provisioned to On-Demand

```yaml
# Remove the trait to use default (on-demand)
# Or explicitly set in component properties:
properties:
  billingMode: PAY_PER_REQUEST
```

**Note**: You can switch billing modes once every 24 hours.

## Combining with Other Traits

### Provisioned + Auto Scaling + Protection

```yaml
traits:
  - type: dynamodb-provisioned-capacity-kro
    properties:
      readCapacityUnits: 100
      writeCapacityUnits: 50
  - type: dynamodb-protection-kro
    properties:
      deletionProtection: true
      pointInTimeRecovery: true
```

### Full Production Stack

```yaml
traits:
  - type: dynamodb-provisioned-capacity-kro
    properties:
      readCapacityUnits: 200
      writeCapacityUnits: 100
  - type: dynamodb-encryption-kro
    properties:
      sseType: KMS
      kmsKeyId: alias/prod-key
  - type: dynamodb-streams-kro
    properties:
      viewType: NEW_AND_OLD_IMAGES
  - type: dynamodb-protection-kro
    properties:
      deletionProtection: true
      pointInTimeRecovery: true
```

## Troubleshooting

### High throttling

1. Check capacity utilization
2. Enable Auto Scaling
3. Increase provisioned capacity
4. Check for hot partitions
5. Consider on-demand mode

### Unexpected costs

1. Review provisioned capacity settings
2. Check if capacity is underutilized
3. Consider reducing capacity or switching to on-demand
4. Look for unused indexes consuming capacity

### Auto Scaling not working

1. Verify Auto Scaling policy is configured
2. Check IAM permissions for Auto Scaling
3. Review CloudWatch alarms
4. Verify target utilization is appropriate

## References

- [DynamoDB Provisioned Capacity](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/ProvisionedThroughput.html)
- [DynamoDB Auto Scaling](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/AutoScaling.html)
- [Reserved Capacity](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/ReservedCapacity.html)
- [Capacity Unit Calculations](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/CapacityUnitCalculations.html)

## Related Traits

- `dynamodb-protection-kro` - Data protection features
- `dynamodb-encryption-kro` - Server-side encryption
- `dynamodb-streams-kro` - Change data capture
