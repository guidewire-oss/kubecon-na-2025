# CLAUDE.md - KubeCon NA 2025 Project Instructions

This file provides guidance to Claude Code for the KubeCon NA 2025 project.

## MCP Server Usage

### DeepWiki MCP Server

Always use the deepwiki mcp server for any question related to KubeVela, Crossplane, Flux CD, Helm, Kustomize, OPA, Cue, KRO, ACK and any other github based Opensource projects.

**Repository Locations for DeepWiki:**
- KubeVela: `kubevela/kubevela`
- Crossplane: `crossplane/crossplane`
- Flux CD: `fluxcd/flux2`
- Helm: `helm/helm`
- Kustomize: `kubernetes-sigs/kustomize`
- OPA: `open-policy-agent/opa`
- Cue: `cue-lang/cue`
- KRO: `kubernetes-sigs/kro` (NOT awslabs/kro)
- ACK: `aws-controllers-k8s/community`

**When using DeepWiki MCP server to query about any codebase:**
- **ALWAYS request to examine actual code implementation, NOT documentation**
- Start queries with: "Looking at the actual code implementation..." or "By examining the code in the codebase..."
- Documentation can be outdated - the code is the source of truth
- Ask for exact property structures and definitions from the code
- Verify feature availability by checking code, not documentation

### Context7 MCP Server

Always use context7 when I need code generation, setup or configuration steps, or library/API documentation. This means you should automatically use the Context7 MCP tools to resolve library id and get library docs without me having to explicitly ask.
