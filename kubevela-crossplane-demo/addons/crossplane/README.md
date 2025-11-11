# Crossplane Addon for KubeVela

This addon installs Crossplane v2.0.2, an open source Kubernetes add-on that enables platform teams to assemble infrastructure from multiple vendors.

## Features
- Universal Control Plane for cloud APIs
- Extensible through Providers  
- Composition of infrastructure resources
- GitOps-friendly infrastructure management
- Includes all necessary CRDs

## Installation

```bash
vela addon enable crossplane-2
```

The addon automatically installs:
- Crossplane CRDs (CompositeResourceDefinitions, Compositions, Providers, Configurations, etc.)
- Crossplane core components (namespace, RBAC, deployment, webhooks)

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| namespace | string | crossplane-system | Namespace for Crossplane |
| replicas | int | 1 | Number of Crossplane replicas |
| image.repository | string | crossplane/crossplane | Crossplane container image repository |
| image.tag | string | v2.0.2 | Crossplane container image tag |
| image.pullPolicy | string | IfNotPresent | Image pull policy |
| resources.limits.cpu | string | 100m | CPU limit |
| resources.limits.memory | string | 512Mi | Memory limit |
| resources.requests.cpu | string | 100m | CPU request |
| resources.requests.memory | string | 256Mi | Memory request |
| webhooks.enabled | bool | false | Enable webhooks (requires TLS certificate setup) |

## Usage

After installation, you can install Crossplane providers:

```bash
kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws
spec:
  package: xpkg.upbound.io/upbound/provider-aws:v0.47.0
EOF
```

## Uninstall

```bash
vela addon disable crossplane-2
```