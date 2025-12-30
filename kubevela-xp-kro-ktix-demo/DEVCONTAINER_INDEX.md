# DevContainer Documentation Index

Complete guide to setting up, maintaining, and troubleshooting kubeconfig in a DevContainer environment.

## Quick Start (2 minutes)

**Just restarted the cluster and kubectl doesn't work?**

👉 Go to: **[KUBECONFIG_CHEATSHEET.md](KUBECONFIG_CHEATSHEET.md)**

Copy the one-liner and paste it. Done!

## Understanding the Setup (10 minutes)

**Want to understand how everything works?**

1. Read: **[DEVCONTAINER_ARCHITECTURE.md](DEVCONTAINER_ARCHITECTURE.md)** - Visual diagrams of how DevContainer connects to k3d
2. Read: **[DEVCONTAINER_SETUP_SUMMARY.md](DEVCONTAINER_SETUP_SUMMARY.md)** - Overview of the solution and workflow

## Complete Reference (30 minutes)

**Need comprehensive documentation for any situation?**

👉 Read: **[DEVCONTAINER_KUBECONFIG_GUIDE.md](DEVCONTAINER_KUBECONFIG_GUIDE.md)**

This covers:
- Why kubeconfig breaks
- All possible fixes
- Common errors and solutions
- Automation scripts
- When to reset everything

## The Problem in 30 Seconds

```
🏠 Host Machine: k3d cluster on random port XXXXX
🐳 DevContainer: Needs kubeconfig to reach k3d
🔄 After restart: Port changes → kubeconfig breaks → kubectl fails

Solution: Update one line in kubeconfig-internal with new port
```

## The Solution in 30 Seconds

```bash
# After running setup.sh, run this one-liner:
NEW_PORT=$(docker port k3d-kubevela-demo-server-0 | grep 6443 | awk '{print $3}' | cut -d: -f2) && \
sed -i "s|server: https://host.docker.internal:[0-9]*$|server: https://host.docker.internal:$NEW_PORT|" kubeconfig-internal && \
KUBECONFIG=./kubeconfig-internal kubectl get nodes
```

Done! Everything should work again.

## Document Purpose and Use Cases

| Document | Purpose | When to Read | Time |
|----------|---------|---|------|
| **This file** | Navigation guide | First time visiting | 2 min |
| **KUBECONFIG_CHEATSHEET.md** | Quick fixes | kubectl just broke | 2 min |
| **DEVCONTAINER_ARCHITECTURE.md** | How it works | Understanding the system | 10 min |
| **DEVCONTAINER_SETUP_SUMMARY.md** | Overview | Getting the big picture | 10 min |
| **DEVCONTAINER_KUBECONFIG_GUIDE.md** | Complete reference | Comprehensive understanding, troubleshooting | 30 min |
| **README.md** | Main documentation | Overall demo info | 20 min |
| **Troubleshooting section in README** | In-context help | Stuck in the main README | 5 min |

## Common Scenarios

### "I just ran setup.sh and kubectl doesn't work"

1. Check if cluster is running: `docker ps | grep k3d`
2. If running, go to: [KUBECONFIG_CHEATSHEET.md](KUBECONFIG_CHEATSHEET.md)
3. Copy the one-liner and run it
4. Test with: `KUBECONFIG=./kubeconfig-internal kubectl get nodes`

### "I want to understand how DevContainer connects to k3d"

1. Read: [DEVCONTAINER_ARCHITECTURE.md](DEVCONTAINER_ARCHITECTURE.md)
2. Look at the network diagram
3. Read the connection flow section

### "kubectl gives weird errors and I don't know why"

1. First, check: [KUBECONFIG_CHEATSHEET.md](KUBECONFIG_CHEATSHEET.md) - Common Issues table
2. If not there, read: [DEVCONTAINER_KUBECONFIG_GUIDE.md](DEVCONTAINER_KUBECONFIG_GUIDE.md) - Troubleshooting section
3. Follow the decision tree

### "I'm a DevContainer user and want to be prepared"

1. Read: [DEVCONTAINER_SETUP_SUMMARY.md](DEVCONTAINER_SETUP_SUMMARY.md) - Understand the workflow
2. Read: [DEVCONTAINER_ARCHITECTURE.md](DEVCONTAINER_ARCHITECTURE.md) - Understand the architecture
3. Bookmark: [KUBECONFIG_CHEATSHEET.md](KUBECONFIG_CHEATSHEET.md) - For when you need quick fixes

### "I want to automate the kubeconfig fix"

Read: [DEVCONTAINER_KUBECONFIG_GUIDE.md](DEVCONTAINER_KUBECONFIG_GUIDE.md) - Automation Script section

## Key Concepts

### host.docker.internal
- Special Docker hostname that resolves from container to host
- Works on Mac, Windows, and Linux (with proper Docker setup)
- Allows DevContainer to reach services on the host machine

### insecure-skip-tls-verify
- Needed because k3d uses self-signed certificates
- Safe in development environment
- Not recommended for production

### kubeconfig-internal
- Local kubeconfig file for this project
- Configured to use host.docker.internal
- Only the port number changes between cluster restarts
- Never needs to be regenerated from scratch (just update the port)

### Port Mapping
- k3d API runs on 6443 inside its container
- Docker maps this to a random host port (e.g., 58991)
- Each cluster restart gets a different random port
- kubeconfig needs the current port to work

## Quick Reference

```
Problem                    → Solution                          → Document
─────────────────────────────────────────────────────────────────────────
kubectl broken             → Update port number               → Cheatsheet
Don't understand why       → Read about architecture          → Architecture
Specific error message     → Find in troubleshooting table    → Guide
Want to understand setup   → Read overview                    → Summary
Need complete reference    → Read everything                  → Guide
Automating the fix         → Use script example               → Guide
Getting started            → Start here                       → This file
```

## File Locations

All DevContainer-related documentation is in the project root:

```
kubevela-xp-kro-ktix-demo/
├── DEVCONTAINER_INDEX.md              ← You are here
├── KUBECONFIG_CHEATSHEET.md           ← Quick fixes
├── DEVCONTAINER_ARCHITECTURE.md       ← Diagrams
├── DEVCONTAINER_SETUP_SUMMARY.md      ← Overview
├── DEVCONTAINER_KUBECONFIG_GUIDE.md   ← Complete guide
├── README.md                          ← Main docs
└── kubeconfig-internal                ← Configuration file (edit only the port)
```

## Maintenance Checklist

After each cluster restart with `setup.sh`:

- [ ] Run one-liner from KUBECONFIG_CHEATSHEET.md
- [ ] Verify: `KUBECONFIG=./kubeconfig-internal kubectl get nodes`
- [ ] Verify: `KUBECONFIG=./kubeconfig-internal vela ls -A`
- [ ] All applications healthy? Check with `vela ls -A`

## Tips for Success

1. **Bookmark the cheatsheet** - You'll use it frequently
2. **Save the one-liner** - Copy it to a notes file for quick access
3. **Create shell aliases** - From KUBECONFIG_CHEATSHEET.md under "Shell Aliases"
4. **Check cluster is running** - Before troubleshooting kubeconfig
5. **Always use full kubeconfig path** - Don't rely on KUBECONFIG in ~/.bashrc

## Getting Help

**Issue not covered?**

1. Check the decision trees in DEVCONTAINER_KUBECONFIG_GUIDE.md
2. Search through all documents for your error message
3. Check the main [README.md](README.md) troubleshooting section
4. Look at docker logs: `docker logs k3d-kubevela-demo-server-0`

## Summary

- ✅ One-liner in KUBECONFIG_CHEATSHEET.md fixes 90% of issues
- ✅ Architecture in DEVCONTAINER_ARCHITECTURE.md explains the why
- ✅ Guide in DEVCONTAINER_KUBECONFIG_GUIDE.md covers all edge cases
- ✅ Only the port number changes between cluster restarts
- ✅ Everything else stays the same

---

**Start with**: [KUBECONFIG_CHEATSHEET.md](KUBECONFIG_CHEATSHEET.md) if you need a quick fix

**Understand better**: [DEVCONTAINER_ARCHITECTURE.md](DEVCONTAINER_ARCHITECTURE.md) + [DEVCONTAINER_SETUP_SUMMARY.md](DEVCONTAINER_SETUP_SUMMARY.md)

**Detailed reference**: [DEVCONTAINER_KUBECONFIG_GUIDE.md](DEVCONTAINER_KUBECONFIG_GUIDE.md)

---

Last Updated: December 30, 2025
