# KubeCon NA 2025 Demo - Setup Guide

This directory contains notebooks and scripts for the KubeCon NA 2025 demo showcasing Crossplane, KubeVela, and OAM components.

## Quick Start

1. **Setup Environment** - Run `00_Env-setup.ipynb`
2. **OAM Contribution Demo** - Run `01_OAM-contrib.ipynb`
3. **Cleanup OAM Demo** - Run `01-OAM-cleanup.ipynb`
4. **Cleanup Environment** - Run `00-Env-cleanup.ipynb`

## Files Overview

### Notebooks
- **`00_Env-setup.ipynb`** - Complete environment setup (k3d, Crossplane, KubeVela, AWS provider)
- **`01_OAM-contrib.ipynb`** - Simplified DynamoDB OAM component contribution workflow
- **`01-OAM-cleanup.ipynb`** - Cleanup for OAM demo resources
- **`00-Env-cleanup.ipynb`** - Complete environment teardown

### Configuration Files
- **`config.yaml`** - Cluster and component configuration
- **`.env.aws`** - AWS credentials (you must create this)
- **`.env.sh`** - Auto-generated environment variables

## AWS Credentials

AWS credentials are required for Crossplane to provision resources. The `00_Env-setup.ipynb` notebook handles credential configuration automatically.

## Prerequisites

### Required Tools
- **k3d** - Lightweight Kubernetes: https://k3d.io/
- **kubectl** - Kubernetes CLI: https://kubernetes.io/docs/tasks/tools/
- **helm** - Kubernetes package manager: https://helm.sh/docs/intro/install/
- **Python 3.x** - With pip
- **vela CLI** - For ComponentDefinition management: https://kubevela.io/docs/installation/standalone

## Setup Steps

### 1. Install Prerequisites

```bash
# Install k3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Install kubectl
# See: https://kubernetes.io/docs/tasks/tools/

# Install helm
# See: https://helm.sh/docs/intro/install/

# Install vela CLI (optional)
curl -fsSl https://kubevela.io/script/install.sh | bash
```

### 2. Run Setup Notebook

Open and run `00_Env-setup.ipynb` in Jupyter:

```bash
jupyter notebook "00_Env-setup.ipynb"
```

Or use the VS Code Jupyter extension.

## Troubleshooting

### AWS Provider Issues

**Problem:** Provider not installing
```bash
kubectl get providers
kubectl describe provider provider-aws-dynamodb
```

**Problem:** Credentials not working
```bash
kubectl get secret aws-credentials -n crossplane-system -o yaml
kubectl get providerconfig default -o yaml
```

**Problem:** DynamoDB table not creating
```bash
kubectl get table -A
kubectl describe table <table-name>
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-aws-dynamodb
```

### General Issues

**Problem:** Ports already in use
- Change ports in `config.yaml`
- Or stop services using ports 6443, 8090

**Problem:** kubectl context not switching
- Manually switch: `kubectl config use-context k3d-kubecon-demo`

**Problem:** CRDs not appearing
- Wait longer (can take 1-2 minutes)
- Check Crossplane logs: `kubectl logs -n crossplane-system -l app=crossplane`

## Cleanup

### Quick Cleanup (OAM Demo Only)
```bash
jupyter notebook "01-OAM-cleanup.ipynb"
```

### Complete Cleanup (Everything)
```bash
jupyter notebook "00-Env-cleanup.ipynb"
# OR manually
k3d cluster delete kubecon-demo
```

## Architecture

```
┌─────────────────────────────────────────────────┐
│  KubeVela Applications (OAM)                    │
├─────────────────────────────────────────────────┤
│  ComponentDefinitions (CUE)                     │
├─────────────────────────────────────────────────┤
│  Crossplane Composite Resources (XRD)           │
├─────────────────────────────────────────────────┤
│  Crossplane Compositions                        │
├─────────────────────────────────────────────────┤
│  Crossplane AWS Provider                        │
├─────────────────────────────────────────────────┤
│  AWS DynamoDB (via provider-aws-dynamodb)       │
└─────────────────────────────────────────────────┘
```

## Security Best Practices

1. Never commit credentials to git
2. Use IAM roles in production
3. Rotate credentials regularly
4. Use least-privilege IAM policies

## Additional Resources

- [Crossplane Documentation](https://docs.crossplane.io/)
- [KubeVela Documentation](https://kubevela.io/)
- [OAM Specification](https://oam.dev/)
- [k3d Documentation](https://k3d.io/)
- [AWS Provider Documentation](https://marketplace.upbound.io/providers/upbound/provider-aws/)

## License

This demo is for educational purposes.
