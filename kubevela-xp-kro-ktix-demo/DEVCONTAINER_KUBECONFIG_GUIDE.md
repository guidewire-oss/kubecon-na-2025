# DevContainer Kubeconfig Setup and Troubleshooting Guide

This guide explains how to properly configure and fix kubeconfig connectivity when running this demo in a DevContainer environment with k3d on the host machine.

## Why This Guide?

When using a DevContainer:
- The k3d cluster runs on the **host machine** (Docker Desktop, Linux with Docker, etc.)
- The DevContainer runs **inside Docker** as a separate container
- kubectl commands from the DevContainer need to reach the k3d API server on the host
- Each time you restart k3d (with `setup.sh`), the API server port changes

This guide covers the quick fix and explains the underlying concepts.

## Quick Fix: Update kubeconfig-internal Port

### When to use this

After running `./setup.sh` and kubectl stops working with connection errors like:
```
error: Unable to connect to the server: dial tcp [::1]:8080: connect: connection refused
```

### The Fix (30 seconds)

**Step 1**: Find the new k3d API server port
```bash
docker port k3d-kubevela-demo-server-0 | grep 6443
```

Output: `6443/tcp -> 0.0.0.0:58991` (your port may be different)

**Step 2**: Edit `kubeconfig-internal` and update the port in this line:
```yaml
server: https://host.docker.internal:58991  # ← Replace 58991 with your new port
```

**Step 3**: Verify it works
```bash
KUBECONFIG=/workspaces/workspace/kubecon-na-2025/kubevela-xp-kro-ktix-demo/kubeconfig-internal kubectl get nodes
```

That's it!

## Understanding the kubeconfig-internal File

### File Location
```
kubeconfig-internal
```

This file is **local to this project directory** and configures kubectl to connect to your k3d cluster running on the host.

### Key Fields Explained

```yaml
---
apiVersion: v1
clusters:
- cluster:
    insecure-skip-tls-verify: true           # ← Trust any certificate
    server: https://host.docker.internal:58991 # ← DevContainer→Host connection
  name: k3d-kubevela-demo
contexts:
- context:
    cluster: k3d-kubevela-demo
    user: admin@k3d-kubevela-demo
  name: k3d-kubevela-demo
current-context: k3d-kubevela-demo
kind: Config
users:
- name: admin@k3d-kubevela-demo
  user:
    client-certificate-data: ...  # ← Don't change these
    client-key-data: ...          # ← They work between k3d and DevContainer
```

### Why These Specific Values?

| Field | Value | Why |
|-------|-------|-----|
| `insecure-skip-tls-verify` | `true` | k3d uses self-signed certificates; we trust the connection |
| `server` | `https://host.docker.internal:XXXX` | Special hostname that resolves from DevContainer to host machine |
| `client-certificate-data` | (k3d-generated) | Internal k3d auth; don't change these |
| Port (XXXX) | Changes on restart | k3d picks a random high port each time; **this is what you update** |

## Automation Script (Optional)

If you want to automate the port update, create this script:

```bash
#!/bin/bash
# File: fix-kubeconfig.sh

# Get the new port
NEW_PORT=$(docker port k3d-kubevela-demo-server-0 | grep 6443 | awk '{print $3}' | cut -d: -f2)

if [ -z "$NEW_PORT" ]; then
    echo "Error: Could not find k3d API server port"
    echo "Is the cluster running? Check with: docker ps | grep k3d"
    exit 1
fi

echo "Updating kubeconfig-internal to use port $NEW_PORT..."

# Update the kubeconfig file
sed -i "s|server: https://host.docker.internal:[0-9]*$|server: https://host.docker.internal:$NEW_PORT|" kubeconfig-internal

# Verify
KUBECONFIG=./kubeconfig-internal kubectl get nodes && echo "✅ Kubeconfig updated successfully!" || echo "❌ Failed to connect"
```

Usage:
```bash
chmod +x fix-kubeconfig.sh
./fix-kubeconfig.sh
```

## Troubleshooting Specific Errors

### Error: `dial tcp [::1]:8080: connect: connection refused`

**Cause**: kubectl is trying to connect to localhost (IPv6) instead of the host machine.

**Fix**:
1. Verify port with: `docker port k3d-kubevela-demo-server-0 | grep 6443`
2. Update `kubeconfig-internal` with the correct port
3. Ensure `server:` line has `host.docker.internal`

**Verify**:
```bash
KUBECONFIG=./kubeconfig-internal kubectl cluster-info
```

### Error: `certificate signed by unknown authority`

**Cause**: kubeconfig is trying to verify the k3d certificate.

**Fix**: Ensure `insecure-skip-tls-verify: true` is in the `cluster:` section:

```yaml
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://host.docker.internal:58991
```

### Error: `dial tcp: lookup host.docker.internal: no such host`

**Cause**: You're not in a DevContainer, or Docker isn't configured to support `host.docker.internal`.

**Options**:
- If on Mac/Windows with Docker Desktop: Already supported (no fix needed)
- If on Linux: May need to add `--add-host=host.docker.internal:host-gateway` to docker run
- If not in DevContainer: Use `localhost` instead of `host.docker.internal`

**Manual fix for kubeconfig**:
```yaml
server: https://localhost:58991  # ← Replace host.docker.internal with localhost
```

### Error: `connection refused` after a long timeout

**Cause**: The port number is wrong (k3d not running on that port).

**Fix**:
1. Check if cluster is running: `docker ps | grep k3d`
2. Get actual port: `docker port k3d-kubevela-demo-server-0 | grep 6443`
3. Update kubeconfig with correct port

## Complete Setup Process

If something is really broken and you need to start fresh:

### Option 1: Manual Regeneration

```bash
# Get fresh kubeconfig from k3d
k3d kubeconfig get kubevela-demo > kubeconfig-internal-fresh

# Customize for DevContainer
cat > kubeconfig-internal-fresh.sed << 'EOF'
s/0\.0\.0\.0/host.docker.internal/g
/server: https/a\    insecure-skip-tls-verify: true
EOF

sed -i -f kubeconfig-internal-fresh.sed kubeconfig-internal-fresh

# Use the new config
mv kubeconfig-internal-fresh kubeconfig-internal

# Test it
KUBECONFIG=./kubeconfig-internal kubectl get nodes
```

### Option 2: Start Over

```bash
# Delete everything and restart
k3d cluster delete kubevela-demo
./setup.sh
```

The `setup.sh` script will automatically create a new `kubeconfig-internal` configured for DevContainer use.

## How setup.sh Handles Kubeconfig

The `setup.sh` script:
1. Creates/recreates the k3d cluster with a random API port
2. Exports kubeconfig from k3d
3. Modifies it to use `host.docker.internal`
4. Adds `insecure-skip-tls-verify: true`
5. Saves it to `kubeconfig-internal`

If you need to understand this process, search for `kubeconfig` in `setup.sh`.

## Tips for Success

1. **Always use the full path** when specifying kubeconfig:
   ```bash
   # Good
   KUBECONFIG=/workspaces/workspace/kubecon-na-2025/kubevela-xp-kro-ktix-demo/kubeconfig-internal vela status

   # Bad (may use system kubeconfig instead)
   KUBECONFIG=./kubeconfig-internal vela status
   ```

2. **Don't edit the user/auth sections**: Only change the `server:` line and add `insecure-skip-tls-verify: true`

3. **Check the port frequently**: When in doubt, always run:
   ```bash
   docker port k3d-kubevela-demo-server-0 | grep 6443
   ```

4. **Create an alias for convenience**:
   ```bash
   alias vela-internal='KUBECONFIG=/workspaces/workspace/kubecon-na-2025/kubevela-xp-kro-ktix-demo/kubeconfig-internal vela'
   alias kubectl-internal='KUBECONFIG=/workspaces/workspace/kubecon-na-2025/kubevela-xp-kro-ktix-demo/kubeconfig-internal kubectl'
   ```

## References

- [k3d Documentation](https://k3d.io/)
- [kubectl kubeconfig Documentation](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/)
- [Docker host.docker.internal](https://docs.docker.com/desktop/networking/#host-internal-networking)

## Questions?

If you encounter issues not covered here:
1. Check `docker ps` - verify k3d container is running
2. Check `docker logs k3d-kubevela-demo-server-0` - k3d logs
3. Verify the port: `docker port k3d-kubevela-demo-server-0`
4. Review the kubeconfig file for syntax errors (YAML indentation is critical!)
