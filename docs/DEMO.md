<!-- omit from toc -->
# Demo Guide - CNOE Azure Reference Implementation

This guide demonstrates the key features and capabilities of the CNOE Azure Reference Implementation through practical examples focused on Azure services and infrastructure.

<!-- omit from toc -->
## Best Practices Demonstrated

### 1. GitOps Workflow

- All changes through Git
- Declarative configuration
- Automated reconciliation

### 2. Security

- Workload Identity for Azure authentication
- Secret management with External Secrets
- TLS everywhere with cert-manager
- Configuration stored securely in Azure Key Vault

### 3. Developer Experience

- Self-service via Backstage templates
- Integrated tooling in single interface
- Documentation as code

### 4. Operational Excellence

- Infrastructure as Code
- Automated DNS and certificate management
- Comprehensive monitoring
- Centralized configuration management

<!-- omit from toc -->
## Table of Contents

- [Prerequisites](#prerequisites)
- [Getting Started: Explore the Platform](#getting-started-explore-the-platform)
  - [Crossplane](#crossplane)
  - [Keycloak](#keycloak)
    - [SSO Credentials](#sso-credentials)
  - [Argo CD](#argo-cd)
- [Argo Workflows](#argo-workflows)
  - [Backstage](#backstage)
- [Demo Scenarios](#demo-scenarios)
  - [Scenario 1: Creating a New Application from Template](#scenario-1-creating-a-new-application-from-template)
- [Reading Material](#reading-material)
- [Feedback and Contributions](#feedback-and-contributions)

## Prerequisites

- Complete installation following the instructions in the [README.md](../README.md) file
- All prerequisite Azure resources (AKS cluster, DNS zone, Key Vault) are properly configured
- Access to Backstage UI at your configured domain
- Default user (`user1`) credentials from Keycloak

## Getting Started: Explore the Platform

After you installed the platform, before performing any operations/scenarios we recommend you first explore the platform.

This section will provide you with instructions on you can access the UI for each component for you to explore. 

To begin the `task get:urls` command can be used to fetch all the URLs.

### Crossplane

An ingress has not been deployed for Crossplane, but there is a UI for it.

If you wish to access the Crossplane UI, you can first run:

```bash
kubectl port-forward service/webui -n crossplane-system 8080:80
```

Then access the Crossplane UI at [localhost:8080](http://localhost:8080).

See the [Crossplane Documentation](https://docs.crossplane.io/) for more information.

### Keycloak

To start exploring Keycloak, open the URL for your Keycloak instance in a web browser and login with the credentials for `cnoe-admin`:

```bash
# Get Keycloak admin password
kubectl -n keycloak get secret keycloak-config -o yaml | yq '.data.KEYCLOAK_ADMIN_PASSWORD | @base64d'
```

See [Keycloak's Server Administration Guide](https://www.keycloak.org/docs/latest/server_admin/index.html) for more information

#### SSO Credentials

SSO is enabled with all other services being integrated with Keycloak. Fetch the credentials for `user1` with the following command:

```bash
# Get user password
kubectl -n keycloak get secret keycloak-config -o yaml | yq '.data.USER1_PASSWORD | @base64d'
```

### Argo CD

To start exploring ArgoCD, open the URL for your ArgoCD instance in a web browser and login with the Keycloak credentials for `user1`.

See the [ArgoCD User Guide](https://argo-cd.readthedocs.io/en/stable/) for more information.

## Argo Workflows

To start exploring Argo Workflow, open the URL for your Argo Workflow instance in a web browser and login with the Keycloak credentials for `user1`.

See [Argo Workflows Documents](https://argo-workflows.readthedocs.io/en/latest/) for more information and workflow examples can be in the [argoproj/argo-workflows](https://github.com/argoproj/argo-workflows/tree/master/examples) repository.

### Backstage

To start exploring Backstage, open the URL for your Backstage instance in a web browser and login with the Keycloak credentials for `user1`.

Once logged in, explore the Backstage UI.

> **Note: at the time of writing, all available templates are for AWS and therefore may not work if you attempt to create a component using them**

See the [Backstage Documentation](https://backstage.io/docs/) for more information

## Demo Scenarios

### Scenario 1: Creating a New Application from Template

@TODO creating templates for Azure is still to be completed [link to issue to be attached]

## Reading Material

Previously linked reading material and more:

- [Backstage Documentation](https://backstage.io/docs/)
- [ArgoCD User Guide](https://argo-cd.readthedocs.io/en/stable/)
- [Argo Workflows Examples](https://github.com/argoproj/argo-workflows/tree/master/examples)
- [Crossplane Documentation](https://docs.crossplane.io/)
- [CNOE Project](https://cnoe.io/)
- [Azure Workload Identity](https://azure.github.io/azure-workload-identity/)

## Feedback and Contributions

Found an issue or have suggestions?

- Open an issue in the repository
- Submit a pull request with improvements
- Join the CNOE community discussions
