# AWS DynamoDB KRO Component - Summary

## Overview

Successfully created a KubeVela ComponentDefinition for AWS DynamoDB using **KRO (Kube Resource Orchestrator)** and **ACK (AWS Controllers for Kubernetes)** instead of Crossplane.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    KubeVela Application                      │
│                 (User-facing abstraction)                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│           ComponentDefinition: aws-dynamodb-kro             │
│                   (KubeVela abstraction)                     │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│           KRO ResourceGraphDefinition (RGD)                 │
│        (Orchestrates resource dependencies)                  │
│                                                              │
│  Creates:                                                    │
│  • Custom API: DynamoDBTable (v1alpha1)                     │
│  • Schema validation and defaults                           │
│  • Status propagation from ACK resources                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│      ACK DynamoDB Table CRD                                 │
│      (dynamodb.services.k8s.aws/v1alpha1)                   │
│                                                              │
│  Manages:                                                    │
│  • Direct AWS API calls via ACK controller                  │
│  • Resource lifecycle (create, update, delete)              │
│  • Status synchronization from AWS                          │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
               ┌───────────────┐
               │  AWS DynamoDB │
               │    Service    │
               └───────────────┘
```

## Key Differences from Crossplane

| Aspect | KRO + ACK | Crossplane |
|--------|-----------|------------|
| **API Mapping** | 1:1 with AWS APIs | Abstracted composition layer |
| **Infrastructure** | KRO + ACK controllers | Crossplane provider infrastructure |
| **Update Speed** | Fast (tracks AWS APIs closely) | Slower (depends on provider releases) |
| **Resource Model** | Native Kubernetes CRDs | Crossplane XRs and MRs |
| **Orchestration** | KRO ResourceGraphDefinitions | Crossplane Compositions |
| **Status Reporting** | Direct from AWS via ACK | Through provider layer |
| **Multi-cloud** | AWS-specific | Cloud-agnostic |

## Files Created

### Component Definition
- **Location**: `.development/definitions/components/aws-dynamodb-kro.cue`
- **Size**: ~8KB
- **Features**:
  - Complete DynamoDB table configuration
  - KRO ResourceGraphDefinition embedded as output
  - Status propagation from ACK to KubeVela
  - Full parameter validation

### Documentation
- **Component Docs**: `.development/definitions/components/aws-dynamodb-kro.md`
  - Complete API reference
  - Usage examples
  - Prerequisites and setup
  - Troubleshooting guide
  - Best practices

- **Examples README**: `.development/definitions/examples/dynamodb-kro/README.md`
  - Example descriptions
  - Testing instructions
  - Customization guide

### Example Applications

1. **basic.yaml** - Simple table with partition key
   - On-demand billing
   - Single attribute
   - Minimal configuration

2. **with-gsi.yaml** - Table with Global Secondary Index
   - Email lookup index
   - Multiple attributes
   - Query pattern optimization

3. **provisioned.yaml** - Provisioned capacity mode
   - Fixed capacity units
   - GSI with dedicated throughput
   - Cost-predictable workloads

4. **production.yaml** - Full-featured production table
   - Streams enabled (CDC)
   - Point-in-time recovery
   - Server-side encryption
   - TTL configuration
   - Deletion protection
   - Resource tags
   - Connection secret output

## Supported Features

### Table Configuration
✅ Table name and region
✅ Billing modes (PAY_PER_REQUEST, PROVISIONED)
✅ Attribute definitions
✅ Key schema (partition + optional sort key)

### Secondary Indexes
✅ Global Secondary Indexes (up to 20)
✅ Local Secondary Indexes (up to 5)
✅ Projection types (ALL, KEYS_ONLY, INCLUDE)
✅ Dedicated throughput for GSIs

### Data Protection
✅ Point-in-time recovery
✅ Server-side encryption (AES256, KMS)
✅ Deletion protection
✅ Backup management

### Advanced Features
✅ DynamoDB Streams (all view types)
✅ Time To Live (TTL)
✅ Table classes (STANDARD, STANDARD_INFREQUENT_ACCESS)
✅ Resource tags
✅ Connection secret output
✅ Provider configuration reference

### Status Reporting
✅ Table ARN
✅ Table status (CREATING, ACTIVE, UPDATING, DELETING)
✅ Table ID
✅ Stream ARN
✅ Item count
✅ Table size
✅ Creation timestamp
✅ Detailed conditions

## Prerequisites

### 1. KRO Installation
```bash
kubectl apply -f https://github.com/kubernetes-sigs/kro/releases/latest/download/kro.yaml
```

### 2. ACK DynamoDB Controller
```bash
export ACK_K8S_NAMESPACE=ack-system

helm repo add aws-controllers-k8s https://aws-controllers-k8s.github.io/charts
helm install dynamodb-chart aws-controllers-k8s/dynamodb-chart \
  --namespace $ACK_K8S_NAMESPACE \
  --create-namespace
```

### 3. AWS Credentials (IRSA Recommended)
```bash
eksctl create iamserviceaccount \
  --name ack-dynamodb-controller \
  --namespace ack-system \
  --cluster my-cluster \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess \
  --approve \
  --override-existing-serviceaccounts
```

### 4. Apply ComponentDefinition
```bash
vela def apply .development/definitions/components/aws-dynamodb-kro.cue
```

## Quick Start

1. **Apply the component definition**:
   ```bash
   vela def apply .development/definitions/components/aws-dynamodb-kro.cue
   ```

2. **Deploy a basic example**:
   ```bash
   kubectl apply -f .development/definitions/examples/dynamodb-kro/basic.yaml
   ```

3. **Check the application**:
   ```bash
   kubectl get app dynamodb-basic-example
   vela status dynamodb-basic-example
   ```

4. **Verify in AWS**:
   - Open AWS Console → DynamoDB
   - Check for table "users-table" in us-east-1

## Testing Checklist

- [ ] Install KRO
- [ ] Install ACK DynamoDB controller
- [ ] Configure AWS credentials
- [ ] Apply ComponentDefinition
- [ ] Test basic example
- [ ] Test with GSI
- [ ] Test provisioned mode
- [ ] Test production config
- [ ] Verify status propagation
- [ ] Test connection secret creation
- [ ] Verify cleanup (deletion)

## Next Steps

### For Development
1. Validate the CUE definition:
   ```bash
   vela def vet .development/definitions/components/aws-dynamodb-kro.cue
   ```

2. Test in a development cluster:
   ```bash
   vela def apply .development/definitions/components/aws-dynamodb-kro.cue -n vela-system
   ```

3. Deploy test applications and verify functionality

### For Production
1. Move to appropriate repository:
   - OSS: `projects/kubevela/vela-templates/definitions/`
   - Internal: Organization's internal definition repository

2. Add CI/CD validation

3. Document in organization wiki

4. Train platform team

## Benefits

### For Platform Engineers
- **Single abstraction layer**: Manage DynamoDB through KubeVela
- **GitOps ready**: All resources declarative
- **No Crossplane overhead**: Simpler architecture
- **Direct AWS integration**: ACK provides immediate AWS API access

### For Developers
- **Simplified interface**: Don't need to know AWS specifics
- **Self-service**: Create tables through KubeVela applications
- **Status visibility**: Table status in Kubernetes
- **Integrated secrets**: Connection details in Kubernetes Secrets

### For Operations
- **Kubernetes-native**: Manage with kubectl and GitOps tools
- **Consistent tooling**: Same tools as other Kubernetes resources
- **Clear ownership**: Tables tied to applications
- **Audit trail**: Git history for all changes

## Limitations & Considerations

### Current Limitations
- **Experimental**: KRO is still under active development
- **AWS Only**: ACK is AWS-specific (no multi-cloud abstraction)
- **Setup Complexity**: Requires KRO + ACK installation
- **Limited CRD Coverage**: Not all DynamoDB features may be in ACK CRDs

### Best Practices
1. Use PAY_PER_REQUEST for variable workloads
2. Enable point-in-time recovery for production
3. Use encryption (SSE) by default
4. Enable deletion protection for critical tables
5. Tag all resources for cost allocation
6. Use IRSA for EKS credentials
7. Test thoroughly before production use

## References

### Documentation
- [KRO Documentation](https://kro.run/)
- [KRO Examples](https://kro.run/examples/)
- [ACK Documentation](https://aws-controllers-k8s.github.io/docs/)
- [ACK DynamoDB CRD Reference](https://aws-controllers-k8s.github.io/community/reference/dynamodb/v1alpha1/table/)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)

### Blog Posts
- [Introducing kro: Kube Resource Orchestrator](https://aws.amazon.com/blogs/opensource/introducing-open-source-kro-kube-resource-orchestrator/)
- [Building Self-Service AWS Infrastructure with KRO and ACK](https://medium.com/@tolghn/building-self-service-aws-infrastructure-with-kro-and-ack-5215631f08ce)
- [Resource Composition with kro (Amazon EKS)](https://docs.aws.amazon.com/eks/latest/userguide/kro.html)

---

**Created**: 2025-12-23
**Status**: Ready for testing
**Version**: 1.0.0
**Engine**: KRO + ACK
**Cloud**: AWS
