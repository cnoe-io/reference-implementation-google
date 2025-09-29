# Task Usage Guidelines

This document gives an overview of the tasks defined in the Taskfile.yml.

## Available Tasks

```bash
task init          # Initialize and validate configuration
task install       # Full installation
task sync          # Deploy/update components (equivalent to helmfile sync)
task diff          # Show pending changes
task update        # Update configuration secrets
task uninstall     # Remove all components

# Helper tasks (for demo/testing only):
task test:aks:create     # Create test AKS cluster (NOT for production)
task test:aks:destroy    # Delete test AKS cluster
task azure:creds:create  # Create Azure credentials (demo only)
task azure:creds:delete  # Delete Azure credentials (demo only)
```

> **Note**: Tasks may update the `config.yaml`

## Production vs Demo Tasks

**Production Tasks** (safe for production use):

```bash
task install    # Full installation
task sync       # Update components (helmfile sync equivalent)
task update     # Update configuration secrets
task diff       # Show pending changes
task uninstall  # Clean removal
```

**Demo/Helper Tasks** (for demonstration and testing only):

```bash
task test:aks:create     # Creates test AKS cluster - NOT for production
task test:aks:destroy    # Removes test AKS cluster
task azure:creds:create  # Creates demo Azure credentials - NOT for production
task azure:creds:delete  # Removes demo Azure credentials
```

> **Important**: Tasks prefixed with `test:` or `azure:creds:` are helper functions for demonstration purposes only. Production Azure resources should be managed through your organization's standard infrastructure management practices (Terraform, Bicep, ARM templates, etc.).

## `task install` vs `task sync`

- `task install` - Complete initial setup including Azure credential configuration
- `task sync` - Updates existing installation (equivalent to `helmfile sync`)

Use `task sync` for updates after the initial installation, not `task install`.

## Updating Configuration

```bash
# Make changes to config.yaml
vim config.yaml

# Update the platform configuration
task update

# Sync changes to all components
task sync
```

## Task Usage Examples

```bash
# View configuration differences before applying
task diff

# Deploy updates (equivalent to helmfile sync)
task sync

# Update only the configuration secrets in Key Vault
task update:secret

# Initialize and validate configuration
task init

# Full reinstallation
task uninstall
task install
```

> **Important**: Tasks prefixed with `test:` or `azure:creds:` are helper functions for demonstration and testing purposes only. They are **NOT recommended for production deployments**. Production infrastructure should be managed using your organization's standard infrastructure management practices.

