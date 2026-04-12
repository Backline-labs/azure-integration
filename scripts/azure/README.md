# Backline AI - Azure Integration Scripts

Scripts to grant Backline AI access to Azure Container Registries and Azure Cloud subscriptions.

## Prerequisites

- Azure CLI installed and logged in (`az login`)
- Permissions to create service principals and assign roles

## Scripts

### install_azure_integration.sh

Grants Backline AI access to specified Azure Container Registries (`AcrPull` role) and/or Azure Cloud subscriptions (`Reader` role).

**What it does:**
1. Creates a service principal for Backline AI in your tenant (if not exists)
2. Assigns `AcrPull` role on specified ACR(s) (for container registry integration)
3. Assigns `Reader` role on specified subscriptions (for Azure Cloud integration)

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
| `--yes` | Required for bulk operations |
| `--dry-run` | Show what would be done without making changes |
| `-h`, `--help` | Show help |

---

### cleanup_azure_integration.sh

Removes Backline AI access from ACRs, Azure Cloud subscriptions, or removes the service principal entirely.

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
| `--yes` | Required for destructive/bulk operations |
| `--dry-run` | Show what would be done without making changes |
| `-h`, `--help` | Show help |

## Notes

- Operations are idempotent - running install multiple times is safe
- Subscription IDs must be valid GUIDs (e.g., `11111111-1111-1111-1111-111111111111`)
- The `--yes` flag is required for:
  - Subscription-wide operations (ACR discovery)
  - Resource group-wide operations (when no specific ACRs listed)
  - Removing the service principal (`--all`)
- Removing specific ACRs or cloud subscriptions keeps the service principal intact for other integrations
- The `--cloud-sub` flag assigns `Reader` role (read-only) at the subscription scope, allowing Backline to query Azure Resource Manager for runtime asset information
