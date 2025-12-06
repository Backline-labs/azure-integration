#!/usr/bin/env bash
set -euo pipefail

# Determine script location for path resolution
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Load environment parameters
source "$PROJECT_ROOT/config/params.sh"
source "$SCRIPT_DIR/validate.sh"

echo ""
echo "=== Azure ACR Federated Identity Cleanup ==="
echo ""

# Validate Azure login
validate_az_login

echo "Application to remove: $APP_NAME"
echo ""
read -p "Are you sure you want to delete this application and all associated resources? (y/n): " CONFIRM

if [[ "$CONFIRM" != "y"* ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Find the application
APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv 2>/dev/null || echo "")

if [[ -z "$APP_ID" ]]; then
    echo "Application '$APP_NAME' not found. Nothing to clean up."
    exit 0
fi

echo ""
echo "Found Application ID: $APP_ID"

# Get Service Principal Object ID
SP_OBJECT_ID=$(az ad sp list --filter "appId eq '$APP_ID'" --query "[0].objectId" -o tsv 2>/dev/null || echo "")

if [[ -n "$SP_OBJECT_ID" ]]; then
    echo "Found Service Principal: $SP_OBJECT_ID"

    echo ""
    echo "Removing role assignments..."

    # Get all role assignments for this service principal
    ROLE_ASSIGNMENTS=$(az role assignment list --assignee "$SP_OBJECT_ID" --query "[].id" -o tsv 2>/dev/null || echo "")

    if [[ -n "$ROLE_ASSIGNMENTS" ]]; then
        for ROLE_ID in $ROLE_ASSIGNMENTS; do
            if az role assignment delete --ids "$ROLE_ID" >/dev/null 2>&1; then
                echo "  Removed role assignment: $ROLE_ID"
            else
                echo "  WARNING: Failed to remove role assignment: $ROLE_ID"
            fi
        done
    else
        echo "  No role assignments found"
    fi
fi

echo ""
echo "Removing federated identity credentials..."

# List and remove all federated credentials
FIC_IDS=$(az ad app federated-credential list --id "$APP_ID" --query "[].id" -o tsv 2>/dev/null || echo "")

if [[ -n "$FIC_IDS" ]]; then
    for FIC_ID in $FIC_IDS; do
        if az ad app federated-credential delete --id "$APP_ID" --federated-credential-id "$FIC_ID" >/dev/null 2>&1; then
            echo "  Removed federated credential: $FIC_ID"
        else
            echo "  WARNING: Failed to remove federated credential: $FIC_ID"
        fi
    done
else
    echo "  No federated credentials found"
fi

echo ""
echo "Removing service principal..."

if [[ -n "$SP_OBJECT_ID" ]]; then
    if az ad sp delete --id "$SP_OBJECT_ID" >/dev/null 2>&1; then
        echo "  Service principal deleted"
    else
        echo "  WARNING: Failed to delete service principal"
    fi
else
    echo "  Service principal not found"
fi

echo ""
echo "Removing application registration..."

if az ad app delete --id "$APP_ID" >/dev/null 2>&1; then
    echo "  Application registration deleted"
else
    echo "  WARNING: Failed to delete application registration"
    exit 1
fi

echo ""
echo "=== Cleanup Complete ==="
echo ""
echo "All resources for '$APP_NAME' have been removed."
