# DynamoDB Protection Trait

## Overview

The `dynamodb-protection` trait enables deletion protection and point-in-time recovery for DynamoDB tables. This trait is critical for production environments, preventing accidental data loss and enabling disaster recovery.

## Use Cases

- **Production environments** requiring data protection
- **Compliance requirements** for backup and recovery
- **Disaster recovery** planning
- **Accidental deletion prevention**
- **Data integrity** and audit requirements

### When NOT to Use

- Development/test environments → Protection adds cost and complexity
- Temporary tables → No need for backups
- Tables with external backups → Duplicate backup costs

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| deletionProtection | bool | No | `true` | Prevent accidental table deletion |
| pointInTimeRecovery | bool | No | `true` | Enable continuous backups (35 days) |

### Parameter Details

#### `deletionProtection`
- **Type**: `bool`
- **Default**: `true`
- **Description**: Prevents table deletion until protection is disabled
  - Requires explicit disable action before deletion
  - Recommended for all production tables
- **Example**: `true`

#### `pointInTimeRecovery`
- **Type**: `bool`
- **Default**: `true`
- **Description**: Enables continuous backups for point-in-time recovery
  - Restore to any second in the last 35 days
  - No performance impact
  - Incurs additional storage costs
- **Example**: `true`

## Cost Implications

### 🔒💰 Medium Cost (Data Protection Investment)

**Point-in-Time Recovery**:
- **Storage cost**: $0.20 per GB-month
- **Restore cost**: Free (same region)
- **Cross-region restore**: Standard data transfer costs

**Deletion Protection**:
- **No cost**: Free feature

**Example Costs**:
- **Small table** (1GB): $0.20/month
- **Medium table** (100GB): $20/month
- **Large table** (1TB): $200/month

**Cost Optimization**:
- Disable PITR for non-critical dev/test tables
- Use on-demand backups for infrequent backup needs
- Consider retention policies (PITR is 35 days only)

## Benefits

### Deletion Protection

**Prevents**:
- Accidental table deletion via console/API/CLI
- Unauthorized deletion by misconfigured automation
- Human error during maintenance

**Requires**:
- Explicit disable action before deletion
- Additional IAM permission: `dynamodb:UpdateTable`

### Point-in-Time Recovery (PITR)

**Enables**:
- Restore to any second within 35 days
- Zero RPO (recovery point objective)
- No performance impact during normal operations
- Continuous backup (no snapshots to manage)

**Use Cases**:
- Recover from accidental writes/deletes
- Restore before application bug corrupted data
- Meet compliance retention requirements
- Disaster recovery testing

## Examples

### Production Table with Full Protection

Enable both deletion protection and PITR:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: production-data
  namespace: production
spec:
  components:
    - name: critical-table
      type: dynamodb-table
      properties:
        region: us-east-1
        attributeDefinitions:
          - attributeName: recordId
            attributeType: S
        keySchema:
          - attributeName: recordId
            keyType: HASH
      traits:
        - type: dynamodb-protection
          properties:
            deletionProtection: true
            pointInTimeRecovery: true
```

### Compliance-Ready Configuration

Full protection with encryption:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: financial-records
  namespace: finance
spec:
  components:
    - name: transactions-table
      type: dynamodb-table
      properties:
        region: us-west-2
        attributeDefinitions:
          - attributeName: transactionId
            attributeType: S
        keySchema:
          - attributeName: transactionId
            keyType: HASH
        tags:
          - key: Compliance
            value: PCI-DSS
          - key: DataClassification
            value: Sensitive
      traits:
        # Data protection
        - type: dynamodb-protection
          properties:
            deletionProtection: true
            pointInTimeRecovery: true

        # Encryption
        - type: dynamodb-encryption
          properties:
            enabled: true
            kmsKeyId: alias/finance-prod
            sseType: KMS
```

### Selective Protection

PITR only, allow deletion:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: analytics-data
  namespace: default
spec:
  components:
    - name: events-table
      type: dynamodb-table
      properties:
        region: us-east-1
        attributeDefinitions:
          - attributeName: eventId
            attributeType: S
        keySchema:
          - attributeName: eventId
            keyType: HASH
      traits:
        - type: dynamodb-protection
          properties:
            deletionProtection: false  # Can delete table
            pointInTimeRecovery: true  # But have backups
```

## Point-in-Time Recovery Details

### Restore Process

**Restore to new table**:
1. Specify restore time (any second in last 35 days)
2. DynamoDB creates new table with restored data
3. Original table remains unchanged
4. Update application to use new table

**Restore time selection**:
- **Latest restorable time**: Most recent backup (within 5 minutes)
- **Specific time**: Choose exact timestamp
- **Earliest restorable time**: 35 days ago

### What Gets Restored

**Included**:
- Table data (all items)
- Table schema (attribute definitions, key schema)
- Local secondary indexes
- Global secondary indexes

**NOT Included**:
- Provisioned capacity settings (uses on-demand by default)
- Auto-scaling settings
- Tags
- IAM policies
- TTL settings
- Streams settings

### Restore Considerations

- **Downtime**: Requires switching application to new table
- **Testing**: Test restores regularly (compliance requirement)
- **Cross-region**: Can restore to different region
- **Time**: Restore time depends on table size (minutes to hours)

## Best Practices

1. **Enable for all production tables**: Default to protection enabled
2. **Test restores regularly**: Validate recovery procedures
3. **Document restore process**: Create runbooks
4. **Monitor PITR costs**: Track storage costs in CloudWatch
5. **Combine with on-demand backups**: For long-term retention (>35 days)
6. **Tag protected tables**: Identify critical tables

## Disaster Recovery Strategy

### Multi-Tier Protection

1. **Tier 1 - PITR**: Continuous backups (35 days)
2. **Tier 2 - On-Demand Backups**: Long-term retention (years)
3. **Tier 3 - Cross-Region Replication**: Global tables for HA

### Recovery Time Objectives (RTO)

- **PITR restore**: 30 minutes to 2 hours (depending on size)
- **On-demand restore**: Similar to PITR
- **Global table failover**: Seconds to minutes

### Recovery Point Objectives (RPO)

- **PITR**: Zero (continuous backup)
- **On-demand backups**: Depends on backup frequency
- **Global tables**: Near-zero (replication lag <1 second)

## Compliance

### HIPAA
- ✅ Point-in-time recovery for data integrity
- ✅ Deletion protection prevents unauthorized removal
- ✅ Audit trail via CloudTrail

### SOC 2
- ✅ Backup and recovery procedures
- ✅ Data availability controls
- ✅ Change management controls

### PCI-DSS
- ✅ Requirement 9.5: Protect backups
- ✅ Requirement 10.5: Protect audit trails
- ✅ Requirement 12.10: Incident response plan

## Troubleshooting

### Issue: Cannot Delete Table

**Symptoms**: Table deletion fails
**Cause**: Deletion protection enabled
**Solution**:
1. Disable deletion protection first
2. Update Application manifest: `deletionProtection: false`
3. Apply changes
4. Delete table

### Issue: PITR Restore Failed

**Symptoms**: Restore operation fails
**Cause**: Invalid restore time or insufficient permissions
**Solution**:
- Check restore time is within 35-day window
- Verify IAM permissions include `dynamodb:RestoreTableToPointInTime`
- Ensure sufficient table quota in target region

### Issue: Unexpected Backup Costs

**Symptoms**: Higher AWS bills
**Cause**: PITR storage costs for large tables
**Solution**:
- Review table size vs backup requirements
- Consider disabling PITR for non-critical tables
- Use on-demand backups for infrequent backup needs

### Issue: Restore Takes Too Long

**Symptoms**: Restore operation exceeds RTO
**Cause**: Large table size
**Solution**:
- Plan for longer restore times (document in runbook)
- Consider global tables for faster failover
- Test restore process regularly to set expectations

## Restore Example (AWS CLI)

```bash
# Restore to latest restorable time
aws dynamodb restore-table-to-point-in-time \
    --source-table-name MyTable \
    --target-table-name MyTable-Restored-$(date +%Y%m%d) \
    --use-latest-restorable-time

# Restore to specific time
aws dynamodb restore-table-to-point-in-time \
    --source-table-name MyTable \
    --target-table-name MyTable-Restored-20250101 \
    --restore-date-time 2025-01-01T12:00:00Z

# Check restore status
aws dynamodb describe-table \
    --table-name MyTable-Restored-20250101 \
    --query 'Table.RestoreSummary'
```

## Related Traits

- **dynamodb-encryption**: Combine for comprehensive security
- **dynamodb-streams**: Enable CDC for additional data protection
- **dynamodb-table**: Base component

## Version History

- **v1.0.0**: Initial release

## Sources

- [DynamoDB Point-in-Time Recovery](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/PointInTimeRecovery.html)
- [DynamoDB Backup and Restore](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/BackupRestore.html)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
