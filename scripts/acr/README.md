# Backline AI - Azure Container Registry Integration

Scripts to grant Backline AI access to pull images from your Azure Container Registries.

## Prerequisites

- Azure CLI installed and logged in (`az login`)
- Permissions to create service principals and assign roles

## Scripts

### install_acr_integration.sh

Grants Backline AI `AcrPull` access to specified Azure Container Registries.

**What it does:**
1. Creates a service principal for Backline AI in your tenant (if not exists)
2. Assigns `AcrPull` role on specified ACR(s)

**Usage:**

```bash
# Single ACR
./install_acr_integration.sh --acr myacr --rg mygroup

# Multiple ACRs in same resource group
./install_acr_integration.sh --acr "acr1 acr2 acr3" --rg mygroup

# ACRs across different resource groups
./install_acr_integration.sh --acr acr1 --rg group1 --acr acr2 --rg group2

# All ACRs in a resource group
./install_acr_integration.sh --rg mygroup --yes

# All ACRs in subscription
./install_acr_integration.sh --subscription --yes

# Interactive mode
./install_acr_integration.sh
```

**Options:**

| Option | Description |
|--------|-------------|
| `--acr <name>` | ACR name(s), space-delimited for multiple |
| `--rg`, `--resource-group <name>` | Resource group for the preceding `--acr` |
| `--subscription` | Add all ACRs in the subscription |
| `--yes` | Required for bulk operations |
| `--dry-run` | Show what would be done without making changes |
| `-h`, `--help` | Show help |

---

### cleanup_acr_integration.sh

Removes Backline AI access from ACRs or removes the service principal entirely.

**Usage:**

```bash
# Remove service principal completely (removes ALL ACR access)
./cleanup_acr_integration.sh --all --yes

# Remove specific ACR
./cleanup_acr_integration.sh --acr myacr --rg mygroup

# Remove multiple ACRs
./cleanup_acr_integration.sh --acr "acr1 acr2" --rg mygroup

# ACRs across different resource groups
./cleanup_acr_integration.sh --acr acr1 --rg group1 --acr acr2 --rg group2

# Remove all ACRs in resource group from integration
./cleanup_acr_integration.sh --rg mygroup --yes

# Interactive mode
./cleanup_acr_integration.sh
```

**Options:**

| Option | Description |
|--------|-------------|
| `--all` | Remove service principal completely |
| `--acr <name>` | ACR name(s) to remove from integration |
| `--rg`, `--resource-group <name>` | Resource group for the preceding `--acr` |
| `--yes` | Required for destructive/bulk operations |
| `--dry-run` | Show what would be done without making changes |
| `-h`, `--help` | Show help |

## Notes

- Operations are idempotent - running install multiple times is safe
- The `--yes` flag is required for:
  - Subscription-wide operations
  - Resource group-wide operations (when no specific ACRs listed)
  - Removing the service principal (`--all`)
- Removing specific ACRs keeps the service principal intact for other integrations

