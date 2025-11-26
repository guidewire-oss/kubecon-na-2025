# High Availability Trait for KubeVela

A KubeVela trait that automatically configures high availability settings for Kubernetes workloads based on environment level (dev, staging, prod).

## Overview

The `high-availability` trait provides a simple, declarative way to configure multiple HA features with a single parameter. It automatically sets up appropriate configurations for:

- **HorizontalPodAutoscaler (HPA)** - Auto-scaling based on CPU utilization
- **PodDisruptionBudget (PDB)** - Controlled pod disruptions during maintenance
- **Topology Spread Constraints** - Distribution across availability zones
- **Pod Anti-Affinity** - Pod distribution across nodes

## Configuration Matrix

| Feature | Dev | Staging | Prod | Prod-Local |
|---------|-----|---------|------|------------|
| **HPA Min/Max Replicas** | 1-2 | 1-3 | 3-6 | 3-6 |
| **HPA CPU Target** | 70% | 70% | 70% | 70% |
| **PodDisruptionBudget** | No | minAvailable: 50% | maxUnavailable: 2 | maxUnavailable: 1 |
| **Topology Spread** | No | No | 3 zones, maxSkew: 1 | No |
| **Anti-Affinity** | No | Preferred (weight: 100) | Required | Preferred (weight: 100) |

**Note:** Use `prod-local` for local development clusters (k3d/kind/minikube) to get production-like HA without requiring multi-zone infrastructure.

## Installation

### 1. Apply the TraitDefinition

```bash
kubectl apply -f high-availability-traitdef.yaml
```

### 2. Verify Installation

```bash
vela traits
# Should show: high-availability
```

### 3. View Trait Details

```bash
vela show high-availability
```

## Usage

### Basic Usage

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: my-app
spec:
  components:
    - name: web-service
      type: webservice
      properties:
        image: nginx:1.21
        ports:
          - port: 80
      traits:
        - type: high-availability
          properties:
            level: prod  # or "dev" (default), "staging"
```

### Multi-Environment Deployment

Use with override policies to apply different HA levels per environment:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: multi-env-app
spec:
  components:
    - name: api-service
      type: webservice
      properties:
        image: my-api:v1.0.0
      traits:
        - type: high-availability
          properties:
            level: dev  # Default for base deployment

  policies:
    - name: topology-staging
      type: topology
      properties:
        namespace: staging

    - name: override-staging
      type: override
      properties:
        components:
          - name: api-service
            traits:
              - type: high-availability
                properties:
                  level: staging

    - name: topology-prod
      type: topology
      properties:
        namespace: prod

    - name: override-prod
      type: override
      properties:
        components:
          - name: api-service
            traits:
              - type: high-availability
                properties:
                  level: prod

  workflow:
    steps:
      - name: deploy-dev
        type: deploy
        properties:
          auto: true

      - name: deploy-staging
        type: deploy
        properties:
          policies: ["topology-staging", "override-staging"]

      - name: deploy-prod
        type: deploy
        properties:
          policies: ["topology-prod", "override-prod"]
```

## Feature Details

### Dev Level (`level: dev`)

**Use case:** Development and testing environments

**Configuration:**
- **HPA:** 1-2 replicas, scales at 70% CPU
- **PDB:** Not configured (allows unrestricted disruptions)
- **Topology Spread:** Not configured (single zone deployment allowed)
- **Anti-Affinity:** Not configured (pods can co-locate on same node)

**Behavior:**
- Minimal resource usage
- Fast deployment
- No disruption protection
- Suitable for rapid iteration

### Staging Level (`level: staging`)

**Use case:** Pre-production testing and validation

**Configuration:**
- **HPA:** 1-3 replicas, scales at 70% CPU
- **PDB:** minAvailable 50% (always keep at least half of pods running)
- **Topology Spread:** Not configured
- **Anti-Affinity:** Preferred scheduling (soft constraint, weight: 100)

**Behavior:**
- Moderate resource usage
- Some disruption protection during updates
- Pods prefer different nodes but can share if necessary
- Suitable for integration testing

### Prod Level (`level: prod`)

**Use case:** Production environments requiring high availability (multi-zone clusters)

**Configuration:**
- **HPA:** 3-6 replicas, scales at 70% CPU
- **PDB:** maxUnavailable 2 (maximum 2 pods can be down simultaneously)
- **Topology Spread:** 3 zones, maxSkew 1 (balanced distribution)
- **Anti-Affinity:** Required scheduling (hard constraint)

**Behavior:**
- Higher resource usage for reliability
- Strong disruption protection
- Pods MUST run on different nodes
- Pods distributed across 3 availability zones
- Maximum resilience to node and zone failures

**Requirements:**
- Multi-node cluster with at least 3 nodes
- Nodes must have `topology.kubernetes.io/zone` labels
- Suitable for: EKS, GKE, AKS, or any multi-zone cluster

### Prod-Local Level (`level: prod-local`)

**Use case:** Local development with production-like HA (k3d/kind/minikube)

**Configuration:**
- **HPA:** 3-6 replicas, scales at 70% CPU
- **PDB:** maxUnavailable 1 (maximum 1 pod can be down)
- **Topology Spread:** Not configured (no zone requirements)
- **Anti-Affinity:** Preferred scheduling (soft constraint, weight: 100)

**Behavior:**
- Production-like HPA and PDB
- Disruption protection suitable for local testing
- Pods prefer different nodes but can share if needed
- No zone distribution requirements
- Works on single-node or multi-node local clusters

**Requirements:**
- Any Kubernetes cluster (single or multi-node)
- No special labels required
- Suitable for: k3d, kind, minikube, Docker Desktop

## Generated Resources

### HorizontalPodAutoscaler (HPA)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: <component-name>
spec:
  minReplicas: <based on level>
  maxReplicas: <based on level>
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
        - type: Percent
          value: 100
          periodSeconds: 60
```

**Features:**
- Gradual scale-down (5 minute stabilization)
- Fast scale-up (1 minute stabilization)
- Scale down by max 50% per minute
- Scale up by max 100% per minute

### PodDisruptionBudget (PDB)

**Staging:**
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: <component-name>
spec:
  minAvailable: 50%
  selector:
    matchLabels:
      app.oam.dev/component: <component-name>
```

**Production:**
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: <component-name>
spec:
  maxUnavailable: 2
  selector:
    matchLabels:
      app.oam.dev/component: <component-name>
```

### Topology Spread Constraints (Production Only)

Added to pod spec:
```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app.oam.dev/component: <component-name>
```

**Behavior:**
- Distributes pods evenly across zones
- Maximum difference of 1 pod between zones
- Will not schedule if constraint cannot be met

### Pod Anti-Affinity

**Staging (Preferred):**
```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          topologyKey: kubernetes.io/hostname
          labelSelector:
            matchLabels:
              app.oam.dev/component: <component-name>
```

**Production (Required):**
```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - topologyKey: kubernetes.io/hostname
        labelSelector:
          matchLabels:
            app.oam.dev/component: <component-name>
```

## Testing

### 1. Deploy Example Application

```bash
# Create namespaces
kubectl create namespace dev
kubectl create namespace staging
kubectl create namespace prod

# Deploy the trait definition
kubectl apply -f high-availability-traitdef.yaml

# Deploy example application
vela up -f ha-example-app.yaml
```

### 2. Verify HPA

```bash
# Check HPA in each environment
kubectl get hpa -n dev
kubectl get hpa -n staging
kubectl get hpa -n prod

# View HPA details
kubectl describe hpa web-service -n prod
```

### 3. Verify PDB

```bash
# Check PDB (staging and prod only)
kubectl get pdb -n staging
kubectl get pdb -n prod

# View PDB status
kubectl describe pdb web-service -n prod
```

### 4. Verify Topology Spread and Anti-Affinity

```bash
# Check pod distribution in prod
kubectl get pods -n prod -o wide

# View pod scheduling constraints
kubectl get pod <pod-name> -n prod -o yaml | grep -A 20 "topologySpreadConstraints"
kubectl get pod <pod-name> -n prod -o yaml | grep -A 20 "affinity"
```

### 5. Test Pod Disruption

```bash
# Staging: Try to drain a node (should respect 50% minAvailable)
kubectl drain <node-name> --ignore-daemonsets

# Production: Should not allow more than 2 pods unavailable
kubectl delete pod <pod-name> -n prod
# Watch: kubectl get pods -n prod -w
```

## Troubleshooting

### HPA Not Scaling

**Symptom:** HPA shows `<unknown>` for current CPU

**Solution:**
1. Ensure metrics-server is installed:
   ```bash
   kubectl get deployment metrics-server -n kube-system
   ```

2. Check if pods have resource requests defined:
   ```bash
   kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 5 "resources:"
   ```

3. HPA requires CPU/memory requests to calculate utilization

### PDB Blocking Updates

**Symptom:** Deployments stuck, events show "Cannot evict pod as it would violate the pod's disruption budget"

**Solution:**
1. Check PDB status:
   ```bash
   kubectl get pdb -n <namespace>
   ```

2. Temporarily adjust PDB:
   ```bash
   kubectl edit pdb <pdb-name> -n <namespace>
   # Change minAvailable or maxUnavailable
   ```

3. Or scale up before updating:
   ```bash
   kubectl scale deployment <name> --replicas=<higher-number> -n <namespace>
   ```

### Anti-Affinity Scheduling Failures

**Symptom:** Pods stuck in Pending state with event "0/N nodes are available: insufficient nodes for spreading"

**Solution:**
1. For production (required anti-affinity):
   - Ensure you have enough nodes (at least as many as desired replicas)
   - Check node availability:
     ```bash
     kubectl get nodes
     ```

2. For staging (preferred anti-affinity):
   - Should not block - check for other issues

3. Temporarily remove anti-affinity constraint:
   - Change level to `dev` or
   - Edit pod spec manually

### Topology Spread Issues

**Symptom:** Production pods not spreading across zones

**Solution:**
1. Verify nodes have zone labels:
   ```bash
   kubectl get nodes --show-labels | grep topology.kubernetes.io/zone
   ```

2. Check if you have 3+ zones:
   ```bash
   kubectl get nodes -L topology.kubernetes.io/zone
   ```

3. For local/single-zone clusters:
   - Use `level: staging` instead of `prod`
   - Or label nodes manually for testing:
     ```bash
     kubectl label node <node-name> topology.kubernetes.io/zone=zone-a
     ```

## Best Practices

### 1. Start with Dev, Graduate to Prod

```yaml
# Initial deployment - use dev
traits:
  - type: high-availability
    properties:
      level: dev

# After testing - promote to staging
# After validation - promote to prod
```

### 2. Always Define Resource Requests

HPA requires resource requests to function:

```yaml
traits:
  - type: resource
    properties:
      requests:
        cpu: "100m"
        memory: "128Mi"
  - type: high-availability
    properties:
      level: prod
```

### 3. Use with Override Policies

Perfect for multi-environment deployments:

```yaml
components:
  - name: api
    traits:
      - type: high-availability
        properties:
          level: dev  # Base level

policies:
  - name: override-prod
    type: override
    properties:
      components:
        - name: api
          traits:
            - type: high-availability
              properties:
                level: prod  # Override for prod
```

### 4. Monitor HPA Metrics

```bash
# Watch HPA in action
watch kubectl get hpa -n prod

# View HPA events
kubectl describe hpa <name> -n prod
```

### 5. Test Disruptions in Staging First

Before applying to production:
1. Deploy to staging with `level: staging`
2. Test rolling updates
3. Test node drains
4. Verify PDB behavior

## Customization

To customize the trait for your needs, edit `high-availability-traitdef.yaml`:

### Change HPA Thresholds

```cue
dev: {
  hpa: {
    min:     1
    max:     5      // Increase max replicas
    cpuUtil: 60     // Lower CPU threshold
  }
}
```

### Add Memory-Based Scaling

```cue
metrics: [{
  type: "Resource"
  resource: {
    name: "cpu"
    target: {
      type:               "Utilization"
      averageUtilization: _selectedConfig.hpa.cpuUtil
    }
  }
}, {
  type: "Resource"
  resource: {
    name: "memory"
    target: {
      type:               "Utilization"
      averageUtilization: 80
    }
  }
}]
```

### Add Custom Levels

```cue
_config: {
  dev: { ... }
  staging: { ... }
  prod: { ... }
  "prod-critical": {
    hpa: {
      min:     5
      max:     20
      cpuUtil: 60
    }
    // ... more aggressive settings
  }
}
```

## Reference

### Parameter Schema

```yaml
parameter:
  level:
    type: string
    description: Environment level for high availability configuration
    enum: ["dev", "staging", "prod"]
    default: "dev"
```

### Workload Compatibility

Compatible with:
- `deployments.apps`
- `statefulsets.apps`

Not compatible with:
- DaemonSets (already run on all nodes)
- Jobs/CronJobs (ephemeral workloads)
- Pods (no controller)

## See Also

- [KubeVela Trait Documentation](https://kubevela.io/docs/end-user/traits/references)
- [Kubernetes HPA Documentation](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Kubernetes PDB Documentation](https://kubernetes.io/docs/tasks/run-application/configure-pdb/)
- [Topology Spread Constraints](https://kubernetes.io/docs/concepts/workloads/pods/pod-topology-spread-constraints/)
- [Pod Anti-Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity)
