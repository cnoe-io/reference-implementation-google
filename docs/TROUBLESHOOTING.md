<!-- omit from toc -->

# Troubleshooting Guide - CNOE Azure Reference Implementation

This
guide covers common issues and their solutions when using the CNOE Azure Reference Implementation with its Kind cluster bootstrap approach.

> Note: Most issues are related to missing prerequisites, authentication, networking, or resource constraints. Start with verifying prerequisites and work systematically through the troubleshooting steps.

<!-- omit from toc -->

## Table of Contents

- [Installation Issues](#installation-issues)
  - [Task Installation Fails](#task-installation-fails)
  - [Kind Cluster Creation Issues](#kind-cluster-creation-issues)
  - [Helmfile Deployment Issues](#helmfile-deployment-issues)
  - [Azure Credentials Issues](#azure-credentials-issues)
- [Configuration Issues](#configuration-issues)
  - [Configuration File Validation](#configuration-file-validation)
  - [GitHub Integration Problems](#github-integration-problems)
  - [Domain and DNS Issues](#domain-and-dns-issues)
  - [Azure Resource Creation Issues](#azure-resource-creation-issues)
- [General Troubleshooting Approach](#general-troubleshooting-approach)
  - [1. Check Kind Cluster Status](#1-check-kind-cluster-status)
  - [2. Check ArgoCD Applications](#2-check-argocd-applications)
  - [3. Check Crossplane Resources](#3-check-crossplane-resources)
  - [4. Common Diagnostic Commands](#4-common-diagnostic-commands)
  - [Common Log Locations](#common-log-locations)
- [Bootstrap Environment Issues](#bootstrap-environment-issues)
  - [Local ArgoCD Issues](#local-argocd-issues)
  - [Local Crossplane Issues](#local-crossplane-issues)
  - [Local DNS Issues](#local-dns-issues)
- [Target AKS Cluster Issues](#target-aks-cluster-issues)
  - [AKS Connection Issues](#aks-connection-issues)
  - [Component Deployment Issues](#component-deployment-issues)
  - [Workload Identity Issues](#workload-identity-issues)
- [Component-Specific Issues](#component-specific-issues)
  - [ArgoCD Issues](#argocd-issues)
    - [ArgoCD Not Accessible](#argocd-not-accessible)
    - [Applications Not Syncing](#applications-not-syncing)
  - [Crossplane Issues](#crossplane-issues)
    - [Provider Not Ready](#provider-not-ready)
    - [Azure Resource Creation Failures](#azure-resource-creation-failures)
  - [ExternalDNS Issues](#externaldns-issues)
    - [DNS Records Not Created](#dns-records-not-created)
  - [Cert-Manager Issues](#cert-manager-issues)
    - [Certificates Not Issued](#certificates-not-issued)
  - [Keycloak Issues](#keycloak-issues)
    - [Keycloak Pod Failing](#keycloak-pod-failing)
    - [SSO Authentication Issues](#sso-authentication-issues)
  - [Backstage Issues](#backstage-issues)
    - [Backstage Pod Crashing](#backstage-pod-crashing)
  - [Ingress Issues](#ingress-issues)
    - [Load Balancer Not Created](#load-balancer-not-created)
- [Performance Issues](#performance-issues)
  - [Slow Installation](#slow-installation)
  - [High Resource Usage](#high-resource-usage)
- [Recovery Procedures](#recovery-procedures)
  - [Reinstalling Components](#reinstalling-components)
  - [Backup and Restore](#backup-and-restore)
  - [Emergency Access](#emergency-access)
- [Getting Help](#getting-help)
  - [Collecting Diagnostic Information](#collecting-diagnostic-information)
  - [Additional Resources](#additional-resources)
- [Prevention Tips](#prevention-tips)

## Installation Issues

### Task Installation Fails

**Symptoms**: `task install` command fails

**Common Causes**:

1. Missing prerequisite Azure resources (AKS cluster, DNS zone)
2. Incorrect configuration in `config.yaml` or `private/azure-credentials.json`
3. Azure CLI not authenticated
4. Kind not installed or Docker not running
5. Missing required tools

**Debug Steps**:

```bash
# Verify prerequisite Azure resources exist
az aks show --name $(yq '.cluster_name' config.yaml) --resource-group $(yq '.resource_group' config.yaml)
az network dns zone show --name $(yq '.domain' config.yaml) --resource-group $(yq '.resource_group' config.yaml)

# Verify required tools
which az kubectl yq helm helmfile task kind yamale

# Check Docker is running (required for Kind)
docker info

# Check Azure CLI login
az account show

# Validate configuration files
task config:lint

# Check cluster OIDC issuer
az aks show --name $(yq '.cluster_name' config.yaml) \
  --resource-group $(yq '.resource_group' config.yaml) \
  --query "oidcIssuerProfile.issuerUrl" -o tsv
```

### Kind Cluster Creation Issues

**Symptoms**: Kind cluster fails to create

**Debug Steps**:

```bash
# Check Docker is running
docker ps

# Check Kind configuration
yq '.' kind.yaml

# Try creating cluster manually
kind create cluster --config kind.yaml --name $(yq '.name' kind.yaml)

# Check for port conflicts
netstat -tulpn | grep -E ':(80|443|30080|30443)'

# Check disk space
df -h
```

**Common Fixes**:

```bash
# Remove existing Kind cluster
task kind:delete

# Clean up Docker resources
docker system prune

# Recreate cluster
task kind:create
```

### Helmfile Deployment Issues

**Symptoms**: Helmfile fails to deploy to Kind cluster

**Debug Steps**:

```bash
# Switch to Kind context
task kubeconfig:set-context:kind

# Check Helmfile syntax
task helmfile:lint

# View what would be deployed
task helmfile:diff

# Check Helm repositories
helm repo list

# Manual Helmfile debug
helmfile --debug diff

# Check Kind cluster nodes
kubectl get nodes
```

### Azure Credentials Issues

**Symptoms**: Crossplane cannot authenticate to Azure

**Debug Steps**:

```bash
# Validate Azure credentials file
task config:lint

# Check credentials format
cat private/azure-credentials.json | yq '.'

# Test Azure authentication manually
az login --service-principal \
  --username $(yq '.clientId' private/azure-credentials.json) \
  --password $(yq '.clientSecret' private/azure-credentials.json) \
  --tenant $(yq '.tenantId' private/azure-credentials.json)

# Check if credentials are loaded in Crossplane
kubectl get secret provider-azure -n crossplane-system -o yaml
```

**Common Fixes**:

```bash
# Recreate credentials file from template
cp private/azure-credentials.template.json private/azure-credentials.json
# Edit with your actual credentials

# Restart Crossplane provider
kubectl rollout restart deployment/crossplane -n crossplane-system
```

## Configuration Issues

### Configuration File Validation

**Symptoms**: Configuration validation fails

**Debug Steps**:

```bash
# Run configuration validation
task config:lint

# Check config.yaml syntax
yq '.' config.yaml

# Check azure-credentials.json syntax
yq '.' private/azure-credentials.json

# Validate against schema
yamale -s config.schema.yaml config.yaml
yamale -s private/azure-credentials.schema.yaml private/azure-credentials.yaml
```

### GitHub Integration Problems

**Symptoms**: ArgoCD cannot connect to GitHub repositories

**Debug Steps**:

```bash
# Verify GitHub configuration in config.yaml
yq '.github' config.yaml

# Check GitHub App credentials
# Ensure GitHub App is installed in your organization

# Test GitHub connectivity from Kind cluster
kubectl run test-pod --rm -i --tty --image=curlimages/curl -- \
  curl -H "Authorization: token YOUR_TOKEN" https://api.github.com/user
```

### Domain and DNS Issues

**Symptoms**: Local services not accessible via `*.local.<domain>` addresses

**Debug Steps**:

```bash
# Check DNS resolution for local services
nslookup argocd.local.YOUR_DOMAIN
nslookup crossplane.local.YOUR_DOMAIN

# Check if local DNS record was created
az network dns record-set a show \
  --name "*.local" \
  --zone-name $(yq '.domain' config.yaml) \
  --resource-group $(yq '.resource_group' config.yaml)

# Check ingress configuration in Kind cluster
task kubeconfig:set-context:kind
kubectl get ingress -A

# Test local services directly
curl -H "Host: argocd.local.YOUR_DOMAIN" http://localhost
```

### Azure Resource Creation Issues

**Symptoms**: Crossplane fails to create Azure resources (Key Vault, Workload Identity)

**Debug Steps**:

```bash
# Switch to Kind context
task kubeconfig:set-context:kind

# Check Crossplane logs
kubectl logs -n crossplane-system deployment/crossplane

# Check Azure provider status
kubectl get providers

# Check managed resources
kubectl get managed -A

# Check specific resources
kubectl get vault -A
kubectl get workloadidentity -A

# Check Azure RBAC permissions
az role assignment list --assignee $(yq '.clientId' private/azure-credentials.json)
```

## General Troubleshooting Approach

### 1. Check Kind Cluster Status

Start troubleshooting with the bootstrap environment:

```bash
# Check Kind cluster exists and is running
kind get clusters
kubectl cluster-info --context kind-$(yq '.name' kind.yaml)

# Check nodes
task kubeconfig:set-context:kind
kubectl get nodes

# Check system pods
kubectl get pods -A
```

### 2. Check ArgoCD Applications

Monitor the bootstrap ArgoCD for deployment status:

```bash
# Access local ArgoCD UI
# Navigate to: http://argocd.local.<your-domain>

# Get local ArgoCD admin password
task kubeconfig:set-context:kind
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Check application status via CLI
kubectl get applications -n argocd
kubectl get applicationsets -n argocd
```

### 3. Check Crossplane Resources

Monitor Azure resource creation:

```bash
# Access local Crossplane dashboard
# Navigate to: http://crossplane.local.<your-domain>

# Check Crossplane resources via CLI
kubectl get managed -A
kubectl get workloadidentity -A
kubectl get vault -A
```

### 4. Common Diagnostic Commands

```bash
# Check overall cluster health
kubectl get nodes
kubectl get pods -A --field-selector=status.phase!=Running

# Check events for errors
kubectl get events -A --sort-by=.metadata.creationTimestamp

# Check resource usage
kubectl top nodes
kubectl top pods -A
```

### Common Log Locations

```bash
# ArgoCD logs (Kind cluster)
kubectl logs -n argocd deployment/argocd-application-controller
kubectl logs -n argocd deployment/argocd-server

# Crossplane logs (Kind cluster)
kubectl logs -n crossplane-system deployment/crossplane

# Component logs (AKS cluster)
task kubeconfig:set-context:aks
kubectl logs -n NAMESPACE deployment/COMPONENT_NAME
```

## Bootstrap Environment Issues

### Local ArgoCD Issues

**Symptoms**: Cannot access ArgoCD at `argocd.local.<domain>`

**Debug Steps**:

```bash
# Switch to Kind context
task kubeconfig:set-context:kind

# Check ArgoCD pods
kubectl get pods -n argocd

# Check ingress configuration
kubectl get ingress -n argocd

# Check if DNS record exists
az network dns record-set a show \
  --name "*.local" \
  --zone-name $(yq '.domain' config.yaml) \
  --resource-group $(yq '.resource_group' config.yaml)

# Port forward to bypass ingress
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

### Local Crossplane Issues

**Symptoms**: Cannot access Crossplane dashboard or resources not creating

**Debug Steps**:

```bash
# Check Crossplane pods
kubectl get pods -n crossplane-system

# Check provider installation
kubectl get providers

# Check provider configuration
kubectl get providerconfigs

# Check crossplane logs
kubectl logs -n crossplane-system deployment/crossplane

# Check Azure provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=azure
```

### Local DNS Issues

**Symptoms**: `*.local.<domain>` addresses not resolving

**Debug Steps**:

```bash
# Check if DNS record was created by Crossplane
kubectl get dnsarecord -A

# Check DNS record in Azure
az network dns record-set a show \
  --name "*.local" \
  --zone-name $(yq '.domain' config.yaml) \
  --resource-group $(yq '.resource_group' config.yaml)

# Check external-dns logs (if applicable)
kubectl logs -n external-dns deployment/external-dns
```

## Target AKS Cluster Issues

### AKS Connection Issues

**Symptoms**: Cannot connect to or deploy to AKS cluster

**Debug Steps**:

```bash
# Verify AKS cluster credentials
task kubeconfig:set-context:aks
kubectl cluster-info

# Check if cluster is accessible
kubectl get nodes

# Verify OIDC issuer configuration
az aks show --name $(yq '.cluster_name' config.yaml) \
  --resource-group $(yq '.resource_group' config.yaml) \
  --query "oidcIssuerProfile.issuerUrl" -o tsv
```

### Component Deployment Issues

**Symptoms**: Components not deploying to AKS cluster from Kind-based ArgoCD

**Debug Steps**:

```bash
# Check ArgoCD application status (from Kind cluster)
task kubeconfig:set-context:kind
kubectl get applications -n argocd

# Check if ArgoCD can reach AKS cluster
kubectl get secret cnoe -n argocd -o yaml

# Check logs for deployment issues
kubectl logs -n argocd deployment/argocd-application-controller
```

### Workload Identity Issues

**Symptoms**: Services on AKS cannot authenticate to Azure

**Debug Steps**:

```bash
# Switch to AKS context
task kubeconfig:set-context:aks

# Check if workload identity was created
az identity list --resource-group $(yq '.resource_group' config.yaml)

# Check service account annotations
kubectl get sa -A -o yaml | grep azure.workload.identity

# Check federated credentials
az identity federated-credential list \
  --name crossplane \
  --resource-group $(yq '.resource_group' config.yaml)
```

## Component-Specific Issues

### ArgoCD Issues

#### ArgoCD Not Accessible

**Symptoms**: Cannot access ArgoCD UI on AKS cluster

**Debug Steps**:

```bash
# Switch to AKS context
task kubeconfig:set-context:aks

# Check ArgoCD deployment
kubectl get pods -n argocd

# Check ingress
kubectl get ingress -n argocd

# Get service URLs
task get:urls

# Port forward to bypass ingress
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

#### Applications Not Syncing

**Symptoms**: ArgoCD applications stuck in "OutOfSync" or "Unknown" state

**Debug Steps**:

```bash
# Check application status
kubectl get applications -n argocd

# Check repository connectivity
kubectl exec -n argocd deployment/argocd-server -- argocd repo list

# Force refresh application
kubectl patch app APP_NAME -n argocd --type merge --patch '{"operation":{"initiatedBy":{"automated":true}}}'
```

### Crossplane Issues

#### Provider Not Ready

**Symptoms**: Crossplane Azure provider fails to install

**Debug Steps**:

```bash
# Switch to Kind context (where Crossplane is running)
task kubeconfig:set-context:kind

# Check provider status
kubectl get providers

# Check provider config
kubectl get providerconfigs

# Check azure credentials secret
kubectl get secret provider-azure -n crossplane-system -o yaml
```

#### Azure Resource Creation Failures

**Symptoms**: Azure resources (Key Vault, Workload Identity) not being created

**Debug Steps**:

```bash
# Check managed resources
kubectl get managed -A

# Check specific resource events
kubectl describe vault VAULT_NAME
kubectl describe workloadidentity IDENTITY_NAME

# Check Azure permissions
az role assignment list --assignee $(yq '.clientId' private/azure-credentials.json)
```

### ExternalDNS Issues

#### DNS Records Not Created

**Symptoms**: DNS records are not automatically created on AKS cluster

**Debug Steps**:

```bash
# Switch to AKS context
task kubeconfig:set-context:aks

# Check external-dns logs
kubectl logs -n external-dns deployment/external-dns

# Check DNS zone permissions
az role assignment list --scope "/subscriptions/$(yq '.subscription' config.yaml)/resourceGroups/$(yq '.resource_group' config.yaml)/providers/Microsoft.Network/dnszones/$(yq '.domain' config.yaml)"

# Verify DNS zone exists
az network dns zone show --name $(yq '.domain' config.yaml) --resource-group $(yq '.resource_group' config.yaml)
```

### Cert-Manager Issues

#### Certificates Not Issued

**Symptoms**: TLS certificates remain in "Pending" state

**Debug Steps**:

```bash
# Switch
 to AKS context
task kubeconfig:set-context:aks

# Check certificate status
kubectl get certificates -A

# Check certificate requests
kubectl get certificaterequests -A

# Check challenges
kubectl get challenges -A

# Check issuer status
kubectl get clusterissuers

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

### Keycloak Issues

#### Keycloak Pod Failing

**Symptoms**: Keycloak pods crash or fail to start on AKS cluster

**Debug Steps**:

```bash
# Switch to AKS context
task kubeconfig:set-context:aks

# Check pod status
kubectl get pods -n keycloak

# Check logs
kubectl logs -n keycloak deployment/keycloak

# Check persistent volume claims
kubectl get pvc -n keycloak

# Check secrets
kubectl get secrets -n keycloak
```

#### SSO Authentication Issues

**Symptoms**: Cannot log into Backstage via Keycloak

**Debug Steps**:

```bash
# Check Keycloak accessibility
curl -k https://keycloak.YOUR_DOMAIN/realms/cnoe/.well-known/openid-configuration

# Check user secrets
kubectl get secrets -n keycloak keycloak-config -o yaml

# Verify Backstage configuration
kubectl get configmap -n backstage backstage-config -o yaml
```

### Backstage Issues

#### Backstage Pod Crashing

**Symptoms**: Backstage pods fail to start on AKS cluster

**Debug Steps**:

```bash
# Switch to AKS context
task kubeconfig:set-context:aks

# Check pod logs
kubectl logs -n backstage deployment/backstage

# Check configuration
kubectl get configmap -n backstage -o yaml

# Check secrets
kubectl get secrets -n backstage -o yaml

# Verify GitHub integration configuration
yq '.github' config.yaml
```

### Ingress Issues

#### Load Balancer Not Created

**Symptoms**: ingress-nginx service has no external IP on AKS cluster

**Debug Steps**:

```bash
# Switch to AKS context
task kubeconfig:set-context:aks

# Check service status
kubectl get svc -n ingress-nginx

# Check ingress-nginx logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Check Azure Load Balancer
az network lb list --resource-group MC_$(yq '.resource_group' config.yaml)_$(yq '.cluster_name' config.yaml)_$(yq '.location' config.yaml)
```

## Performance Issues

### Slow Installation

**Symptoms**: Installation takes very long or times out

**Common Causes**:

1. DNS propagation delays
2. Certificate issuance delays
3. Image pull issues
4. Resource constraints on Kind cluster or AKS

**Debug Steps**:

```bash
# Check Kind cluster resources
task kubeconfig:set-context:kind
kubectl top nodes
kubectl top pods -A

# Check AKS cluster resources
task kubeconfig:set-context:aks
kubectl top nodes

# Check image pull status
kubectl get events -A --sort-by=.metadata.creationTimestamp | grep Pull

# Monitor Crossplane resource creation
kubectl get managed -A -w
```

### High Resource Usage

**Symptoms**: Cluster running out of resources

**Debug Steps**:

```bash
# Check resource requests and limits on both clusters
kubectl describe nodes

# Identify resource-hungry pods
kubectl top pods -A --sort-by=cpu
kubectl top pods -A --sort-by=memory

# Check persistent volume usage
kubectl get pv
```

## Recovery Procedures

### Reinstalling Components

```bash
# Clean reinstall
task uninstall
task install

# Reinstall only AKS components (keep Kind cluster)
task kubeconfig:set-context:kind
kubectl -n argocd delete app cnoe
task sync
```

### Backup and Restore

```bash
# Backup ArgoCD configuration from Kind cluster
task kubeconfig:set-context:kind
kubectl get applications -n argocd -o yaml > argocd-apps-backup.yaml

# Backup configuration
cp config.yaml config-backup.yaml
cp private/azure-credentials.json private/azure-credentials-backup.json

# Restore from backup
kubectl apply -f argocd-apps-backup.yaml
```

### Emergency Access

```bash
# Direct kubectl access to services on AKS
task kubeconfig:set-context:aks
kubectl port-forward svc/argocd-server -n argocd 8080:80
kubectl port-forward svc/backstage -n backstage 3000:7007

# Access Kind cluster services
task kubeconfig:set-context:kind
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

## Getting Help

### Collecting Diagnostic Information

```bash
# Create diagnostic bundle
mkdir cnoe-diagnostics

# Collect Kind cluster information
task kubeconfig:set-context:kind
kubectl cluster-info dump --output-directory=cnoe-diagnostics/kind-cluster-info
kubectl get events -A --sort-by=.metadata.creationTimestamp > cnoe-diagnostics/kind-events.yaml
kubectl get pods -A -o yaml > cnoe-diagnostics/kind-pods.yaml

# Collect AKS cluster information
task kubeconfig:set-context:aks
kubectl cluster-info dump --output-directory=cnoe-diagnostics/aks-cluster-info
kubectl get events -A --sort-by=.metadata.creationTimestamp > cnoe-diagnostics/aks-events.yaml
kubectl get pods -A -o yaml > cnoe-diagnostics/aks-pods.yaml

# Collect configuration
task helmfile:status > cnoe-diagnostics/helmfile-status.txt
yq '.' config.yaml > cnoe-diagnostics/config.yaml
# DO NOT include azure-credentials.json in diagnostic bundle for security reasons

# Collect Azure resources
az resource list --resource-group $(yq '.resource_group' config.yaml) > cnoe-diagnostics/azure-resources.json
```

### Additional Resources

- [CNOE Community](https://cnoe.io/community)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Crossplane Documentation](https://docs.crossplane.io/)
- [Backstage Documentation](https://backstage.io/docs/)
- [Kind Documentation](https://kind.sigs.k8s.io/)

## Prevention Tips

1. **Proper Prerequisites**: Ensure AKS cluster and DNS zone are properly provisioned before installation
2. **Configuration Management**: Keep `config.yaml` and `azure-credentials.json` up-to-date and validate before applying changes
3. **Regular Updates**: Use `task sync` to keep components updated
4. **Monitor Resources**: Set up monitoring for both Kind and AKS cluster resources
5. **Backup Strategy**: Regular backups of critical configurations
6. **Testing**: Test changes in a separate environment first
7. **Infrastructure Management**: Use proper infrastructure management tools for production Azure resources
8. **Docker Health**: Ensure Docker is running properly for Kind cluster operations
9. **Network Connectivity**: Ensure reliable internet connection for image pulls and Azure API calls
10. **Azure Permissions**: Verify service principal has necessary permissions for resource creation
