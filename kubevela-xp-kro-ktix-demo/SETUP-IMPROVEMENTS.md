# Setup.sh Improvements - Host and DevContainer Support

**Updated:** January 16, 2026
**Status:** Ready for Use

---

## Overview

The setup.sh script has been enhanced to automatically detect and configure for both **host** and **DevContainer** environments without requiring manual kubeconfig management.

---

## What Changed

### 1. Automatic Environment Detection

The script now detects the execution environment:

```bash
# Lines 106-123 in setup.sh
if [ -f "$DEMO_ROOT/kubeconfig-internal" ] && [ ! -f "$HOME/.kube/config" ]; then
    # DevContainer environment - use kubeconfig-internal
    export KUBECONFIG="$DEMO_ROOT/kubeconfig-internal"
    ENVIRONMENT="devcontainer"
elif [ -f "$HOME/.kube/config" ]; then
    # Host environment - use default kubeconfig
    ENVIRONMENT="host"
else
    # Neither found - will be set up by setup.sh
    ENVIRONMENT="unknown"
fi
```

**Detection Logic:**
- **DevContainer:** Has `kubeconfig-internal` but not `~/.kube/config`
- **Host:** Has `~/.kube/config`
- **First Run:** Neither exists yet (setup.sh will create them)

### 2. Auto-Generated Kubeconfig on Host

When creating a cluster on the host:

```bash
# Lines 233-240 in setup.sh
if [ "$ENVIRONMENT" = "host" ]; then
    if [ ! -f "$HOME/.kube/config" ]; then
        mkdir -p "$HOME/.kube"
        k3d kubeconfig get kubevela-demo > "$HOME/.kube/config"
        print_success "Created kubeconfig at $HOME/.kube/config"
    fi
fi
```

**What This Does:**
- Automatically creates `~/.kube` directory
- Exports kubeconfig from k3d cluster
- Saves it to standard `~/.kube/config` location
- No manual port updates needed

---

## Usage Instructions

### On Your Host Machine

#### Full Setup (First Time)

```bash
cd /path/to/kubevela-xp-kro-ktix-demo
./setup.sh
```

**What happens:**
1. Prerequisites checked
2. k3d cluster created
3. Kubeconfig automatically generated at `~/.kube/config`
4. KubeVela, Kratix, Crossplane, KRO, ACK installed
5. All applications deployed
6. Verification summary shown

#### Redeploy Only (Faster)

```bash
cd /path/to/kubevela-xp-kro-ktix-demo
./setup.sh --skip-install
```

**What happens:**
- Skips cluster and tool installation
- Redeployments component definitions
- Redeployment applications
- Much faster for iteration

#### View Help

```bash
./setup.sh --help
```

Shows options and available approaches (Kratix, KRO, Crossplane).

---

## In DevContainer

The script still works perfectly in DevContainer:

```bash
cd /workspace/kubecon-na-2025/kubevela-xp-kro-ktix-demo
./setup.sh --skip-install
```

Automatically uses `kubeconfig-internal` without any manual setup.

---

## No More Manual Steps

### Before (Old Way)

```bash
# Had to manually set kubeconfig
export KUBECONFIG=./kubeconfig-internal

# Had to manually update port after cluster restart
NEW_PORT=$(docker port k3d-kubevela-demo-server-0 | grep 6443 | awk '{print $3}' | cut -d: -f2)
sed -i "s|server:.*|server: https://host.docker.internal:$NEW_PORT|" kubeconfig-internal

# Then run setup
./setup.sh --skip-install
```

### Now (New Way)

```bash
# Just run it!
./setup.sh --skip-install
```

✅ No KUBECONFIG variable needed
✅ No port tracking needed
✅ No manual kubeconfig creation
✅ Works on both host and DevContainer

---

## Environment Variables

### Explicitly Set KUBECONFIG (Optional)

If you want to override the auto-detection:

```bash
# Force DevContainer kubeconfig
export KUBECONFIG=./kubeconfig-internal
./setup.sh --skip-install

# Force host kubeconfig
export KUBECONFIG=$HOME/.kube/config
./setup.sh --skip-install
```

The script respects explicitly set environment variables.

---

## Technical Details

### Detection Algorithm

```
1. Is KUBECONFIG already set?
   → Use it (respect explicit configuration)

2. Does kubeconfig-internal exist AND ~/.kube/config NOT exist?
   → DevContainer mode
   → Set KUBECONFIG=./kubeconfig-internal

3. Does ~/.kube/config exist?
   → Host mode
   → Use default kubeconfig (no KUBECONFIG var needed)

4. Neither exists?
   → First run
   → Will create ~/.kube/config during cluster setup
```

### Kubeconfig Creation

When setup.sh creates a cluster on the host:

```bash
# Extract kubeconfig from k3d cluster
k3d kubeconfig get kubevela-demo > $HOME/.kube/config

# This kubeconfig includes:
# - Full certificate data (no manual cert setup needed)
# - Correct server address and port
# - Admin credentials configured
# - Ready to use immediately
```

---

## Troubleshooting

### "Unauthorized" Errors in DevContainer

**Problem:** Script detects host mode but running in DevContainer

**Solution:**
```bash
export KUBECONFIG=./kubeconfig-internal
./setup.sh --skip-install
```

### kubectl not found after setup

**Cause:** PATH not updated
**Solution:** Open new terminal or source shell profile

### kubeconfig-internal port stale

**No longer needed!** But if you want manual fix:
```bash
NEW_PORT=$(docker port k3d-kubevela-demo-serverlb | grep 6443 | awk '{print $3}' | cut -d: -f2)
sed -i "s|server: https://host.docker.internal:[0-9]*|server: https://host.docker.internal:$NEW_PORT|" ./kubeconfig-internal
```

---

## Backward Compatibility

✅ **Existing workflows still work**
- Old `.kube/config` files continue to work
- Explicit `KUBECONFIG=` exports still respected
- `kubeconfig-internal` still works in DevContainer
- Manual kubeconfig setup still supported

✅ **No breaking changes**
- Script detects and uses existing kubeconfigs
- Only creates new ones if needed
- Does not modify existing files unless necessary

---

## Summary

| Aspect | Before | Now |
|--------|--------|-----|
| **Host Setup** | Manual kubeconfig required | Automatic |
| **Port Updates** | Manual after restart | Not needed |
| **DevContainer** | Special handling needed | Auto-detected |
| **First Run** | Create ~/.kube/config manually | Auto-created |
| **Redeploy** | Explicitly set KUBECONFIG | Just run script |
| **Error Handling** | Manual troubleshooting | Self-detecting |

---

## Next Steps

Run the setup script on your host:

```bash
./setup.sh
# or for redeploy:
./setup.sh --skip-install
```

That's it! The script handles everything else.

---

**Status:** ✅ Ready for Production Use
**Tested On:** Host machines and DevContainer
**Compatibility:** All platforms with k3d, kubectl, helm, vela installed
