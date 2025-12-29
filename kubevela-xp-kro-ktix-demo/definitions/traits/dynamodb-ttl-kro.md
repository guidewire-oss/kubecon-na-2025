# DynamoDB TTL Trait (KRO)

## Overview

The `dynamodb-ttl-kro` trait enables Time To Live (TTL) on a DynamoDB table, allowing automatic expiration and deletion of items based on a timestamp attribute. This is useful for managing ephemeral data, complying with data retention policies, and reducing storage costs.

## Applies To

- Components of type: `aws-dynamodb-kro`
- Workload type: `kro.run/DynamoDBTable`

## Use Cases

- **Session management**: Auto-expire user sessions
- **Temporary data**: Cache entries, temporary tokens
- **Data retention compliance**: Automatically delete old records
- **Cost optimization**: Reduce storage costs by removing expired data
- **Event logs**: Auto-purge old application logs
- **Trial periods**: Expire free trial access automatically

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `enabled` | boolean | No | `true` | Enable TTL |
| `attributeName` | string | No | `expiresAt` | Attribute name containing expiration timestamp |

## How It Works

1. **Add TTL attribute to items**: Store Unix timestamp (seconds since epoch)
2. **DynamoDB checks periodically**: Scans for expired items
3. **Items deleted automatically**: No read/write capacity consumed
4. **Deletion within 48 hours**: Items expire "eventually" (not immediate)
5. **Streams capture deletions**: If streams enabled, get TTL delete events

## Examples

### Basic TTL (Default Attribute)

Enable TTL using default `expiresAt` attribute:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: session-table
spec:
  components:
    - name: user-sessions
      type: aws-dynamodb-kro
      properties:
        tableName: user-sessions
        region: us-east-1
        attributeDefinitions:
          - attributeName: sessionId
            attributeType: S
        keySchema:
          - attributeName: sessionId
            keyType: HASH
      traits:
        - type: dynamodb-ttl-kro
```

### Custom TTL Attribute

Use a custom attribute name:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: cache-table
spec:
  components:
    - name: api-cache
      type: aws-dynamodb-kro
      properties:
        tableName: api-cache
        region: us-east-1
        attributeDefinitions:
          - attributeName: cacheKey
            attributeType: S
        keySchema:
          - attributeName: cacheKey
            keyType: HASH
      traits:
        - type: dynamodb-ttl-kro
          properties:
            enabled: true
            attributeName: ttl
```

### Session Management Example

Complete session management with 24-hour expiration:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: auth-sessions
spec:
  components:
    - name: sessions
      type: aws-dynamodb-kro
      properties:
        tableName: auth-sessions
        region: us-east-1
        attributeDefinitions:
          - attributeName: sessionId
            attributeType: S
        keySchema:
          - attributeName: sessionId
            keyType: HASH
      traits:
        - type: dynamodb-ttl-kro
          properties:
            attributeName: expiresAt
        - type: dynamodb-streams-kro
          properties:
            viewType: KEYS_ONLY  # Track session deletions
```

## Setting TTL Values

### Calculate Expiration Timestamp

**Python:**
```python
import time

# Expire in 24 hours
expiration = int(time.time()) + (24 * 60 * 60)

item = {
    'sessionId': 'session-123',
    'userId': 'user-456',
    'expiresAt': expiration
}
```

**JavaScript:**
```javascript
// Expire in 1 hour
const expiration = Math.floor(Date.now() / 1000) + (60 * 60);

const item = {
  sessionId: 'session-123',
  userId: 'user-456',
  expiresAt: expiration
};
```

**Java:**
```java
import java.time.Instant;

// Expire in 30 days
long expiration = Instant.now().getEpochSecond() + (30 * 24 * 60 * 60);

Map<String, AttributeValue> item = new HashMap<>();
item.put("sessionId", AttributeValue.builder().s("session-123").build());
item.put("expiresAt", AttributeValue.builder().n(String.valueOf(expiration)).build());
```

**Go:**
```go
import "time"

// Expire in 7 days
expiration := time.Now().Unix() + (7 * 24 * 60 * 60)

item := map[string]types.AttributeValue{
    "sessionId": &types.AttributeValueMemberS{Value: "session-123"},
    "expiresAt": &types.AttributeValueMemberN{Value: fmt.Sprint(expiration)},
}
```

### Common Expiration Patterns

```python
import time

current_time = int(time.time())

# 1 hour
expire_1h = current_time + (60 * 60)

# 24 hours
expire_24h = current_time + (24 * 60 * 60)

# 7 days
expire_7d = current_time + (7 * 24 * 60 * 60)

# 30 days
expire_30d = current_time + (30 * 24 * 60 * 60)

# 1 year
expire_1y = current_time + (365 * 24 * 60 * 60)
```

## Important Behaviors

### Deletion Timing

⚠️ **Not Immediate**: Items expire within 48 hours after the TTL timestamp
- Typically within minutes to hours
- Depends on table size and delete throughput
- Expired items may still appear in queries until deleted

### Handling Expired Items

**Option 1: Filter expired items in application:**
```python
import time

def get_active_session(session_id):
    response = table.get_item(Key={'sessionId': session_id})

    if 'Item' not in response:
        return None

    item = response['Item']
    current_time = int(time.time())

    # Check if expired
    if item.get('expiresAt', 0) < current_time:
        return None  # Treat as expired

    return item
```

**Option 2: Use filter expression:**
```python
import time

current_time = int(time.time())

response = table.query(
    KeyConditionExpression='userId = :uid',
    FilterExpression='expiresAt > :now OR attribute_not_exists(expiresAt)',
    ExpressionAttributeValues={
        ':uid': user_id,
        ':now': current_time
    }
)
```

### Capacity Impact

✅ **Free operations:**
- TTL deletions consume no read/write capacity
- No throttling from TTL deletions

⚠️ **Streams impact:**
- TTL deletions create stream records
- May increase stream processing costs

### Monitoring TTL Deletions

Track TTL activity with CloudWatch metrics:
- **TimeToLiveDeletedItemCount**: Items deleted by TTL
- **SystemErrors**: TTL deletion errors

## Use Case Examples

### 1. Session Store

**24-hour session timeout:**
```python
def create_session(user_id, session_id):
    expiration = int(time.time()) + (24 * 60 * 60)

    table.put_item(Item={
        'sessionId': session_id,
        'userId': user_id,
        'createdAt': int(time.time()),
        'expiresAt': expiration,
        'data': {'...': '...'}
    })
```

### 2. API Rate Limiting

**Per-minute rate limit tracking:**
```python
def record_api_call(api_key, request_id):
    # Expire after 60 seconds
    expiration = int(time.time()) + 60

    table.put_item(Item={
        'apiKey': api_key,
        'requestId': request_id,
        'timestamp': int(time.time()),
        'expiresAt': expiration
    })
```

### 3. Temporary Tokens

**Short-lived access tokens:**
```python
def create_temp_token(token, user_id, duration_minutes=15):
    expiration = int(time.time()) + (duration_minutes * 60)

    table.put_item(Item={
        'token': token,
        'userId': user_id,
        'expiresAt': expiration,
        'permissions': ['read', 'write']
    })
```

### 4. Event Logs

**90-day log retention:**
```python
def log_event(event_id, event_data):
    # Keep logs for 90 days
    expiration = int(time.time()) + (90 * 24 * 60 * 60)

    table.put_item(Item={
        'eventId': event_id,
        'timestamp': int(time.time()),
        'expiresAt': expiration,
        'data': event_data
    })
```

### 5. Trial Accounts

**14-day trial period:**
```python
def create_trial_account(account_id):
    # Trial expires in 14 days
    expiration = int(time.time()) + (14 * 24 * 60 * 60)

    table.put_item(Item={
        'accountId': account_id,
        'accountType': 'trial',
        'createdAt': int(time.time()),
        'expiresAt': expiration
    })
```

## Best Practices

1. **Always filter expired items in queries**
   - Don't rely on immediate deletion
   - Check `expiresAt` in application code

2. **Use Number type for TTL attribute**
   - Must be Number (N) type
   - Unix timestamp in seconds (not milliseconds)

3. **Handle missing TTL gracefully**
   - Items without TTL attribute are never deleted
   - Useful for mixing permanent and temporary data

4. **Document TTL behavior**
   - Inform users of 48-hour deletion window
   - Document expected retention periods

5. **Monitor TTL deletions**
   - Track `TimeToLiveDeletedItemCount` metric
   - Alert on unexpected patterns

6. **Consider streams for cleanup notifications**
   - Trigger cleanup in other systems
   - Audit deleted records

## Combining with Other Traits

### TTL + Streams (Track Deletions)

```yaml
traits:
  - type: dynamodb-ttl-kro
    properties:
      attributeName: expiresAt
  - type: dynamodb-streams-kro
    properties:
      viewType: OLD_IMAGE  # Capture deleted items
```

### Full Session Table

```yaml
traits:
  - type: dynamodb-ttl-kro
    properties:
      attributeName: expiresAt
  - type: dynamodb-encryption-kro
    properties:
      sseType: AES256
  - type: dynamodb-protection-kro
    properties:
      deletionProtection: true
      pointInTimeRecovery: false  # Ephemeral data
```

## Troubleshooting

### Items not deleting

**Causes:**
1. TTL attribute is not Number type
2. Timestamp is in milliseconds (should be seconds)
3. Attribute name doesn't match configuration
4. Table has many items (slower processing)

**Solutions:**
```python
# Correct: seconds since epoch
correct_ttl = int(time.time()) + 3600

# Wrong: milliseconds
wrong_ttl = int(time.time() * 1000) + 3600  # Don't do this!

# Wrong: string type
wrong_ttl = str(int(time.time()) + 3600)  # Don't do this!
```

### Verify TTL configuration

```bash
aws dynamodb describe-time-to-live \
  --table-name user-sessions
```

### Check TTL deletions

```bash
# CloudWatch metric
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name TimeToLiveDeletedItemCount \
  --dimensions Name=TableName,Value=user-sessions \
  --start-time 2024-12-22T00:00:00Z \
  --end-time 2024-12-23T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

## Cost Savings Example

**Scenario**: Session table with 10M sessions/day, 50 bytes/session

**Without TTL:**
- Storage: 500 GB accumulated over 100 days
- Cost: 500 GB × $0.25/GB = $125/month

**With TTL (24-hour retention):**
- Storage: 5 GB (24 hours of data)
- Cost: 5 GB × $0.25/GB = $1.25/month
- **Savings: $123.75/month (99% reduction)**

## Compliance and Data Retention

### GDPR Right to Erasure

TTL can help with data retention limits:
- Set expiration based on legal requirements
- Automatic deletion reduces manual work
- Document retention periods

### Example: 30-day personal data retention

```python
def store_personal_data(user_id, data):
    # GDPR: Delete after 30 days
    expiration = int(time.time()) + (30 * 24 * 60 * 60)

    table.put_item(Item={
        'userId': user_id,
        'data': data,
        'collectedAt': int(time.time()),
        'expiresAt': expiration
    })
```

## References

- [DynamoDB TTL](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/TTL.html)
- [TTL Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/time-to-live-ttl-before-you-start.html)
- [TTL Monitoring](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/time-to-live-ttl-cloudwatch-metrics.html)

## Related Traits

- `dynamodb-streams-kro` - Capture TTL deletions
- `dynamodb-protection-kro` - Backup before expiration
