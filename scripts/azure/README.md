# Backline AI - Azure Integration Scripts

Scripts to grant Backline AI access to Azure Container Registries, Azure Cloud subscriptions, and AKS clusters.

## Prerequisites

- Azure CLI installed and logged in (`az login`)
- Permission to create service principals in your Entra ID tenant
- Permission to assign roles at the relevant scope for each integration:

| Integration | Flag | Required permission | Scope |
|-------------|------|---------------------|-------|
| Azure Container Registry | `--acr` | Owner or Role Based Access Control Administrator | ACR resource or its resource group |
| Azure Cloud | `--cloud-sub` | Owner or Role Based Access Control Administrator | Subscription |
| AKS | `--aks-sub` | Owner or Role Based Access Control Administrator | AKS cluster or its resource group |

> The script assigns **read-only** roles to Backline. The elevated permission is only required for the person *running* the script in order to create those role assignments. See [Microsoft's documentation](https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-steps#step-4-check-your-prerequisites) for details.

## Scripts

### install_azure_integration.sh

Grants Backline AI access to Azure Container Registries (`AcrPull`), Azure Cloud subscriptions (`Reader`), and/or AKS clusters (`Azure Kubernetes Service RBAC Reader`).

**What it does:**
1. Creates a service principal for Backline AI in your tenant (if not exists)
2. Assigns `AcrPull` role on specified ACR(s) (for container registry integration)
3. Assigns `Reader` role on specified subscriptions (for Azure Cloud integration)
4. Assigns `Azure Kubernetes Service RBAC Reader` role on AKS clusters (for Kubernetes resource visibility)

**Usage:**

```bash
# Single ACR
./install_azure_integration.sh --acr myacr --rg mygroup

# Multiple ACRs in same resource group
./install_azure_integration.sh --acr "acr1 acr2 acr3" --rg mygroup

# ACRs across different resource groups
./install_azure_integration.sh --acr acr1 --rg group1 --acr acr2 --rg group2

# All ACRs in a resource group
./install_azure_integration.sh --rg mygroup --yes

# All ACRs in subscription
./install_azure_integration.sh --subscription --yes

# Azure Cloud - Reader role on subscriptions
./install_azure_integration.sh --cloud-sub 11111111-1111-1111-1111-111111111111

# Azure Cloud - multiple subscriptions
./install_azure_integration.sh --cloud-sub 11111111-1111-1111-1111-111111111111 --cloud-sub 22222222-2222-2222-2222-222222222222

# Both ACR and Azure Cloud
./install_azure_integration.sh --acr myacr --rg mygroup --cloud-sub 11111111-1111-1111-1111-111111111111

# AKS - prompt per cluster to select which ones to include
./install_azure_integration.sh --aks-sub 11111111-1111-1111-1111-111111111111

# AKS - grant access to all clusters without prompting
./install_azure_integration.sh --aks-sub 11111111-1111-1111-1111-111111111111 --aks-all

# AKS - multiple subscriptions
./install_azure_integration.sh --aks-sub 11111111-1111-1111-1111-111111111111 --aks-sub 22222222-2222-2222-2222-222222222222 --aks-all

# Azure Cloud Reader + AKS access together
./install_azure_integration.sh --cloud-sub 11111111-1111-1111-1111-111111111111 --aks-sub 11111111-1111-1111-1111-111111111111

# Interactive mode
./install_azure_integration.sh
```

**Options:**

| Option | Description |
|--------|-------------|
| `--acr <name>` | ACR name(s), space-delimited for multiple |
| `--rg`, `--resource-group <name>` | Resource group for the preceding `--acr` |
| `--subscription` | Add all ACRs in the subscription |
| `--cloud-sub <id>` | Subscription ID to grant Reader role (repeatable) |
| `--aks-sub <id>` | Subscription ID to grant AKS RBAC Reader on clusters (repeatable) |
| `--aks-all` | Grant AKS access to all clusters without prompting per cluster |
| `--yes` | Required for bulk ACR operations |
| `--dry-run` | Show what would be done without making changes |
| `-h`, `--help` | Show help |

**AKS prerequisite:** Each cluster must have Azure RBAC for Kubernetes enabled before running this script. To enable it on an existing cluster:

```bash
az aks update --resource-group <rg> --name <cluster-name> --enable-azure-rbac
```

---

### cleanup_azure_integration.sh

Removes Backline AI access from ACRs, Azure Cloud subscriptions, AKS clusters, or removes the service principal entirely.

**Usage:**

```bash
# Remove service principal completely (removes ALL access)
./cleanup_azure_integration.sh --all --yes

# Remove specific ACR
./cleanup_azure_integration.sh --acr myacr --rg mygroup

# Remove multiple ACRs
./cleanup_azure_integration.sh --acr "acr1 acr2" --rg mygroup

# ACRs across different resource groups
./cleanup_azure_integration.sh --acr acr1 --rg group1 --acr acr2 --rg group2

# Remove all ACRs in resource group from integration
./cleanup_azure_integration.sh --rg mygroup --yes

# Remove Reader role from Azure Cloud subscription
./cleanup_azure_integration.sh --cloud-sub 11111111-1111-1111-1111-111111111111

# Remove Reader role from multiple subscriptions
./cleanup_azure_integration.sh --cloud-sub 11111111-1111-1111-1111-111111111111 --cloud-sub 22222222-2222-2222-2222-222222222222

# Remove AKS RBAC Reader from all clusters in a subscription
./cleanup_azure_integration.sh --aks-sub 11111111-1111-1111-1111-111111111111

# Remove AKS RBAC Reader from multiple subscriptions
./cleanup_azure_integration.sh --aks-sub 11111111-1111-1111-1111-111111111111 --aks-sub 22222222-2222-2222-2222-222222222222

# Interactive mode
./cleanup_azure_integration.sh
```

**Options:**

| Option | Description |
|--------|-------------|
| `--all` | Remove service principal completely |
| `--acr <name>` | ACR name(s) to remove from integration |
| `--rg`, `--resource-group <name>` | Resource group for the preceding `--acr` |
| `--cloud-sub <id>` | Subscription ID to remove Reader role from (repeatable) |
| `--aks-sub <id>` | Subscription ID to remove AKS RBAC Reader from all clusters (repeatable) |
| `--yes` | Required for destructive/bulk operations |
| `--dry-run` | Show what would be done without making changes |
| `-h`, `--help` | Show help |

## Notes

- Operations are idempotent - running install multiple times is safe
- Subscription IDs must be valid GUIDs (e.g., `11111111-1111-1111-1111-111111111111`)
- The `--yes` flag is required for:
  - Subscription-wide ACR operations
  - Resource group-wide ACR operations (when no specific ACRs listed)
  - Removing the service principal (`--all`)
- Removing specific resources keeps the service principal intact for other integrations
- The `--cloud-sub` flag assigns `Reader` role (read-only) at the subscription scope, allowing Backline to query Azure Resource Manager for runtime asset information
- The `--aks-sub` flag assigns `Azure Kubernetes Service RBAC Reader` at the cluster scope, allowing Backline to read Kubernetes resources (pods, deployments, services, etc.) from within each cluster
