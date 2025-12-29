# DynamoDB Local Secondary Index Trait

## Overview

The `dynamodb-local-index` trait adds Local Secondary Indexes (LSI) to DynamoDB tables. LSIs provide an alternate sort key for queries while using the same partition key as the table, enabling efficient queries within a single partition.

## Use Cases

- **Alternate sort keys** for same partition key
- **Single-partition queries** with different sorting
- **Query flexibility** without additional partition keys
- **Strongly consistent reads** (unlike GSIs)

### When NOT to Use

- Need different partition key → Use GSI instead
- Table doesn't have sort key → LSI requires composite key
- Need more than 5 indexes per table → LSI limit is 5
- Large items per partition → 10GB limit per partition key value

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| indexes | array | Yes | Array of local secondary indexes (max 5) |

### Index Configuration

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| indexName | string | Yes | Name of the LSI |
| keySchema | array | Yes | Must use same partition key, different sort key |
| projection | object | Yes | Attributes to project |

## Key Differences: LSI vs GSI

| Feature | Local Secondary Index | Global Secondary Index |
|---------|----------------------|------------------------|
| Partition Key | **Same as table** | **Different from table** |
| Sort Key | Different | Different |
| Consistency | **Strongly consistent** | Eventually consistent only |
| Capacity | Shares table capacity | Separate capacity |
| Creation | **Must create with table** | Can add anytime |
| Limit | **5 per table** | 20 per table |
| Size | 10GB per partition key | No limit |

## Cost Implications

### 💰 Low to Medium Cost

**Storage**: Additional storage for indexed attributes
- **ALL projection**: Higher storage costs
- **KEYS_ONLY**: Minimal storage overhead
- **INCLUDE**: Moderate storage costs

**Capacity**: Uses table's provisioned throughput (no additional capacity costs)

**Cost Optimization**:
- Use `KEYS_ONLY` when possible
- Limit number of LSIs (max 5 anyway)
- Consider GSI if strongly consistent reads not required

## Limitations

- **Maximum**: 5 LSIs per table
- **Creation time**: Must be created with table (cannot add later)
- **Size limit**: 10GB per partition key value (including LSIs)
- **Partition key**: Must match table's partition key
- **Table requirement**: Table must have composite key (partition + sort)

## Examples

### Basic LSI Example

Query users by different sort keys:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: user-activity
  namespace: default
spec:
  components:
    - name: activity-table
      type: dynamodb-table
      properties:
        region: us-east-1
        attributeDefinitions:
          - attributeName: userId
            attributeType: S
          - attributeName: timestamp
            attributeType: N
          - attributeName: activityType
            attributeType: S
        keySchema:
          - attributeName: userId
            keyType: HASH
          - attributeName: timestamp
            keyType: RANGE
      traits:
        - type: dynamodb-local-index
          properties:
            indexes:
              # Query by activity type instead of timestamp
              - indexName: ActivityTypeIndex
                keySchema:
                  - attributeName: userId    # Same as table
                    keyType: HASH
                  - attributeName: activityType
                    keyType: RANGE
                projection:
                  projectionType: ALL
```

### Multiple LSIs

Multiple alternate sort keys for flexible queries:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: sensor-data
  namespace: default
spec:
  components:
    - name: readings-table
      type: dynamodb-table
      properties:
        region: us-west-2
        attributeDefinitions:
          - attributeName: deviceId
            attributeType: S
          - attributeName: timestamp
            attributeType: N
          - attributeName: temperature
            attributeType: N
          - attributeName: humidity
            attributeType: N
        keySchema:
          - attributeName: deviceId
            keyType: HASH
          - attributeName: timestamp
            keyType: RANGE
      traits:
        - type: dynamodb-local-index
          properties:
            indexes:
              # Query by temperature
              - indexName: TemperatureIndex
                keySchema:
                  - attributeName: deviceId
                    keyType: HASH
                  - attributeName: temperature
                    keyType: RANGE
                projection:
                  projectionType: KEYS_ONLY

              # Query by humidity
              - indexName: HumidityIndex
                keySchema:
                  - attributeName: deviceId
                    keyType: HASH
                  - attributeName: humidity
                    keyType: RANGE
                projection:
                  projectionType: INCLUDE
                  nonKeyAttributes: [location, batteryLevel]
```

## Best Practices

1. **Plan at table creation**: LSIs cannot be added later
2. **Limit number**: Maximum 5 LSIs per table
3. **Monitor size**: 10GB limit per partition key value
4. **Use KEYS_ONLY**: Minimize storage overhead
5. **Strongly consistent reads**: Leverage LSI advantage over GSI

## Query Patterns

### Query LSI with Strongly Consistent Read
```python
response = dynamodb.query(
    TableName='MyTable',
    IndexName='ActivityTypeIndex',
    ConsistentRead=True,  # Possible with LSI!
    KeyConditionExpression='userId = :uid AND activityType = :type',
    ExpressionAttributeValues={
        ':uid': 'user123',
        ':type': 'login'
    }
)
```

## Troubleshooting

### Issue: Cannot Add LSI to Existing Table

**Symptoms**: LSI creation fails
**Cause**: LSIs must be created with table
**Solution**: Create new table with LSI, migrate data, delete old table

### Issue: 10GB Limit Exceeded

**Symptoms**: ItemCollectionSizeLimitExceededException
**Cause**: Single partition > 10GB (including all LSIs)
**Solution**:
- Remove unnecessary LSIs
- Use GSI instead (no size limit)
- Redesign partition key for better distribution

## Related Traits

- **dynamodb-global-index**: For queries with different partition keys
- **dynamodb-table**: Base component

## Version History

- **v1.0.0**: Initial release

## Sources

- [AWS DynamoDB Local Secondary Indexes](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/LSI.html)
