# DynamoDB Table Examples

This directory contains working examples for the DynamoDB table component and its related traits. These examples demonstrate various configurations from basic usage to production-ready deployments.

## Quick Start

The simplest way to create a DynamoDB table:

```bash
kubectl apply -f basic.yaml
```

## Prerequisites

Before running these examples, ensure you have:

- **KubeVela installed** in your Kubernetes cluster
- **Crossplane installed** with AWS provider configured
- **AWS credentials** configured via Crossplane ProviderConfig
- **Definitions installed**:
  - `dynamodb-table` component
  - `dynamodb-provisioned-capacity` trait
  - `dynamodb-global-index` trait
  - `dynamodb-local-index` trait
  - `dynamodb-encryption` trait
  - `dynamodb-protection` trait
  - `dynamodb-streams` trait

### Installing Definitions

```bash
# Install component definition
vela def apply .development/definitions/components/dynamodb-table.cue

# Install trait definitions
vela def apply .development/definitions/traits/dynamodb-provisioned-capacity.cue
vela def apply .development/definitions/traits/dynamodb-global-index.cue
vela def apply .development/definitions/traits/dynamodb-local-index.cue
vela def apply .development/definitions/traits/dynamodb-encryption.cue
vela def apply .development/definitions/traits/dynamodb-protection.cue
vela def apply .development/definitions/traits/dynamodb-streams.cue
```

## Examples Overview

### 1. basic.yaml
**Minimal DynamoDB table configuration**

- **Use case**: Simple key-value store, session storage
- **Cost**: 💰 (lowest - on-demand billing)
- **Features**: Partition key only, on-demand billing
- **When to use**: Quick testing, development, simple applications

```bash
kubectl apply -f basic.yaml
vela status basic-dynamodb-table
```

### 2. with-sort-key.yaml
**Table with composite key (partition + sort key)**

- **Use case**: Time-series data, hierarchical data, user activity logs
- **Cost**: 💰 (on-demand billing)
- **Features**: Composite key enables range queries
- **When to use**: Need to query/sort by timestamp or secondary attribute

```bash
kubectl apply -f with-sort-key.yaml
vela status user-events
```

### 3. with-provisioned-capacity.yaml
**Table with provisioned read/write capacity**

- **Use case**: Predictable traffic, cost optimization for steady workloads
- **Cost**: 💰💰 (controlled cost with provisioned capacity)
- **Features**: 100 RCU, 50 WCU for cost-effective consistent traffic
- **When to use**: Production apps with predictable, consistent load

```bash
kubectl apply -f with-provisioned-capacity.yaml
vela status provisioned-table
```

### 4. with-global-index.yaml
**Table with Global Secondary Indexes**

- **Use case**: Multiple query patterns, query by non-key attributes
- **Cost**: 💰💰 (additional indexes increase storage and capacity costs)
- **Features**: Query by email or creation date instead of userId
- **When to use**: Need alternate access patterns without table scans

```bash
kubectl apply -f with-global-index.yaml
vela status users-with-gsi
```

### 5. with-encryption.yaml
**Table with custom KMS encryption**

- **Use case**: Compliance requirements (HIPAA, PCI-DSS, GDPR)
- **Cost**: 💰💰 (KMS key + API request costs)
- **Features**: Customer-managed encryption keys, audit trails
- **When to use**: Regulatory compliance, sensitive data protection

**Note**: Replace `alias/dynamodb-prod` with your KMS key before deploying.

```bash
# Update KMS key in the file first
kubectl apply -f with-encryption.yaml
vela status encrypted-table
```

### 6. with-protection.yaml
**Table with deletion protection and PITR**

- **Use case**: Production environments, critical data protection
- **Cost**: 💰💰 (point-in-time recovery storage costs)
- **Features**: Prevents deletion, 35-day backup retention
- **When to use**: All production tables, compliance requirements

```bash
kubectl apply -f with-protection.yaml
vela status protected-table
```

### 7. with-streams.yaml
**Table with DynamoDB Streams**

- **Use case**: Event-driven architectures, Lambda triggers, CDC
- **Cost**: 💰 (stream read costs)
- **Features**: Captures all item changes in real-time
- **When to use**: Real-time analytics, data replication, audit logs

```bash
kubectl apply -f with-streams.yaml
vela status stream-enabled-table
```

### 8. production.yaml
**Production-ready configuration with all features**

- **Use case**: Enterprise production deployments
- **Cost**: 💰💰💰 (comprehensive features, optimized for reliability)
- **Features**:
  - Provisioned capacity (500 RCU, 250 WCU)
  - 2 Global Secondary Indexes
  - Custom KMS encryption
  - Deletion protection + PITR
  - DynamoDB Streams
- **When to use**: Production financial/critical applications

**Note**: Update KMS key alias before deploying.

```bash
# Update KMS key in the file first
kubectl apply -f production.yaml
vela status production-dynamodb
```

## Testing Examples

### Apply an Example

```bash
# Apply one of the examples
kubectl apply -f with-sort-key.yaml

# Check application status
vela status user-events

# View detailed information
vela show user-events

# Check health status
kubectl get application user-events -o yaml | grep -A 10 status
```

### Verify Table Creation

```bash
# List DynamoDB Tables via Crossplane
kubectl get table.dynamodb.aws.crossplane.io

# Check table status
kubectl describe table.dynamodb.aws.crossplane.io events-table

# Verify in AWS (if you have AWS CLI configured)
aws dynamodb describe-table --table-name events-table --region us-west-2
```

### Clean Up

```bash
# Delete application (will delete DynamoDB table)
kubectl delete -f with-sort-key.yaml

# Or delete by name
vela delete user-events
```

## Customization Guide

All examples can be customized by modifying the `properties` section:

### Change Region

```yaml
properties:
  region: eu-west-1  # Change to your preferred region
```

### Add Tags

```yaml
properties:
  tags:
    - key: Team
      value: DataEngineering
    - key: CostCenter
      value: Engineering
```

### Adjust Capacity

```yaml
traits:
  - type: dynamodb-provisioned-capacity
    properties:
      readCapacityUnits: 200   # Increase for higher traffic
      writeCapacityUnits: 100
```

### Add Additional Attributes

```yaml
properties:
  attributeDefinitions:
    - attributeName: userId
      attributeType: S
    - attributeName: timestamp
      attributeType: N
    - attributeName: category  # Add new attribute
      attributeType: S
```

## Cost Estimation

### Monthly Cost Examples (us-east-1)

| Example | Storage | Capacity | Additional | Total/Month |
|---------|---------|----------|------------|-------------|
| basic.yaml | 1GB | On-demand (1M req) | - | ~$2 |
| with-provisioned-capacity.yaml | 1GB | 100 RCU, 50 WCU | - | ~$56 |
| with-global-index.yaml | 2GB | On-demand (1M req) | 2 GSIs | ~$4 |
| with-encryption.yaml | 1GB | On-demand (1M req) | KMS | ~$62 |
| with-protection.yaml | 1GB + backups | On-demand (1M req) | PITR (1GB) | ~$2.20 |
| with-streams.yaml | 1GB | On-demand (1M req) | Streams | ~$2.10 |
| production.yaml | 2GB + backups | 500 RCU, 250 WCU | All features | ~$350 |

**Note**: Actual costs vary based on request volume, data size, and usage patterns.

## Troubleshooting

### Issue: Application Stuck in "Running"

**Check status**:
```bash
vela status <app-name>
kubectl get application <app-name> -o yaml
```

**Common causes**:
- Crossplane provider not configured
- AWS credentials missing/invalid
- IAM permissions insufficient

### Issue: Table Not Created

**Check Crossplane resources**:
```bash
kubectl get table.dynamodb.aws.crossplane.io
kubectl describe table.dynamodb.aws.crossplane.io <table-name>
```

**Check events**:
```bash
kubectl get events --sort-by='.lastTimestamp'
```

### Issue: Definition Not Found

**Verify definitions are installed**:
```bash
vela def list | grep dynamodb
```

**Install missing definitions**:
```bash
vela def apply .development/definitions/components/dynamodb-table.cue
```

## Best Practices

1. **Start with basic.yaml**: Test basic functionality first
2. **Use provisioned capacity**: For predictable workloads (30%+ cheaper)
3. **Enable protection**: Always for production tables
4. **Tag everything**: Use consistent tagging for cost tracking
5. **Test locally**: Validate YAML before deploying to production
6. **Monitor costs**: Set up AWS Cost Explorer alerts

## Additional Resources

- [DynamoDB Component Documentation](../../components/dynamodb-table.md)
- [Trait Documentation](../../traits/)
- [AWS DynamoDB Pricing](https://aws.amazon.com/dynamodb/pricing/)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [Crossplane AWS Provider](https://marketplace.upbound.io/providers/crossplane-contrib/provider-aws/)

## Support

For issues or questions:
- Check the troubleshooting section above
- Review component/trait documentation
- Consult AWS DynamoDB documentation
- Check Crossplane provider logs

## Contributing

To add new examples:
1. Create a new YAML file with descriptive name
2. Add comments explaining the use case
3. Update this README with example description
4. Test the example before committing
