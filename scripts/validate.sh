#!/usr/bin/env bash
set -euo pipefail

validate_az_login() {
    if ! az account show >/dev/null 2>&1; then
        echo "ERROR: You must be logged into Azure CLI or Cloud Shell."
        exit 1
    fi
}

validate_acr() {
    local acr_name="$1"
    local rg="$2"
    if ! az acr show -n "$acr_name" -g "$rg" >/dev/null 2>&1; then
        echo "ERROR: ACR '${acr_name}' not found in resource group '${rg}'."
        exit 1
    fi
}

validate_permissions() {
    local rg="$1"
    if ! az role assignment list --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$rg" >/dev/null 2>&1; then
        echo "ERROR: You do not have permission to assign roles in resource group '${rg}'."
        exit 1
    fi
}

validate_params() {
    local errors=0

    if [[ -z "$AWS_REGION" ]]; then
        echo "ERROR: AWS_REGION is not set in config/params.sh"
        echo "       Example: AWS_REGION=\"us-east-1\""
        errors=$((errors + 1))
    fi

    if [[ -z "$OIDC_ID" ]]; then
        echo "ERROR: OIDC_ID is not set in config/params.sh"
        echo "       Find it with: aws eks describe-cluster --name <cluster-name> --query 'cluster.identity.oidc.issuer' --output text"
        errors=$((errors + 1))
    fi

    if [[ -z "$EKS_NAMESPACE" ]]; then
        echo "ERROR: EKS_NAMESPACE is not set in config/params.sh"
        errors=$((errors + 1))
    fi

    if [[ -z "$EKS_SERVICE_ACCOUNT" ]]; then
        echo "ERROR: EKS_SERVICE_ACCOUNT is not set in config/params.sh"
        errors=$((errors + 1))
    fi

    if [[ -z "$APP_NAME" ]]; then
        echo "ERROR: APP_NAME is not set in config/params.sh"
        errors=$((errors + 1))
    fi

    if [[ $errors -gt 0 ]]; then
        echo ""
        echo "Please configure the required parameters in config/params.sh before running this script."
        exit 1
    fi
}