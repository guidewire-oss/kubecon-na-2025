# KubeCon North America 2025 Demos

This repository contains demos for KubeCon North America 2025 showcasing KubeVela, Crossplane, and OAM components.

## Demos

### 1. KubeVela Power Demo
**Location:** `kubevela-demo/`

Showcases KubeVela's unified application delivery model compared to traditional approaches using a real-world Product Catalog API with S3 integration. Demonstrates 83% fewer files and 65% less code compared to traditional Terraform + Kubernetes + Dagger approach.

**See:** [`kubevela-demo/README.md`](kubevela-demo/README.md) for complete documentation
- [`kubevela-demo/DEMO_PLAN.md`](kubevela-demo/DEMO_PLAN.md) - Demo plan and architecture
- [`kubevela-demo/COMPARISON.md`](kubevela-demo/COMPARISON.md) - Detailed comparison
- [`kubevela-demo/imperative/DEMO_STEPS.md`](kubevela-demo/imperative/DEMO_STEPS.md) - Traditional approach steps

**Advanced Features:**
- **[README_ADVANCED.md](README_ADVANCED.md)** - Parameter passing, observability, and high-availability traits guide

### 2. Component Contributor Demo
**Location:** `component-contributor-demo/`

Contains notebooks and scripts showcasing the component contributor model with Crossplane, KubeVela, and OAM. Also includes the k3d cluster setup used across all demos.

**See:** [`component-contributor-demo/README.md`](component-contributor-demo/README.md) for setup guide

### 3. KubeVela + Crossplane Demo
**Location:** `kubevela-crossplane-demo/`

**Status:** Work in Progress

**See:** [`kubevela-crossplane-demo/readme.md`](kubevela-crossplane-demo/readme.md) for current documentation

**Next Steps**
- Finish it and document it

## Quick Start

### Automated Complete Setup

Run the top-level setup script to configure everything automatically:

```bash
./setup.sh
```

This script will:
1. ✅ Check prerequisites (k3d, kubectl, helm, vela, docker, python)
2. ✅ Create k3d cluster with local registry
3. ✅ Install Crossplane and KubeVela
4. ✅ Deploy basic KubeVela demo application
5. ✅ Deploy advanced demo with parameter passing
6. ✅ Set up observability stack (Prometheus + Grafana)
7. ✅ Install HA trait and deploy sample application

**Time:** ~10-15 minutes

### Manual Setup (Advanced Users)

For step-by-step manual setup:

```bash
# 1. Setup cluster
cd component-contributor-demo
./setup.sh  # or use: jupyter notebook "00_Env-setup.ipynb"

# 2. Deploy basic demo
cd ../kubevela-demo/kubevela
vela up -f application.yaml

# 3. Setup observability
./setup-observability.sh

# 4. Deploy HA trait
./deploy-ha-trait.sh
```

### Run Demos
Once the environment is set up, explore the demos:
- **KubeVela Demo:** See `kubevela-demo/README.md`
- **Component Contributor Demo:** Run `component-contributor-demo/01_OAM-contrib.ipynb`
- **Advanced Features:** See `README_ADVANCED.md`

## Project Structure
```
kubecon-na-2025/
├── README.md                          # This file - repository overview
├── README_ADVANCED.md                 # Advanced features guide (parameter passing, observability, HA)
├── setup.sh                           # Dependency installation
├── component-contributor-demo/        # Component contributor demo + cluster setup
│   ├── 00_Env-setup.ipynb             # K3d cluster setup
│   └── README.md                      # Setup guide
├── kubevela-demo/                     # KubeVela power demo
│   ├── README.md                      # Main demo documentation
│   ├── DEMO_PLAN.md                   # Architecture and planning
│   ├── COMPARISON.md                  # Traditional vs KubeVela comparison
│   └── kubevela/                      # KubeVela implementation
│       ├── OBSERVABILITY.md           # Observability setup guide
│       ├── HIGH_AVAILABILITY_TRAIT.md # HA trait documentation
│       └── HA_TRAIT_QUICKSTART.md     # HA trait quick reference
└── kubevela-crossplane-demo/          # WIP: Advanced integration demo
    └── readme.md
```

## Additional Resources
- [KubeVela Documentation](https://kubevela.io/)
- [Crossplane Documentation](https://docs.crossplane.io/)
- [OAM Specification](https://oam.dev/)
- [Slack channel](https://cloud-native.slack.com/archives/C01BLQ3HTJA)
- [KubeVela Roadmap](https://github.com/kubevela/kubevela.github.io/blob/main/docs/roadmap/README.md)
- [DeepWiki MCP Server](https://docs.devin.ai/work-with-devin/deepwiki-mcp)
- [DeepWiki KubeVela AI Documentation and AI Chat](https://deepwiki.com/kubevela/kubevela)

## Claude Users

While we update the docs, I recommend adding the following to your `CLAUDE.md`. Feel free to help by submitting PRs for documentation or any other improvements.

https://docs.devin.ai/work-with-devin/deepwiki-mcp

```
- Use the DeepWiki MCP server for KubeVela questions
## DeepWiki MCP Server Usage (for KubeVela and other projects)

**When using DeepWiki MCP server to query about any codebase:**
- **ALWAYS request to examine actual code implementation, NOT documentation**
- Start queries with: "Looking at the actual code implementation..." or "By examining the code in the codebase..."
- Documentation can be outdated - the code is the source of truth
- Ask for exact property structures and definitions from the code
- Verify feature availability by checking code, not documentation
```