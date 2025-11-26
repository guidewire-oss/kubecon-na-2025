# Advanced Features Guide

This guide covers the advanced KubeVela features demonstrated in this repository: parameter passing, observability, and high-availability traits.

## Table of Contents
- [Parameter Passing](#parameter-passing)
- [Observability](#observability)
- [High-Availability Traits](#high-availability-traits)
- [Quick Reference](#quick-reference)

## Parameter Passing

KubeVela enables sophisticated parameter passing between components, workflows, and environments, reducing configuration complexity by 65% compared to traditional approaches.

### Component-to-Component Communication

Components can output values that other components consume as inputs:

```yaml
# S3 bucket outputs its status
- name: kv-prodcat-images
  type: simple-s3
  outputs:
    - name: bucketArn
      valueFrom: output.status.bucketArn
    - name: bucketName
      valueFrom: output.status.bucketName
    - name: bucketRegion
      valueFrom: output.status.region

# Application component receives these values
- name: kv-product-cat-api
  type: webservice
  inputs:
    - from: bucketArn
      parameterKey: env[0].value
    - from: bucketName
      parameterKey: env[1].value
    - from: bucketRegion
      parameterKey: env[2].value
```

### Workflow Step Variable Passing

Workflow steps can pass data to downstream steps:

```yaml
workflow:
  steps:
    - name: create-resource
      type: step-group
      outputs:
        - name: resourceId
          valueFrom: response.id
        - name: resourceUrl
          valueFrom: |
            "http://service.namespace.svc.cluster.local:8080/api/" + response.id

    - name: verify-resource
      type: request
      inputs:
        - from: resourceUrl
          parameterKey: url
```

**Key Benefits:**
- Single source of truth for configuration
- Type-safe parameter propagation
- Automatic dependency ordering
- Reduces code from 746 lines → 258 lines (65% reduction)

### Environment-Specific Overrides

Use policies to customize parameters per environment:

```yaml
policies:
  - name: override-dev
    type: override
    properties:
      components:
        - name: kv-product-cat-api
          traits:
            - type: hpa
              properties:
                min: 1
                max: 3

  - name: override-prod
    type: override
    properties:
      components:
        - name: kv-product-cat-api
          traits:
            - type: hpa
              properties:
                min: 3
                max: 10
```

### CUE Template Parameters

Define reusable components with structured parameters:

```cue
parameter: {
  // Required parameters
  bucketName: string
  region: string

  // Optional with defaults
  versioning: *false | bool
  encryption: *true | bool
}
```

**Examples:**
- `kubevela-demo/kubevela/application.yaml` - Basic parameter passing
- `kubevela-demo/kubevela/s3-bucket-app.yaml` - Advanced patterns
- `kubevela-crossplane-demo/apps/webservice-s3-app.yaml` - Complex workflows

## Observability

Comprehensive observability stack with Prometheus, Grafana, and Loki for monitoring KubeVela applications and platform health.

### Quick Setup

```bash
cd kubevela-demo/kubevela
./setup-observability.sh
```

Access points:
- **Grafana:** http://localhost:3000 (admin / [from secret])
- **Prometheus:** http://localhost:9090

### KubeVela Platform Metrics

The platform exposes 8+ core metrics at `http://kubevela-vela-core.vela-system:8080/metrics`:

| Metric | Type | Description |
|--------|------|-------------|
| `kubevela_application_health_status` | Gauge | Overall health (1=healthy, 0=unhealthy) |
| `kubevela_application_phase` | Gauge | Application lifecycle phase |
| `kubevela_application_workflow_phase` | Gauge | Workflow execution phase |
| `application_reconcile_time_seconds` | Histogram | Reconciliation duration |
| `workflow_finished_time_seconds` | Histogram | Workflow completion time |
| `apply_component_time_seconds` | Histogram | Component apply duration |
| `workflow_step_phase_number` | Gauge | Steps in each phase |
| `application_phase_number` | Gauge | Applications in each phase |

### Application-Level Metrics

Enable application metric scraping with annotations:

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"
```

### Pre-built Dashboards

Three Grafana dashboards are included:

1. **kubevela-dashboard.json** - Platform-wide KubeVela metrics
2. **s3-storage-app-dashboard.json** - Multi-environment application view
3. **s3-storage-app-dashboard-single.json** - Single application focus

Import via Grafana UI: **Dashboards → Import → Upload JSON file**

### Multi-Environment Monitoring

Track applications across dev/staging/prod:

```promql
# Health by environment
kubevela_application_health_status{
  name="s3-storage-app",
  namespace=~"dev|staging|prod"
}

# Pod count by environment
count(kube_pod_info{
  namespace=~"dev|staging|prod",
  pod=~"storage-api.*"
}) by (namespace)

# CPU usage by environment
sum(rate(container_cpu_usage_seconds_total{
  namespace=~"dev|staging|prod",
  pod=~"storage-api.*"
}[5m])) by (namespace)
```

**Documentation:**
- `kubevela-demo/kubevela/OBSERVABILITY.md` - Complete guide (436 lines)
- `kubevela-demo/kubevela/setup-observability.sh` - Automated setup

## High-Availability Traits

A sophisticated trait system that automatically configures HPA, PDB, topology spread, and anti-affinity based on environment level.

### Configuration Matrix

| Feature | Dev | Staging | Prod | Prod-Local |
|---------|-----|---------|------|------------|
| **HPA Min/Max** | 1-2 | 1-3 | 3-6 | 3-6 |
| **HPA CPU Target** | 70% | 70% | 70% | 70% |
| **Pod Disruption Budget** | None | 50% min available | Max 2 unavailable | Max 1 unavailable |
| **Topology Spread** | None | None | 3 zones (maxSkew: 1) | None |
| **Anti-Affinity** | None | Preferred (weight: 100) | Required | Preferred (weight: 100) |

### Usage

Apply the trait to any deployment or statefulset:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: my-app
spec:
  components:
    - name: api-service
      type: webservice
      properties:
        image: my-api:v1.0.0
        ports:
          - port: 8080
      traits:
        - type: high-availability
          properties:
            level: prod  # dev | staging | prod | prod-local
```

### Generated Resources

#### Horizontal Pod Autoscaler (All Levels)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  minReplicas: 3  # varies by level
  maxReplicas: 6  # varies by level
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # 5-min stabilization
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60  # 1-min stabilization
      policies:
        - type: Percent
          value: 100
          periodSeconds: 60
```

#### Pod Disruption Budget (Staging, Prod, Prod-Local)

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
spec:
  minAvailable: "50%"          # staging
  # OR
  maxUnavailable: 2            # prod
  # OR
  maxUnavailable: 1            # prod-local
```

#### Topology Spread Constraints (Prod Only)

```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
```

#### Pod Anti-Affinity (Staging, Prod, Prod-Local)

**Staging/Prod-Local (Preferred):**
```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          topologyKey: kubernetes.io/hostname
```

**Prod (Required):**
```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - topologyKey: kubernetes.io/hostname
```

### Progressive Scaling Behavior

The trait implements progressive scaling to prevent rapid scale-up/down cycles:

- **Scale Up:** 1-minute stabilization, 100% increase per minute
- **Scale Down:** 5-minute stabilization, 50% decrease per minute

This prevents pod thrashing during load fluctuations.

### Local Cluster Considerations

Use `prod-local` level for single-node or local clusters:

```yaml
traits:
  - type: high-availability
    properties:
      level: prod-local  # Optimized for local k3d/kind/minikube
```

**Why?** Production level requires zone topology labels that local clusters lack, causing the "didn't match pod topology spread constraints" error.

### Deployment

Install the trait definition:

```bash
cd kubevela-demo/kubevela
./deploy-ha-trait.sh
```

Or manually:

```bash
vela def apply high-availability-traitdef.yaml
```

### Examples

- `kubevela-demo/kubevela/ha-example-app.yaml` - Generic multi-level example
- `kubevela-demo/kubevela/ha-example-app-local.yaml` - Local cluster optimized
- `kubevela-demo/kubevela/application.yaml` - Integrated with parameter passing

### Troubleshooting

**Issue:** Pods stuck in `Pending` with topology spread errors

**Solution:** Use `prod-local` instead of `prod` for local clusters:

```bash
cd kubevela-demo/kubevela
./fix-ha-local.sh  # Interactive troubleshooting tool
```

**Documentation:**
- `kubevela-demo/kubevela/HIGH_AVAILABILITY_TRAIT.md` - Complete guide (634 lines)
- `kubevela-demo/kubevela/HA_TRAIT_QUICKSTART.md` - Quick reference
- `kubevela-demo/kubevela/FIX_TOPOLOGY_ISSUE.md` - Topology troubleshooting

## Quick Reference

### File Locations

**Parameter Passing:**
- `kubevela-demo/kubevela/application.yaml` - Basic examples
- `kubevela-demo/kubevela/s3-bucket-app.yaml` - Advanced patterns
- `kubevela-crossplane-demo/apps/webservice-s3-app.yaml` - Complex workflows

**Observability:**
- `kubevela-demo/kubevela/OBSERVABILITY.md` - Complete guide
- `kubevela-demo/kubevela/setup-observability.sh` - Setup script
- `kubevela-demo/kubevela/kubevela-dashboard.json` - Platform dashboard
- `kubevela-demo/kubevela/s3-storage-app-dashboard.json` - App dashboard

**High-Availability:**
- `kubevela-demo/kubevela/HIGH_AVAILABILITY_TRAIT.md` - Complete guide
- `kubevela-demo/kubevela/high-availability-trait.cue` - Implementation
- `kubevela-demo/kubevela/high-availability-traitdef.yaml` - Trait definition
- `kubevela-demo/kubevela/deploy-ha-trait.sh` - Deployment script

### Common Commands

```bash
# Setup observability
cd kubevela-demo/kubevela && ./setup-observability.sh

# Deploy HA trait
cd kubevela-demo/kubevela && ./deploy-ha-trait.sh

# Check application status
vela status <app-name> -n <namespace>

# View application metrics
kubectl port-forward -n vela-system svc/kubevela-vela-core 8080:8080
curl http://localhost:8080/metrics | grep kubevela_application

# Test application with parameter passing
cd kubevela-demo/kubevela && vela up -f application.yaml
```

### Performance Metrics

**Code Reduction:**
- Traditional approach: 746 lines (Terraform + K8s + Dagger)
- KubeVela approach: 258 lines
- **Reduction: 65%**

**File Count:**
- Traditional: 15 files
- KubeVela: 3 files
- **Reduction: 83%**

**Environment Consistency:**
- Single application definition
- Policy-based overrides
- Unified workflow testing

## Additional Resources

- [Main README](README.md) - Repository overview
- [KubeVela Demo](kubevela-demo/README.md) - Complete demo guide
- [Component Contributor Demo](component-contributor-demo/README.md) - Setup guide
- [KubeVela Documentation](https://kubevela.io/)
- [DeepWiki AI Documentation](https://deepwiki.com/kubevela/kubevela)
