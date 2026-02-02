<!-- omit from toc -->

# Troubleshooting Guide - CNOE GCP Reference Implementation

This guide covers common issues and their solutions when using the CNOE GCP Reference Implementation with its Kind cluster bootstrap approach.

> Note: Most issues are related to missing prerequisites, authentication, networking, or resource constraints. Start with verifying prerequisites and work systematically through the troubleshooting steps.

<!-- omit from toc -->

## Table of Contents

- [Installation Issues](#installation-issues)
  - [Task Installation Fails](#task-installation-fails)
  - [Kind Cluster Creation Issues](#kind-cluster-creation-issues)
  - [Helmfile Deployment Issues](#helmfile-deployment-issues)
  - [GCP Credentials Issues](#gcp-credentials-issues)
- [Configuration Issues](#configuration-issues)
  - [Configuration File Validation](#configuration-file-validation)
  - [GitHub Integration Problems](#github-integration-problems)
  - [Domain and DNS Issues](#domain-and-dns-issues)
  - [GCP Resource Creation Issues](#gcp-resource-creation-issues)
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
- [Target GKE Cluster Issues](#target-gke-cluster-issues)
  - [GKE Connection Issues](#gke-connection-issues)
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

1. Missing prerequisite GCP resources (GKE cluster, Cloud DNS zone, Secret Manager)
2. Incorrect configuration in `config.yaml`
3. gcloud CLI not authenticated
4. Kind not installed or Docker not running
5. Missing required tools

**Debug Steps**:

```bash
# Verify prerequisite GCP resources exist
gcloud container clusters describe $(yq '.cluster_name' config.yaml) --region=$(yq '.region' config.yaml) --project=$(yq '.project' config.yaml)
gcloud dns managed-zones describe $(yq '.dns_zone' config.yaml) --project=$(yq '.project' config.yaml)
gcloud secrets describe $(yq '.secret_manager' config.yaml) --project=$(yq '.project' config.yaml) || echo "Secret Manager will be created"

# Verify required tools
which gcloud kubectl yq helm helmfile task kind yamale

# Check Docker is running (required for Kind)
docker info

# Check gcloud CLI authentication
gcloud auth list
gcloud config get-value project

# Validate configuration files
task config:lint

# Check cluster workload identity configuration
gcloud container clusters describe $(yq '.cluster_name' config.yaml) --region=$(yq '.region' config.yaml) --format="value(workloadIdentityConfig)"
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

### GCP Credentials Issues

**Symptoms**: Crossplane cannot authenticate to GCP

**Debug Steps**:

```bash
# Validate GCP credentials
gcloud auth application-default print-access-token

# Check current gcloud configuration
gcloud config list

# Check if service account has necessary permissions
gcloud projects get-iam-policy $(yq '.project' config.yaml) \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:serviceAccount:*"

# Check if credentials are loaded in Crossplane
kubectl get secret -n crossplane-system
kubectl get providerconfig -n crossplane-system
```

**Common Fixes**:

```bash
# Re-authenticate gcloud
gcloud auth login
gcloud auth application-default login

# Set the correct project
gcloud config set project $(yq '.project' config.yaml)

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
gcloud dns record-sets list \
  --zone=$(yq '.dns_zone' config.yaml) \
  --filter="name:*.local.$(yq '.dns_domain' config.yaml)" \
  --project=$(yq '.project' config.yaml)

# Check ingress configuration in Kind cluster
task kubeconfig:set-context:kind
kubectl get ingress -A

# Test local services directly
curl -H "Host: argocd.local.YOUR_DOMAIN" http://localhost
```

### GCP Resource Creation Issues

**Symptoms**: Crossplane fails to create or manage GCP resources (Secret Manager, Workload Identity)

**Debug Steps**:

```bash
# Switch to Kind context
task kubeconfig:set-context:kind

# Check Crossplane logs
kubectl logs -n crossplane-system deployment/crossplane

# Check GCP provider status
kubectl get providers

# Check managed resources
kubectl get managed -A

# Check specific resources
kubectl get secret -A
kubectl get serviceaccount -A

# Check GCP IAM permissions
gcloud projects get-iam-policy $(yq '.project' config.yaml) \
  --flatten="bindings[].members" \
  --format="table(bindings.role,bindings.members)"
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
kubectl get managed -A | grep -i dns

# Check DNS record in GCP
gcloud dns record-sets list \
  --zone=$(yq '.dns_zone' config.yaml) \
  --filter="name:*.local.$(yq '.dns_domain' config.yaml)" \
  --project=$(yq '.project' config.yaml)

# Check external-dns logs (if applicable)
kubectl logs -n external-dns deployment/external-dns
```

## Target GKE Cluster Issues

### GKE Connection Issues

**Symptoms**: Cannot connect to or deploy to GKE cluster

**Debug Steps**:

```bash
# Verify GKE cluster credentials
task kubeconfig:set-context:gke
kubectl cluster-info

# Check if cluster is accessible
kubectl get nodes

# Verify Workload Identity configuration
gcloud container clusters describe $(yq '.cluster_name' config.yaml) \
  --region=$(yq '.region' config.yaml) \
  --project=$(yq '.project' config.yaml) \
  --format="value(workloadIdentityConfig)"
```

### Component Deployment Issues

**Symptoms**: Components not deploying to GKE cluster from Kind-based ArgoCD

**Debug Steps**:

```bash
# Check ArgoCD application status (from Kind cluster)
task kubeconfig:set-context:kind
kubectl get applications -n argocd

# Check if ArgoCD can reach GKE cluster
kubectl get secret cnoe -n argocd -o yaml

# Check logs for deployment issues
kubectl logs -n argocd deployment/argocd-application-controller
```

### Workload Identity Issues

**Symptoms**: Services on GKE cannot authenticate to GCP

**Debug Steps**:

```bash
# Switch to GKE context
task kubeconfig:set-context:gke

# Check if workload identity was created
gcloud iam service-accounts list --project=$(yq '.project' config.yaml)

# Check service account annotations
kubectl get sa -A -o yaml | grep iam.gke.io/gcp-service-account

# Check IAM bindings for workload identity
gcloud iam service-accounts get-iam-policy \
  crossplane@$(yq '.project' config.yaml).iam.gserviceaccount.com \
  --project=$(yq '.project' config.yaml)
```

## Component-Specific Issues

### ArgoCD Issues

#### ArgoCD Not Accessible

**Symptoms**: Cannot access ArgoCD UI on GKE cluster

**Debug Steps**:

```bash
# Switch to GKE context
task kubeconfig:set-context:gke

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

#### GCP Resource Creation Failures

**Symptoms**: GCP resources (Secret Manager, Workload Identity) not being created

**Debug Steps**:

```bash
# Check managed resources
kubectl get managed -A

# Check specific resource events
kubectl describe secret SECRET_NAME -n crossplane-system
kubectl describe serviceaccount SA_NAME -n crossplane-system

# Check GCP permissions
gcloud projects get-iam-policy $(yq '.project' config.yaml) \
  --flatten="bindings[].members" \
  --format="table(bindings.role,bindings.members)"
```

### ExternalDNS Issues

#### DNS Records Not Created

**Symptoms**: DNS records are not automatically created on GKE cluster

**Debug Steps**:

```bash
# Switch to GKE context
task kubeconfig:set-context:gke

# Check external-dns logs
kubectl logs -n external-dns deployment/external-dns

# Check DNS zone permissions
gcloud dns managed-zones describe $(yq '.dns_zone' config.yaml) \
  --project=$(yq '.project' config.yaml)

# List current DNS records
gcloud dns record-sets list \
  --zone=$(yq '.dns_zone' config.yaml) \
  --project=$(yq '.project' config.yaml)

# Check service account permissions for external-dns
kubectl get sa -n external-dns -o yaml
```

### Cert-Manager Issues

#### Certificates Not Issued

**Symptoms**: TLS certificates remain in "Pending" state

**Debug Steps**:

```bash
# Switch to GKE context
task kubeconfig:set-context:gke

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

**Symptoms**: Keycloak pods crash or fail to start on GKE cluster

**Debug Steps**:

```bash
# Switch to GKE context
task kubeconfig:set-context:gke

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

**Symptoms**: Backstage pods fail to start on GKE cluster

**Debug Steps**:

```bash
# Switch to GKE context
task kubeconfig:set-context:gke

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

**Symptoms**: ingress-nginx service has no external IP on GKE cluster

**Debug Steps**:

```bash
# Switch to GKE context
task kubeconfig:set-context:gke

# Check service status
kubectl get svc -n ingress-nginx

# Check ingress-nginx logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Check GCP Load Balancer
gcloud compute forwarding-rules list --project=$(yq '.project' config.yaml)
gcloud compute backend-services list --project=$(yq '.project' config.yaml)
```

## Performance Issues

### Slow Installation

**Symptoms**: Installation takes very long or times out

**Common Causes**:

1. DNS propagation delays
2. Certificate issuance delays
3. Image pull issues
4. Resource constraints on Kind cluster or GKE

**Debug Steps**:

```bash
# Check Kind cluster resources
task kubeconfig:set-context:kind
kubectl top nodes
kubectl top pods -A

# Check GKE cluster resources
task kubeconfig:set-context:gke
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

# Reinstall only GKE components (keep Kind cluster)
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

# Restore from backup
kubectl apply -f argocd-apps-backup.yaml
```

### Emergency Access

```bash
# Direct kubectl access to services on GKE
task kubeconfig:set-context:gke
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

# Collect GKE cluster information
task kubeconfig:set-context:gke
kubectl cluster-info dump --output-directory=cnoe-diagnostics/gke-cluster-info
kubectl get events -A --sort-by=.metadata.creationTimestamp > cnoe-diagnostics/gke-events.yaml
kubectl get pods -A -o yaml > cnoe-diagnostics/gke-pods.yaml

# Collect configuration
task helmfile:status > cnoe-diagnostics/helmfile-status.txt
yq '.' config.yaml > cnoe-diagnostics/config.yaml
# DO NOT include GCP service account keys in diagnostic bundle for security reasons

# Collect GCP resources
gcloud compute instances list --project=$(yq '.project' config.yaml) > cnoe-diagnostics/gcp-instances.json
gcloud dns managed-zones list --project=$(yq '.project' config.yaml) > cnoe-diagnostics/gcp-dns-zones.json
```

### Additional Resources

- [CNOE Community](https://cnoe.io/community)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Crossplane Documentation](https://docs.crossplane.io/)
- [Backstage Documentation](https://backstage.io/docs/)
- [Kind Documentation](https://kind.sigs.k8s.io/)

## Prevention Tips

1. **Proper Prerequisites**: Ensure GKE cluster, Cloud DNS zone, and Secret Manager are properly provisioned before installation
2. **Configuration Management**: Keep `config.yaml` up-to-date and validate before applying changes
3. **Regular Updates**: Use `task sync` to keep components updated
4. **Monitor Resources**: Set up monitoring for both Kind and GKE cluster resources
5. **Backup Strategy**: Regular backups of critical configurations
6. **Testing**: Test changes in a separate environment first
7. **Infrastructure Management**: Use proper infrastructure management tools for production GCP resources
8. **Docker Health**: Ensure Docker is running properly for Kind cluster operations
9. **Network Connectivity**: Ensure reliable internet connection for image pulls and GCP API calls
10. **GCP Permissions**: Verify service account has necessary IAM permissions for resource creation and management
