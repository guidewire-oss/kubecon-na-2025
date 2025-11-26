# High Availability Trait - Quick Start

## Installation

```bash
./deploy-ha-trait.sh
```

## Quick Usage

### Single Line Configuration

```yaml
traits:
  - type: high-availability
    properties:
      level: prod  # or "dev" (default), "staging"
```

## Configuration Matrix

| Level | HPA | PDB | Topology Spread | Anti-Affinity |
|-------|-----|-----|----------------|---------------|
| **dev** | 1-2 replicas | ❌ No | ❌ No | ❌ No |
| **staging** | 1-3 replicas | ✅ min 50% | ❌ No | ✅ Preferred |
| **prod** | 3-6 replicas | ✅ max 2 down | ✅ 3 zones | ✅ Required |
| **prod-local** | 3-6 replicas | ✅ max 1 down | ❌ No | ✅ Preferred |

**Note:** Use `prod-local` for local development (k3d/kind/minikube) to get prod-like HA without topology spread constraints.

## Common Patterns

### Pattern 1: Simple Dev Deployment

```yaml
components:
  - name: api
    type: webservice
    properties:
      image: my-api:v1
    traits:
      - type: high-availability
        properties:
          level: dev
```

### Pattern 2: Multi-Environment with Override

```yaml
components:
  - name: api
    traits:
      - type: high-availability
        properties:
          level: dev  # Base

policies:
  - name: override-prod
    type: override
    properties:
      components:
        - name: api
          traits:
            - type: high-availability
              properties:
                level: prod  # Override
```

### Pattern 3: With S3 Storage App

```yaml
components:
  - name: storage-api
    type: webservice
    properties:
      image: k3d-registry.localhost:5000/kv-product-cat-api:v1.0.0
    traits:
      - type: high-availability
        properties:
          level: staging
      - type: resource
        properties:
          requests:
            cpu: "100m"
            memory: "128Mi"
```

## Verification Commands

```bash
# Check HPA
kubectl get hpa -n <namespace>

# Check PDB
kubectl get pdb -n <namespace>

# Check pod distribution
kubectl get pods -n <namespace> -o wide

# Check pod anti-affinity
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 10 affinity
```

## Troubleshooting

### HPA shows `<unknown>`
→ Install metrics-server or ensure resource requests are defined

### PDB blocks updates
→ Temporarily scale up: `kubectl scale deployment <name> --replicas=<more> -n <ns>`

### Pods stuck Pending (Topology Spread)
→ For local dev: Use `prod-local` instead of `prod`
→ Or run: `./fix-ha-local.sh` for guided fix
→ For real clusters: Ensure nodes have zone labels

## Files

- `high-availability-traitdef.yaml` - TraitDefinition
- `high-availability-trait.cue` - CUE template (standalone)
- `ha-example-app.yaml` - Example application
- `HIGH_AVAILABILITY_TRAIT.md` - Full documentation
- `deploy-ha-trait.sh` - Deployment script
