#!/usr/bin/env bash
set -euo pipefail

# Determine script location for path resolution
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Load environment parameters
source "$PROJECT_ROOT/config/params.sh"
source "$SCRIPT_DIR/validate.sh"

echo ""
echo "=== Azure ACR Federated Identity Setup for Backline AI ==="
echo ""

# Ask customer for runtime input
read -p "Enter ACR name: " ACR_NAME
read -p "Enter Resource Group name: " RG_NAME

# --- Validate environment ---
validate_az_login
validate_acr "$ACR_NAME" "$RG_NAME"
validate_permissions "$RG_NAME"
validate_params

ACR_ID=$(az acr show -n "$ACR_NAME" -g "$RG_NAME" --query "id" -o tsv)

echo ""
echo "=== Creating Azure AD Application ==="

# Check if application already exists
EXISTING_APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv 2>/dev/null || echo "")

if [[ -n "$EXISTING_APP_ID" ]]; then
    echo "Application '$APP_NAME' already exists with ID: $EXISTING_APP_ID"
    APP_ID="$EXISTING_APP_ID"

    # Get existing service principal
    SP_OBJECT_ID=$(az ad sp show --id $APP_ID --query "id" -o tsv 2>/dev/null || echo "")

    if [[ -z "$SP_OBJECT_ID" ]]; then
        echo "Creating Service Principal for existing application..."
        SP_OBJECT_ID=$(az ad sp create --id "$APP_ID" --query "id" -o tsv)
        echo "Service Principal created: $SP_OBJECT_ID"
    else
        echo "Service Principal already exists: $SP_OBJECT_ID"
    fi
else
    APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
    if [[ -z "$APP_ID" ]]; then
        echo "ERROR: Failed to create Azure AD Application"
        exit 1
    fi
    echo "Application created: $APP_ID"

    echo "Creating Service Principal..."
    SP_OBJECT_ID=$(az ad sp create --id "$APP_ID" --query "id" -o tsv)
    if [[ -z "$SP_OBJECT_ID" ]]; then
        echo "ERROR: Failed to create Service Principal"
        exit 1
    fi
    echo "Service Principal created: $SP_OBJECT_ID"
fi

echo ""
echo "=== Creating Federated Identity Credential ==="
EKS_OIDC_ISSUER_URL="https://oidc.eks.$AWS_REGION.amazonaws.com/id/$OIDC_ID"
FIC_NAME="Backline-AI-$AWS_REGION"

# Check if FIC already exists
EXISTING_FIC=$(az ad app federated-credential list --id "$APP_ID" --query "[?name=='$FIC_NAME'].name" -o tsv 2>/dev/null || echo "")

if [[ -n "$EXISTING_FIC" ]]; then
    echo "Federated Identity Credential '$FIC_NAME' already exists, skipping..."
else
    if az ad app federated-credential create \
      --id "$APP_ID" \
      --parameters "{
        \"name\": \"$FIC_NAME\",
        \"issuer\": \"${EKS_OIDC_ISSUER_URL}\",
        \"subject\": \"system:serviceaccount:${EKS_NAMESPACE}:${EKS_SERVICE_ACCOUNT}\",
        \"audiences\": [\"api://AzureADTokenExchange\"]
      }" >/dev/null 2>&1; then
        echo "Federated Identity Credential '$FIC_NAME' created successfully"
    else
        echo "ERROR: Failed to create Federated Identity Credential"
        exit 1
    fi
fi

echo ""
echo "=== Assigning ACR Roles ==="

# Check and assign AcrPull role
if az role assignment list --assignee "$SP_OBJECT_ID" --scope "$ACR_ID" --role "AcrPull" --query "[0].id" -o tsv 2>/dev/null | grep -q .; then
    echo "AcrPull role already assigned, skipping..."
else
    if az role assignment create --assignee "$SP_OBJECT_ID" --role "AcrPull" --scope "$ACR_ID" >/dev/null 2>&1; then
        echo "AcrPull role assigned successfully"
    else
        echo "WARNING: Failed to assign AcrPull role (may already exist)"
    fi
fi

# Check and assign AcrReader role
if az role assignment list --assignee "$SP_OBJECT_ID" --scope "$ACR_ID" --role "Reader" --query "[0].id" -o tsv 2>/dev/null | grep -q .; then
    echo "Reader role already assigned, skipping..."
else
    if az role assignment create --assignee "$SP_OBJECT_ID" --role "Reader" --scope "$ACR_ID" >/dev/null 2>&1; then
        echo "Reader role assigned successfully"
    else
        echo "WARNING: Failed to assign Reader role (may already exist)"
    fi
fi

echo ""
echo "=== DONE ==="
echo ""
echo "Tenant ID: $(az account show --query tenantId -o tsv)"
echo "Application (Client) ID: $APP_ID"
echo "Service Principal Object ID: $SP_OBJECT_ID"
echo "Federated Identity Credential: $FIC_NAME"
echo "ACR Resource ID: $ACR_ID"
echo ""
echo "Your Azure AD app is ready for OIDC authentication from EKS."
