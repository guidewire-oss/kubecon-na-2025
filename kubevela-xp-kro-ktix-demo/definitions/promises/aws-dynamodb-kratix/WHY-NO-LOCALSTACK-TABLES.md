# Why check-dynamodb-tables.sh Doesn't See Kratix Promise Tables

## Short Answer

**Different clusters, different approaches, different stages of completion.**

The LocalStack demo script only looks in the kubecon-na-2025 cluster where KRO/Crossplane have already created actual tables in LocalStack. The Kratix Promise tables are on a different cluster (kubevela-devex) and are still at the definition stage (awaiting Kratix operator execution).

---

## Detailed Explanation

### 1. The LocalStack Demo Script

**Location:** `kubecon-na-2025/kubevela-xp-kro-localstack/check-dynamodb-tables.sh`

**What it does:**
- Connects to the kubecon-na-2025 cluster
- Finds the LocalStack pod (mock AWS service)
- Runs: `aws dynamodb list-tables --endpoint-url=http://localhost:4566`
- Displays tables **ACTUALLY CREATED** in LocalStack

**Why it works:**
- ✅ KRO/Crossplane controllers are **ACTIVELY RUNNING**
- ✅ ACK DynamoDB controller is **ACTIVELY RUNNING**
- ✅ Tables are **ACTUALLY CREATED** in LocalStack
- ✅ LocalStack persists table data

**Example output:**
```
✓ Found the following DynamoDB tables:
  • api-sessions-kro
  • (other tables created by KRO/Crossplane)
```

---

### 2. The Kratix Promise Tables

**Location:** `kubevela-devex/.development/promises/aws-dynamodb-kratix/`
**Cluster:** `kubevela-demo` (different from kubecon-na-2025)

**What exists:**
- ✅ Promise definition: INSTALLED
- ✅ DynamoDBRequest CRD: INSTALLED
- ✅ 5 test requests: CREATED
- ✅ Validation: WORKING

**What's missing:**
- ❌ Kratix operator: NOT RUNNING
- ❌ Workflow execution: NOT HAPPENING
- ❌ ACK Table manifests: NOT CREATED
- ❌ Actual DynamoDB tables: NOT CREATED

**Why tables don't exist:**
- Requests are just Kubernetes resources stored in etcd
- No process is monitoring them for conversion
- No workflow has generated ACK manifests
- No table creation has been initiated

---

### 3. The Resource Creation Chain

#### What WOULD happen with Kratix operator:

```
DynamoDBRequest created
  │ (user creates: kubectl apply -f request.yaml)
  ├─ Request stored in Kubernetes ✅
  │
  └─ Kratix Operator detects new request ⏳
      │ (operator must be running)
      │
      └─ Executes resource.configure workflow ⏳
          │ (workflow.py must run)
          │
          └─ Validates request ✅ (we tested this)
              │
              └─ Generates ACK Table manifest ⏳
                  │
                  └─ Stores manifest as ACK Table resource ⏳
                      │
                      └─ ACK controller detects Table resource ⏳
                          │
                          └─ Creates actual DynamoDB table in AWS ⏳
```

#### Current state:
- ✅ Request created
- ⏳ Everything else pending Kratix operator

---

### 4. Why They're on Different Clusters

**kubecon-na-2025/kubevela-xp-kro-localstack/**
- Demo project for KubeVela + KRO + Crossplane + LocalStack
- Multiple controllers actively running
- LocalStack running in cluster (mock AWS)
- Tables getting created in real-time
- Designed to show **working system**

**kubevela-devex/**
- New project for Kratix Promise implementation
- Promise definition just deployed
- No Kratix operator installed
- No table creation process active
- Designed to show **Promise architecture and definitions**

---

### 5. How to Check Each

**LocalStack Demo:**
```bash
$ cd kubecon-na-2025/kubevela-xp-kro-localstack/
$ ./check-dynamodb-tables.sh
# Shows tables in LocalStack (created by KRO/Crossplane)
```

**Kratix Promise:**
```bash
$ cd kubevela-devex/.development/promises/aws-dynamodb-kratix/
$ ./check-promise-requests.sh
# Shows requests in Kubernetes (pending Kratix operator)
```

---

### 6. Key Architectural Differences

| Aspect | LocalStack Demo | Kratix Promise |
|--------|-----------------|----------------|
| **Architecture** | KRO/Crossplane → ACK → LocalStack | Promise → Kratix Workflow → ACK → AWS |
| **Execution Model** | Continuous reconciliation loops | Event-driven workflows |
| **Operator Status** | Controllers running | Operator not installed |
| **Table Status** | ✅ Created and queryable | ⏳ Pending operator |
| **Where to check** | In LocalStack pod | In Kubernetes resources |

---

### 7. What's Actually the Same

Both use:
- AWS ACK (AWS Controllers for Kubernetes)
- Kubernetes CustomResourceDefinitions (CRDs)
- YAML manifests for resource definition
- Same underlying DynamoDB concepts

But delivered via:
- **LocalStack Demo:** Direct KRO/Crossplane controllers
- **Kratix Promise:** Promise-based platform service

---

## Summary

**The scripts don't conflict** - they're checking different things on different clusters:

### check-dynamodb-tables.sh
- → Looks in LocalStack (kubecon cluster)
- → Queries actual tables created by KRO/Crossplane
- → Shows ✅ working system with real tables

### check-promise-requests.sh
- → Looks at Kubernetes resources (kubevela cluster)
- → Shows DynamoDB requests stored as CRDs
- → Shows ⏳ pending operator execution

---

## To See Kratix Promise Tables Get Created

You need to:
1. **Install Kratix operator** - enables workflow execution
2. **Configure ACK controller** - enables table creation
3. **Provide AWS credentials** - enables actual AWS access
4. **Then the workflow will execute** and create actual tables

This is by design:
- **Promise** = framework/product definition (independent)
- **Operator** = runtime that executes the Promise (optional deployment)

The Promise can be versioned, distributed, and tested independently of any particular operator version!
