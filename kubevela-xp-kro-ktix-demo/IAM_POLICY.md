# Minimal IAM Policy for Demo Setup

This document describes the minimal AWS IAM permissions required to run the `setup.sh` script successfully.

## Required IAM Policy

The IAM user must have the following permissions for DynamoDB tables with the `tenant-atlantis-*` prefix:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DynamoDBTableManagement",
      "Effect": "Allow",
      "Action": [
        "dynamodb:CreateTable",
        "dynamodb:DescribeTable",
        "dynamodb:DeleteTable",
        "dynamodb:UpdateTable",
        "dynamodb:TagResource",
        "dynamodb:UntagResource",
        "dynamodb:ListTagsOfResource"
      ],
      "Resource": [
        "arn:aws:dynamodb:us-west-2:*:table/tenant-atlantis-*"
      ]
    },
    {
      "Sid": "DynamoDBTableListing",
      "Effect": "Allow",
      "Action": [
        "dynamodb:ListTables"
      ],
      "Resource": "*"
    },
    {
      "Sid": "DynamoDBStreams",
      "Effect": "Allow",
      "Action": [
        "dynamodb:DescribeStream",
        "dynamodb:GetRecords",
        "dynamodb:GetShardIterator",
        "dynamodb:ListStreams"
      ],
      "Resource": [
        "arn:aws:dynamodb:us-west-2:*:table/tenant-atlantis-*/stream/*"
      ]
    },
    {
      "Sid": "DynamoDBContributorInsights",
      "Effect": "Allow",
      "Action": [
        "dynamodb:DescribeContributorInsights",
        "dynamodb:UpdateContributorInsights"
      ],
      "Resource": [
        "arn:aws:dynamodb:us-west-2:*:table/tenant-atlantis-*"
      ]
    },
    {
      "Sid": "DynamoDBContinuousBackups",
      "Effect": "Allow",
      "Action": [
        "dynamodb:DescribeContinuousBackups",
        "dynamodb:UpdateContinuousBackups"
      ],
      "Resource": [
        "arn:aws:dynamodb:us-west-2:*:table/tenant-atlantis-*"
      ]
    },
    {
      "Sid": "DynamoDBTimeToLive",
      "Effect": "Allow",
      "Action": [
        "dynamodb:DescribeTimeToLive",
        "dynamodb:UpdateTimeToLive"
      ],
      "Resource": [
        "arn:aws:dynamodb:us-west-2:*:table/tenant-atlantis-*"
      ]
    }
  ]
}
```

## Policy Explanation

### Table Name Prefix Restriction

All permissions are scoped to tables with the `tenant-atlantis-*` prefix. This:
- Provides resource-level access control
- Prevents accidental modification of other tables
- Follows least-privilege security principles

### Required Actions

1. **Table Management**: Create, describe, update, and delete tables
2. **Tagging**: Manage resource tags for organization and billing
3. **Streams**: Enable and manage DynamoDB Streams for change data capture
4. **Contributor Insights**: Monitor read/write patterns
5. **Continuous Backups**: Configure point-in-time recovery (PITR)
6. **Time to Live**: Enable automatic item expiration

### Regional Scope

The policy is scoped to `us-west-2` region. Update the region in:
- All `Resource` ARNs
- The `../. env.aws` file
- Application YAML files in `definitions/examples/`

## Applying the Policy

### Via AWS Console

1. Go to IAM → Users → Select your user
2. Click "Add permissions" → "Create inline policy"
3. Switch to JSON editor
4. Paste the policy above
5. Review and create the policy

### Via AWS CLI

```bash
# Save the policy to a file
cat > dynamodb-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    // ... paste policy from above ...
  ]
}
EOF

# Attach the policy to your user
aws iam put-user-policy \
  --user-name tenant-atlantis-teamcity \
  --policy-name DynamoDBDemoAccess \
  --policy-document file://dynamodb-policy.json
```

## Verification

Test the permissions:

```bash
# Set credentials
export AWS_ACCESS_KEY_ID=your-access-key
export AWS_SECRET_ACCESS_KEY=your-secret-key
export AWS_DEFAULT_REGION=us-west-2

# Test table creation
aws dynamodb create-table \
  --table-name tenant-atlantis-test-table \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# Test table describe
aws dynamodb describe-table --table-name tenant-atlantis-test-table

# Clean up
aws dynamodb delete-table --table-name tenant-atlantis-test-table
```

## Troubleshooting

### AccessDeniedException

If you see `AccessDeniedException`:
- Verify table names start with `tenant-atlantis-`
- Check the region matches `us-west-2`
- Confirm the action is listed in the policy
- Wait 1-2 minutes for policy changes to propagate

### Permission Denied for Specific Actions

If specific operations fail, check the action in AWS CloudTrail:
```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=CreateTable \
  --max-results 10
```

The error message will show which specific permission is missing.

## Additional Resources

- [AWS DynamoDB IAM Permissions](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/using-identity-based-policies.html)
- [IAM Policy Simulator](https://policysim.aws.amazon.com/)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
