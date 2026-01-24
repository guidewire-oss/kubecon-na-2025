# Kratix Promise vs LocalStack Demo - Quick Comparison

## Two Different Approaches to DynamoDB on Kubernetes

### 1️⃣ LocalStack Demo (kubecon-na-2025)
**Architecture:** KRO/Crossplane → LocalStack Mock AWS
**Tables created by:** Direct controller loop (KRO/Crossplane)
**Billing location:** LocalStack pod in cluster
**Check with:** `./check-dynamodb-tables.sh`

**Status:**
- ✅ KRO/Crossplane watching resources
- ✅ ACK controller managing tables
- ✅ Tables exist in LocalStack
- ✅ Can query with AWS CLI

**Requests tracked by:** KRO SimpleDynamoDB / Crossplane Composition

---

### 2️⃣ Kratix Promise (kubevela-devex)
**Architecture:** Kratix Promise → ACK → AWS (when connected)
**Tables created by:** Kratix workflows + ACK controller
**Billing location:** Actual AWS (or LocalStack if configured)
**Check with:** `./check-promise-requests.sh`

**Status:**
- ✅ Promise definition installed
- ✅ DynamoDBRequest CRD available
- ✅ 5 test requests created
- ⏳ Waiting for Kratix operator to execute workflows
- ❌ No actual tables yet (operator required)

**Requests tracked by:** Kratix DynamoDBRequest CRD

---

## Why They Don't Integrate

| Aspect | LocalStack | Kratix |
|--------|-----------|--------|
| **Purpose** | Full AWS mock in container | Platform-as-product framework |
| **Controller** | KRO / Crossplane controllers | Kratix operator |
| **Workflows** | Implicit (in controller) | Explicit (promise.yaml) |
| **Platform Model** | Direct Kubernetes resources | Marketplace model |
| **Cluster** | kubecon-na-2025 setup | kubevela-devex setup |
| **Tables visible in** | LocalStack pod | Not yet (pending operator) |

---

## Using Both Together

You could theoretically run both:

1. **LocalStack Cluster**
   - KRO/Crossplane creating tables
   - Check: `./check-dynamodb-tables.sh`

2. **Kratix Cluster**
   - Promise defining DynamoDB service
   - Kratix operator routing to LocalStack cluster
   - Check: `./check-promise-requests.sh`

This would create a **platform** (Kratix Promise) managing table creation across clusters!

---

## Which Should You Use?

**Use LocalStack Demo if:**
- You want immediate table creation
- You need mock AWS for testing
- You want to see KRO/Crossplane in action
- You don't need operator infrastructure

**Use Kratix Promise if:**
- You want platform-as-product architecture
- You need explicit workflow control
- You want marketplace-style service distribution
- You're building internal developer platforms

Both are valid approaches! They're designed for different use cases.
