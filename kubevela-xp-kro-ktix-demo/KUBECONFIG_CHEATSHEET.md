# Kubeconfig Cheatsheet for DevContainer Users

Quick reference for common kubeconfig operations in a DevContainer environment.

## The One-Liner (Copy & Paste This)

After running `setup.sh`, if kubectl stops working:

```bash
NEW_PORT=$(docker port k3d-kubevela-demo-server-0 | grep 6443 | awk '{print $3}' | cut -d: -f2) && \
sed -i "s|server: https://host.docker.internal:[0-9]*$|server: https://host.docker.internal:$NEW_PORT|" kubeconfig-internal && \
echo "✅ Updated kubeconfig to use port $NEW_PORT" && \
KUBECONFIG=./kubeconfig-internal kubectl get nodes
```

## Step-by-Step Manual Fix (3 Steps)

### 1. Find the new port
```bash
docker port k3d-kubevela-demo-server-0 | grep 6443
```

Example output: `6443/tcp -> 0.0.0.0:58991`
→ **Your port is: 58991**

### 2. Edit kubeconfig-internal
Update the `server:` line to use the new port:

```yaml
server: https://host.docker.internal:58991  # ← Replace 58991 with your actual port
```

### 3. Test connectivity
```bash
KUBECONFIG=./kubeconfig-internal kubectl get nodes
```

Success output:
```
NAME                     STATUS   ROLES          AGE   VERSION
k3d-kubevela-demo-server-0   Ready    control-plane  2d    v1.28.0+k3s1
k3d-kubevela-demo-agent-0    Ready    <none>         2d    v1.28.0+k3s1
k3d-kubevela-demo-agent-1    Ready    <none>         2d    v1.28.0+k3s1
```

## Using VelaUX and Vela CLI

After fixing kubeconfig, also update these commands:

### Check cluster status
```bash
KUBECONFIG=./kubeconfig-internal vela status <app-name>
```

### List all applications
```bash
KUBECONFIG=./kubeconfig-internal vela ls -A
```

### Deploy an application
```bash
KUBECONFIG=./kubeconfig-internal vela up -f definitions/examples/my-app.yaml
```

## Shell Aliases (Optional Setup)

Add these to your `.bashrc` or `.zshrc` for easier typing:

```bash
# Aliases for this project
alias k-internal='KUBECONFIG=/workspaces/workspace/kubecon-na-2025/kubevela-xp-kro-ktix-demo/kubeconfig-internal kubectl'
alias v-internal='KUBECONFIG=/workspaces/workspace/kubecon-na-2025/kubevela-xp-kro-ktix-demo/kubeconfig-internal vela'

# Then use like:
# k-internal get nodes
# v-internal ls -A
# v-internal status my-app
```

## Common Issues & Fixes

| Problem | Check | Fix |
|---------|-------|-----|
| `connection refused` | `docker ps \| grep k3d` | Start cluster: `./setup.sh` |
| `dial tcp [::1]:8080` | Port in kubeconfig | Update port (see above) |
| `certificate signed by unknown authority` | kubeconfig clusters section | Add `insecure-skip-tls-verify: true` |
| `lookup host.docker.internal: no such host` | Running in DevContainer? | Use `localhost` if not in DevContainer |

## Cluster Healthcheck

```bash
# Everything at once
KUBECONFIG=./kubeconfig-internal kubectl cluster-info && \
KUBECONFIG=./kubeconfig-internal kubectl get nodes && \
KUBECONFIG=./kubeconfig-internal vela ls -A
```

## After Getting It Working

Save these commands for later:

```bash
# Get the port (in case you need it later)
docker port k3d-kubevela-demo-server-0 | grep 6443

# Check kubeconfig is correct
grep "server:" kubeconfig-internal

# Verify connectivity
KUBECONFIG=./kubeconfig-internal kubectl get nodes --no-headers | wc -l
# Should output: 3 (for 1 server + 2 agents)
```

## Reset Everything (Nuclear Option)

If something is seriously broken:

```bash
# Delete the cluster
k3d cluster delete kubevela-demo

# Delete local kubeconfig
rm kubeconfig-internal

# Start fresh
./setup.sh

# Wait 2-3 minutes for everything to stabilize
sleep 180

# Verify it works
KUBECONFIG=./kubeconfig-internal vela ls -A
```

## Full Guide

For detailed explanations and troubleshooting, see: **[DEVCONTAINER_KUBECONFIG_GUIDE.md](DEVCONTAINER_KUBECONFIG_GUIDE.md)**
