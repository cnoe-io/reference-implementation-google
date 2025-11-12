# Task Usage Guidelines

This document gives an overview of the tasks defined in the Taskfile.yml.

## Available Tasks

```bash
task init          # Initialize and validate configuration
task install       # Full installation (creates Kind cluster and deploys)
task apply         # Apply configuration to existing Kind cluster
task sync          # Deploy/update components (equivalent to helmfile sync)
task diff          # Show pending changes
task uninstall     # Remove all components and clean up

# Utility tasks:
task get:urls      # Get service URLs from AKS cluster
task config:lint   # Validate configuration files

# Kind cluster management:
task kind:create   # Create local Kind cluster
task kind:delete   # Delete local Kind cluster

# Kubeconfig management:
task kubeconfig:set-context:gke   # Set kubectl context to GKE cluster
task kubeconfig:set-context:kind  # Set kubectl context to Kind cluster

# Helmfile operations:
task helmfile:init     # Initialize Helmfile
task helmfile:lint     # Validate Helmfile configuration
task helmfile:diff     # Show Helmfile differences
task helmfile:apply    # Apply Helmfile configuration
task helmfile:sync     # Sync Helmfile releases
task helmfile:destroy  # Destroy Helmfile releases
```

> **Note**: Tasks may update the `config.yaml` file during execution

## Installation Flow

The installation process uses a **local Kind cluster** as a bootstrap environment:

1. **`task init`** - Validates configuration and initializes Helmfile
2. **`task install`** - Creates Kind cluster and applies configuration
3. **Monitor** - Use local URLs (`argocd.local.<domain>`, `crossplane.local.<domain>`) to observe installation progress
4. **Access** - Once complete, use `task get:urls` to get AKS cluster service URLs

## Production vs Bootstrap Tasks

**Bootstrap Tasks** (use local Kind cluster):

```bash
task install       # Full installation using Kind cluster
task apply         # Apply to existing Kind cluster
task sync          # Update components via Helmfile
task diff          # Show pending changes
task uninstall     # Clean removal of all resources
```

**Utility Tasks** (interact with GKE cluster):

```bash
task get:urls      # Get service URLs from target GKE cluster
task kubeconfig:set-context:gke  # Switch to GKE cluster context
```

**Configuration Tasks**:

```bash
task init          # Initialize and validate all configuration
task config:lint   # Validate config.yaml and azure-credentials.json
```

## `task install` vs `task apply` vs `task sync`

- **`task install`** - Complete installation including Kind cluster creation and full deployment
- **`task apply`** - Apply configuration to existing Kind cluster (skips cluster creation)
- **`task sync`** - Updates existing installation (equivalent to `helmfile sync`)

Use `task sync` for updates after the initial installation, not `task install`.

## Configuration Requirements

The installation requires configuration files:

1. **`config.yaml`** - Main configuration (copy from `config.template.yaml`)
2. **GCP service account credentials** - Set up via gcloud CLI or service account key file

Configuration is validated automatically during `task init` and `task config:lint`.

## Monitoring Installation Progress

During installation, monitor progress using local Kind cluster services:

```bash
# Access local ArgoCD dashboard
# Navigate to: http://argocd.local.<your-domain>

# Access local Crossplane dashboard
# Navigate to: http://crossplane.local.<your-domain>

# Get local ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Context Switching

The Taskfile manages kubectl contexts automatically:

```bash
# Switch to Kind cluster context (for monitoring bootstrap)
task kubeconfig:set-context:kind

# Switch to GKE cluster context (for accessing final services)
task kubeconfig:set-context:gke

# Get service URLs from GKE cluster
task get:urls
```

## Helmfile Integration

Direct Helmfile operations are available:

```bash
# View configuration differences
task helmfile:diff

# Apply changes
task helmfile:apply

# Sync all releases
task helmfile:sync

# Check release status
task helmfile:status
```

## Task Usage Examples

```bash
# Complete fresh installation
task init
task install

# View what would change before applying
task diff

# Apply updates to existing installation
task sync

# Get final service URLs from AKS cluster
task get:urls

# Clean up everything
task uninstall
```

## Environment Variables

The Taskfile sets these environment variables:

- `KUBECONFIG` - Points to `private/kubeconfig` for isolation
- `REPO_ROOT` - Points to repository root directory

## Validation

Configuration validation happens automatically during:

- `task init`
- `task config:lint`
- Any task that depends on `config:lint`

Validation includes:

- `config.yaml` schema validation
- GCP credentials validation
- Required CLI tools availability check

## Bootstrap Architecture

The installation follows this flow:

1. **Local Kind Cluster** - Bootstrap environment with ArgoCD and Crossplane
2. **GCP Resource Management** - Crossplane manages Secret Manager and Workload Identity
3. **GKE Deployment** - ArgoCD deploys CNOE components to target GKE cluster
4. **Cleanup** - Kind cluster can be removed after installation completes

This approach provides better isolation and observability during the installation process.
