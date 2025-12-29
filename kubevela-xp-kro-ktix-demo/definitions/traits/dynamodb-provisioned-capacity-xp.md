# DynamoDB Provisioned Capacity Trait

## Overview

The `dynamodb-provisioned-capacity` trait configures provisioned throughput capacity for DynamoDB tables using PROVISIONED billing mode. This trait is essential for workloads with predictable, consistent traffic patterns where you want to control costs by pre-provisioning capacity.

## Use Cases

- **Predictable workloads** with consistent traffic patterns
- **Cost optimization** for steady-state applications (up to 75% cheaper than on-demand)
- **Performance guarantees** with reserved capacity
- **Enterprise applications** with SLA requirements
- **High-throughput applications** benefiting from lower per-request costs

### When NOT to Use

- Unpredictable or spiky traffic → Use PAY_PER_REQUEST billing mode
- Development/testing environments → On-demand is simpler
- Applications with variable load → Consider auto-scaling or on-demand

## Parameters

| Parameter | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| readCapacityUnits | int (>0) | Yes | Number of read capacity units (RCU) | `5` |
| writeCapacityUnits | int (>0) | Yes | Number of write capacity units (WCU) | `5` |

### Parameter Details

#### `readCapacityUnits`
- **Type**: `int` (must be > 0)
- **Required**: Yes
- **Description**: Number of strongly consistent reads per second (4KB each)
  - 1 RCU = 1 strongly consistent read/second of up to 4KB
  - 1 RCU = 2 eventually consistent reads/second of up to 4KB
  - Larger items consume multiple RCUs
- **Calculation**: Divide expected reads/second by item size
- **Example**: For 100 reads/sec of 8KB items: 100 * (8/4) = 200 RCUs

#### `writeCapacityUnits`
- **Type**: `int` (must be > 0)
- **Required**: Yes
- **Description**: Number of writes per second (1KB each)
  - 1 WCU = 1 write/second of up to 1KB
  - Larger items consume multiple WCUs
- **Calculation**: Divide expected writes/second by item size
- **Example**: For 50 writes/sec of 3KB items: 50 * 3 = 150 WCUs

## Cost Implications

### 💰💰 Medium to High Cost

**Provisioned Capacity Pricing** (us-east-1):
- **Read Capacity**: $0.00013 per RCU-hour (~$0.094 per RCU-month)
- **Write Capacity**: $0.00065 per WCU-hour (~$0.47 per WCU-month)

**Example Monthly Costs**:
- **Small table** (5 RCU, 5 WCU): ~$2.82/month
- **Medium table** (100 RCU, 100 WCU): ~$56.40/month
- **Large table** (1000 RCU, 1000 WCU): ~$564/month

**Cost Optimization**:
- **Reserved Capacity**: Save up to 53% with 1-year or 3-year commitments
- **Auto Scaling**: Automatically adjust capacity based on utilization (requires additional configuration)
- **Right-sizing**: Monitor CloudWatch metrics and adjust RCU/WCU accordingly

### Comparison: Provisioned vs On-Demand

**Break-even point** (us-east-1):
- On-demand: $1.25 per million writes, $0.25 per million reads
- Provisioned: Break-even at ~2.6M requests per WCU-month, ~1.9M requests per RCU-month
- **Rule of thumb**: Use provisioned if you can utilize >30% of capacity consistently

## Behavior

This trait:
1. **Overrides** the component's `billingMode` to `PROVISIONED`
2. **Sets** `provisionedThroughput` with specified RCU and WCU values
3. **Applies** to the base table (use separate traits for index capacity)

## Examples

### Basic Example

Provision capacity for a moderate-traffic table:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: user-profiles
  namespace: default
spec:
  components:
    - name: profiles-table
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
        - type: dynamodb-provisioned-capacity
          properties:
            readCapacityUnits: 100
            writeCapacityUnits: 50
```

### High-Throughput Example

Large capacity for high-traffic application:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: analytics-events
  namespace: default
spec:
  components:
    - name: events-table
      type: dynamodb-table
      properties:
        region: us-west-2
        attributeDefinitions:
          - attributeName: eventId
            attributeType: S
          - attributeName: timestamp
            attributeType: N
        keySchema:
          - attributeName: eventId
            keyType: HASH
          - attributeName: timestamp
            keyType: RANGE
      traits:
        - type: dynamodb-provisioned-capacity
          properties:
            readCapacityUnits: 1000
            writeCapacityUnits: 500
```

### Cost-Optimized Example

Minimal capacity for low-traffic table:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: config-store
  namespace: default
spec:
  components:
    - name: config-table
      type: dynamodb-table
      properties:
        region: us-east-1
        attributeDefinitions:
          - attributeName: configKey
            attributeType: S
        keySchema:
          - attributeName: configKey
            keyType: HASH
      traits:
        - type: dynamodb-provisioned-capacity
          properties:
            readCapacityUnits: 5      # Minimum
            writeCapacityUnits: 5     # Minimum
```

## Capacity Planning

### Calculate Required Capacity

**Read Capacity**:
```
RCU = (reads per second) * (item size in KB / 4KB) / (consistency factor)
Consistency factor: 1 for strongly consistent, 2 for eventually consistent
```

**Write Capacity**:
```
WCU = (writes per second) * (item size in KB rounded up to nearest KB)
```

**Example**:
- 200 reads/sec, 2KB items, eventually consistent: 200 * (2/4) / 2 = 50 RCU
- 100 writes/sec, 1.5KB items: 100 * 2 = 200 WCU

### Monitoring

Monitor these CloudWatch metrics to optimize capacity:
- **ConsumedReadCapacityUnits**: Actual read capacity consumed
- **ConsumedWriteCapacityUnits**: Actual write capacity consumed
- **UserErrors**: Throttling due to exceeded capacity
- **SystemErrors**: Service-side errors

**Target Utilization**: Aim for 70-80% utilization for cost efficiency while avoiding throttling

## Throttling

When requests exceed provisioned capacity:
- **Behavior**: Requests are throttled with `ProvisionedThroughputExceededException`
- **Impact**: Application errors, increased latency
- **Solutions**:
  1. Increase provisioned capacity
  2. Implement exponential backoff in application
  3. Use DynamoDB auto-scaling (requires additional setup)
  4. Consider switching to on-demand billing

## Troubleshooting

### Issue: Frequent Throttling

**Symptoms**: High UserErrors metric, application timeouts
**Cause**: Insufficient provisioned capacity
**Solution**:
1. Check CloudWatch metrics for ConsumedReadCapacityUnits and ConsumedWriteCapacityUnits
2. Increase RCU/WCU by 20-50%
3. Consider burst capacity (300 seconds of unused capacity)
4. Implement application-side retries with exponential backoff

### Issue: High Costs

**Symptoms**: Higher AWS bills than expected
**Cause**: Over-provisioned capacity
**Solution**:
1. Review CloudWatch metrics for actual utilization
2. Reduce RCU/WCU to target 70-80% utilization
3. Consider switching to on-demand if utilization <30%
4. Implement auto-scaling for variable workloads

### Issue: Cannot Change Capacity

**Symptoms**: Update fails or is delayed
**Cause**: DynamoDB limits capacity changes
**Solution**:
- Maximum 4 decreases per 24-hour period
- No limit on increases
- Wait for previous update to complete
- Use auto-scaling for automatic adjustments

## Best Practices

1. **Start small**: Begin with low capacity and scale up based on metrics
2. **Monitor utilization**: Target 70-80% utilization for cost efficiency
3. **Use auto-scaling**: Configure DynamoDB auto-scaling for variable loads
4. **Reserved capacity**: Purchase reserved capacity for predictable workloads (53% savings)
5. **Burst capacity**: DynamoDB provides up to 300 seconds of burst capacity
6. **Global tables**: Provision capacity in each region independently

## Related Traits

- **dynamodb-global-index**: Requires separate capacity provisioning per index
- **dynamodb-table**: Base component (defaults to PAY_PER_REQUEST)

## Version History

- **v1.0.0**: Initial release

## Sources

- [AWS DynamoDB Pricing](https://aws.amazon.com/dynamodb/pricing/)
- [DynamoDB Capacity Planning](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.ReadWriteCapacityMode.html)
- [DynamoDB Cost Optimization](https://www.sedai.io/blog/how-to-optimize-amazon-dynamodb-costs-in-2025)
