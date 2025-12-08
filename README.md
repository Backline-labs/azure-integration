# Azure Integration for Backline AI

Scripts for integrating Backline AI with Azure services.

## Available Integrations

### Azure Container Registry (ACR)

Grant Backline AI access to pull images from your ACRs.

```bash
cd scripts/acr

# Add single ACR
./install_acr_integration.sh --acr myacr --rg mygroup

# Remove access
./cleanup_acr_integration.sh --acr myacr --rg mygroup
```

See [scripts/acr/README.md](scripts/acr/README.md) for full documentation.

## Prerequisites

- Azure CLI installed
- Logged in to Azure (`az login`)
- Appropriate permissions to create service principals and assign roles
