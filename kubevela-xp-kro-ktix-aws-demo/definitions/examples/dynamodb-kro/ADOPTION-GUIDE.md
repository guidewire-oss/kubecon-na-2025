# DynamoDB Table Adoption Guide

This guide explains how to adopt existing DynamoDB tables using the KRO + ACK integration with KubeVela.

## What is Resource Adoption?

**Resource adoption** is the process of bringing existing cloud resources (created outside Kubernetes) under Kubernetes/KRO/ACK management. This allows you to:

- Manage existing AWS resources as Kubernetes custom resources
- Use KubeVela to orchestrate already-provisioned infrastructure
- Migrate from manual AWS management to infrastructure-as-code
- Avoid disrupting existing applications while adding Kubernetes governance

## Adoption Methods

This demo supports two adoption approaches:

### Method 1: KubeVela Component (Recommended for this Demo)

Using the KubeVela `aws-dynamodb-kro` component:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: adopt-app
spec:
  components:
    - name: adopted-table
      type: aws-dynamodb-kro
      properties:
        tableName: existing-table-kro    # Name without the "tenant-atlantis-" prefix
        region: us-west-2
        billingMode: PAY_PER_REQUEST
        attributeDefinitions: [...]  # Must match existing table
        keySchema: [...]              # Must match existing table
```

**How it works:**
1. You specify the name of an existing table
2. The component creates a KRO DynamoDBTable resource
3. KRO creates/updates the corresponding ACK Table resource
4. ACK detects the table exists and adopts it
5. The table is now managed by KubeVela/KRO/ACK

### Method 2: Direct ACK Adoption (ACK-native approach)

Using ACK's annotation-based adoption directly:

```yaml
apiVersion: dynamodb.services.k8s.aws/v1alpha1
kind: Table
metadata:
  name: my-table
  annotations:
    services.k8s.aws/adoption-policy: "adopt"
    services.k8s.aws/adoption-fields: |
      {
        "name": "tenant-atlantis-existing-table"
      }
spec:
  # Specify schema matching the existing table
  attributeDefinitions: [...]
  keySchema: [...]
  billingMode: PAY_PER_REQUEST
```

**How it works:**
1. ACK controller detects the adoption annotation
2. Calls AWS DescribeTable to fetch existing table details
3. Populates the resource spec/status with fetched information
4. Marks resource as adopted with `services.k8s.aws/adopted: true`
5. Applies tags to AWS table indicating ACK management

## Key Concepts

### The "tenant-atlantis-" Prefix

All tables in this demo must start with `tenant-atlantis-` due to IAM policy constraints.

When using the KubeVela component:
- You specify the base name: `tableName: "sessions"`
- Component automatically adds prefix: `"tenant-atlantis-sessions"`
- Existing table in AWS must be: `"tenant-atlantis-sessions"`

### Adoption vs. Creation

| Scenario | Behavior |
|----------|----------|
| Table doesn't exist in AWS | KRO/ACK creates it |
| Table exists in AWS with same config | ACK adopts it (lifecycle managed) |
| Table exists but config mismatches | ACK attempts to update to match spec |
| Table exists, managed by another system | Adoption may fail with validation error |

## Step-by-Step Adoption Example

### 1. Create an Existing DynamoDB Table (outside Kubernetes)

Create a table manually via AWS CLI:

```bash
aws dynamodb create-table \
  --table-name tenant-atlantis-legacy-data \
  --attribute-definitions \
    AttributeName=id,AttributeType=S \
    AttributeName=timestamp,AttributeType=N \
  --key-schema \
    AttributeName=id,KeyType=HASH \
    AttributeName=timestamp,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --region us-west-2
```

Wait for the table to become ACTIVE:

```bash
aws dynamodb describe-table \
  --table-name tenant-atlantis-legacy-data \
  --region us-west-2 \
  --query 'Table.TableStatus'
```

### 2. Create Adoption Application in Kubernetes

Create the adoption application (see `adopt-existing.yaml`):

```bash
KUBECONFIG=./kubeconfig-internal kubectl apply -f definitions/examples/dynamodb-kro/adopt-existing.yaml
```

### 3. Verify Adoption

Check the application status:

```bash
KUBECONFIG=./kubeconfig-internal vela status dynamodb-adopt-existing-example
```

Check the KRO DynamoDBTable resource:

```bash
KUBECONFIG=./kubeconfig-internal kubectl get dynamodbtable -A
```

Check the ACK Table resource:

```bash
KUBECONFIG=./kubeconfig-internal kubectl get table.dynamodb.services.k8s.aws -A
```

Verify the table has the adoption annotation:

```bash
KUBECONFIG=./kubeconfig-internal kubectl get table.dynamodb.services.k8s.aws adopted-table -o yaml | grep -A 5 annotations
```

Check AWS console to verify table is still there:

```bash
aws dynamodb describe-table \
  --table-name tenant-atlantis-legacy-data \
  --region us-west-2 \
  --query 'Table.{Status:TableStatus, Items:ItemCount, Size:TableSizeBytes}'
```

### 4. Manage via KubeVela

After adoption, the table is fully managed by KubeVela/KRO/ACK. You can:

- **Apply traits** to add features (encryption, streams, TTL)
- **Update via Application YAML** instead of AWS Console
- **Track changes** through Kubernetes audit logs
- **Apply policies** using KubeVela policies or Kubernetes RBAC

Example: Adding encryption trait:

```yaml
spec:
  components:
    - name: adopted-table
      type: aws-dynamodb-kro
      properties:
        tableName: legacy-data-kro
        # ... other properties ...
      traits:
        - type: dynamodb-encryption-kro
          properties:
            sseType: KMS
            kmsMasterKeyID: arn:aws:kms:us-west-2:123456789012:key/...
```

### 5. Cleanup

When you delete the application, KRO/ACK will delete the table from AWS:

```bash
KUBECONFIG=./kubeconfig-internal kubectl delete app dynamodb-adopt-existing-example
```

**Important**: This will DELETE the table from AWS. If you want to keep the table but stop managing it via Kubernetes:
1. Remove the adoption annotation
2. Delete the Kubernetes resource
3. Table remains in AWS

## Adoption Scenarios

### Scenario 1: Migrate Legacy Table to KubeVela Management

**Situation**: You have a legacy DynamoDB table created manually in AWS. You want to migrate to Infrastructure-as-Code via KubeVela.

**Steps**:
1. Document existing table configuration (attributes, keys, settings)
2. Create adoption application matching that configuration
3. Apply adoption application
4. Verify adoption successful
5. Now managed by KubeVela; continue making changes in version control

### Scenario 2: Multi-Region Table Adoption

**Situation**: You have existing tables in multiple regions you want to manage together.

**Solution**:
```yaml
components:
  - name: table-us-west
    type: aws-dynamodb-kro
    properties:
      tableName: service-data-kro
      region: us-west-2
      # ... schema ...

  - name: table-us-east
    type: aws-dynamodb-kro
    properties:
      tableName: service-data-kro
      region: us-east-1
      # ... schema ...
```

Both tables are now managed together as a single application.

### Scenario 3: Blue-Green Migration

**Situation**: You want to migrate from one table to another without downtime.

**Solution**:
1. Create new table via KubeVela as normal
2. Migrate data (offline)
3. Switch application to use new table
4. Keep old table adopted for reference (read-only)
5. Delete when confirmed data migration complete

## Validation Before Adoption

### Pre-Adoption Checklist

- [ ] Table exists in AWS and is in ACTIVE state
- [ ] Table name starts with `tenant-atlantis-`
- [ ] Documented current table attributes and key schema
- [ ] Documented billing mode (PAY_PER_REQUEST or PROVISIONED)
- [ ] Verified no other systems are managing this table
- [ ] Backed up table data (optional but recommended)
- [ ] IAM credentials have DynamoDB permissions
- [ ] ACK DynamoDB controller is running and healthy

### Schema Matching

Your adoption application spec **MUST** match the existing table configuration:

```bash
# Get current table schema
aws dynamodb describe-table \
  --table-name tenant-atlantis-existing-table \
  --region us-west-2 \
  --query 'Table.{Attrs:AttributeDefinitions, Keys:KeySchema, Billing:BillingModeSummary}'
```

Compare the output to your adoption spec.

## Troubleshooting

### Issue: Table adoption fails with "ValidationException"

**Cause**: Schema mismatch between adoption spec and existing table

**Solution**:
1. Get current table schema: `aws dynamodb describe-table ...`
2. Compare to your adoption spec
3. Update adoption spec to match exactly
4. Reapply application

### Issue: ACK controller reports "AccessDeniedException"

**Cause**: IAM credentials lack DynamoDB permissions

**Solution**:
1. Verify ACK controller has appropriate IAM role/permissions
2. Check `IAM_POLICY.md` in project root for required permissions
3. Ensure credentials are mounted to ACK controller pod
4. Check controller logs: `kubectl logs -n ack-system -l app.kubernetes.io/name=dynamodb-chart`

### Issue: Adoption successful but table not appearing in `vela ls`

**Cause**: KubeVela may not have synced yet

**Solution**:
```bash
# Wait for KubeVela to detect resources (may take 30-60 seconds)
sleep 30
KUBECONFIG=./kubeconfig-internal vela ls -A

# If still not showing, check KubeVela logs
KUBECONFIG=./kubeconfig-internal kubectl logs -n vela-system -l app.kubernetes.io/name=kubevela
```

### Issue: "cannot adopt resource not owned by ACK"

**Cause**: Table was created by another ACK controller or system

**Solution**:
- This is a safety feature to prevent conflicts
- Verify the table is actually not managed by anything else
- If it's safe, you may need to remove conflicting management before adoption

## Best Practices

1. **Document Everything**: Keep track of what you're adopting and why
2. **Test in Non-Prod First**: Adopt a non-critical table first to understand the process
3. **Use Version Control**: Store adoption specs in Git alongside other infrastructure
4. **Add Labels**: Use labels to track adoption status and source
5. **Monitor Changes**: Enable CloudTrail to track AWS resource changes
6. **Backup Before Adoption**: Take DynamoDB backups before beginning adoption
7. **Gradual Migration**: Don't adopt all tables at once; do it incrementally
8. **Validate Automation**: Test adoption process multiple times before automating

## See Also

- `adopt-existing.yaml` - Example adoption application
- `basic.yaml` - Creating new tables (for comparison)
- `../components/aws-dynamodb-kro.md` - Component documentation
- [KRO Documentation](https://kro.run/) - Resource adoption concepts
- [ACK Documentation](https://aws-controllers-k8s.github.io/) - ACK adoption mechanisms
