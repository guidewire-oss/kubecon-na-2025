# DynamoDB Table Component

## Overview

The `dynamodb-table` component creates AWS DynamoDB NoSQL database tables using Crossplane. DynamoDB is a fully managed, serverless key-value NoSQL database designed to run high-performance applications at any scale with built-in security, backup and restore, and in-memory caching.

## Use Cases

- **NoSQL databases** for web and mobile applications
- **Session storage** for high-traffic web applications
- **Metadata storage** for S3 objects or application data
- **Gaming leaderboards** with fast read/write access
- **IoT data ingestion** with high write throughput
- **Real-time analytics** with DynamoDB Streams integration
- **Shopping carts** and user profiles for e-commerce

### When NOT to Use

- Complex relational queries with JOIN operations → Use RDS instead
- Full-text search requirements → Use Elasticsearch/OpenSearch
- ACID transactions across multiple tables → Use RDS with PostgreSQL/MySQL
- Analytics with complex aggregations → Use Redshift or Athena

## Parameters

### Required Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| region | string | AWS region where the table will be created | `us-east-1` |
| attributeDefinitions | array | Attribute definitions for keys and indexes | See below |
| keySchema | array | Primary key schema (partition key + optional sort key) | See below |

### Optional Parameters

| Parameter | Type | Default | Description | Example |
|-----------|------|---------|-------------|---------|
| billingMode | string | `PAY_PER_REQUEST` | Billing mode for capacity management | `PROVISIONED` |
| tableClass | string | `STANDARD` | Storage class for the table | `STANDARD_INFREQUENT_ACCESS` |
| tags | array | - | Key-value tags for organization | See below |
| providerConfigRef | string | `default` | Crossplane provider config reference | `aws-provider` |

### Parameter Details

#### `region`
- **Type**: `string`
- **Required**: Yes
- **Description**: AWS region where the DynamoDB table will be created
- **Example**: `us-east-1`, `us-west-2`, `eu-west-1`

#### `attributeDefinitions`
- **Type**: `array`
- **Required**: Yes
- **Description**: Array of attribute definitions that describe the key schema for the table and indexes. Only define attributes used in key schemas (partition keys, sort keys, or index keys).
- **Fields**:
  - `attributeName` (string): Name of the attribute
  - `attributeType` (string): Data type - `S` (string), `N` (number), or `B` (binary)
- **⚠️ Important**: Always quote attribute type values (`"S"`, `"N"`, `"B"`). Unquoted values like `N` are interpreted as booleans by YAML parsers.
- **Example**:
  ```yaml
  attributeDefinitions:
    - attributeName: userId
      attributeType: "S"
    - attributeName: timestamp
      attributeType: "N"
  ```

#### `keySchema`
- **Type**: `array`
- **Required**: Yes
- **Description**: Specifies the attributes that make up the primary key. Must contain exactly one `HASH` (partition key) and optionally one `RANGE` (sort key).
- **Fields**:
  - `attributeName` (string): Name of the key attribute (must be defined in attributeDefinitions)
  - `keyType` (string): `HASH` for partition key, `RANGE` for sort key
- **Example**:
  ```yaml
  keySchema:
    - attributeName: userId
      keyType: HASH
    - attributeName: timestamp
      keyType: RANGE
  ```

#### `billingMode`
- **Type**: `string`
- **Required**: No
- **Default**: `PAY_PER_REQUEST`
- **Options**: `PAY_PER_REQUEST` (on-demand) or `PROVISIONED`
- **Description**: Controls how you are charged for read and write throughput
  - **PAY_PER_REQUEST**: Pay per request (recommended for unpredictable workloads)
  - **PROVISIONED**: Specify read/write capacity units (use with `dynamodb-provisioned-capacity` trait)
- **Note**: Traits can override this value. The `dynamodb-provisioned-capacity` trait automatically sets this to `PROVISIONED`.
- **Example**: `PAY_PER_REQUEST`

#### `tableClass`
- **Type**: `string`
- **Required**: No
- **Default**: `STANDARD`
- **Options**: `STANDARD` or `STANDARD_INFREQUENT_ACCESS`
- **Description**: Storage class for the table
  - **STANDARD**: Default table class for frequently accessed data
  - **STANDARD_INFREQUENT_ACCESS**: Cost-optimized for infrequently accessed data (lower storage cost, higher request cost)
- **Example**: `STANDARD_INFREQUENT_ACCESS`

#### `tags`
- **Type**: `array`
- **Required**: No
- **Description**: Key-value pairs for organizing and managing resources
- **Example**:
  ```yaml
  tags:
    - key: Environment
      value: Production
    - key: Team
      value: Backend
  ```

## Health Policies

The component implements comprehensive health policies to track table status:

### Status Details
Captured fields exported to Application status:
- **tableArn**: Amazon Resource Name (ARN) of the table
- **tableStatus**: Current status (`CREATING`, `ACTIVE`, `UPDATING`, `DELETING`)
- **itemCount**: Approximate number of items in the table
- **tableSizeBytes**: Approximate size of the table in bytes

### Health Check
The table is considered healthy when:
- Crossplane status conditions are present and True
- Table status is `ACTIVE`

### Custom Status Messages
- **Healthy**: "Table ACTIVE: {itemCount} items, {tableSizeBytes} bytes, ARN: {tableArn}"
- **Unhealthy**: "Table status: {tableStatus} - waiting for ACTIVE state"

## Cost Implications

### Billing Modes

**PAY_PER_REQUEST (On-Demand)** 💰
- Pay per request pricing
- No capacity planning required
- Best for: Unpredictable or spiky traffic
- Cost: $1.25 per million write requests, $0.25 per million read requests (us-east-1)

**PROVISIONED** 💰💰
- Pre-provisioned read/write capacity units
- Lower cost for predictable, consistent traffic
- Requires capacity planning and monitoring
- Use with `dynamodb-provisioned-capacity` trait
- Cost: ~$0.00065 per WCU-hour, ~$0.00013 per RCU-hour (us-east-1)

### Table Classes

**STANDARD** 💰
- Default storage class
- Optimized for frequently accessed data
- Higher throughput performance

**STANDARD_INFREQUENT_ACCESS** 💰 (50% savings)
- Lower storage costs (~50% cheaper)
- Higher per-request costs
- Best for: Data accessed less than once per month

### Additional Costs
- **Storage**: $0.25 per GB-month (STANDARD), $0.125 per GB-month (STANDARD_IA)
- **Data transfer**: Standard AWS data transfer rates apply
- **Backups**: Point-in-time recovery and on-demand backups incur additional costs (see `dynamodb-protection` trait)
- **Streams**: DynamoDB Streams incur additional costs (see `dynamodb-streams` trait)
- **Global tables**: Cross-region replication costs apply

## Security Considerations

### Encryption
- **Encryption at rest**: Enabled by default with AWS-managed keys
- **Custom KMS encryption**: Use `dynamodb-encryption` trait for compliance requirements
- **Encryption in transit**: All API calls use TLS/HTTPS

### Access Control
- **IAM policies**: Control access through Crossplane ProviderConfig
- **Fine-grained access**: Item-level permissions via IAM policy conditions
- **VPC endpoints**: Access DynamoDB without internet gateway for enhanced security

### Authentication
- **AWS credentials**: Managed via Crossplane ProviderConfig
- **IRSA**: Use IAM Roles for Service Accounts in EKS

### Compliance
- **SOC**: SOC 1, 2, 3 compliant
- **PCI DSS**: Level 1 compliant
- **HIPAA**: HIPAA eligible
- **FedRAMP**: FedRAMP authorized

## Related Traits

Enhance the `dynamodb-table` component with these traits:

- **dynamodb-provisioned-capacity**: Set read/write capacity units for predictable workloads (💰💰 cost control)
- **dynamodb-global-index**: Add global secondary indexes for alternate query patterns (💰💰 expensive)
- **dynamodb-local-index**: Add local secondary indexes for alternate sort keys (💰 storage overhead)
- **dynamodb-encryption**: Custom KMS encryption for compliance (🔒 security)
- **dynamodb-protection**: Deletion protection + point-in-time recovery (🔒💰 data protection)
- **dynamodb-streams**: Enable change data capture for event-driven architectures (💰 streaming costs)

## Examples

### Basic Example - Partition Key Only

Minimal DynamoDB table with partition key:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: user-sessions
  namespace: default
spec:
  components:
    - name: sessions-table
      type: dynamodb-table
      properties:
        region: us-east-1
        attributeDefinitions:
          - attributeName: sessionId
            attributeType: "S"
        keySchema:
          - attributeName: sessionId
            keyType: HASH
```

### Example with Composite Key

Table with partition key and sort key:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: user-events
  namespace: default
spec:
  components:
    - name: events-table
      type: dynamodb-table
      properties:
        region: us-west-2
        attributeDefinitions:
          - attributeName: userId
            attributeType: "S"
          - attributeName: timestamp
            attributeType: "N"
        keySchema:
          - attributeName: userId
            keyType: HASH
          - attributeName: timestamp
            keyType: RANGE
        tags:
          - key: Application
            value: Analytics
          - key: Environment
            value: Production
```

### Example with Table Class

Cost-optimized table for infrequent access:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: archive-data
  namespace: default
spec:
  components:
    - name: archive-table
      type: dynamodb-table
      properties:
        region: us-east-1
        attributeDefinitions:
          - attributeName: recordId
            attributeType: "S"
        keySchema:
          - attributeName: recordId
            keyType: HASH
        tableClass: STANDARD_INFREQUENT_ACCESS
```

## Common Patterns

### Pattern 1: Simple Key-Value Store
**Use case**: Session storage, cache
```yaml
attributeDefinitions:
  - attributeName: key
    attributeType: "S"
keySchema:
  - attributeName: key
    keyType: HASH
```

### Pattern 2: Time-Series Data
**Use case**: Logs, metrics, events
```yaml
attributeDefinitions:
  - attributeName: deviceId
    attributeType: "S"
  - attributeName: timestamp
    attributeType: "N"
keySchema:
  - attributeName: deviceId
    keyType: HASH
  - attributeName: timestamp
    keyType: RANGE
```

### Pattern 3: User Data with Sort Key
**Use case**: User profiles, shopping carts
```yaml
attributeDefinitions:
  - attributeName: userId
    attributeType: "S"
  - attributeName: itemType
    attributeType: "S"
keySchema:
  - attributeName: userId
    keyType: HASH
  - attributeName: itemType
    keyType: RANGE
```

## Troubleshooting

### Issue: Table Creation Fails

**Symptoms**: Table stays in CREATING status or fails
**Possible Causes**:
- Invalid AWS credentials in ProviderConfig
- Insufficient IAM permissions
- Invalid attribute or key schema
**Solution**:
1. Check Crossplane provider logs: `kubectl logs -n crossplane-system deployment/crossplane`
2. Verify ProviderConfig has correct credentials
3. Ensure IAM role has `dynamodb:CreateTable` permission
4. Validate attribute names match between attributeDefinitions and keySchema

### Issue: "ValidationException: One or more parameter values were invalid"

**Symptoms**: Table creation fails with validation error
**Cause**: Mismatch between attributeDefinitions and keySchema
**Solution**: Ensure all attributes used in keySchema are defined in attributeDefinitions

### Issue: High Costs

**Symptoms**: Unexpected AWS bills
**Possible Causes**:
- On-demand billing with high request volumes
- Unused global secondary indexes consuming capacity
- Large table size with frequent scans
**Solution**:
1. Review request patterns and consider PROVISIONED billing
2. Remove unused indexes
3. Use Query instead of Scan operations
4. Enable DynamoDB auto-scaling (use `dynamodb-provisioned-capacity` trait)

### Issue: Table Status Shows "UPDATING"

**Symptoms**: Table remains in UPDATING status
**Cause**: Normal during:
- Adding/removing indexes
- Updating provisioned capacity
- Enabling/disabling streams or PITR
**Solution**: Wait for operation to complete (typically 5-15 minutes for indexes)

## Migration Guide

### Migrating from Terraform

If migrating from Terraform DynamoDB resources:

1. Export existing table schema from AWS Console or CLI
2. Map Terraform attributes to component parameters:
   - `hash_key` → keySchema with HASH type
   - `range_key` → keySchema with RANGE type
   - `billing_mode` → billingMode
   - `attribute` → attributeDefinitions
3. Create Application manifest with matching parameters
4. Use Crossplane import feature to adopt existing table (avoid recreation)

### Upgrading Table Configuration

To modify an existing table:
1. Update the Application manifest with new parameters
2. Apply changes: `kubectl apply -f application.yaml`
3. Monitor table status: `vela status <app-name>`

**Note**: Some operations require table recreation (changing primary key). Plan for downtime or use blue-green deployment.

## Version History

- **v1.0.0**: Initial release with Crossplane DynamoDB Table CRD support

## Sources

- [Upbound DynamoDB Table CRD](https://marketplace.upbound.io/providers/crossplane-contrib/provider-aws/v0.46.0/resources/dynamodb.aws.crossplane.io/Table/v1alpha1)
- [AWS DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [DynamoDB Cost Optimization 2025](https://www.sedai.io/blog/how-to-optimize-amazon-dynamodb-costs-in-2025)
- [DynamoDB Security Best Practices](https://dynobase.dev/dynamodb-security/)
