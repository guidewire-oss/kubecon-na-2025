# Changelog

## 2025-12-29 - KRO + ACK Integration Fixes

### Fixed: KRO ResourceGraphDefinition and ACK Integration

**Problems:**
1. KRO instances showing `state="ERROR"` with "ResourcesInProgress"
2. ACK tables failing with region and validation errors
3. KubeVela applications stuck in "runningWorkflow" with unhealthy status
4. Applications showing "all resources are created and ready" but marked unhealthy

**Root Causes:**
1. **Wrong region annotation**: Used `kro.run/region` instead of ACK standard `services.k8s.aws/region`
2. **Missing optional operator**: Status field `latestStreamARN` referenced without CEL optional operator
3. **AWS API validation errors**: Empty strings sent for optional fields (e.g., `kmsMasterKeyID: ""`)
4. **Specification conflicts**: Sending disabled feature specs (e.g., `streamSpecification: { streamEnabled: false }`) tells ACK to disable streams that don't exist
5. **Health check mismatch**: Component checked for `state == "Ready"` but KRO sets `state = "ACTIVE"` for DynamoDB

**Solutions:**
1. **Fixed region configuration** (definitions/kro/dynamodb-rgd.yaml):
   - Changed annotation from `kro.run/region` to `services.k8s.aws/region`
   - Updated all examples to use `us-west-2` region

2. **Fixed optional status fields** (definitions/kro/dynamodb-rgd.yaml):
   - Added CEL optional operator: `${table.status.?latestStreamARN}`
   - Prevents errors when field doesn't exist

3. **Fixed AWS API validation** (definitions/kro/dynamodb-rgd.yaml):
   - Completely removed optional feature specifications from RGD template
   - Only include `tableName`, `billingMode`, `attributeDefinitions`, `keySchema`
   - Let ACK use AWS defaults for unspecified features
   - Traits can still enable features via strategic patches

4. **Fixed health checks** (definitions/components/aws-dynamodb-kro.cue):
   - Updated `healthPolicy` to check: `if context.output.status.state == "ACTIVE"`
   - Updated `customStatus.readyReplicas` to check: `if context.output.status.state == "ACTIVE"`
   - Changed from checking "Ready" to "ACTIVE"

5. **Fixed IAM compatibility**:
   - Updated all example table names to use `tenant-atlantis-` prefix
   - Supports resource-level IAM permissions with table name patterns

**Files Changed:**
- `definitions/kro/dynamodb-rgd.yaml` - Fixed region annotation, optional fields, removed feature specs
- `definitions/components/aws-dynamodb-kro.cue` - Fixed health policy and customStatus
- `definitions/examples/dynamodb-kro/*.yaml` - Updated region and table names
- `definitions/traits/dynamodb-protection-kro.cue` - Compatible with new RGD approach

**Known Limitations:**
- Removed global and local secondary indexes from RGD schema (KRO doesn't support complex nested arrays)
- KRO's `Ready` condition shows "Unknown" status (implementation detail, doesn't affect functionality)
- All optional features should be enabled via traits to avoid validation conflicts

**Verification:**
```bash
# Check applications are healthy
vela ls -A
# Should show: PHASE=running, HEALTHY=healthy

# Check ACK tables
kubectl get table.dynamodb.services.k8s.aws -n default
# Should show: STATUS=ACTIVE, SYNCED=True

# Check KRO instances
kubectl get dynamodbtable.kro.run -n default
# Should show: STATE=ACTIVE
```

---

## 2025-12-29 - Critical Fix (Earlier)

### Fixed: CUE Disjunction Error with Boolean Fields and Trait Patching

**Problem:**
Applications with traits were failing with CUE evaluation error:
```
cannot convert incomplete value "|((bool){ false }, (bool){ true }, (bool){ bool })" to JSON
```

**Root Cause:**
Boolean fields had BOTH a default value pattern AND redundant conditional reassignments:
```cue
ttlEnabled: *false | bool
if parameter.ttlEnabled != _|_ {
    ttlEnabled: parameter.ttlEnabled  // Redundant - creates disjunction
}
```

When traits patched these fields, CUE created incomplete disjunctions from three sources:
1. The default value (`*false | bool`)
2. The conditional reassignment
3. The trait patch value

This resulted in an incomplete value that couldn't be marshaled to JSON.

**Solution:**
Simplified boolean field definitions to use a single disjunction that handles both parameters and defaults:
```cue
// Before (WRONG - creates disjunction):
ttlEnabled: *false | bool
if parameter.ttlEnabled != _|_ {
    ttlEnabled: parameter.ttlEnabled
}

// After (CORRECT - single unified expression):
ttlEnabled: parameter.ttlEnabled | *false
```

This pattern:
- Provides `false` as the default when parameter is undefined
- Allows parameters to override the default
- Allows traits to patch the value
- All in a single unification without disjunctions

**Fields Fixed:**
- `streamEnabled` - Line 74
- `pointInTimeRecoveryEnabled` - Line 80
- `sseEnabled` - Line 83
- `ttlEnabled` - Line 92
- `deletionProtectionEnabled` - Line 98

**Files Updated:**
- `definitions/components/aws-dynamodb-kro.cue` - Lines 74, 80, 83, 92, 98

**Impact:**
- ✅ All KRO traits now work without CUE evaluation errors
- ✅ Applications with multiple traits deploy successfully
- ✅ Both inline parameters and trait patches work correctly
- ✅ Cleaner, more idiomatic CUE code

**Tested:**
- Successfully deployed `definitions/examples/dynamodb-kro/with-traits-basic.yaml` with TTL, Streams, and Encryption traits

---

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
