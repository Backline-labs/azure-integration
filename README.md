# Azure Integration for Backline AI

Scripts for integrating Backline AI with Azure services.

## Available Integrations

### Azure Container Registry (ACR)

Grant Backline AI access to pull images from your ACRs.

```bash
cd scripts/azure

# Add single ACR
./install_azure_integration.sh --acr myacr --rg mygroup

# Remove access
./cleanup_azure_integration.sh --acr myacr --rg mygroup
```

### Azure Cloud

Grant Backline AI read-only access to your Azure subscriptions for runtime asset analysis (exploitability assessment).

```bash
cd scripts/azure

# Grant Reader role on a subscription
./install_azure_integration.sh --cloud-sub <subscription-id>

# Grant Reader role on multiple subscriptions
./install_azure_integration.sh --cloud-sub <sub-id-1> --cloud-sub <sub-id-2>

# Remove Reader role
./cleanup_azure_integration.sh --cloud-sub <subscription-id>
```

### AKS (Kubernetes)

Grant Backline AI read access to Kubernetes resources (pods, deployments, services, etc.) inside your AKS clusters.

> **Prerequisite:** Each cluster must have Azure RBAC for Kubernetes enabled:
> ```bash
> az aks update --resource-group <rg> --name <cluster-name> --enable-azure-rbac
> ```

```bash
cd scripts/azure

# Grant access - prompts per cluster to select which ones to include
./install_azure_integration.sh --aks-sub <subscription-id>

# Grant access to all clusters without prompting
./install_azure_integration.sh --aks-sub <subscription-id> --aks-all

# Remove access from all clusters in a subscription
./cleanup_azure_integration.sh --aks-sub <subscription-id>
```

See [scripts/azure/README.md](scripts/azure/README.md) for full documentation.

## Prerequisites

- Azure CLI installed
- Logged in to Azure (`az login`)
- Appropriate permissions to create service principals and assign roles
