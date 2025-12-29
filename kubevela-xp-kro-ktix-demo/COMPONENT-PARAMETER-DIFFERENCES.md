# Component Parameter Differences: Crossplane vs KRO

## Summary

**The KubeVela component parameters are NOT the same between Crossplane and KRO implementations.**

This is intentional and reflects the different philosophies and capabilities of each infrastructure engine.

## Parameter Comparison

### Common Required Parameters ✅

Both implementations require:
- `region` - AWS region
- `tableName` - Table name (implicit in metadata for KRO)
- `attributeDefinitions` - Array of attribute definitions
- `keySchema` - Primary key schema

### Common Optional Parameters ✅

Both implementations support:
- `billingMode` - PAY_PER_REQUEST or PROVISIONED
- `tableClass` - STANDARD or STANDARD_INFREQUENT_ACCESS
- `tags` - Key-value tags
- `provisionedThroughput` - For PROVISIONED billing mode

### Differences

| Parameter | Crossplane (XP) | KRO | Reason for Difference |
|-----------|----------------|-----|----------------------|
| **attributeType** | Enum: `"S" \| "N" \| "B"` | String | XP validates at component level; KRO passes through to AWS |
| **keyType** | Enum: `"HASH" \| "RANGE"` | String | XP validates at component level; KRO passes through to AWS |
| **streamEnabled** | ❌ Not available | ✅ Boolean | KRO exposes all ACK fields; XP relies on traits |
| **streamViewType** | ❌ Not available | ✅ String | KRO exposes all ACK fields; XP relies on traits |
| **pointInTimeRecoveryEnabled** | ❌ Not available | ✅ Boolean | KRO exposes all ACK fields; XP relies on traits |
| **sseEnabled** | ❌ Not available | ✅ Boolean | KRO exposes all ACK fields; XP relies on traits |
| **sseType** | ❌ Not available | ✅ String | KRO exposes all ACK fields; XP relies on traits |
| **kmsMasterKeyID** | ❌ Not available | ✅ String | KRO exposes all ACK fields; XP relies on traits |
| **ttlEnabled** | ❌ Not available | ✅ Boolean | KRO exposes all ACK fields; XP relies on traits |
| **ttlAttributeName** | ❌ Not available | ✅ String | KRO exposes all ACK fields; XP relies on traits |
| **deletionProtectionEnabled** | ❌ Not available | ✅ Boolean | KRO exposes all ACK fields; XP relies on traits |
| **globalSecondaryIndexes** | ❌ Not available | ✅ Array | KRO supports inline; XP uses trait |
| **localSecondaryIndexes** | ❌ Not available | ✅ Array | KRO supports inline; XP uses trait |
| **providerConfigRef** | ✅ String (default: "default") | ✅ Object | Different structure for different providers |
| **writeConnectionSecretToRef** | ❌ Not available | ✅ Object | ACK-specific feature |

## Why Are They Different?

### 1. **Design Philosophy**

**Crossplane (aws-dynamodb-xp)**:
- **Trait-based composition**: Advanced features exposed via traits
- **Simplified base component**: Minimal required parameters
- **Validation at component level**: Type-safe enums for common values
- **Opinionated defaults**: Sensible defaults for most use cases

**KRO (aws-dynamodb-kro)**:
- **Feature parity with AWS**: All ACK DynamoDB fields exposed
- **Direct AWS API mapping**: 1:1 with AWS DynamoDB API
- **Flexible inline configuration**: Can configure everything in one place
- **Passthrough validation**: AWS validates the values

### 2. **Trait Strategy**

**Crossplane Approach**:
```yaml
spec:
  components:
    - name: my-table
      type: aws-dynamodb-xp
      properties:
        region: us-west-2
        attributeDefinitions: [...]
        keySchema: [...]
      traits:
        - type: dynamodb-ttl-xp
          properties:
            enabled: true
            attributeName: expireAt
        - type: dynamodb-streams-xp
          properties:
            enabled: true
            viewType: NEW_AND_OLD_IMAGES
```

**KRO Approach (Option 1 - Inline)**:
```yaml
spec:
  components:
    - name: my-table
      type: aws-dynamodb-kro
      properties:
        region: us-west-2
        attributeDefinitions: [...]
        keySchema: [...]
        ttlEnabled: true
        ttlAttributeName: expireAt
        streamEnabled: true
        streamViewType: NEW_AND_OLD_IMAGES
```

**KRO Approach (Option 2 - With Traits)**:
```yaml
spec:
  components:
    - name: my-table
      type: aws-dynamodb-kro
      properties:
        region: us-west-2
        attributeDefinitions: [...]
        keySchema: [...]
      traits:
        - type: dynamodb-ttl-kro
          properties:
            enabled: true
            attributeName: expireAt
        - type: dynamodb-streams-kro
          properties:
            enabled: true
            viewType: NEW_AND_OLD_IMAGES
```

### 3. **Type Safety vs Flexibility**

**Crossplane**:
- Enforces type safety: `attributeType: "S" | "N" | "B"`
- Catches errors at KubeVela layer
- Better developer experience with IDE autocomplete

**KRO**:
- Accepts any string: `attributeType: string`
- AWS API validates the values
- More flexible but errors caught later

## Should They Be the Same?

### Arguments FOR Standardization

1. **Portability**: Users could switch between implementations without changing YAML
2. **Consistency**: Same mental model across both approaches
3. **Easier Migration**: Move from XP to KRO (or vice versa) seamlessly

### Arguments AGAINST Standardization (Current Design)

1. **Different Capabilities**: KRO/ACK exposes more AWS-specific features
2. **Design Patterns**: XP favors traits; KRO favors inline configuration
3. **API Alignment**: KRO maintains 1:1 mapping with AWS API
4. **Provider Differences**: XP uses Upbound provider schema; KRO uses ACK CRDs
5. **User Choice**: Different users prefer different approaches

## Recommendation

**Current design is appropriate because:**

1. **Target Different Use Cases**:
   - Use **XP** for multi-cloud portability and opinionated abstractions
   - Use **KRO** for AWS-specific features and direct API control

2. **Trait Coverage**: Both support traits, so users can choose their style

3. **Simple Component Available**: `aws-dynamodb-simple-kro` provides simplified interface

4. **Clear Documentation**: Users understand the differences and make informed choices

## Making Them More Similar

If standardization is desired, here are options:

### Option 1: Crossplane Component Parity (Recommended)

Add all optional parameters to XP component (matching KRO):
```cue
parameter: {
    // ... existing required params ...

    // Add optional inline configuration
    streamEnabled?: bool
    streamViewType?: "KEYS_ONLY" | "NEW_IMAGE" | "OLD_IMAGE" | "NEW_AND_OLD_IMAGES"
    ttlEnabled?: bool
    ttlAttributeName?: string
    // ... etc
}
```

**Pros**: Both components have same interface
**Cons**: XP component becomes more complex; traits become less necessary

### Option 2: Simplify KRO Component

Remove optional parameters from KRO, force trait usage:
```cue
parameter: {
    // Only required parameters
    tableName: string
    region: string
    attributeDefinitions: [...]
    keySchema: [...]
    billingMode?: string
}
```

**Pros**: Both components similarly minimal
**Cons**: Loses KRO's advantage of inline configuration; feels un-AWS-like

### Option 3: Create Abstract Wrapper Component

Create a third component that abstracts both:
```cue
"aws-dynamodb-abstract": {
    // Unified interface that translates to either XP or KRO
    parameter: {
        engine: "crossplane" | "kro"
        // Standardized parameters
    }
}
```

**Pros**: True portability
**Cons**: Added complexity; loses provider-specific benefits

## Conclusion

**Current design is intentional and justified.** The differences reflect:
- Different design philosophies (abstraction vs. direct control)
- Different target users (multi-cloud vs. AWS-native)
- Different provider capabilities (Crossplane vs. ACK)

Users benefit from having both options and can choose based on their needs. Documentation clearly explains the differences and helps users select the right approach.

If standardization is required for a specific use case, Option 1 (add parameters to XP) is recommended as it maintains backward compatibility while providing parity.

---

**Status**: Documented
**Date**: 2025-12-24
**Decision**: Keep different parameter sets with clear documentation
