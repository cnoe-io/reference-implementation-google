<!-- omit from toc -->
# Troubleshooting Guide - CNOE Azure Reference Implementation

This guide covers common issues and their solutions when using the CNOE Azure Reference Implementation with Taskfile and Helmfile.

> Note: Most issues are related to missing prerequisites, authentication, networking, or resource constraints. Start with verifying prerequisites and work systematically through the troubleshooting steps.

<!-- omit from toc -->
## Table of Contents

- [Installation Issues](#installation-issues)
  - [Task Installation Fails](#task-installation-fails)
  - [Helmfile Deployment Issues](#helmfile-deployment-issues)
  - [Azure Workload Identity Issues](#azure-workload-identity-issues)
- [Configuration Issues](#configuration-issues)
  - [GitHub Integration Problems](#github-integration-problems)
  - [Domain and DNS Issues](#domain-and-dns-issues)
  - [Azure Key Vault Issues](#azure-key-vault-issues)
- [General Troubleshooting Approach](#general-troubleshooting-approach)
  - [1. Check ArgoCD Applications](#1-check-argocd-applications)
  - [2. Check Taskfile Operations](#2-check-taskfile-operations)
  - [3. Common Diagnostic Commands](#3-common-diagnostic-commands)
  - [Common Log Locations](#common-log-locations)
- [Component-Specific Issues](#component-specific-issues)
  - [ArgoCD Issues](#argocd-issues)
    - [ArgoCD Not Accessible](#argocd-not-accessible)
    - [Applications Not Syncing](#applications-not-syncing)
  - [Crossplane Issues](#crossplane-issues)
    - [Provider Not Ready](#provider-not-ready)
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

1. Missing prerequisite Azure resources (AKS cluster, DNS zone, Key Vault)
2. Incorrect configuration in config.yaml
3. Azure CLI not authenticated
4. Incorrect cluster context
5. Missing required tools

**Debug Steps**:

```bash
# Verify prerequisite Azure resources exist
az aks show --name $(yq '.cluster_name' config.yaml) --resource-group $(yq '.resource_group' config.yaml)
az network dns zone show --name $(yq '.domain' config.yaml) --resource-group $(yq '.resource_group' config.yaml)
az keyvault show --name $(yq '.keyvault' config.yaml) --resource-group $(yq '.resource_group' config.yaml)

# Verify required tools
which az kubectl yq jq helm helmfile task

# Check Azure CLI login
az account show

# Verify correct cluster context
kubectl config current-context

# Validate configuration file
yq '.' config.yaml

# Check cluster OIDC issuer
az aks show --name $(yq '.cluster_name' config.yaml) \
  --resource-group $(yq '.resource_group' config.yaml) \
  --query "oidcIssuerProfile.issuerUrl" -o tsv
```

### Helmfile Deployment Issues

**Symptoms**: Helmfile fails to deploy ArgoCD

**Debug Steps**:

```bash
# Check Helmfile syntax
task helmfile:lint

# View what would be deployed
task helmfile:diff

# Check Helm repositories
helm repo list

# Manual Helmfile debug
helmfile --debug diff
```

### Azure Workload Identity Issues

**Symptoms**: Components can't authenticate to Azure services

**Debug Steps**:

```bash
# Check managed identity creation
az identity list --resource-group $(yq '.resource_group' config.yaml)

# Verify federated credentials
az identity federated-credential list \
  --name crossplane \
  --resource-group $(yq '.resource_group' config.yaml)

# Check service account annotations
kubectl get sa crossplane -n crossplane-system -o yaml

# Verify workload identity resources
kubectl get workloadidentities.azure.livewyer.io -A -o yaml
```

**Common Fixes**:

```bash
# Update Azure credentials (for demo environments only)
task azure:creds:delete
task azure:creds:create

# Update workload identity configuration
task update:secret:azure
```

> **Important**: The `azure:creds:*` tasks are helper functions for demonstration only. In production, Azure identities should be managed through your organization's infrastructure management approach.

## Configuration Issues

### GitHub Integration Problems

**Symptoms**: Backstage cannot connect to GitHub

**Solutions**:

```bash
# Verify GitHub configuration in config.yaml
yq '.github' config.yaml

# Check if configuration was uploaded to Key Vault
az keyvault secret show --name config --vault-name $(yq '.keyvault' config.yaml)

# Update configuration
task update:secret
```

> **Important**: GitHub integration details are stored in `config.yaml`, not in private files. All configuration is centralized in this file and stored securely in Azure Key Vault.

### Domain and DNS Issues

**Symptoms**: Services not accessible via domain names

**Debug Steps**:

```bash
# Check DNS resolution
nslookup backstage.YOUR_DOMAIN

# Verify ingress configuration
kubectl get ingress -A

# Check external-dns logs
kubectl logs -n external-dns deployment/external-dns

# Test load balancer IP
kubectl get svc -n ingress-nginx ingress-nginx-controller
curl -H "Host: backstage.YOUR_DOMAIN" http://LOAD_BALANCER_IP
```

### Azure Key Vault Issues

**Symptoms**: External secrets cannot fetch secrets from Key Vault

**Debug Steps**:

```bash
# Check Key Vault access
az keyvault secret list --vault-name $(yq '.keyvault' config.yaml)

# Verify external-secrets logs
kubectl logs -n external-secrets deployment/external-secrets

# Check workload identity for external-secrets
kubectl get workloadidentity external-secrets -n external-secrets -o yaml

# Test Key Vault connectivity
kubectl run test-pod --rm -i --tty --image=mcr.microsoft.com/azure-cli -- az keyvault secret list --vault-name $(yq '.keyvault' config.yaml)
```

## General Troubleshooting Approach

### 1. Check ArgoCD Applications

All components are deployed as ArgoCD applications. Start by checking their status:

```bash
# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward to ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

Navigate to http://localhost:8080 and login with username `admin` to view:

- Application sync status
- Resource health
- Event logs
- Sync history

### 2. Check Taskfile Operations

```bash
# View available tasks
task --list-all

# Check configuration
task diff

# Verify Helmfile status
task helmfile:status
```

### 3. Common Diagnostic Commands

```bash
# Check cluster connectivity
kubectl cluster-info

# View all ArgoCD applications
kubectl get applications -n argocd

# Check application sets
kubectl get applicationsets -n argocd

# View workload identities
kubectl get workloadidentities.azure.livewyer.io -A
```

### Common Log Locations

```bash
# ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller
kubectl logs -n argocd deployment/argocd-server

# Component logs
kubectl logs -n NAMESPACE deployment/COMPONENT_NAME

# System logs
journalctl -u kubelet (on cluster nodes)
```

## Component-Specific Issues

### ArgoCD Issues

#### ArgoCD Not Accessible

**Symptoms**: Cannot access ArgoCD UI

**Debug Steps**:

```bash
# Check ArgoCD deployment
kubectl get pods -n argocd

# Check ingress
kubectl get ingress -n argocd

# Check service
kubectl get svc -n argocd argocd-server

# Check logs
kubectl logs -n argocd deployment/argocd-server
```

#### Applications Not Syncing

**Symptoms**: ArgoCD applications stuck in "OutOfSync" or "Unknown" state

**Common Fix**:

```bash
# Force refresh application
kubectl patch app APP_NAME -n argocd --type merge --patch '{"operation":{"initiatedBy":{"automated":true}}}'

# Check repository access
kubectl get secret -n argocd argocd-repo-server-tls-certs-cm

# Verify repository connectivity
kubectl exec -n argocd deployment/argocd-server -- argocd repo list
```

### Crossplane Issues

#### Provider Not Ready

**Symptoms**: Crossplane Azure provider fails to install

**Debug Steps**:

```bash
# Check provider status
kubectl get providers

# Check provider config
kubectl get providerconfigs

# Check crossplane logs
kubectl logs -n crossplane-system deployment/crossplane

# Verify workload identity
kubectl describe workloadidentity crossplane -n crossplane-system
```

### ExternalDNS Issues

#### DNS Records Not Created

**Symptoms**: DNS records are not automatically created

**Debug Steps**:

```bash
# Check external-dns logs
kubectl logs -n external-dns deployment/external-dns

# Check workload identity
kubectl get workloadidentity external-dns -n external-dns -o yaml

# Verify DNS zone permissions
az role assignment list --scope "/subscriptions/$(yq '.subscription' config.yaml)/resourceGroups/$(yq '.resource_group' config.yaml)/providers/Microsoft.Network/dnszones/$(yq '.domain' config.yaml)"
```

**Common Fix**:

```bash
# Update external-dns workload identity (demo environments)
task update:secret:external-dns

# Check domain configuration
yq '.domain' config.yaml

# Verify DNS zone exists
az network dns zone show --name $(yq '.domain' config.yaml) --resource-group $(yq '.resource_group' config.yaml)
```

### Cert-Manager Issues

#### Certificates Not Issued

**Symptoms**: TLS certificates remain in "Pending" state

**Debug Steps**:

```bash
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

**Common Error Messages**:

```
Get "http://example.com/.well-known/acme-challenge/...": dial tcp: lookup example.com: no such host
```

**Solution**: DNS propagation delay. Wait 5-10 minutes for DNS to propagate.

### Keycloak Issues

#### Keycloak Pod Failing

**Symptoms**: Keycloak pods crash or fail to start

**Debug Steps**:

```bash
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
kubectl get secrets -n keycloak keycloak-user-config -o yaml

# Verify Backstage configuration
kubectl get configmap -n backstage backstage-config -o yaml
```

### Backstage Issues

#### Backstage Pod Crashing

**Symptoms**: Backstage pods fail to start

**Debug Steps**:

```bash
# Check pod logs
kubectl logs -n backstage deployment/backstage

# Check configuration
kubectl get configmap -n backstage -o yaml

# Check secrets
kubectl get secrets -n backstage -o yaml

# Verify GitHub integration configuration in config.yaml
yq '.github' config.yaml
```

### Ingress Issues

#### Load Balancer Not Created

**Symptoms**: ingress-nginx service has no external IP

**Debug Steps**:

```bash
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
4. Resource constraints

**Debug Steps**:

```bash
# Check node resources
kubectl top nodes

# Check pod resources
kubectl top pods -A

# Scale up cluster if needed (using your infrastructure management approach)
# Example for testing: az aks scale --name CLUSTER --resource-group RG --node-count 3

# Check image pull status
kubectl get events -A --sort-by=.metadata.creationTimestamp
```

### High Resource Usage

**Symptoms**: Cluster running out of resources

**Debug Steps**:

```bash
# Check resource requests and limits
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
# Reinstall specific component
kubectl delete app COMPONENT_NAME -n argocd
task sync

# Full reinstall
task uninstall
task install
```

### Backup and Restore

```bash
# Backup ArgoCD configuration
kubectl get applications -n argocd -o yaml > argocd-apps-backup.yaml

# Backup configuration from Key Vault
az keyvault secret show --name config --vault-name $(yq '.keyvault' config.yaml) > config-backup.json

# Restore from backup
kubectl apply -f argocd-apps-backup.yaml
```

### Emergency Access

```bash
# Direct kubectl access to services
kubectl port-forward svc/argocd-server -n argocd 8080:80
kubectl port-forward svc/backstage -n backstage 3000:7007

# Reset ArgoCD admin password
kubectl patch secret argocd-initial-admin-secret -n argocd -p '{"data":{"password":"'$(echo -n 'new-password' | base64)'"}}'
```

## Getting Help

### Collecting Diagnostic Information

```bash
# Create diagnostic bundle
mkdir cnoe-diagnostics
kubectl cluster-info dump --output-directory=cnoe-diagnostics/cluster-info
kubectl get events -A --sort-by=.metadata.creationTimestamp > cnoe-diagnostics/events.yaml
kubectl get pods -A -o yaml > cnoe-diagnostics/pods.yaml
task helmfile:status > cnoe-diagnostics/helmfile-status.txt
yq '.' config.yaml > cnoe-diagnostics/config.yaml
```

### Additional Resources

- [CNOE Community](https://cnoe.io/community)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Backstage Documentation](https://backstage.io/docs/)

## Prevention Tips

1. **Proper Prerequisites**: Ensure all Azure resources are properly provisioned before installation
2. **Configuration Management**: Keep config.yaml up-to-date and validate before applying changes
3. **Regular Updates**: Use `task sync` to keep components updated
4. **Monitor Resources**: Set up monitoring for cluster resources
5. **Backup Strategy**: Regular backups of critical configurations
6. **Testing**: Test changes in a separate environment first
7. **Infrastructure Management**: Use proper infrastructure management tools for production Azure resources
