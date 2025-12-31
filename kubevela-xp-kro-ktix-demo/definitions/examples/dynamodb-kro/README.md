# DynamoDB KRO Examples

This directory contains examples for using the `aws-dynamodb-kro` component with KubeVela.

## Prerequisites

Before running these examples, ensure you have:

1. **KRO installed** in your cluster
2. **ACK DynamoDB Controller** installed and configured
3. **AWS credentials** configured (IRSA, IAM role, or AWS credentials)
4. **ComponentDefinition** applied to your cluster

See the [component documentation](../../components/aws-dynamodb-kro.md) for detailed setup instructions.

## Resource Adoption

### adopt-existing.yaml

**NEW**: Demonstrates adopting an existing DynamoDB table created outside Kubernetes.

Instead of creating a new table, this example shows how to bring an existing table under KubeVela/KRO/ACK management. Perfect for:
- Migrating legacy tables to Infrastructure-as-Code
- Bringing manually-created tables under Kubernetes governance
- Managing existing AWS resources without re-creating them

**See**: [ADOPTION-GUIDE.md](./ADOPTION-GUIDE.md) for comprehensive adoption documentation, scenarios, and troubleshooting.

```bash
KUBECONFIG=./kubeconfig-internal vela up -f adopt-existing.yaml
```

## Examples

### Component-Only Examples

#### basic.yaml

The simplest DynamoDB table configuration:
- On-demand billing (PAY_PER_REQUEST)
- Single partition key
- No additional features

**Use case**: Development, testing, simple key-value storage

```bash
kubectl apply -f basic.yaml
```

#### with-gsi.yaml

Table with a Global Secondary Index:
- On-demand billing
- Partition key on main table
- GSI for querying by email

**Use case**: Applications needing multiple query patterns

```bash
kubectl apply -f with-gsi.yaml
```

#### provisioned.yaml

Table with provisioned capacity (configured in properties):
- Provisioned billing mode
- Fixed read/write capacity units
- GSI with dedicated capacity

**Use case**: Predictable workloads with consistent traffic

```bash
kubectl apply -f provisioned.yaml
```

#### production.yaml

Full-featured production configuration (all-in-one):
- On-demand billing
- Partition key + sort key
- Global secondary index
- DynamoDB Streams enabled
- Point-in-time recovery
- Server-side encryption
- TTL configuration
- Deletion protection
- Resource tags
- Connection secret output

**Use case**: Production workloads requiring full data protection

```bash
kubectl apply -f production.yaml
```

### Trait-Based Examples

Using modular traits for cleaner, more composable configurations:

#### with-traits-basic.yaml

Session table with modular trait configuration:
- TTL for auto-expiration
- Streams for tracking
- Encryption

**Use case**: User session management

```bash
kubectl apply -f with-traits-basic.yaml
```

#### with-traits-production.yaml

Full production table using traits:
- Provisioned capacity
- Full protection (deletion + PITR)
- KMS encryption
- Change data capture streams

**Use case**: Critical production data with full protection

```bash
kubectl apply -f with-traits-production.yaml
```

#### with-traits-cache.yaml

API cache table optimized for temporary data:
- TTL for auto-cleanup
- Basic encryption
- Deletion protection (but no PITR)
- Streams for invalidation tracking

**Use case**: API response caching

```bash
kubectl apply -f with-traits-cache.yaml
```

#### with-traits-staging.yaml

Cost-optimized staging environment:
- On-demand billing
- Basic protection
- AWS-managed encryption
- Streams for testing

**Use case**: Non-production testing environment

```bash
kubectl apply -f with-traits-staging.yaml
```

## Testing

After applying an example, check the application status:

```bash
# Check application
kubectl get app -n default

# Check detailed status
kubectl get app dynamodb-basic-example -o yaml

# Check KRO ResourceGroup instance
kubectl get dynamodbtable

# Check ACK DynamoDB Table
kubectl get table.dynamodb.services.k8s.aws
```

## Checking AWS Console

Verify the table was created in AWS:

1. Open AWS Console → DynamoDB
2. Select the region specified in your example (e.g., us-east-1)
3. Find your table by name
4. Check table configuration matches your specification

## Cleanup

Delete the application and wait for AWS resources to be removed:

```bash
kubectl delete app dynamodb-basic-example
```

Check that the AWS table is deleted:
```bash
aws dynamodb list-tables --region us-east-1
```

## Customization

To customize these examples:

1. **Change region**: Update the `region` field
2. **Adjust capacity**: Modify `provisionedThroughput` values
3. **Add more indexes**: Add entries to `globalSecondaryIndexes`
4. **Enable features**: Set flags like `streamEnabled`, `sseEnabled`
5. **Add tags**: Add entries to the `tags` array

## Common Modifications

### Enable Streams
```yaml
streamEnabled: true
streamViewType: NEW_AND_OLD_IMAGES
```

### Add Encryption with Customer Key
```yaml
sseEnabled: true
sseType: KMS
kmsMasterKeyID: arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012
```

### Add Local Secondary Index
```yaml
localSecondaryIndexes:
  - indexName: status-index
    keySchema:
      - attributeName: userId
        keyType: HASH
      - attributeName: status
        keyType: RANGE
    projection:
      projectionType: ALL
```

## Troubleshooting

If an example fails to deploy:

1. **Check ACK controller logs**:
   ```bash
   kubectl logs -n ack-system -l app.kubernetes.io/name=dynamodb-chart
   ```

2. **Check KRO status**:
   ```bash
   kubectl get resourcegraphdefinition dynamodbtable -o yaml
   ```

3. **Check application status**:
   ```bash
   kubectl describe app dynamodb-basic-example
   ```

4. **Verify IAM permissions**: Ensure the ACK controller has DynamoDB permissions

5. **Check AWS service quotas**: Verify you haven't hit account limits

## Next Steps

- Review the [component documentation](../components/aws-dynamodb-kro.md)
- Learn about [DynamoDB best practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- Explore [KRO documentation](https://kro.run/)
- Read about [ACK controllers](https://aws-controllers-k8s.github.io/docs/)
