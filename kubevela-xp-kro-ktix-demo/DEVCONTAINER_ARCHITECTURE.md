# DevContainer Architecture Diagram

Visual representation of how the DevContainer connects to k3d running on the host.

## Network Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│ HOST MACHINE (Mac/Linux/Windows with Docker)                        │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │ Docker Desktop / Docker Engine                             │   │
│  │                                                            │   │
│  │  ┌──────────────────────────────────────────────────┐    │   │
│  │  │ k3d Cluster (Kubernetes in Docker)               │    │   │
│  │  │                                                  │    │   │
│  │  │  Container: k3d-kubevela-demo-server-0          │    │   │
│  │  │  API Server: 6443 (internal)                     │    │   │
│  │  │             ↓                                    │    │   │
│  │  │  Exposed on Host Port: 58991 (or random XXXXX) │    │   │
│  │  │                                                  │    │   │
│  │  │  Containers:                                    │    │   │
│  │  │  - KubeVela (vela-system namespace)             │    │   │
│  │  │  - Crossplane (crossplane-system namespace)     │    │   │
│  │  │  - KRO (kro-system namespace)                   │    │   │
│  │  │  - ACK DynamoDB (ack-system namespace)          │    │   │
│  │  │  - Demo Apps (default, production namespaces)   │    │   │
│  │  └──────────────────────────────────────────────────┘    │   │
│  │                                                            │   │
│  └────────────────────────────────────────────────────────────┘   │
│                           │                                        │
│                           │ Port Mapping                           │
│                           │ 6443 → 58991                           │
│                           │ (or other random port)                 │
│                           ↓                                        │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │ Docker Network: bridge                                     │   │
│  │  • 0.0.0.0:58991 (accessible from containers)            │   │
│  │  • host.docker.internal:58991 (from DevContainer)        │   │
│  └────────────────────────────────────────────────────────────┘   │
│           ↑                                                        │
│           │                                                        │
└─────────────────────────────────────────────────────────────────────┘
            │
            │ Network Bridge
            │
┌─────────────────────────────────────────────────────────────────────┐
│ DEVCONTAINER (Separate Docker Container)                            │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │ Development Environment                                   │    │
│  │                                                            │    │
│  │  • kubectl (uses kubeconfig-internal)                     │    │
│  │  • vela CLI                                               │    │
│  │  • docker CLI (Docker-in-Docker)                          │    │
│  │  • bash/zsh shell                                         │    │
│  │                                                            │    │
│  │  kubeconfig-internal:                                     │    │
│  │  ┌──────────────────────────────────────────────────┐    │    │
│  │  │ server: https://host.docker.internal:58991       │    │    │
│  │  │ insecure-skip-tls-verify: true                   │    │    │
│  │  │ client-certificate-data: [...k3d-generated...]   │    │    │
│  │  └──────────────────────────────────────────────────┘    │    │
│  │                                                            │    │
│  │  Commands:                                                │    │
│  │  $ KUBECONFIG=./kubeconfig-internal kubectl get nodes   │    │
│  │  $ KUBECONFIG=./kubeconfig-internal vela ls -A          │    │
│  │  $ KUBECONFIG=./kubeconfig-internal vela up -f app.yaml │    │
│  │                                                            │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Connection Flow

### Successful Connection Flow

```
DevContainer kubectl command
        ↓
KUBECONFIG=./kubeconfig-internal kubectl get nodes
        ↓
kubeconfig-internal reads:
  • server: https://host.docker.internal:58991
  • insecure-skip-tls-verify: true
  • client certificates
        ↓
kubectl resolves host.docker.internal → 127.0.0.1 (in container network)
        ↓
Connection to Docker bridge network
        ↓
Docker maps 127.0.0.1:58991 → host 0.0.0.0:58991
        ↓
Reaches k3d API server on host machine
        ↓
k3d API server responds
        ↓
Response flows back through the bridge
        ↓
kubectl displays results
```

## Port Mapping Diagram

```
Host Machine                  Docker Bridge            Container
═════════════════════════════════════════════════════════════════

k3d API Server
:6443 (internal)
        │
        └─→ Mapped to 58991
                │
        ┌───────┴───────┐
        │               │
   0.0.0.0:58991   bridge network:58991
   (host port)     (accessible to containers)
        │               │
        └───────┬───────┘
                │
     host.docker.internal:58991
        (from DevContainer's perspective)
                │
        DevContainer can now reach
        k3d API server on host machine
```

## Port Change Scenario

### Before Cluster Restart

```
kubeconfig-internal:
  server: https://host.docker.internal:58991

Actual k3d port: 58991

✅ Connection Works
```

### After Cluster Restart with setup.sh

```
kubeconfig-internal:
  server: https://host.docker.internal:58991  ← OLD (still has old port)

Actual k3d port: 61234                        ← NEW (k3d picked a different port)

❌ Connection Fails
   └─ kubectl tries 58991 but k3d is on 61234
```

### After Kubeconfig Update

```
kubeconfig-internal:
  server: https://host.docker.internal:61234  ← UPDATED (matches new port)

Actual k3d port: 61234

✅ Connection Works Again
```

## Why host.docker.internal?

Different approaches for different scenarios:

```
Development Environment | Solution | Why
═════════════════════════════════════════════════════════════════
Mac with Docker Desktop | host.docker.internal | Built-in Docker feature
Linux with Docker       | host.docker.internal | Requires --add-host flag
Windows with Docker     | host.docker.internal | Built-in Docker feature
Not in container        | localhost            | Direct local access
Not in container        | <IP>                 | Direct IP access
```

For DevContainer, `host.docker.internal` is the standard solution because:
- ✅ Works consistently across platforms
- ✅ Handles NAT and network translation automatically
- ✅ Doesn't require knowing the host's actual IP
- ✅ Built-in to Docker (no extra configuration)

## Kubeconfig Fields Explained

```yaml
---
apiVersion: v1

clusters:
- cluster:
    # ↓ Trust any certificate (k3d uses self-signed certs)
    insecure-skip-tls-verify: true

    # ↓ Host to reach k3d from DevContainer
    server: https://host.docker.internal:58991

  # ↓ Name of this cluster configuration
  name: k3d-kubevela-demo

contexts:
- context:
    cluster: k3d-kubevela-demo
    user: admin@k3d-kubevela-demo
  name: k3d-kubevela-demo

# ↓ Which context to use by default
current-context: k3d-kubevela-demo

kind: Config

users:
- name: admin@k3d-kubevela-demo
  user:
    # ↓ Client certificate (auth with k3d)
    client-certificate-data: LS0tLS1CRUdJTi...

    # ↓ Client key (auth with k3d)
    client-key-data: LS0tLS1CRUdJTi...
```

## Troubleshooting Decision Tree

```
Does kubectl work?
│
├─ YES → Everything is good! No action needed.
│
└─ NO
   │
   ├─ Is k3d running?
   │  │
   │  ├─ NO  → Run: ./setup.sh
   │  │
   │  └─ YES → Continue below
   │
   ├─ Can you see k3d ports?
   │  │
   │  ├─ NO  → Check Docker: docker ps | grep k3d
   │  │
   │  └─ YES → Get port: docker port k3d-kubevela-demo-server-0 | grep 6443
   │
   ├─ Does port in kubeconfig match actual port?
   │  │
   │  ├─ NO  → Update port in kubeconfig-internal
   │  │        Run: one-liner from KUBECONFIG_CHEATSHEET.md
   │  │
   │  └─ YES → Check kubeconfig syntax
   │           • insecure-skip-tls-verify: true present?
   │           • host.docker.internal in server line?
   │           • Valid YAML indentation?
   │
   └─ Still doesn't work?
      └─ Read DEVCONTAINER_KUBECONFIG_GUIDE.md (full troubleshooting)
```

## Summary

| Component | Role | Changes |
|-----------|------|---------|
| Host Machine | Runs Docker with k3d cluster | Port assignment changes |
| k3d API Server | Kubernetes API endpoint | Always on 6443 inside container |
| Host Port | External access point | Changes each cluster restart |
| kubeconfig-internal | Connection config for DevContainer | Must update port after restart |
| host.docker.internal | DNS resolution bridge | Never changes |
| insecure-skip-tls-verify | Trust k3d certificates | Never changes |

---

For quick fixes: [KUBECONFIG_CHEATSHEET.md](KUBECONFIG_CHEATSHEET.md)
For complete guide: [DEVCONTAINER_KUBECONFIG_GUIDE.md](DEVCONTAINER_KUBECONFIG_GUIDE.md)
