# DynamoDB KRO Traits

Modular traits for configuring AWS DynamoDB tables with the `aws-dynamodb-kro` component.

## Available Traits

| Trait | Purpose | Cost Impact |
|-------|---------|-------------|
| `dynamodb-streams-kro` | Change data capture | Low (streams) |
| `dynamodb-encryption-kro` | Server-side encryption | Free (AES256) / ~$1/mo + usage (KMS) |
| `dynamodb-provisioned-capacity-kro` | Fixed capacity billing | Variable (cheaper at scale) |
| `dynamodb-protection-kro` | Deletion protection + backups | ~$0.20/GB/mo (PITR) |
| `dynamodb-ttl-kro` | Auto-expire items | Free (saves storage costs) |

## Quick Reference

### Stream Configuration

```yaml
traits:
  - type: dynamodb-streams-kro
    properties:
      enabled: true
      viewType: NEW_AND_OLD_IMAGES  # KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES
```

**Use for**: Lambda triggers, CDC, event-driven architectures

### Encryption

```yaml
traits:
  - type: dynamodb-encryption-kro
    properties:
      enabled: true
      sseType: AES256  # or KMS
      # kmsKeyId: arn:aws:kms:...  # Required for KMS
```

**Use for**: Data at rest encryption, compliance (HIPAA, PCI-DSS)

### Provisioned Capacity

```yaml
traits:
  - type: dynamodb-provisioned-capacity-kro
    properties:
      readCapacityUnits: 10
      writeCapacityUnits: 5
```

**Use for**: Predictable workloads, cost optimization at scale

### Protection

```yaml
traits:
  - type: dynamodb-protection-kro
    properties:
      deletionProtection: true
      pointInTimeRecovery: true
```

**Use for**: Production tables, data protection, disaster recovery

### Time To Live

```yaml
traits:
  - type: dynamodb-ttl-kro
    properties:
      enabled: true
      attributeName: expiresAt
```

**Use for**: Sessions, cache, temporary data, compliance retention

## Common Patterns

### 1. Production Table (Full Protection)

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
  - type: dynamodb-provisioned-capacity-kro
    properties:
      readCapacityUnits: 100
      writeCapacityUnits: 50
```

**When**: Critical production data requiring full protection and audit trail

### 2. Session Store

```yaml
traits:
  - type: dynamodb-ttl-kro
    properties:
      attributeName: expiresAt
  - type: dynamodb-streams-kro
    properties:
      viewType: KEYS_ONLY
  - type: dynamodb-encryption-kro
    properties:
      sseType: AES256
```

**When**: User sessions with automatic expiration

### 3. API Cache

```yaml
traits:
  - type: dynamodb-ttl-kro
    properties:
      attributeName: ttl
  - type: dynamodb-encryption-kro
    properties:
      sseType: AES256
  - type: dynamodb-protection-kro
    properties:
      deletionProtection: true
      pointInTimeRecovery: false  # No backup for cache
```

**When**: API response caching with auto-expiration

### 4. High-Volume Analytics

```yaml
traits:
  - type: dynamodb-provisioned-capacity-kro
    properties:
      readCapacityUnits: 1000
      writeCapacityUnits: 2000
  - type: dynamodb-streams-kro
    properties:
      viewType: NEW_IMAGE
  - type: dynamodb-encryption-kro
    properties:
      sseType: AES256
```

**When**: High-throughput event ingestion with stream processing

### 5. Staging Environment (Cost-Optimized)

```yaml
traits:
  - type: dynamodb-protection-kro
    properties:
      deletionProtection: true
      pointInTimeRecovery: false  # Save cost
  - type: dynamodb-encryption-kro
    properties:
      sseType: AES256  # Free encryption
  # Note: Using on-demand billing (no provisioned trait)
```

**When**: Non-production environment requiring basic protection

### 6. Compliance-Ready (HIPAA/PCI-DSS)

```yaml
traits:
  - type: dynamodb-encryption-kro
    properties:
      sseType: KMS
      kmsKeyId: alias/compliance-key
  - type: dynamodb-protection-kro
    properties:
      deletionProtection: true
      pointInTimeRecovery: true
  - type: dynamodb-streams-kro
    properties:
      viewType: NEW_AND_OLD_IMAGES  # Full audit trail
```

**When**: Sensitive data requiring regulatory compliance

## Trait Compatibility Matrix

| Trait | Compatible With | Notes |
|-------|----------------|-------|
| `streams` | All | Always compatible |
| `encryption` | All | Always compatible |
| `provisioned-capacity` | All | Mutually exclusive with on-demand billing |
| `protection` | All | Always compatible |
| `ttl` | All | Always compatible |

## Decision Tree

```
Need automatic expiration?
├─ Yes → Use dynamodb-ttl-kro
└─ No

Need change tracking?
├─ Yes → Use dynamodb-streams-kro
└─ No

Production data?
├─ Yes
│   ├─ Sensitive/Compliance →
│   │   ├─ dynamodb-encryption-kro (KMS)
│   │   ├─ dynamodb-protection-kro (full)
│   │   └─ dynamodb-streams-kro (audit)
│   └─ Standard →
│       ├─ dynamodb-encryption-kro (AES256)
│       └─ dynamodb-protection-kro (deletion only)
└─ No (Dev/Staging) → dynamodb-encryption-kro (AES256)

Predictable traffic?
├─ Yes → dynamodb-provisioned-capacity-kro
└─ No → Use on-demand (no trait)
```

## Cost Optimization Guide

### Development Tables
```yaml
traits:
  - type: dynamodb-encryption-kro
    properties:
      sseType: AES256  # Free
  # No other traits (minimal cost)
```
**Monthly cost**: Storage only (~$0.25/GB)

### Staging Tables
```yaml
traits:
  - type: dynamodb-encryption-kro
    properties:
      sseType: AES256  # Free
  - type: dynamodb-protection-kro
    properties:
      deletionProtection: true
      pointInTimeRecovery: false  # Skip PITR
```
**Monthly cost**: Storage + deletion protection (free)

### Production Tables
```yaml
traits:
  - type: dynamodb-encryption-kro
    properties:
      sseType: KMS
      kmsKeyId: alias/prod-key  # ~$1/mo + usage
  - type: dynamodb-protection-kro
    properties:
      deletionProtection: true
      pointInTimeRecovery: true  # ~$0.20/GB/mo
  - type: dynamodb-streams-kro  # Minimal cost
```
**Monthly cost**: Storage + KMS (~$1) + PITR (~$0.20/GB) + streams (usage)

## Best Practices

### 1. Always Start with Encryption

```yaml
traits:
  - type: dynamodb-encryption-kro
    properties:
      sseType: AES256  # Free, no reason not to use
```

### 2. Enable Protection for Non-Ephemeral Data

```yaml
traits:
  - type: dynamodb-protection-kro
    properties:
      deletionProtection: true  # Free
      pointInTimeRecovery: true  # Paid but essential
```

### 3. Use TTL for Temporary Data

```yaml
traits:
  - type: dynamodb-ttl-kro
    properties:
      attributeName: expiresAt
```

**Benefit**: Automatic cleanup, reduced storage costs

### 4. Enable Streams for Event-Driven Architectures

```yaml
traits:
  - type: dynamodb-streams-kro
    properties:
      viewType: NEW_AND_OLD_IMAGES
```

**Benefit**: Enables Lambda triggers, CDC, analytics pipelines

### 5. Use Provisioned Capacity for High Volume

```yaml
traits:
  - type: dynamodb-provisioned-capacity-kro
    properties:
      readCapacityUnits: 1000
      writeCapacityUnits: 500
```

**Benefit**: Up to 60% cost savings vs on-demand at high volume

## Troubleshooting

### Trait Not Applied

**Check trait exists:**
```bash
vela trait ls | grep dynamodb-kro
```

**Apply trait definition:**
```bash
vela def apply .development/definitions/traits/dynamodb-streams-kro.cue
```

### Configuration Conflict

**Example**: Provisioned capacity + on-demand billing
```yaml
# Wrong - conflict
properties:
  billingMode: PAY_PER_REQUEST
traits:
  - type: dynamodb-provisioned-capacity-kro  # Overrides to PROVISIONED
```

**Solution**: Remove conflicting property or trait

### Trait Not Taking Effect

**Check application status:**
```bash
kubectl get app <app-name> -o yaml
vela status <app-name>
```

**Check trait patch:**
```bash
kubectl describe dynamodbtable <table-name>
```

## Migration Guide

### From All-in-One to Traits

**Before (all properties):**
```yaml
spec:
  components:
    - name: user-table
      type: aws-dynamodb-kro
      properties:
        tableName: users
        streamEnabled: true
        streamViewType: NEW_AND_OLD_IMAGES
        sseEnabled: true
        sseType: AES256
        deletionProtectionEnabled: true
        pointInTimeRecoveryEnabled: true
```

**After (with traits):**
```yaml
spec:
  components:
    - name: user-table
      type: aws-dynamodb-kro
      properties:
        tableName: users
        # Only core schema properties
      traits:
        - type: dynamodb-streams-kro
          properties:
            viewType: NEW_AND_OLD_IMAGES
        - type: dynamodb-encryption-kro
          properties:
            sseType: AES256
        - type: dynamodb-protection-kro
          properties:
            deletionProtection: true
            pointInTimeRecovery: true
```

**Benefits**:
- More modular and composable
- Easier to understand and maintain
- Reusable trait configurations

## Examples

See the `examples/dynamodb-kro/` directory for complete examples:

- `with-traits-basic.yaml` - Simple table with basic traits
- `with-traits-production.yaml` - Full production configuration
- `with-traits-cache.yaml` - Cache table with TTL
- `with-traits-staging.yaml` - Cost-optimized staging setup

## Documentation

Each trait has comprehensive documentation:

- `dynamodb-streams-kro.md` - Stream configuration
- `dynamodb-encryption-kro.md` - Encryption setup
- `dynamodb-provisioned-capacity-kro.md` - Capacity planning
- `dynamodb-protection-kro.md` - Data protection
- `dynamodb-ttl-kro.md` - TTL configuration

## References

- [KubeVela Traits](https://kubevela.io/docs/end-user/traits/references)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [AWS DynamoDB Pricing](https://aws.amazon.com/dynamodb/pricing/)

---

**Created**: 2025-12-23
**Component**: aws-dynamodb-kro
**Engine**: KRO + ACK
**Version**: 1.0.0
