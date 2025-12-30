# DevContainer Setup - Complete Summary

This document summarizes the complete process for setting up and maintaining the KubeVela DynamoDB demo in a DevContainer environment with k3d running on the host machine.

## Problem Statement

When running this demo in a DevContainer:
- The k3d Kubernetes cluster runs on the **host machine** (Docker Desktop, Linux, etc.)
- The DevContainer runs **inside Docker** as a separate container
- Each time you restart the cluster, k3d assigns a **new random API server port**
- The kubeconfig file (`kubeconfig-internal`) becomes outdated and needs updating
- kubectl commands fail with connection errors until the port is updated

## Solution Overview

The solution involves three key components:

1. **kubeconfig-internal** - A local kubeconfig file configured for DevContainer→Host connectivity
2. **Host-internal resolution** - Uses `host.docker.internal` as the hostname (special Docker feature)
3. **Insecure TLS mode** - Skips certificate verification for k3d's self-signed certificates

## The Fix (After Each Cluster Restart)

### Quick Version (Copy & Paste)

```bash
# Find new port and update kubeconfig in one command
NEW_PORT=$(docker port k3d-kubevela-demo-server-0 | grep 6443 | awk '{print $3}' | cut -d: -f2) && \
sed -i "s|server: https://host.docker.internal:[0-9]*$|server: https://host.docker.internal:$NEW_PORT|" kubeconfig-internal && \
echo "✅ Updated to port $NEW_PORT" && \
KUBECONFIG=./kubeconfig-internal kubectl get nodes
```

### Manual Version (3 Steps)

**Step 1**: Find the new port
```bash
docker port k3d-kubevela-demo-server-0 | grep 6443
# Output: 6443/tcp -> 0.0.0.0:58991
# Your port: 58991 (may be different)
```

**Step 2**: Edit `kubeconfig-internal`
```yaml
server: https://host.docker.internal:58991  # ← Update the port number only
```

**Step 3**: Verify
```bash
KUBECONFIG=./kubeconfig-internal kubectl get nodes
```

## How kubeconfig-internal Works

### File Structure

```yaml
clusters:
- cluster:
    insecure-skip-tls-verify: true           # Required for k3d self-signed certs
    server: https://host.docker.internal:58991 # DevContainer→Host connection
  name: k3d-kubevela-demo
```

### Key Configuration Details

| Component | Setting | Why |
|-----------|---------|-----|
| **Hostname** | `host.docker.internal` | Special Docker hostname that resolves from container to host |
| **Port** | `XXXXX` (5-digit number) | Changes on each cluster restart; this is what you update |
| **TLS Verification** | `insecure-skip-tls-verify: true` | k3d uses self-signed certificates |
| **Certificates** | (don't change) | Internal k3d auth credentials; work across container boundary |

## Documentation Structure

### For Quick Fixes
1. **[KUBECONFIG_CHEATSHEET.md](KUBECONFIG_CHEATSHEET.md)** ← **START HERE**
   - 30-second one-liner
   - 3-step manual fix
   - Common issues table
   - Shell aliases for convenience

### For Complete Understanding
2. **[DEVCONTAINER_KUBECONFIG_GUIDE.md](DEVCONTAINER_KUBECONFIG_GUIDE.md)** ← **READ THIS**
   - Complete troubleshooting guide
   - Why each setting matters
   - Automation script example
   - Detailed error explanations
   - Alternative approaches

### For Reference
3. **This document** - Summary and architecture overview

## Automation (Optional)

If you want to automate the fix, save this script as `fix-kubeconfig.sh`:

```bash
#!/bin/bash
NEW_PORT=$(docker port k3d-kubevela-demo-server-0 | grep 6443 | awk '{print $3}' | cut -d: -f2)
if [ -z "$NEW_PORT" ]; then
    echo "❌ Error: Cluster not running"
    exit 1
fi
sed -i "s|server: https://host.docker.internal:[0-9]*$|server: https://host.docker.internal:$NEW_PORT|" kubeconfig-internal
KUBECONFIG=./kubeconfig-internal kubectl get nodes && echo "✅ Updated to port $NEW_PORT" || echo "❌ Failed"
```

Then run: `chmod +x fix-kubeconfig.sh && ./fix-kubeconfig.sh`

## Workflow After setup.sh

```
1. Run setup.sh
   ↓
2. k3d creates cluster with random port (e.g., 58991)
   ↓
3. setup.sh creates kubeconfig-internal with that port
   ↓
4. Everything works!
   ↓
5. [days later] Run setup.sh again to recreate cluster
   ↓
6. k3d creates cluster with NEW random port (e.g., 61234)
   ↓
7. Old kubeconfig-internal still has port 58991 → kubectl breaks
   ↓
8. Run one-liner to update port to 61234
   ↓
9. Everything works again!
```

## Why This Matters

### Without kubeconfig Fix
- `kubectl get nodes` → Connection refused
- `vela ls` → Connection refused
- `vela up` → Connection refused
- All K8s operations fail

### With kubeconfig Fix
- All commands work
- Cluster is fully accessible
- Applications can be deployed
- Status can be checked

## Common Mistakes (and How to Avoid Them)

| Mistake | Problem | Fix |
|---------|---------|-----|
| Using `localhost` instead of `host.docker.internal` | Name resolution fails in DevContainer | Use `host.docker.internal` (Docker feature) |
| Removing `insecure-skip-tls-verify: true` | Certificate validation fails | Keep it in the config |
| Updating client certificates | Authentication breaks | Only update the `server:` line and port |
| Forgetting to use full kubeconfig path | Uses system kubeconfig instead | Always: `KUBECONFIG=./kubeconfig-internal kubectl ...` |
| Editing wrong kubeconfig | Changes don't take effect | Verify you're editing the local `kubeconfig-internal` |

## Troubleshooting Decision Tree

```
kubectl doesn't work?
├─ Is the cluster running?
│  └─ docker ps | grep k3d
│     ├─ No → Run ./setup.sh
│     └─ Yes → Continue below
├─ Is kubeconfig-internal readable?
│  └─ ls -la kubeconfig-internal
│     ├─ No → Check file permissions
│     └─ Yes → Continue below
├─ Is the port correct?
│  └─ docker port k3d-kubevela-demo-server-0 | grep 6443
│     ├─ Port different from kubeconfig → Update port
│     └─ Port matches kubeconfig → Continue below
└─ Check kubeconfig syntax
   └─ grep "insecure-skip-tls-verify" kubeconfig-internal
      ├─ Not found → Add it
      └─ Found → See DEVCONTAINER_KUBECONFIG_GUIDE.md
```

## Next Steps

1. **First Time Setup**
   - Run `./setup.sh`
   - Verify with: `KUBECONFIG=./kubeconfig-internal kubectl get nodes`

2. **After Cluster Restart**
   - Use the one-liner from KUBECONFIG_CHEATSHEET.md
   - Or follow the 3-step manual process

3. **Stuck?**
   - Read KUBECONFIG_CHEATSHEET.md (quick reference)
   - Read DEVCONTAINER_KUBECONFIG_GUIDE.md (complete guide)
   - Check the troubleshooting section below

## Key Takeaways

- ✅ Only the **port number** changes between cluster restarts
- ✅ Use the **one-liner** for automatic fix
- ✅ Use **`host.docker.internal`** (DevContainer magic)
- ✅ Keep **`insecure-skip-tls-verify: true`** (k3d requirement)
- ✅ Always use **full kubeconfig path** with `KUBECONFIG=./kubeconfig-internal`

## Additional Resources

- [Docker host.docker.internal documentation](https://docs.docker.com/desktop/networking/#host-internal-networking)
- [k3d documentation](https://k3d.io/usage/kubeconfig/)
- [kubectl kubeconfig docs](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/)

## Quick Links

- 🚀 **Quick Fix**: [KUBECONFIG_CHEATSHEET.md](KUBECONFIG_CHEATSHEET.md)
- 📖 **Full Guide**: [DEVCONTAINER_KUBECONFIG_GUIDE.md](DEVCONTAINER_KUBECONFIG_GUIDE.md)
- 🏠 **Main README**: [README.md](README.md)

---

**Last Updated**: December 30, 2025
**Tested With**: DevContainer, k3d, Docker Desktop
**Status**: Production-tested procedure
