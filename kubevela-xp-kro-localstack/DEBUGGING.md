# Debugging Guide - LocalStack KRO Demo

This guide helps troubleshoot issues with the LocalStack demo, especially when DynamoDB tables aren't being created.

**Note:** This demo uses KRO only (Crossplane examples have been removed for simplicity). All references below are to KRO ResourceGraphDefinitions and ACK controllers.

## Problem: Tables Not Created in LocalStack

If you run `./setup.sh` successfully but `./check-dynamodb-tables.sh` shows no tables, use this debugging workflow.

## Step 1: Run Full Diagnostics

```bash
./debug-resources.sh
```

This script will:
- Show all infrastructure pods (LocalStack, KubeVela, Crossplane, KRO, ACK)
- List all Kubernetes resources related to DynamoDB
- Display controller logs for errors
- Show application status
- Test LocalStack connectivity

**What to look for:**
- Are SimpleDynamoDB resources created? (under section 3)
- Are ACK Table resources created? (under section 3)
- Are Crossplane Table resources created? (under section 3)
- Are there error messages in controller logs? (section 7)

## Step 2: Test Manual Table Creation

```bash
./test-manual-table-creation.sh
```

This script will:
1. Create a SimpleDynamoDB resource manually
2. Wait and check if KRO converts it to an ACK Table
3. Check ACK controller logs for errors
4. Verify table appears in LocalStack
5. Create a Crossplane Table resource manually
6. Check Crossplane controller logs for errors
7. Verify table appears in LocalStack

**This isolates the issue to:**
- SimpleDynamoDB not created by VeLa → VeLa component issue
- SimpleDynamoDB created but no ACK Table → KRO RGD not working
- ACK Table created but no LocalStack table → ACK controller issue
- Crossplane Table created but no LocalStack table → Crossplane provider issue

## Diagnostic Decision Tree

```
Tables not in LocalStack?
│
├─→ Run: debug-resources.sh
│   │
│   └─→ Check Section 3: SimpleDynamoDB Resources
│       │
│       ├─ NONE EXIST
│       │  └─→ VeLa not creating components
│       │     └─→ Run: vela status session-api-app-kro
│       │     └─→ Check: kubectl describe application session-api-app-kro
│       │
│       └─ EXIST
│          └─→ Check Section 3: ACK Table Resources
│             │
│             ├─ NONE EXIST
│             │  └─→ KRO not watching SimpleDynamoDB
│             │     └─→ Check: kubectl get resourcegraphdefinitions
│             │     └─→ Check KRO logs for "simpledynamodb"
│             │
│             └─ EXIST
│                └─→ Check ACK Controller Logs (Section 7)
│                   ├─ Errors about LocalStack endpoint
│                   │  └─→ Fix: verify endpoint in setup.sh
│                   ├─ Errors about credentials
│                   │  └─→ Fix: verify ACK secrets
│                   └─ No errors but table not in LocalStack
│                      └─→ Check ACK deployment: kubectl logs -n ack-system -l app=ack-dynamodb-controller
│
└─→ For manual testing, see "Test KRO Table Creation" section
```

## Common Issues and Fixes

### Issue 1: SimpleDynamoDB Resources Don't Exist

**Symptom:**
- `debug-resources.sh` section 3 shows no SimpleDynamoDB resources
- `check-dynamodb-tables.sh` shows applications deployed but no tables

**Causes:**
1. VeLa components not deployed correctly
2. VeLa application not creating component instances

**Debugging:**

```bash
# Check if component definitions exist
kubectl get componentdefinitions -n vela-system | grep dynamodb

# Check application status
vela ls -A
vela status session-api-app-kro
vela status session-api-app-xp

# Check application spec
kubectl get application session-api-app-kro -o yaml | grep -A 30 "spec:"
```

**Fix:**
```bash
# Re-deploy component definitions
vela def apply definitions/components/aws-dynamodb-simple-kro.cue
vela def apply definitions/components/aws-dynamodb-simple-xp.cue

# Re-deploy applications
vela up -f definitions/examples/session-api-app-kro.yaml
vela up -f definitions/examples/session-api-app-xp.yaml
```

### Issue 2: SimpleDynamoDB Exists But No ACK Table

**Symptom:**
- `debug-resources.sh` section 3 shows SimpleDynamoDB but no ACK Table resources
- KRO ResourceGraphDefinition exists but not working

**Causes:**
1. KRO RGD not watching SimpleDynamoDB CRD
2. KRO RGD deployed AFTER components (wrong order)
3. KRO not started/healthy

**Debugging:**

```bash
# Check if RGD exists
kubectl get resourcegraphdefinitions

# Check KRO pod status
kubectl get pods -n kro-system

# Check KRO logs
kubectl logs -n kro-system -l app.kubernetes.io/instance=kro | grep -i simple

# Manually check if RGD watches SimpleDynamoDB
kubectl get resourcegraphdefinitions -o yaml | grep -A 5 "SimpleDynamoDB"
```

**Fix:**
```bash
# Redeploy RGD first, then components (must be in order)
kubectl apply -f definitions/kro/simple-dynamodb-rgd.yaml
sleep 5
vela def apply definitions/components/aws-dynamodb-simple-kro.cue
```

### Issue 3: ACK Table Exists But No LocalStack Table

**Symptom:**
- `debug-resources.sh` shows ACK Table resources
- LocalStack shows no tables in `list-tables` output
- ACK controller running but tables not syncing

**Causes:**
1. ACK not configured to use LocalStack endpoint
2. ACK credentials wrong
3. ACK controller not watching Table resources
4. LocalStack endpoint unreachable from ACK

**Debugging:**

```bash
# Check ACK controller logs
kubectl logs -n ack-system -l app=ack-dynamodb-controller | grep -i error
kubectl logs -n ack-system -l app=ack-dynamodb-controller | grep -i localstack
kubectl logs -n ack-system -l app=ack-dynamodb-controller | grep -i endpoint

# Check if Table resource has status conditions
kubectl get table.dynamodb.services.k8s.aws -A -o yaml | grep -A 10 "status:"

# Check if ACK can reach LocalStack
kubectl exec -n ack-system <ack-pod> -- \
  curl -v http://localstack.localstack-system.svc.cluster.local:4566/

# Check ACK environment variables
kubectl get deployment -n ack-system ack-dynamodb-controller -o yaml | grep -A 20 "env:"
```

**Fix:**
```bash
# Verify ACK was installed correctly
./install-ack.sh

# Or check what went wrong in Phase 6 of setup
kubectl logs -n ack-system -l app=ack-dynamodb-controller | tail -100
```


## Manual Test Flow

For manual testing without running the full test script:

### Test: Can KRO create tables?

```bash
# Create SimpleDynamoDB manually
kubectl apply -f - <<'EOF'
apiVersion: kro.run/v1alpha1
kind: SimpleDynamoDB
metadata:
  name: test-kro-simple
  namespace: default
spec:
  tableName: test-kro
  region: us-west-2
EOF

# Wait and check
sleep 10
kubectl get simpledynamodb test-kro-simple -o yaml
kubectl get table.dynamodb.services.k8s.aws -o yaml

# Check LocalStack
kubectl run -it --rm debug --image=amazon/aws-cli -- \
  --endpoint-url=http://localstack.localstack-system.svc.cluster.local:4566 \
  --region=us-west-2 \
  dynamodb list-tables
```

## Viewing Logs in Real-Time

To watch logs as resources are created:

```bash
# Terminal 1: Watch ACK controller
kubectl logs -n ack-system -l app=ack-dynamodb-controller -f

# Terminal 2: Watch Crossplane controller
kubectl logs -n crossplane-system -l app=crossplane -f

# Terminal 3: Watch KRO controller
kubectl logs -n kro-system -l app.kubernetes.io/instance=kro -f

# Terminal 4: Create test resources
kubectl apply -f definitions/examples/session-api-app-kro.yaml
# or run test-manual-table-creation.sh
```

## Useful Commands

```bash
# List all SimpleDynamoDB resources
kubectl get simpledynamodb -A

# Watch SimpleDynamoDB resources being created
kubectl get simpledynamodb -A -w

# List all ACK Table resources
kubectl get table.dynamodb.services.k8s.aws -A

# Watch ACK Table resources being created
kubectl get table.dynamodb.services.k8s.aws -A -w

# Check LocalStack pod
kubectl get pods -n localstack-system -o wide

# Test LocalStack connectivity
kubectl run -it --rm debug --image=amazon/aws-cli -- \
  --endpoint-url=http://localstack.localstack-system.svc.cluster.local:4566 \
  --region=us-west-2 \
  dynamodb list-tables
```

## Getting Help

If you're still stuck:

1. Run `./debug-resources.sh` and save output:
   ```bash
   ./debug-resources.sh > debug-output.txt 2>&1
   ```

2. Run `./test-manual-table-creation.sh` and save output:
   ```bash
   ./test-manual-table-creation.sh > test-output.txt 2>&1
   ```

3. Check the "Decision Tree" section above to identify which component is failing

4. Review the relevant "Common Issues" section for your situation

5. Check controller logs specifically for your failing component
