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

See [scripts/azure/README.md](scripts/azure/README.md) for full documentation.

## Prerequisites

- Azure CLI installed
- Logged in to Azure (`az login`)
- Appropriate permissions to create service principals and assign roles
