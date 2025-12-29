# Changelog

## 2025-12-24 - Latest Fixes

### Fixed: Trait Patching Conflict with Boolean Defaults

**Problem:**
Production example with traits (`with-traits-production.yaml`) failed with:
```
spec.pointInTimeRecoveryEnabled: conflicting values true and false
```

**Root Cause:**
Component was setting boolean fields with concrete `false` values instead of default values, preventing traits from overriding them.

**Solution:**
Changed boolean field initialization from:
```cue
pointInTimeRecoveryEnabled: false  // Concrete value - can't override
```
To:
```cue
pointInTimeRecoveryEnabled: *false | bool  // Default value - can override
```

**Files Updated:**
- `definitions/components/aws-dynamodb-kro.cue` - Lines 83, 89, 101, 110

**Impact:**
- All KRO traits now work correctly with component defaults
- Production example deploys successfully
- Consistent with other optional boolean fields

See: `FIX-TRAIT-CONFLICT.md` for detailed explanation

### Fixed: KRO Controller Deployment Name in setup.sh

**Problem:**
Setup script tried to restart deployment `kro-controller-manager` which doesn't exist.

**Root Cause:**
KRO deployment is named `kro`, not `kro-controller-manager`.

**Solution:**
Updated setup.sh Phase 5.5 to use correct deployment name:
```bash
kubectl rollout restart deployment/kro -n kro-system
```

---

## 2024-12-24 - Bug Fixes

### Fixed: YAML Boolean Parsing Issue with DynamoDB Attribute Types

**Problem:**
Applications with multiple attribute definitions were failing with CUE validation errors:
```
output.spec.forProvider.attributeDefinitions.1.attributeType: 3 errors in empty disjunction
```

**Root Cause:**
YAML interprets unquoted single letters as booleans or other types:
- `N` → `false` (boolean)
- `S` → `"S"` (string, but inconsistent)
- `B` → `false` (boolean)

This caused type mismatches when CUE tried to validate against the `"S" | "N" | "B"` constraint.

**Solution:**
1. Updated all YAML example files to quote attribute type values:
   - Changed: `attributeType: S` → `attributeType: "S"`
   - Changed: `attributeType: N` → `attributeType: "N"`
   - Changed: `attributeType: B` → `attributeType: "B"`

2. Files updated:
   - `definitions/examples/dynamodb-table/*.yaml` (all files)
   - `definitions/examples/dynamodb-kro/*.yaml` (all files)

**Command used to fix all files:**
```bash
find definitions/examples -name "*.yaml" -exec sed -i.bak 's/attributeType: \([SNB]\)$/attributeType: "\1"/g' {} \;
find definitions/examples -name "*.yaml.bak" -delete
```

### Fixed: Billing Mode Conflict with Provisioned Capacity Trait

**Problem:**
Production applications using the `dynamodb-provisioned-capacity-xp` trait were failing:
```
spec.forProvider.billingMode: conflicting values "PROVISIONED" and "PAY_PER_REQUEST"
```

**Root Cause:**
The component definition was setting a hard default for `billingMode` using the pattern:
```cue
billingMode: *"PAY_PER_REQUEST" | parameter.billingMode
```

This created a conflict when traits tried to patch the field with `"PROVISIONED"`.

**Solution:**
Changed the billing mode definition in `definitions/components/aws-dynamodb-xp.cue` to allow trait overrides:
```cue
// Before:
if parameter.billingMode != _|_ {
    billingMode: parameter.billingMode
}
if parameter.billingMode == _|_ {
    billingMode: "PAY_PER_REQUEST"
}

// After:
billingMode: *"PAY_PER_REQUEST" | string
if parameter.billingMode != _|_ {
    billingMode: parameter.billingMode
}
```

This pattern:
- Provides a default value of `"PAY_PER_REQUEST"` for applications without traits
- Allows traits to override the value by patching with any string
- Still respects explicit `billingMode` parameters when provided

**Component Updated:**
- `definitions/components/aws-dynamodb-xp.cue`

**Reapply Command:**
```bash
vela def apply definitions/components/aws-dynamodb-xp.cue
```

### Fixed: API Version Mismatch in Component Definition

**Problem:**
Applications were failing with:
```
no matches for kind "Table" in version "dynamodb.aws.crossplane.io/v1alpha1"
```

**Root Cause:**
The component definition had inconsistent API versions:
- Workload definition: `dynamodb.aws.upbound.io/v1beta1`
- Template output: `dynamodb.aws.crossplane.io/v1alpha1`

**Solution:**
Updated template output to match workload definition:
```cue
// Before:
apiVersion: "dynamodb.aws.crossplane.io/v1alpha1"

// After:
apiVersion: "dynamodb.aws.upbound.io/v1beta1"
```

**Component Updated:**
- `definitions/components/aws-dynamodb-xp.cue`

**Reapply Command:**
```bash
vela def apply definitions/components/aws-dynamodb-xp.cue
# Recreate existing applications to apply the fix
kubectl delete application <app-name>
kubectl apply -f definitions/examples/dynamodb-table/<example>.yaml
```

### Fixed: Tags Format for Upbound Provider

**Problem:**
Applications with tags were failing with:
```
spec.forProvider.tags: Invalid value: "array": spec.forProvider.tags in body must be of type object: "array"
```

**Root Cause:**
The Upbound provider expects tags as an object (map of key-value pairs), not an array.

**Solution:**
Added CUE transformation in component definition to convert array format to object:
```cue
// Convert tags array [{key: "K", value: "V"}] to object {K: "V"}
if parameter.tags != _|_ {
    tags: {
        for tag in parameter.tags {
            "\(tag.key)": tag.value
        }
    }
}
```

This allows users to continue using the intuitive array format in their YAML while the component automatically converts it to the provider's expected format.

**Component Updated:**
- `definitions/components/aws-dynamodb-xp.cue`

**Reapply Command:**
```bash
vela def apply definitions/components/aws-dynamodb-xp.cue
# Recreate applications with tags
kubectl delete application <app-name>
kubectl apply -f definitions/examples/dynamodb-table/<example>.yaml
```

### Verification

All example applications now work correctly:
- ✅ `basic.yaml` - Single attribute definition
- ✅ `with-sort-key.yaml` - Multiple attribute definitions  
- ✅ `with-streams.yaml` - Multiple attributes + streams trait
- ✅ `production.yaml` - Multiple attributes + provisioned capacity trait

### Prerequisites Created

The production namespace needs to exist before applying production examples:
```bash
kubectl create namespace production
```
