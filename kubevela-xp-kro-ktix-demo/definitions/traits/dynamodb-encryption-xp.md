# DynamoDB Encryption Trait

## Overview

The `dynamodb-encryption` trait configures server-side encryption with custom KMS keys for DynamoDB tables. This trait is essential for meeting compliance requirements (HIPAA, PCI-DSS, GDPR) by providing customer-managed encryption keys and audit trails.

## Use Cases

- **Compliance requirements** (HIPAA, PCI-DSS, GDPR, SOC 2)
- **Custom key management** with key rotation policies
- **Audit trails** via AWS CloudTrail for key usage
- **Cross-account encryption** using shared KMS keys
- **Regulatory data protection** with customer-managed keys

### When NOT to Use

- Default AWS-managed encryption sufficient → DynamoDB encrypts at rest by default
- No compliance requirements → AWS-managed keys are free
- Cost-sensitive applications → Custom KMS keys add $1/month per key + API costs

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| enabled | bool | No | `true` | Enable server-side encryption |
| kmsKeyId | string | No | - | KMS key ID or ARN for encryption |
| sseType | string | No | - | Encryption type: `AES256` or `KMS` |

### Parameter Details

#### `enabled`
- **Type**: `bool`
- **Default**: `true`
- **Description**: Enable/disable server-side encryption
  - DynamoDB always encrypts at rest, this controls custom KMS usage
- **Example**: `true`

#### `kmsKeyId`
- **Type**: `string`
- **Required**: No
- **Description**: KMS key ID, ARN, alias, or alias ARN
  - If not specified, uses AWS-managed key (`aws/dynamodb`)
  - Custom key enables audit trails and key rotation control
- **Examples**:
  - Key ID: `1234abcd-12ab-34cd-56ef-1234567890ab`
  - Key ARN: `arn:aws:kms:us-east-1:123456789012:key/1234abcd-12ab-34cd-56ef-1234567890ab`
  - Alias: `alias/my-dynamodb-key`
  - Alias ARN: `arn:aws:kms:us-east-1:123456789012:alias/my-dynamodb-key`

#### `sseType`
- **Type**: `string`
- **Options**: `AES256` or `KMS`
- **Description**: Server-side encryption algorithm
  - **KMS**: AWS Key Management Service (default for custom keys)
  - **AES256**: Advanced Encryption Standard 256-bit (AWS-managed)
- **Example**: `KMS`

## Cost Implications

### 🔒 Security Investment

**KMS Costs** (per key):
- **Key storage**: $1/month per customer-managed key
- **API requests**:
  - Free tier: 20,000 requests/month
  - After free tier: $0.03 per 10,000 requests
- **Cross-region**: Additional costs for multi-region keys

**DynamoDB Encryption**:
- **No additional cost** for encryption at rest (included)
- **AWS-managed keys**: Free (default behavior)
- **Customer-managed keys**: KMS costs only

**Example Monthly Cost** (medium table):
- 10M read/write requests = 20M KMS requests
- Cost: $1 (key) + $60 (API requests) = **$61/month**

**Cost Optimization**:
- Use single KMS key for multiple tables
- Enable automatic key rotation (no extra cost)
- Monitor KMS API usage in CloudWatch

## Security Benefits

### Customer-Managed Keys (CMK)

**Benefits**:
1. **Full control**: Create, rotate, disable, delete keys
2. **Audit trails**: CloudTrail logs all key usage
3. **Key policies**: Fine-grained access control
4. **Cross-account access**: Share encrypted data securely
5. **Compliance**: Meet regulatory requirements

**AWS-Managed Keys**:
- Automatic rotation every 3 years
- No key management overhead
- Cannot be deleted or disabled
- Limited to single AWS account

## Examples

### Basic Encryption with Custom KMS Key

Enable custom KMS encryption:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: secure-user-data
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
        keySchema:
          - attributeName: userId
            keyType: HASH
      traits:
        - type: dynamodb-encryption
          properties:
            enabled: true
            kmsKeyId: alias/dynamodb-prod
            sseType: KMS
```

### HIPAA-Compliant Configuration

For healthcare data with strict compliance:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: patient-records
  namespace: healthcare
spec:
  components:
    - name: records-table
      type: dynamodb-table
      properties:
        region: us-east-1
        attributeDefinitions:
          - attributeName: patientId
            attributeType: S
        keySchema:
          - attributeName: patientId
            keyType: HASH
      traits:
        - type: dynamodb-encryption
          properties:
            enabled: true
            # Use dedicated HIPAA-compliant KMS key
            kmsKeyId: arn:aws:kms:us-east-1:123456789012:key/hipaa-cmk-1234
            sseType: KMS

        # Add protection for data integrity
        - type: dynamodb-protection
          properties:
            deletionProtection: true
            pointInTimeRecovery: true
```

### Cross-Account Encryption

Shared KMS key across accounts:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: shared-data
  namespace: default
spec:
  components:
    - name: shared-table
      type: dynamodb-table
      properties:
        region: us-west-2
        attributeDefinitions:
          - attributeName: dataId
            attributeType: S
        keySchema:
          - attributeName: dataId
            keyType: HASH
      traits:
        - type: dynamodb-encryption
          properties:
            enabled: true
            # Cross-account KMS key ARN
            kmsKeyId: arn:aws:kms:us-west-2:999999999999:key/shared-key-5678
            sseType: KMS
```

## Best Practices

1. **Use KMS aliases**: Easier to manage than raw key IDs
2. **Enable automatic rotation**: Rotate keys annually
3. **Separate keys by environment**: Dev/staging/prod keys
4. **Monitor key usage**: CloudTrail + CloudWatch alarms
5. **Key policies**: Principle of least privilege
6. **Backup keys**: Document key IDs and policies

## KMS Key Policy Example

Grant DynamoDB access to your KMS key:

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
          "kms:ViaService": "dynamodb.us-east-1.amazonaws.com",
          "kms:CallerAccount": "123456789012"
        }
      }
    }
  ]
}
```

## Compliance

### HIPAA Compliance
- ✅ Customer-managed KMS keys required
- ✅ Enable CloudTrail logging
- ✅ Automatic key rotation enabled
- ✅ Access policies documented

### PCI-DSS Compliance
- ✅ Encryption at rest with strong cryptography
- ✅ Key management procedures
- ✅ Access control and monitoring
- ✅ Regular key rotation

### GDPR Compliance
- ✅ Data encryption at rest
- ✅ Right to be forgotten (key deletion)
- ✅ Audit trail for data access
- ✅ Data residency controls (regional keys)

## Troubleshooting

### Issue: KMS Key Not Found

**Symptoms**: Table creation fails with KMS error
**Cause**: Invalid key ID or insufficient permissions
**Solution**:
- Verify key exists: `aws kms describe-key --key-id <key>`
- Check key policy allows DynamoDB access
- Ensure Crossplane IAM role has `kms:DescribeKey` permission

### Issue: Access Denied

**Symptoms**: Cannot read/write to table
**Cause**: Missing KMS permissions
**Solution**:
- Add `kms:Decrypt` permission to application IAM role
- Update KMS key policy to allow decrypt operations
- Verify key is enabled (not disabled or pending deletion)

### Issue: High KMS Costs

**Symptoms**: Unexpected KMS API charges
**Cause**: High request volume
**Solution**:
- Use data caching to reduce DynamoDB requests
- Consider AWS-managed keys for non-compliance workloads
- Share single KMS key across multiple tables

## Related Traits

- **dynamodb-protection**: Combine with encryption for comprehensive data protection
- **dynamodb-table**: Base component

## Version History

- **v1.0.0**: Initial release

## Sources

- [DynamoDB Encryption at Rest](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/EncryptionAtRest.html)
- [AWS KMS Pricing](https://aws.amazon.com/kms/pricing/)
- [DynamoDB Security Best Practices](https://dynobase.dev/dynamodb-security/)
