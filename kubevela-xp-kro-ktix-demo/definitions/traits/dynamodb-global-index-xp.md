# DynamoDB Global Secondary Index Trait

## Overview

The `dynamodb-global-index` trait adds Global Secondary Indexes (GSI) to DynamoDB tables. GSIs enable alternate query patterns by allowing you to query on attributes other than the primary key, providing flexible data access patterns without table scans.

## Use Cases

- **Alternate query patterns** requiring different partition/sort keys
- **Multiple access patterns** for the same data
- **Query by non-key attributes** (e.g., query users by email instead of userId)
- **Sparse indexes** for querying subset of data
- **Cross-partition queries** spanning multiple partition key values

### When NOT to Use

- Queries on primary key are sufficient → No GSI needed
- Real-time strong consistency required → GSIs are eventually consistent
- Cost constraints → Each GSI adds capacity costs
- Simple queries → Consider application-side filtering first

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| indexes | array | Yes | Array of global secondary indexes (max 20) |

### Index Configuration

Each index in the `indexes` array has these fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| indexName | string | Yes | Name of the GSI |
| keySchema | array | Yes | Key schema for the index |
| projection | object | Yes | Attributes to project into index |
| provisionedThroughput | object | No | Capacity for PROVISIONED billing mode |

#### `keySchema`
- **Type**: array
- **Required**: Yes
- **Description**: Partition key (HASH) required, sort key (RANGE) optional
- **Example**:
  ```yaml
  keySchema:
    - attributeName: email
      keyType: HASH
    - attributeName: createdAt
      keyType: RANGE
  ```

#### `projection`
- **Type**: object
- **Required**: Yes
- **Fields**:
  - `projectionType`: `ALL`, `KEYS_ONLY`, or `INCLUDE`
  - `nonKeyAttributes`: Array of attribute names (only for `INCLUDE` type)
- **Description**:
  - **ALL**: Project all attributes (highest storage cost, no additional reads)
  - **KEYS_ONLY**: Only key attributes (lowest storage cost, requires additional reads for non-key data)
  - **INCLUDE**: Project specified attributes (balanced approach)
- **Example**:
  ```yaml
  projection:
    projectionType: INCLUDE
    nonKeyAttributes: [name, email, status]
  ```

#### `provisionedThroughput` (PROVISIONED billing only)
- **Type**: object
- **Required**: Only if table uses PROVISIONED billing
- **Fields**:
  - `readCapacityUnits`: int (>0)
  - `writeCapacityUnits`: int (>0)
- **Example**:
  ```yaml
  provisionedThroughput:
    readCapacityUnits: 50
    writeCapacityUnits: 25
  ```

## Cost Implications

### 💰💰 High Cost

GSIs incur **additional costs** beyond base table:

**Storage Costs**:
- **Projection ALL**: ~2x table storage (duplicates all data)
- **Projection KEYS_ONLY**: Minimal additional storage
- **Projection INCLUDE**: Depends on included attributes

**Capacity Costs** (PROVISIONED billing):
- Each GSI has separate read/write capacity
- **Example**: Table with 100 RCU/100 WCU + 2 GSIs with 50 RCU/50 WCU each
  - Total: 200 RCU, 200 WCU
  - Cost: ~$113/month (vs $56/month for table only)

**Capacity Costs** (PAY_PER_REQUEST billing):
- Each GSI query/scan charged separately
- Writes to table also write to GSIs

**Cost Optimization**:
1. **Minimize GSIs**: Only create needed indexes
2. **Use KEYS_ONLY**: Project only necessary attributes
3. **Sparse indexes**: Use GSI for subset of items
4. **Lower GSI capacity**: GSIs often need less capacity than table

## Limitations

- **Maximum**: 20 GSIs per table
- **Consistency**: Eventually consistent (no strongly consistent reads)
- **Key attributes**: Must be defined in table's attributeDefinitions
- **Creation time**: 5-15 minutes per index
- **Updates**: Cannot modify key schema after creation (must delete and recreate)

## Examples

### Single GSI for Email Lookup

Query users by email instead of userId:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: user-management
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
          - attributeName: email
            attributeType: S
        keySchema:
          - attributeName: userId
            keyType: HASH
      traits:
        - type: dynamodb-global-index
          properties:
            indexes:
              - indexName: EmailIndex
                keySchema:
                  - attributeName: email
                    keyType: HASH
                projection:
                  projectionType: ALL
```

### Multiple GSIs with Different Projections

Complex access patterns with optimized projections:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: product-catalog
  namespace: default
spec:
  components:
    - name: products-table
      type: dynamodb-table
      properties:
        region: us-west-2
        attributeDefinitions:
          - attributeName: productId
            attributeType: S
          - attributeName: category
            attributeType: S
          - attributeName: price
            attributeType: N
          - attributeName: createdAt
            attributeType: N
        keySchema:
          - attributeName: productId
            keyType: HASH
      traits:
        - type: dynamodb-global-index
          properties:
            indexes:
              # Query by category and price
              - indexName: CategoryPriceIndex
                keySchema:
                  - attributeName: category
                    keyType: HASH
                  - attributeName: price
                    keyType: RANGE
                projection:
                  projectionType: INCLUDE
                  nonKeyAttributes: [name, description, imageUrl]

              # Query by creation date (all attributes)
              - indexName: CreatedAtIndex
                keySchema:
                  - attributeName: createdAt
                    keyType: HASH
                projection:
                  projectionType: ALL
```

### GSI with Provisioned Capacity

GSI with separate capacity for cost control:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: order-system
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
          - attributeName: customerId
            attributeType: S
          - attributeName: orderDate
            attributeType: N
        keySchema:
          - attributeName: orderId
            keyType: HASH
      traits:
        - type: dynamodb-provisioned-capacity
          properties:
            readCapacityUnits: 100
            writeCapacityUnits: 100

        - type: dynamodb-global-index
          properties:
            indexes:
              - indexName: CustomerOrdersIndex
                keySchema:
                  - attributeName: customerId
                    keyType: HASH
                  - attributeName: orderDate
                    keyType: RANGE
                projection:
                  projectionType: KEYS_ONLY
                provisionedThroughput:
                  readCapacityUnits: 50    # Lower than table
                  writeCapacityUnits: 50
```

### Sparse Index Example

GSI for subset of items (e.g., only active items):

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: inventory
  namespace: default
spec:
  components:
    - name: items-table
      type: dynamodb-table
      properties:
        region: us-east-1
        attributeDefinitions:
          - attributeName: itemId
            attributeType: S
          - attributeName: status
            attributeType: S    # Only "active" items will be indexed
        keySchema:
          - attributeName: itemId
            keyType: HASH
      traits:
        - type: dynamodb-global-index
          properties:
            indexes:
              - indexName: ActiveItemsIndex
                keySchema:
                  - attributeName: status
                    keyType: HASH
                projection:
                  projectionType: ALL
```

**Note**: Only items with a `status` attribute will appear in the GSI, making it sparse and cost-effective.

## Best Practices

1. **Plan access patterns first**: Design GSIs based on query requirements
2. **Use sparse indexes**: Only index items with specific attributes
3. **Optimize projections**:
   - Use `KEYS_ONLY` if you can query by key and fetch details separately
   - Use `INCLUDE` for frequently accessed attributes
   - Avoid `ALL` unless necessary (doubles storage)
4. **Lower GSI capacity**: GSIs often need 30-50% of table capacity
5. **Batch index creation**: Create multiple GSIs together (faster than sequential)
6. **Monitor GSI utilization**: Remove unused indexes

## Query Patterns

### Query by GSI
```python
response = dynamodb.query(
    TableName='MyTable',
    IndexName='EmailIndex',
    KeyConditionExpression='email = :email',
    ExpressionAttributeValues={':email': 'user@example.com'}
)
```

### Query with Sort Key Range
```python
response = dynamodb.query(
    TableName='MyTable',
    IndexName='CategoryPriceIndex',
    KeyConditionExpression='category = :cat AND price BETWEEN :min AND :max',
    ExpressionAttributeValues={
        ':cat': 'Electronics',
        ':min': 100,
        ':max': 500
    }
)
```

## Troubleshooting

### Issue: Index Creation Takes Long Time

**Symptoms**: GSI stuck in CREATING status
**Cause**: Large tables take longer to backfill
**Solution**:
- Wait (can take hours for large tables)
- Monitor progress via AWS Console
- Index is usable once status is ACTIVE

### Issue: High GSI Costs

**Symptoms**: Higher bills than expected
**Cause**: GSI storage and capacity costs
**Solution**:
1. Use `KEYS_ONLY` or `INCLUDE` instead of `ALL`
2. Remove unused GSIs
3. Lower GSI capacity (often needs less than table)
4. Use sparse indexes

### Issue: Throttling on GSI

**Symptoms**: `ProvisionedThroughputExceededException` on GSI queries
**Cause**: Insufficient GSI capacity
**Solution**:
- Increase GSI read/write capacity
- Balance load across multiple GSIs
- Consider on-demand billing for unpredictable loads

### Issue: Cannot Find Data in GSI

**Symptoms**: Query returns no results
**Cause**:
- GSI is eventually consistent (slight delay)
- Sparse index missing attribute
**Solution**:
- Wait a few milliseconds for eventual consistency
- Verify item has GSI key attributes
- Check projection includes required attributes

## Related Traits

- **dynamodb-local-index**: Alternative for queries sharing partition key
- **dynamodb-provisioned-capacity**: Required for GSI capacity in PROVISIONED mode
- **dynamodb-table**: Base component

## Version History

- **v1.0.0**: Initial release

## Sources

- [AWS DynamoDB Global Secondary Indexes](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GSI.html)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
