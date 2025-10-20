![overview](docs/images/overview.png)

> [!NOTE]
> Applications deployed in this repository are a starting point to get environment into production.

<!-- omit from toc -->

# CNOE Azure Reference Implementation

This repository provides a reference implementation for deploying Cloud Native Operations Enabler (CNOE) components on Azure Kubernetes Service (AKS) using GitOps principles.

<!-- omit from toc -->

## Table of Contents

- [Architecture](#architecture)
  - [Deployed Components](#deployed-components)
- [Important Notes](#important-notes)
- [Prerequisites](#prerequisites)
  - [Required Azure Resources](#required-azure-resources)
    - [Setup Guidance for Azure Resources](#setup-guidance-for-azure-resources)
  - [GitHub Integration Setup](#github-integration-setup)
    - [Create GitHub App for Backstage](#create-github-app-for-backstage)
    - [Create GitHub Token](#create-github-token)
- [Installation Flow](#installation-flow)
- [Security Notes](#security-notes)
- [Installation Steps](#installation-steps)
  - [Installation Requirements](#installation-requirements)
  - [1. Configure the Installation](#1-configure-the-installation)
    - [DNS and TLS Configuration](#dns-and-tls-configuration)
      - [Automatic (Recommended)](#automatic-recommended)
      - [Manual](#manual)
  - [2. Install Components](#2-install-components)
  - [3. Monitor Installation](#3-monitor-installation)
  - [4. Get Access URLs](#4-get-access-urls)
  - [5. Access Backstage](#5-access-backstage)
- [Usage](#usage)
- [Update Component Configurations](#update-component-configurations)
  - [Backstage Templates](#backstage-templates)
- [Uninstall](#uninstall)
- [Contributing](#contributing)
- [Troubleshooting](#troubleshooting)
- [Potential Enhancements](#potential-enhancements)

## Architecture

- Installation is managed through **Taskfile** and **Helmfile**
  - See [TASKFILE.md](./docs/TASKFILE.md) for information about the tasks defined in the `Taskfile.yml` file.
- Uses a **local Kind cluster** as a bootstrap environment to deploy CNOE to the target AKS cluster
- Components are deployed as **ArgoCD Applications**
- Uses **Azure Workload Identity** for secure authentication to Azure services (created automatically via Crossplane)
- Files under the `/packages` directory are meant to be usable without modifications
- Configuration is externalised through the `config.yaml` file

### Deployed Components

| Component        | Version    | Purpose                        |
| ---------------- | ---------- | ------------------------------ |
| ArgoCD           | 8.0.14     | GitOps continuous deployment   |
| Crossplane       | 2.0.2-up.4 | Infrastructure as Code         |
| Ingress-nginx    | 4.7.0      | Ingress controller             |
| ExternalDNS      | 1.16.1     | Automatic DNS management       |
| External-secrets | 0.17.0     | Secret management              |
| Cert-manager     | 1.17.2     | TLS certificate management     |
| Keycloak         | 24.7.3     | Identity and access management |
| Backstage        | 2.6.0      | Developer portal               |
| Argo-workflows   | 0.45.18    | Workflow orchestration         |

## Important Notes

- **Azure Resource Management**: This repository does not manage Azure infrastructure. AKS cluster and DNS zone must be provisioned separately using your organization's infrastructure management approach.
- **Production Readiness**: The helper tasks in this repository are for creating Azure resources for demo purposes only. Any production deployments should follow enterprise infrastructure management practices.
- **Configuration Management**: All configuration is centralised in `config.yaml`. The `private/` directory is only for temporary files during development.
- **Bootstrap Approach**: The installation uses a local Kind cluster to bootstrap the installation to the target AKS cluster. The Kind cluster can be deleted after installation is complete.

## Prerequisites

### Required Azure Resources

Before using this reference implementation, you **MUST** have the following Azure resources already created and configured:

1. **AKS Cluster** (1.27+) with:
   - OIDC Issuer enabled (`--enable-oidc-issuer`)
   - Workload Identity enabled (`--enable-workload-identity`)
   - Sufficient node capacity for all components
     - For example, the demonstration AKS cluster created with the helper task `test:aks:create` has node pool with the node size set to `standard_d4alds_v6` by default
2. **Azure DNS Zone**
   - A registered domain with Azure DNS as the authoritative DNS service

> **Important**:
>
> - All Azure resources must be in the same subscription and resource group
> - Azure Key Vault and Crossplane Workload Identity are **NO LONGER** prerequisites - they will be created automatically during installation
> - These resources are prerequisites and must be provisioned using your organisation's preferred infrastructure management approach (Terraform, Bicep, ARM templates, etc.). The tasks in this repository that create Azure resources (`test:aks:create`, etc.) are helper functions for demonstration purposes only and are **NOT recommended for production deployments**.

#### Setup Guidance for Azure Resources

For setting up the prerequisite Azure resources, refer to the official Azure documentation:

- [Create an AKS cluster](https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough)
- [Azure DNS zones](https://docs.microsoft.com/en-us/azure/dns/)

### GitHub Integration Setup

#### Create GitHub App for Backstage

You need a GitHub App to enable Backstage integration with your GitHub organisation.

**Option 1: Using Backstage CLI (Recommended)**

```bash
npx '@backstage/cli' create-github-app ${GITHUB_ORG_NAME}
# Select appropriate permissions when prompted
# Install the app to your organisation in the browser

# Move the credentials file to a temporary location
mkdir -p private
GITHUB_APP_FILE=$(ls github-app-* | head -n1)
mv ${GITHUB_APP_FILE} private/github-integration.yaml
```

**Option 2: Manual Creation**
Follow [Backstage GitHub App documentation](https://backstage.io/docs/integrations/github/github-apps) and save the credentials as `private/github-integration.yaml`.

> **Note**: The `private/` directory is for temporary files during development/testing only. All configuration must be properly stored in `config.yaml` for the actual deployment.

#### Create GitHub Token

Create a GitHub Personal Access Token with these permissions:

- Repository access for all repositories
- Read-only access to: Administration, Contents, and Metadata

Save the token value temporarily as you will need it when creating the `config.yaml` file.

## Installation Flow

The installation process follows this new pattern using a local Kind cluster as bootstrap:

1. Configure your environment settings in `config.yaml`
2. Set up Azure credentials in `private/azure-credentials.json`
3. Run `task install` which:
   - Creates a local Kind cluster using the configuration in `kind.yaml`
   - Deploys components to Kind cluster via Helmfile as specified in `bootstrap-addons.yaml`
   - Crossplane on Kind cluster connects to Azure and creates necessary cloud resources:
     - Crossplane Workload Identity
     - Azure Key Vault
     - DNS records (`*.local.<domain>`) for observing local installation
   - Deploys CNOE components to the target AKS cluster via ArgoCD
4. Monitor installation progress via local ArgoCD at `argocd.local.<domain>` and Crossplane at `crossplane.local.<domain>`
5. Once installation is complete, the local Kind cluster is no longer needed

```mermaid
---
title: Installation Process
---
erDiagram
  "Local Machine" ||--o{ "Taskfile" : "1. executes"
  "Taskfile" ||--o{ "Kind Cluster" : "2. creates local cluster"
  "Taskfile" ||--o{ "Helmfile" : "3. deploys to Kind"
  "Helmfile" ||--o{ "ArgoCD (Kind)" : "4. installs locally"
  "ArgoCD (Kind)" ||--o{ "Crossplane (Kind)" : "5. installs"
  "Crossplane (Kind)" ||--o{ "Azure Resources" : "6. creates"
  "ArgoCD (Kind)" ||--o{ "AKS Cluster" : "7. deploys CNOE"
```

## Security Notes

- GitHub App credentials contain sensitive information - handle with care
- Azure credentials are stored in `private/azure-credentials.json` (copy from your Azure credential)
- Configuration secrets are stored in Azure Key Vault (created automatically)
- Workload Identity is used for secure Azure authentication (created automatically)
- TLS encryption is used for all external traffic

## Installation Steps

### Installation Requirements

- **Azure CLI** (2.13+) with subscription access
- **kubectl** (1.27+)
- **kubelogin** for AKS authentication
- **yq** for YAML processing
- **helm** (3.x)
- **helmfile**
- **task** (Taskfile executor)
- **kind** for local Kubernetes cluster
- **yamale** for configuration validation
- A **GitHub Organisation** (free to create)

### 1. Configure the Installation

Copy and customise the configuration:

```bash
cp config.yaml.template config.yaml
# Edit config.yaml with your values
```

Set up Azure credentials:

```bash
# Copy your Azure credentials to the private directory
cp private/azure-credentials.template.json private/azure-credentials.json
# Edit private/azure-credentials.json with your actual Azure credentials
```

Key configuration sections in `config.yaml`:

- `repo`: The details of the repository hosting the reference azure implementation code
- `cluster_name`: Your AKS cluster name
- `subscription`: Your Azure subscription ID
- `location`: The target Azure region
- `resource_group`: Your Azure resource group
- `cluster_oidc_issuer_url`: The AKS OIDC issuer URL
- `domain`: The base domain name you will be using for exposing services
- `github`: GitHub App credentials (from the [Github Integration Setup](#github-integration-setup))

#### DNS and TLS Configuration

##### Automatic (Recommended)

- Set your domain in `config.yaml`
- ExternalDNS manages DNS records automatically
- Cert-manager handles Let's Encrypt certificates

##### Manual

- Set DNS records to point to the ingress load balancer IP
- Provide your own TLS certificates as Kubernetes secrets

### 2. Install Components

If installing the reference implementation on a machine for the first time run:

```bash
task init
```

If you haven't previously run `task init`, then you will be prompted to install several Helm plugins required by Helmfile when you run the next command:

```bash
# Install all components
task install
```

> **Notes**:
>
> - `task install` will create a local Kind cluster and use it to bootstrap the installation to your AKS cluster
> - Post-installation, use `task apply` (the equivalent to running `helmfile apply`) to apply updates. See the [Task Usage Guidelines](docs/TASKFILE.md) for more information.

### 3. Monitor Installation

During installation, you can monitor progress using the local Kind cluster:

```bash
# Access local ArgoCD (running on Kind cluster)
# Navigate to: https://argocd.local.<your-domain>

# Access local Crossplane dashboard
# Navigate to: https://crossplane.local.<your-domain>

# Get ArgoCD admin password for local cluster
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Once the AKS installation is complete, you can also access ArgoCD on the target cluster:

```bash
# Switch to AKS cluster context
task kubeconfig:set-context:aks

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access ArgoCD (running on AKS cluster)
# Navigate to: https://argocd.<your-domain>
```

### 4. Get Access URLs

Use the `task get:urls` command to fetch all the URLs from the target AKS cluster:

```bash
task get:urls
```

The URL structure of the URLs will depend on the type of routing you set in the configuration. Examples of the set of URLs that can be outputted are below:

**Domain-based routing** (default):

- Backstage: `https://backstage.YOUR_DOMAIN`
- ArgoCD: `https://argocd.YOUR_DOMAIN`
- Keycloak: `https://keycloak.YOUR_DOMAIN`
- Argo Workflows: `https://argo-workflows.YOUR_DOMAIN`

**Path-based routing** (set `path_routing: true`):

- Backstage: `https://YOUR_DOMAIN/`
- ArgoCD: `https://YOUR_DOMAIN/argocd`
- Keycloak: `https://YOUR_DOMAIN/keycloak`
- Argo Workflows: `https://YOUR_DOMAIN/argo-workflows`

### 5. Access Backstage

Once the Keycloak and Backstage are installed on the target AKS cluster, check you can login to the Backstage UI with a default user:

```bash
# Switch to AKS cluster context
task kubeconfig:set-context:aks

# Get user password
kubectl -n keycloak get secret keycloak-config -o yaml | yq '.data.USER1_PASSWORD | @base64d'
```

## Usage

See [DEMO.md](docs/DEMO.md) for information on how to navigate the platform and for usage examples.

## Update Component Configurations

If you want to try customising component configurations, you can do so by updating the `packages/addons/values.yaml` file and using `task sync` to apply the updates.

### Backstage Templates

Backstage templates can be found in the `templates/` directory

## Uninstall

```bash
# Remove all components and clean up Azure resources
task uninstall

# Clean up GitHub App and tokens manually
# Delete the GitHub organisation if no longer needed
```

> **Note**: The `task uninstall` command will clean up both the local Kind cluster and remove CNOE components from the target AKS cluster. Azure resources created by Crossplane (Key Vault, Workload Identity) will also be cleaned up automatically.

## Contributing

This reference implementation is designed to be:

- **Forkable**: Create your own version for your organisation
- **Customizable**: Modify configurations without changing core packages
- **Extensible**: Add new components following the established patterns

## Troubleshooting

See [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues and detailed troubleshooting steps.

## Potential Enhancements

The installation of this Azure reference implementation will give you a starting point for the platform, however as previously stated applications deployed in this repository are not meant or configured for production. To push it towards production ready, you can make further enhancements that could include:

1. Modifying the basic and Argo workflow templates for your specific Azure use cases
2. Integrating additional Azure services with Crossplane
3. Configuring auto-scaling for AKS and Azure resources
4. Adding OPA Gatekeeper for governance
5. Integrating a monitoring stack. For example:
   1. Deploy Prometheus and Grafana
   2. Configure service monitors for Azure resources
   3. View metrics and Azure resource status in Backstage
6. Implementing GitOps-based environment promotion:
   1. **Development**: Deploy to dev environment via Git push
   2. **Testing**: Promote to test environment via ArgoCD
   3. **Production**: Use ArgoCD sync waves for controlled rollout
