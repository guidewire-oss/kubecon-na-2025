# DynamoDB Components Summary

## Overview

This project contains **two complete DynamoDB component implementations** for KubeVela, each using a different infrastructure orchestration engine:

1. **Crossplane-based** (`aws-dynamodb-xp`)
2. **KRO + ACK-based** (`aws-dynamodb-kro`)

Both implementations provide the same DynamoDB features but use different underlying technologies.

## Component Comparison

| Aspect | Crossplane (`-xp`) | KRO + ACK (`-kro`) |
|--------|-------------------|-------------------|
| **Component Name** | `aws-dynamodb-xp` | `aws-dynamodb-kro` |
| **Infrastructure** | Crossplane AWS Provider | KRO + ACK DynamoDB Controller |
| **API** | `dynamodb.aws.crossplane.io/v1alpha1` | `kro.run/v1alpha1` (RGD) → ACK |
| **Maturity** | Mature, production-ready | Experimental (KRO is new) |
| **Multi-cloud** | Yes (Crossplane abstracts clouds) | No (AWS-specific via ACK) |
| **API Mapping** | Abstracted through Crossplane | 1:1 with AWS DynamoDB API |
| **Update Speed** | Depends on Crossplane releases | Fast (ACK tracks AWS closely) |
| **Orchestration** | Crossplane Compositions | KRO ResourceGraphDefinitions |
| **Setup Complexity** | Requires Crossplane + AWS Provider | Requires KRO + ACK Controller |

## File Structure

```
.development/definitions/
├── components/
│   ├── aws-dynamodb-xp.cue       # Crossplane component (4.3KB)
│   ├── aws-dynamodb-xp.md        # Crossplane docs
│   ├── aws-dynamodb-kro.cue      # KRO component (11KB)
│   └── aws-dynamodb-kro.md       # KRO docs (16KB)
│
├── traits/
│   # Crossplane traits (6 traits)
│   ├── dynamodb-streams-xp.cue
│   ├── dynamodb-streams-xp.md
│   ├── dynamodb-encryption-xp.cue
│   ├── dynamodb-encryption-xp.md
│   ├── dynamodb-global-index-xp.cue
│   ├── dynamodb-global-index-xp.md
│   ├── dynamodb-local-index-xp.cue
│   ├── dynamodb-local-index-xp.md
│   ├── dynamodb-protection-xp.cue
│   ├── dynamodb-protection-xp.md
│   ├── dynamodb-provisioned-capacity-xp.cue
│   └── dynamodb-provisioned-capacity-xp.md
│
│   # KRO traits (5 traits)
│   ├── dynamodb-streams-kro.cue
│   ├── dynamodb-streams-kro.md
│   ├── dynamodb-encryption-kro.cue
│   ├── dynamodb-encryption-kro.md
│   ├── dynamodb-provisioned-capacity-kro.cue
│   ├── dynamodb-provisioned-capacity-kro.md
│   ├── dynamodb-protection-kro.cue
│   ├── dynamodb-protection-kro.md
│   ├── dynamodb-ttl-kro.cue
│   ├── dynamodb-ttl-kro.md
│   └── DYNAMODB-KRO-TRAITS-README.md
│
└── examples/
    └── dynamodb-kro/
        ├── basic.yaml
        ├── with-gsi.yaml
        ├── provisioned.yaml
        ├── production.yaml
        ├── with-traits-basic.yaml
        ├── with-traits-production.yaml
        ├── with-traits-cache.yaml
        ├── with-traits-staging.yaml
        └── README.md
```

## Component Details

### Crossplane Component: `aws-dynamodb-xp`

**Type**: `aws-dynamodb-xp`

**Engine**: Crossplane AWS Provider

**Traits Available:**
- `dynamodb-streams-xp` - Change data capture
- `dynamodb-encryption-xp` - Server-side encryption
- `dynamodb-global-index-xp` - Add global secondary indexes
- `dynamodb-local-index-xp` - Add local secondary indexes
- `dynamodb-protection-xp` - Deletion protection + backups
- `dynamodb-provisioned-capacity-xp` - Fixed capacity billing

**Labels:**
```yaml
catalog.kubevela.io/category: cloud-resource
catalog.kubevela.io/provider: aws
catalog.kubevela.io/engine: crossplane
```

**Example:**
```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: my-table-xp
spec:
  components:
    - name: user-table
      type: aws-dynamodb-xp
      properties:
        tableName: users
        # ... DynamoDB configuration
      traits:
        - type: dynamodb-streams-xp
        - type: dynamodb-encryption-xp
        - type: dynamodb-protection-xp
```

### KRO Component: `aws-dynamodb-kro`

**Type**: `aws-dynamodb-kro`

**Engine**: KRO (Kube Resource Orchestrator) + ACK (AWS Controllers for Kubernetes)

**Traits Available:**
- `dynamodb-streams-kro` - Change data capture
- `dynamodb-encryption-kro` - Server-side encryption
- `dynamodb-provisioned-capacity-kro` - Fixed capacity billing
- `dynamodb-protection-kro` - Deletion protection + backups
- `dynamodb-ttl-kro` - Time To Live for auto-expiration

**Labels:**
```yaml
catalog.kubevela.io/category: cloud-resource
catalog.kubevela.io/provider: aws
catalog.kubevela.io/engine: kro
```

**Example:**
```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: my-table-kro
spec:
  components:
    - name: user-table
      type: aws-dynamodb-kro
      properties:
        tableName: users
        region: us-east-1
        # ... DynamoDB configuration
      traits:
        - type: dynamodb-streams-kro
        - type: dynamodb-encryption-kro
        - type: dynamodb-protection-kro
        - type: dynamodb-ttl-kro
```

## When to Use Each

### Use Crossplane (`aws-dynamodb-xp`) When:

✅ **Multi-cloud strategy** - Need abstraction across AWS, Azure, GCP
✅ **Existing Crossplane infrastructure** - Already using Crossplane
✅ **Mature ecosystem** - Want production-proven technology
✅ **Composition features** - Need Crossplane's advanced composition
✅ **Unified control plane** - Managing all cloud resources via Crossplane
✅ **GitOps with Crossplane** - Existing Crossplane-based GitOps pipelines

### Use KRO (`aws-dynamodb-kro`) When:

✅ **AWS-specific** - Only deploying to AWS
✅ **Direct API mapping** - Want 1:1 with AWS DynamoDB API
✅ **Latest features** - Need newest AWS DynamoDB features quickly
✅ **Simpler architecture** - Prefer lighter-weight solution
✅ **Kubernetes-native** - Want pure Kubernetes CRDs
✅ **Experimentation** - Willing to use newer technology (KRO is experimental)

## Trait Comparison

| Trait | Crossplane | KRO | Notes |
|-------|-----------|-----|-------|
| **Streams** | ✅ `dynamodb-streams-xp` | ✅ `dynamodb-streams-kro` | Same functionality |
| **Encryption** | ✅ `dynamodb-encryption-xp` | ✅ `dynamodb-encryption-kro` | Same functionality |
| **Provisioned Capacity** | ✅ `dynamodb-provisioned-capacity-xp` | ✅ `dynamodb-provisioned-capacity-kro` | Same functionality |
| **Protection** | ✅ `dynamodb-protection-xp` | ✅ `dynamodb-protection-kro` | Same functionality |
| **Global Indexes** | ✅ `dynamodb-global-index-xp` | ❌ N/A | Configure in component properties |
| **Local Indexes** | ✅ `dynamodb-local-index-xp` | ❌ N/A | Configure in component properties |
| **TTL** | ❌ N/A | ✅ `dynamodb-ttl-kro` | KRO-only feature |

## Feature Parity

Both implementations support:
- ✅ All billing modes (on-demand, provisioned)
- ✅ Partition and sort keys
- ✅ Global and local secondary indexes
- ✅ DynamoDB Streams
- ✅ Server-side encryption (AES256, KMS)
- ✅ Point-in-time recovery
- ✅ Deletion protection
- ✅ TTL configuration
- ✅ Tags
- ✅ Connection secrets

## Prerequisites

### For Crossplane (`-xp`)

1. **Crossplane installed**:
   ```bash
   kubectl create namespace crossplane-system
   helm repo add crossplane-stable https://charts.crossplane.io/stable
   helm install crossplane crossplane-stable/crossplane \
     --namespace crossplane-system
   ```

2. **Crossplane AWS Provider**:
   ```bash
   kubectl apply -f - <<EOF
   apiVersion: pkg.crossplane.io/v1
   kind: Provider
   metadata:
     name: provider-aws
   spec:
     package: xpkg.upbound.io/upbound/provider-aws:v0.40.0
   EOF
   ```

3. **AWS ProviderConfig** with credentials

### For KRO (`-kro`)

1. **KRO installed**:
   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/kro/releases/latest/download/kro.yaml
   ```

2. **ACK DynamoDB Controller**:
   ```bash
   helm repo add aws-controllers-k8s https://aws-controllers-k8s.github.io/charts
   helm install dynamodb-chart aws-controllers-k8s/dynamodb-chart \
     --namespace ack-system --create-namespace
   ```

3. **AWS credentials** (IRSA, IAM role, or credentials)

## Migration Between Engines

### From Crossplane to KRO

```yaml
# Before (Crossplane)
spec:
  components:
    - name: user-table
      type: aws-dynamodb-xp
      properties:
        tableName: users
      traits:
        - type: dynamodb-streams-xp
        - type: dynamodb-encryption-xp

# After (KRO)
spec:
  components:
    - name: user-table
      type: aws-dynamodb-kro      # Change component type
      properties:
        tableName: users
        region: us-east-1           # Add region (required for KRO)
      traits:
        - type: dynamodb-streams-kro     # Change trait suffix
        - type: dynamodb-encryption-kro  # Change trait suffix
```

### From KRO to Crossplane

```yaml
# Before (KRO)
spec:
  components:
    - name: user-table
      type: aws-dynamodb-kro
      properties:
        tableName: users
        region: us-east-1
      traits:
        - type: dynamodb-ttl-kro          # KRO-specific
        - type: dynamodb-streams-kro

# After (Crossplane)
spec:
  components:
    - name: user-table
      type: aws-dynamodb-xp      # Change component type
      properties:
        tableName: users
        # Remove region (handled by ProviderConfig)
        ttlEnabled: true         # Move TTL to properties
        ttlAttributeName: expiresAt
      traits:
        - type: dynamodb-streams-xp      # Change trait suffix
```

## Naming Convention

The suffix convention helps identify the infrastructure engine:

- **`-xp`** = Crossplane-based implementation
- **`-kro`** = KRO + ACK-based implementation

This makes it explicit which engine you're using and prevents confusion when both are installed in the same cluster.

## Best Practices

1. **Choose one engine per environment** - Don't mix Crossplane and KRO for DynamoDB in the same cluster
2. **Use consistent naming** - Follow the `-xp` or `-kro` convention
3. **Document your choice** - Make it clear which engine your team uses
4. **Test both if unsure** - Try both in dev/test before committing to production
5. **Consider team expertise** - Use what your team knows best

## Future Enhancements

### Potential Crossplane Additions
- TTL trait (currently property-only)
- Auto-scaling trait
- Global tables trait

### Potential KRO Additions
- Index traits (currently property-only)
- Backup management trait
- Continuous backup trait

## Documentation

- **Crossplane Component**: `components/aws-dynamodb-xp.md`
- **KRO Component**: `components/aws-dynamodb-kro.md`
- **KRO Traits Guide**: `traits/DYNAMODB-KRO-TRAITS-README.md`
- **Examples**: `examples/dynamodb-kro/README.md`

## References

### Crossplane
- [Crossplane Documentation](https://docs.crossplane.io/)
- [Crossplane AWS Provider](https://marketplace.upbound.io/providers/upbound/provider-aws/)

### KRO + ACK
- [KRO Documentation](https://kro.run/)
- [ACK DynamoDB Controller](https://aws-controllers-k8s.github.io/community/reference/dynamodb/)
- [AWS Controllers for Kubernetes](https://aws-controllers-k8s.github.io/docs/)

---

**Created**: 2025-12-23
**Status**: Complete
**Implementations**: 2 (Crossplane + KRO)
**Total Traits**: 11 (6 Crossplane + 5 KRO)
**Total Files**: 35+
