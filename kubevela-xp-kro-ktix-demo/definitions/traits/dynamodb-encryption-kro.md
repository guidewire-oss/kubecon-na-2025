# DynamoDB Encryption Trait (KRO)

## Overview

The `dynamodb-encryption-kro` trait enables server-side encryption (SSE) for DynamoDB tables, encrypting data at rest using either AWS-managed keys (AES256) or customer-managed KMS keys.

## Applies To

- Components of type: `aws-dynamodb-kro`
- Workload type: `kro.run/DynamoDBTable`

## Security Benefits

- ✅ Data encrypted at rest
- ✅ Compliance with regulatory requirements (HIPAA, PCI-DSS, etc.)
- ✅ Protection against physical media theft
- ✅ Automatic key rotation (with KMS)
- ✅ Audit trail via CloudTrail (with KMS)
- ✅ No performance impact

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `enabled` | boolean | No | `true` | Enable server-side encryption |
| `sseType` | string | No | `AES256` | Encryption type: `AES256` or `KMS` |
| `kmsKeyId` | string | Conditional | - | KMS key ID/ARN (required if sseType is `KMS`) |

## Encryption Types

### AES256 (AWS Managed)

- **Key Management**: Fully managed by AWS
- **Cost**: Free
- **Key Rotation**: Automatic (managed by AWS)
- **Audit**: Limited visibility
- **Use Case**: Standard encryption needs

### KMS (Customer Managed)

- **Key Management**: Customer-controlled via AWS KMS
- **Cost**: KMS charges apply (~$1/month per key + usage)
- **Key Rotation**: Optional automatic rotation
- **Audit**: Full CloudTrail logging
- **Use Case**: Compliance, custom key policies, granular access control

## Examples

### Basic Encryption (AWS Managed)

Use AWS-managed encryption keys (no cost, fully automatic):

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: encrypted-table
spec:
  components:
    - name: user-table
      type: aws-dynamodb-kro
      properties:
        tableName: users-encrypted
        region: us-east-1
        attributeDefinitions:
          - attributeName: userId
            attributeType: S
        keySchema:
          - attributeName: userId
            keyType: HASH
      traits:
        - type: dynamodb-encryption-kro
          properties:
            enabled: true
            sseType: AES256
```

### KMS Encryption (Customer Managed Key)

Use your own KMS key for full control and audit capability:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: kms-encrypted-table
spec:
  components:
    - name: sensitive-data
      type: aws-dynamodb-kro
      properties:
        tableName: sensitive-data
        region: us-east-1
        attributeDefinitions:
          - attributeName: recordId
            attributeType: S
        keySchema:
          - attributeName: recordId
            keyType: HASH
      traits:
        - type: dynamodb-encryption-kro
          properties:
            enabled: true
            sseType: KMS
            kmsKeyId: arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012
```

### KMS with Alias

Reference KMS key by alias:

```yaml
traits:
  - type: dynamodb-encryption-kro
    properties:
      enabled: true
      sseType: KMS
      kmsKeyId: alias/dynamodb-encryption-key
```

### Encryption Disabled

Explicitly disable encryption (not recommended):

```yaml
traits:
  - type: dynamodb-encryption-kro
    properties:
      enabled: false
```

## KMS Key Setup

### Create KMS Key

```bash
# Create the key
aws kms create-key \
  --description "DynamoDB table encryption key" \
  --key-usage ENCRYPT_DECRYPT \
  --origin AWS_KMS

# Create an alias
aws kms create-alias \
  --alias-name alias/dynamodb-encryption-key \
  --target-key-id <key-id>

# Enable automatic rotation
aws kms enable-key-rotation --key-id <key-id>
```

### KMS Key Policy

Your KMS key policy must allow DynamoDB to use the key:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Allow DynamoDB to use the key",
      "Effect": "Allow",
      "Principal": {
        "Service": "dynamodb.amazonaws.com"
      },
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:CreateGrant"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "dynamodb.us-east-1.amazonaws.com"
        }
      }
    }
  ]
}
```

## IAM Permissions

### For ACK Controller

The ACK DynamoDB controller needs permission to use KMS keys:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kms:CreateGrant",
        "kms:DescribeKey",
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": "arn:aws:kms:*:*:key/*"
    }
  ]
}
```

### For Application Access

Applications need permission to read/write encrypted data:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey"
      ],
      "Resource": "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "dynamodb.us-east-1.amazonaws.com"
        }
      }
    }
  ]
}
```

## Comparison: AES256 vs KMS

| Feature | AES256 | KMS |
|---------|--------|-----|
| **Cost** | Free | ~$1/month + usage |
| **Key Management** | AWS managed | Customer managed |
| **Key Rotation** | Automatic | Optional automatic |
| **Access Control** | Table-level IAM | Granular via key policy |
| **Audit Logging** | DynamoDB logs only | Full CloudTrail logs |
| **Cross-Account** | Not supported | Supported via grants |
| **Compliance** | Basic | Advanced (HIPAA, PCI-DSS) |
| **Performance** | Same | Same |

## Best Practices

1. **Always enable encryption**
   - Default to AES256 for most use cases
   - Use KMS for compliance requirements

2. **Use KMS for sensitive data**
   - PHI (Protected Health Information)
   - PII (Personally Identifiable Information)
   - Financial records
   - Secrets and credentials

3. **Enable automatic key rotation**
   ```bash
   aws kms enable-key-rotation --key-id <key-id>
   ```

4. **Use separate keys per environment**
   - Development: dev-dynamodb-key
   - Staging: staging-dynamodb-key
   - Production: prod-dynamodb-key

5. **Monitor KMS usage**
   - Set up CloudWatch alarms for KMS API calls
   - Monitor KMS costs
   - Track key usage patterns

6. **Document key ARNs**
   - Store key ARNs in parameter store or secrets manager
   - Tag keys with application and environment

## Combining with Other Traits

### Encryption + Protection

```yaml
traits:
  - type: dynamodb-encryption-kro
    properties:
      enabled: true
      sseType: KMS
      kmsKeyId: alias/prod-dynamodb-key
  - type: dynamodb-protection-kro
    properties:
      deletionProtection: true
      pointInTimeRecovery: true
```

### Full Security Stack

```yaml
traits:
  - type: dynamodb-encryption-kro
    properties:
      sseType: KMS
      kmsKeyId: alias/prod-key
  - type: dynamodb-protection-kro
    properties:
      deletionProtection: true
      pointInTimeRecovery: true
  - type: dynamodb-streams-kro
    properties:
      viewType: NEW_AND_OLD_IMAGES
```

## Changing Encryption Settings

### Enabling Encryption

You can enable encryption on an existing unencrypted table by adding the trait:

```yaml
# Before: unencrypted table
# After: add trait
traits:
  - type: dynamodb-encryption-kro
    properties:
      enabled: true
```

### Changing from AES256 to KMS

Update the trait configuration:

```yaml
# Before: AES256
traits:
  - type: dynamodb-encryption-kro
    properties:
      sseType: AES256

# After: KMS
traits:
  - type: dynamodb-encryption-kro
    properties:
      sseType: KMS
      kmsKeyId: arn:aws:kms:us-east-1:123456789012:key/...
```

**Note**: DynamoDB re-encrypts data in the background. This is a non-disruptive operation.

## Compliance Considerations

### HIPAA

- ✅ Use KMS encryption
- ✅ Enable CloudTrail logging
- ✅ Implement key policies with least privilege
- ✅ Enable automatic key rotation
- ✅ Document encryption methods

### PCI-DSS

- ✅ Encrypt cardholder data at rest
- ✅ Use strong cryptography (AES256 or KMS)
- ✅ Implement key management procedures
- ✅ Restrict access to encryption keys
- ✅ Audit key usage

### GDPR

- ✅ Encrypt personal data at rest
- ✅ Implement right to erasure (key deletion)
- ✅ Document data protection measures
- ✅ Use KMS for data controller requirements

## Troubleshooting

### Encryption not enabled

Check the table configuration:
```bash
kubectl get dynamodbtable user-table -o yaml | grep -A 5 sse
```

### KMS key access denied

1. Verify IAM permissions for ACK controller
2. Check KMS key policy allows DynamoDB
3. Verify key ARN is correct
4. Check CloudTrail for specific error

### Performance issues

Encryption has no performance impact. If you experience issues:
- Check table capacity (not encryption-related)
- Monitor CloudWatch metrics
- Review application access patterns

## Cost Estimation

### AES256
- **Cost**: $0 (included with DynamoDB)

### KMS
- **Key storage**: ~$1/month per key
- **API requests**: $0.03 per 10,000 requests
- **Example**: 1M operations/day ≈ $90/month in KMS costs

**Optimization**: Use one KMS key for multiple tables in the same environment.

## References

- [DynamoDB Encryption at Rest](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/EncryptionAtRest.html)
- [AWS KMS Best Practices](https://docs.aws.amazon.com/kms/latest/developerguide/best-practices.html)
- [KMS Key Policies](https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html)

## Related Traits

- `dynamodb-protection-kro` - Deletion protection and backups
- `dynamodb-streams-kro` - Change data capture
