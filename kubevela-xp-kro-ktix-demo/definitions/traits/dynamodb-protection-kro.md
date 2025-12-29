# DynamoDB Protection Trait (KRO)

## Overview

The `dynamodb-protection-kro` trait enables critical data protection features for DynamoDB tables, including deletion protection and point-in-time recovery (PITR). These features protect against accidental data loss and enable disaster recovery.

## Applies To

- Components of type: `aws-dynamodb-kro`
- Workload type: `kro.run/DynamoDBTable`

## Protection Features

### Deletion Protection
- Prevents accidental deletion via console, CLI, or API
- Must be explicitly disabled before table can be deleted
- No additional cost
- **Highly recommended for production tables**

### Point-in-Time Recovery (PITR)
- Continuous backups for the last 35 days
- Restore to any second within the backup window
- No performance impact
- Additional cost: ~$0.20 per GB-month
- **Essential for production data**

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `deletionProtection` | boolean | No | `true` | Prevent table deletion |
| `pointInTimeRecovery` | boolean | No | `true` | Enable continuous backups |

## Examples

### Full Protection (Recommended for Production)

Enable both deletion protection and PITR:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: protected-table
spec:
  components:
    - name: user-data
      type: aws-dynamodb-kro
      properties:
        tableName: users-prod
        region: us-east-1
        attributeDefinitions:
          - attributeName: userId
            attributeType: S
        keySchema:
          - attributeName: userId
            keyType: HASH
      traits:
        - type: dynamodb-protection-kro
          properties:
            deletionProtection: true
            pointInTimeRecovery: true
```

### Deletion Protection Only

Protect against deletion but skip PITR (saves cost):

```yaml
traits:
  - type: dynamodb-protection-kro
    properties:
      deletionProtection: true
      pointInTimeRecovery: false
```

### PITR Only

Enable backups without deletion protection:

```yaml
traits:
  - type: dynamodb-protection-kro
    properties:
      deletionProtection: false
      pointInTimeRecovery: true
```

### Development Table (No Protection)

Disable all protection for dev/test environments:

```yaml
traits:
  - type: dynamodb-protection-kro
    properties:
      deletionProtection: false
      pointInTimeRecovery: false
```

## Deletion Protection

### How It Works

When enabled, any attempt to delete the table will fail with:

```
DeletionProtectionException: Table cannot be deleted because
deletion protection is enabled. Disable deletion protection and try again.
```

### Disabling Deletion Protection

To delete a protected table:

1. Update the application to disable protection:
```yaml
traits:
  - type: dynamodb-protection-kro
    properties:
      deletionProtection: false
```

2. Wait for update to complete
3. Delete the table

### Best Practices

✅ **Always enable for production tables**
✅ Enable for staging tables with important data
❌ Optional for development/test tables
✅ Use naming conventions (e.g., `*-prod`) to identify protected tables
✅ Document tables that require protection

## Point-in-Time Recovery (PITR)

### How It Works

- **Continuous backups**: Automatically captures changes
- **35-day retention**: Restore to any point in the last 35 days
- **Second-level granularity**: Restore to any specific second
- **No performance impact**: Backups are asynchronous
- **Separate billing**: Charged per GB of table size

### Restore Process

**1. Identify restore point:**
```bash
# List backup details
aws dynamodb describe-continuous-backups \
  --table-name users-prod
```

**2. Restore to new table:**
```bash
aws dynamodb restore-table-to-point-in-time \
  --source-table-name users-prod \
  --target-table-name users-prod-restored-2024-01-15 \
  --restore-date-time "2024-01-15T10:30:00Z"
```

**3. Verify restored data:**
```bash
# Check item count
aws dynamodb describe-table \
  --table-name users-prod-restored-2024-01-15 \
  --query 'Table.ItemCount'
```

**4. Switch application to restored table:**
- Update application configuration
- Or swap table names (requires deleting original)

### Restore Options

**Restore to specific timestamp:**
```bash
aws dynamodb restore-table-to-point-in-time \
  --source-table-name orders-prod \
  --target-table-name orders-prod-restored \
  --restore-date-time "2024-12-23T15:45:30Z"
```

**Restore to latest restorable time:**
```bash
aws dynamodb restore-table-to-point-in-time \
  --source-table-name orders-prod \
  --target-table-name orders-prod-restored \
  --use-latest-restorable-time
```

**Restore with different configuration:**
```bash
aws dynamodb restore-table-to-point-in-time \
  --source-table-name orders-prod \
  --target-table-name orders-prod-restored \
  --use-latest-restorable-time \
  --billing-mode-override PAY_PER_REQUEST
```

### What Gets Restored

✅ **Restored:**
- All items and attributes
- Partition and sort keys
- Local secondary indexes
- Table structure

❌ **Not Restored (must reconfigure):**
- Global secondary indexes (recreated but empty)
- Streams configuration
- TTL settings
- Auto Scaling settings
- Tags
- IAM policies

## Cost Analysis

### Deletion Protection
- **Cost**: $0 (free)

### Point-in-Time Recovery
- **Cost**: ~$0.20 per GB per month
- Based on table size, not data size
- Includes all indexes

**Example costs:**
- 10 GB table = $2/month
- 100 GB table = $20/month
- 1 TB table = $200/month

### Cost Optimization

1. **Enable only for production**: Skip dev/test tables
2. **Monitor table size**: Large indexes increase cost
3. **Use on-demand backups for infrequent changes**: If you rarely need backups
4. **Consider backup retention**: 35 days may be excessive

## Monitoring

### Check Protection Status

```bash
# Deletion protection status
aws dynamodb describe-table \
  --table-name users-prod \
  --query 'Table.DeletionProtectionEnabled'

# PITR status
aws dynamodb describe-continuous-backups \
  --table-name users-prod \
  --query 'ContinuousBackupsDescription.PointInTimeRecoveryDescription.PointInTimeRecoveryStatus'
```

### Latest Restorable Time

```bash
aws dynamodb describe-continuous-backups \
  --table-name users-prod \
  --query 'ContinuousBackupsDescription.PointInTimeRecoveryDescription.LatestRestorableDateTime'
```

### CloudWatch Metrics

Monitor these metrics:
- **Table size**: Affects PITR costs
- **Item count**: Track data growth
- **Consumed capacity**: Understand usage patterns

## Disaster Recovery Scenarios

### Scenario 1: Accidental Data Deletion

**Problem**: Application bug deleted 1000 items at 2:30 PM

**Solution**:
```bash
# Restore to 2:29 PM (before deletion)
aws dynamodb restore-table-to-point-in-time \
  --source-table-name users-prod \
  --target-table-name users-prod-recovered \
  --restore-date-time "2024-12-23T14:29:00Z"
```

### Scenario 2: Bad Deployment

**Problem**: Deployment at 3:00 PM corrupted data

**Solution**:
```bash
# Restore to 2:59 PM (before deployment)
aws dynamodb restore-table-to-point-in-time \
  --source-table-name orders-prod \
  --target-table-name orders-prod-pre-deployment \
  --restore-date-time "2024-12-23T14:59:00Z"
```

### Scenario 3: Ransomware Attack

**Problem**: Table data encrypted by malicious actor

**Solution**:
```bash
# Restore to before attack
aws dynamodb restore-table-to-point-in-time \
  --source-table-name sensitive-data \
  --target-table-name sensitive-data-clean \
  --restore-date-time "2024-12-20T10:00:00Z"
```

### Scenario 4: Accidental Table Deletion Attempt

**Problem**: Admin tries to delete production table

**Solution**: Deletion protection prevents deletion automatically. No action needed.

## Testing Recovery

### Regular Recovery Drills

**Monthly drill process:**

1. **Restore to test table:**
```bash
aws dynamodb restore-table-to-point-in-time \
  --source-table-name users-prod \
  --target-table-name users-prod-drill-$(date +%Y%m%d) \
  --use-latest-restorable-time
```

2. **Verify data integrity:**
```bash
# Compare item counts
aws dynamodb scan --table-name users-prod --select COUNT
aws dynamodb scan --table-name users-prod-drill-20241223 --select COUNT
```

3. **Test application connectivity:**
```bash
# Update config to point to restored table
# Run integration tests
# Verify all queries work
```

4. **Document results:**
- Restore time: How long did it take?
- Data accuracy: Was data correct?
- Issues: What problems occurred?

5. **Clean up:**
```bash
aws dynamodb delete-table --table-name users-prod-drill-20241223
```

## Best Practices

### Always Enable for Production

```yaml
# Production environment
traits:
  - type: dynamodb-protection-kro
    properties:
      deletionProtection: true
      pointInTimeRecovery: true
```

### Environment-Based Configuration

**Production:**
```yaml
traits:
  - type: dynamodb-protection-kro
    properties:
      deletionProtection: true
      pointInTimeRecovery: true
```

**Staging:**
```yaml
traits:
  - type: dynamodb-protection-kro
    properties:
      deletionProtection: true
      pointInTimeRecovery: false  # Cost savings
```

**Development:**
```yaml
# No protection trait (use defaults)
```

### Document Recovery Procedures

Create runbooks for common scenarios:

1. **Accidental deletion recovery**
2. **Point-in-time restore process**
3. **Failover procedures**
4. **Escalation contacts**

### Test Regularly

- Monthly: Restore drill
- Quarterly: Full disaster recovery test
- Annually: Cross-region recovery test

### Monitor Costs

```bash
# Check table size (affects PITR costs)
aws dynamodb describe-table \
  --table-name users-prod \
  --query 'Table.TableSizeBytes'
```

## Combining with Other Traits

### Full Production Protection

```yaml
traits:
  - type: dynamodb-protection-kro
    properties:
      deletionProtection: true
      pointInTimeRecovery: true
  - type: dynamodb-encryption-kro
    properties:
      sseType: KMS
      kmsKeyId: alias/prod-key
  - type: dynamodb-streams-kro
    properties:
      viewType: NEW_AND_OLD_IMAGES
```

### Cost-Optimized Production

```yaml
traits:
  - type: dynamodb-protection-kro
    properties:
      deletionProtection: true
      pointInTimeRecovery: false  # Use on-demand backups instead
  - type: dynamodb-encryption-kro
    properties:
      sseType: AES256  # Free encryption
```

## Compliance Considerations

### HIPAA

✅ **Required:**
- Enable point-in-time recovery
- Enable deletion protection
- Document recovery procedures
- Test recovery regularly

### PCI-DSS

✅ **Required:**
- Backup cardholder data
- Retention period: minimum 90 days (use on-demand backups + PITR)
- Test restore procedures

### SOC 2

✅ **Required:**
- Data backup and recovery procedures
- Regular testing of backups
- Documentation of RTO/RPO
- Monitoring and alerting

## Troubleshooting

### Cannot delete table

**Cause**: Deletion protection enabled

**Solution**:
```yaml
# Disable protection first
traits:
  - type: dynamodb-protection-kro
    properties:
      deletionProtection: false
```

### Restore failed

**Common causes:**
1. Target table name already exists
2. Invalid timestamp (outside 35-day window)
3. IAM permissions missing

**Solution**:
```bash
# Check IAM permissions
aws iam simulate-principal-policy \
  --policy-source-arn <role-arn> \
  --action-names dynamodb:RestoreTableToPointInTime \
  --resource-arns <table-arn>
```

### PITR not available

**Cause**: Recently enabled (not immediately available)

**Solution**: Wait 5-10 minutes after enabling PITR

## References

- [DynamoDB Point-in-Time Recovery](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/PointInTimeRecovery.html)
- [DynamoDB Deletion Protection](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/WorkingWithTables.Basics.html#WorkingWithTables.Basics.DeletionProtection)
- [Restore Using PITR](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/PointInTimeRecovery.Tutorial.html)

## Related Traits

- `dynamodb-encryption-kro` - Server-side encryption
- `dynamodb-streams-kro` - Change data capture for replication
