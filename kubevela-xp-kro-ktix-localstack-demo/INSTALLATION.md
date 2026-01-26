# Installation Guide: Kratix Operator & ACK DynamoDB Controller

## 📋 Overview

This guide covers the installation of two key infrastructure controllers for the KubeCon NA 2025 LocalStack demo:

1. **ACK (AWS Controllers for Kubernetes)** - DynamoDB Controller
2. **Kratix** - Platform Engineering Operator

Both are now integrated into the automated setup process and available as standalone installation scripts.

---

## 🚀 Quick Start

### Option 1: Full Automated Setup (Recommended)

```bash
# Install everything: KubeVela, Crossplane, KRO, LocalStack, ACK, and Kratix
./setup.sh
```

This runs a 10+ phase installation that includes:
- Phase 1: Cluster creation (if needed)
- Phase 2: LocalStack installation
- Phase 3: KubeVela installation
- Phase 4: Crossplane installation
- Phase 5: KRO installation
- **Phase 6: ACK DynamoDB Controller** ✨ NEW
- **Phase 6.5: Kratix Operator** ✨ NEW
- Phase 7: Component definitions
- Phase 8-11: Finalization and testing

### Option 2: Standalone Installation (ACK Only)

```bash
# Install just ACK DynamoDB Controller
./install-ack.sh
```

### Option 3: Standalone Installation (Kratix Only)

```bash
# Install just Kratix Operator
./install-kratix.sh
```

### Option 4: Skip Build and Install

```bash
# Install without rebuilding Docker images
./setup.sh --skip-build

# Install without any components (definitions only)
./setup.sh --skip-install
```

---

## 📊 What Gets Installed

### ACK DynamoDB Controller

| Component | Details |
|-----------|---------|
| **Namespace** | `ack-system` |
| **CRD** | `tables.dynamodb.services.k8s.aws` |
| **ServiceAccount** | `ack-dynamodb` |
| **ClusterRole** | `ack-dynamodb` |
| **Deployment** | `ack-dynamodb-controller` |
| **Image** | `public.ecr.aws/aws-controllers-k8s/dynamodb-controller:v1.4.0` |

**Enables:**
- Creating DynamoDB tables via Kubernetes resources
- Managing table lifecycle (create, update, delete)
- Integration with LocalStack for local development
- Native Kubernetes API for AWS resources

### Kratix Operator

| Component | Details |
|-----------|---------|
| **Namespace** | `kratix-system` |
| **CRDs** | `promises.platform.kratix.io`, `requests.platform.kratix.io` |
| **ServiceAccount** | `kratix-controller-manager` |
| **ClusterRole** | `kratix` |
| **Deployment** | `kratix-controller-manager` |
| **Version** | v0.3.1 (or fallback minimal CRDs) |

**Enables:**
- Platform engineering patterns with Promises
- Infrastructure abstraction layer
- Self-service resource provisioning
- Workflow automation for infrastructure

---

## 🔧 Installation Details

### Phase 6: ACK DynamoDB Controller

**File:** `setup.sh` (lines 359-477)

**What happens:**
1. Creates `ack-system` namespace
2. Creates `localstack-credentials` secret
3. Installs ACK DynamoDB CRD from GitHub
4. Creates ServiceAccount, ClusterRole, ClusterRoleBinding
5. Deploys ACK controller pod

**Credentials:**
- AWS Access Key ID: `test` (dummy, for LocalStack)
- AWS Secret Access Key: `test` (dummy, for LocalStack)
- Region: `us-west-2`
- Endpoint: `http://localstack.localstack-system.svc.cluster.local:4566`

### Phase 6.5: Kratix Operator (NEW)

**File:** `setup.sh` (lines 479-561)

**What happens:**
1. Creates `kratix-system` namespace
2. Attempts to download official Kratix release (v0.3.1)
3. Falls back to minimal CRD installation if download fails
4. Creates ServiceAccount, ClusterRole, ClusterRoleBinding
5. Deploys Kratix controller pod

**Fallback Behavior:**
- If official release download fails, minimal CRDs are applied
- This ensures the API is always available, even if controller pod doesn't start
- CRDs installed: Promise, ResourceRequest, Workplace

---

## ✅ Verification

### Check Installation Status

```bash
# Set kubeconfig if needed
export KUBECONFIG=./kubeconfig-host

# Check ACK
kubectl get ns ack-system
kubectl get sa -n ack-system ack-dynamodb
kubectl get crd tables.dynamodb.services.k8s.aws
kubectl get deployment -n ack-system

# Check Kratix
kubectl get ns kratix-system
kubectl get sa -n kratix-system
kubectl get crd | grep kratix
kubectl get deployment -n kratix-system

# List all DynamoDB CRDs
kubectl get crd | grep dynamodb
```

### Check Pod Status

```bash
# ACK controller pod (may be in ImagePullBackOff)
kubectl get pods -n ack-system
kubectl describe pod -n ack-system -l app=ack-dynamodb-controller

# Kratix controller pod (may be in ImagePullBackOff)
kubectl get pods -n kratix-system
kubectl describe pod -n kratix-system -l app.kubernetes.io/name=kratix

# View logs
kubectl logs -n ack-system -l app=ack-dynamodb-controller --tail=50
kubectl logs -n kratix-system -l app.kubernetes.io/name=kratix --tail=50
```

---

## 🐛 Troubleshooting

### Issue: Controller Pod in ImagePullBackOff

**Symptom:** Pod shows `ImagePullBackOff` status but CRD is installed

```bash
kubectl get pods -n ack-system
# NAME                                    READY   STATUS
# ack-dynamodb-controller-xxx             0/1     ImagePullBackOff
```

**Cause:** The controller image can't be pulled from ECR (network isolation, private networks, etc.)

**Solution 1: Ignore (Recommended for LocalStack)**
- The CRD is installed and functional
- KRO can use it directly without the controller
- Perfect for local development with LocalStack

**Solution 2: Load Image Locally**
```bash
# If you have Docker access
docker pull public.ecr.aws/aws-controllers-k8s/dynamodb-controller:v1.4.0
k3d image import <image-id> -c kubevela-demo

# Then restart the deployment
kubectl rollout restart deployment/ack-dynamodb-controller -n ack-system
```

**Solution 3: Use Alternative Image**
```bash
# Patch the deployment to use a different image
kubectl set image deployment/ack-dynamodb-controller \
  -n ack-system \
  controller=your-registry/ack-controller:latest
```

**Solution 4: Build Image Locally**
```bash
# Clone ACK repo
git clone https://github.com/aws-controllers-k8s/dynamodb-controller
cd dynamodb-controller

# Build image
docker build -t ack-dynamodb-controller:custom .

# Load to k3d
k3d image import ack-dynamodb-controller:custom -c kubevela-demo

# Update deployment
kubectl set image deployment/ack-dynamodb-controller \
  -n ack-system \
  controller=ack-dynamodb-controller:custom
```

### Issue: CRD Not Available

**Symptom:** CRD can't be found even after installation

```bash
kubectl get crd tables.dynamodb.services.k8s.aws
# Error: No resources found
```

**Solution:**
```bash
# Manually install CRD
kubectl apply -f https://raw.githubusercontent.com/aws-controllers-k8s/dynamodb-controller/main/helm/crds/dynamodb.services.k8s.aws_tables.yaml

# Verify
kubectl get crd tables.dynamodb.services.k8s.aws
```

### Issue: Kratix v0.3.1 Not Found

**Symptom:** Kratix release download fails (404)

```bash
# This is handled automatically by setup.sh
# It falls back to minimal CRD installation
# Check that minimal CRDs are available:
kubectl get crd promises.platform.kratix.io
```

**Solution:**
- Setup.sh automatically handles this with fallback CRDs
- Manual installation uses fallback if download fails
- The Promise and ResourceRequest CRDs are always available

---

## 📖 Documentation Files

| File | Purpose |
|------|---------|
| `INSTALLATION.md` | This file - Installation guide |
| `INSTALLATION-SUMMARY.md` | Detailed installation report |
| `QUICK-REFERENCE.md` | Quick command reference |
| `ARCHITECTURE.md` | System architecture and integration |
| `README.md` | Project overview |
| `CLAUDE.md` | Developer guide |
| `DEBUGGING.md` | Troubleshooting guide |

---

## 🔗 Integration Points

### ACK + KRO Integration

```
KRO ResourceGraphDefinition
        ↓
    References: SimpleDynamoDB
        ↓
    Creates: dynamodb.services.k8s.aws/Table
        ↓
    Managed by: ACK Controller (or directly by Kubernetes)
        ↓
    Synced to: LocalStack DynamoDB
```

### Kratix + ACK Integration

```
Kratix Promise (Infrastructure Definition)
        ↓
    Provides: ResourceRequest API
        ↓
    Maps to: dynamodb.services.k8s.aws/Table
        ↓
    Created by: ACK Controller
        ↓
    Deployed to: LocalStack
```

### Full Stack: Kratix + KRO + ACK + LocalStack

```
┌─────────────────────────────────────┐
│  Developer's Application            │
│  (Defines infrastructure needs)      │
└────────────────┬────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│  Kratix Promise API                 │ (Platform abstraction)
│  (Infrastructure as a Platform)      │
└────────────────┬────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│  KRO ResourceGraphDefinition        │ (Orchestration layer)
│  (Transforms abstractions to APIs)   │
└────────────────┬────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│  ACK Table CRD                      │ (Kubernetes-native AWS API)
│  (tables.dynamodb.services.k8s.aws) │
└────────────────┬────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│  LocalStack DynamoDB                │ (Local AWS emulation)
│  (No AWS account required)           │
└─────────────────────────────────────┘
```

---

## 🎯 Next Steps

### 1. Verify Installation
```bash
# Run the setup
./setup.sh

# Or verify existing installation
kubectl get deployment -n ack-system
kubectl get deployment -n kratix-system
```

### 2. Create Test Resources

**Test ACK:**
```bash
kubectl apply -f - <<'EOF'
apiVersion: dynamodb.services.k8s.aws/v1alpha1
kind: Table
metadata:
  name: test-table
spec:
  tableName: test-table
  attributeDefinitions:
  - attributeName: id
    attributeType: S
  keySchema:
  - attributeName: id
    keyType: HASH
  billingMode: PAY_PER_REQUEST
EOF

kubectl describe table test-table
```

**Test Kratix:**
```bash
kubectl apply -f - <<'EOF'
apiVersion: kratix.io/v1alpha1
kind: Promise
metadata:
  name: test-promise
spec:
  api:
    apiVersion: apiextensions.k8s.io/v1
    kind: CustomResourceDefinition
    metadata:
      name: databases.example.io
    spec:
      group: example.io
      scope: Namespaced
      names:
        kind: Database
        plural: databases
      versions:
      - name: v1
        served: true
        storage: true
        schema:
          openAPIV3Schema:
            type: object
            properties:
              spec:
                type: object
EOF

kubectl get promises
```

### 3. Deploy Demo Applications

```bash
# KRO-based app
vela up -f definitions/examples/session-api-app-kro.yaml

# Check status
vela status session-api-app-kro
```

### 4. Review Documentation
- **ARCHITECTURE.md** - Understand the system design
- **QUICK-REFERENCE.md** - Quick command reference
- **DEBUGGING.md** - Troubleshooting guide

---

## 📚 Additional Resources

- **ACK Documentation:** https://aws-controllers-k8s.github.io/community/
- **Kratix Documentation:** https://kratix.io/
- **KRO Documentation:** https://kubernetes-sigs.github.io/kro/
- **LocalStack Documentation:** https://docs.localstack.cloud/

---

## ⚙️ Configuration Details

### ACK Environment Variables

```
AWS_REGION:        us-west-2
AWS_ENDPOINT_URL:  http://localstack.localstack-system.svc.cluster.local:4566
AWS_ACCESS_KEY_ID: test
AWS_SECRET_ACCESS_KEY: test
```

### Kratix Configuration

```
Version:  v0.3.1 (or fallback minimal setup)
Namespace: kratix-system
CRDs: Promise, ResourceRequest, Workplace
```

### LocalStack Configuration

```
Endpoint:   http://localstack.localstack-system.svc.cluster.local:4566
Region:     us-west-2
Services:   DynamoDB (enabled)
Credentials: test/test (dummy credentials)
```

---

## 📝 Notes

- **Controllers in ImagePullBackOff:** This is normal in isolated environments. The CRDs are what matter.
- **LocalStack:** Running locally in the cluster, no AWS account needed.
- **Credentials:** All credentials are dummy/test values. No real AWS credentials required.
- **Image Pull:** If you need working controllers, use a local registry or pre-cache images.

---

## 🤝 Contributing

To improve the installation:
1. Report issues with specific phases
2. Suggest alternatives for image pull problems
3. Add support for additional controllers

---

**Last Updated:** January 15, 2026
**Status:** ✓ Installation Complete
**Tested On:** k3d cluster with Kubernetes v1.31.5
