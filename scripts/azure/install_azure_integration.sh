#!/usr/bin/env bash
set -euo pipefail

# Backline AI Azure Integration - Install Script
# Creates service principal and grants AcrPull and/or Reader permissions

readonly BACKLINE_APP_ID="3fc75f55-e53f-4950-9127-665106cded58"

# Arrays to collect ACR/RG pairs
declare -a ACR_NAMES=()
declare -a RESOURCE_GROUPS=()
# Arrays to collect subscription IDs for Azure Cloud Reader role
declare -a CLOUD_SUBSCRIPTION_IDS=()
SUBSCRIPTION_MODE=false
YES_FLAG=false
DRY_RUN=false
CURRENT_ACR=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Grant Backline AI access to Azure Container Registries and/or Azure Cloud subscriptions.

ACR OPTIONS:
    --acr <name>              ACR name(s), space-delimited for multiple in same RG
    --rg, --resource-group <name>  Resource group for preceding --acr
    --subscription            Add all ACRs in the subscription

AZURE CLOUD OPTIONS:
    --cloud-sub <id>          Subscription ID to grant Reader role (repeatable)

GENERAL OPTIONS:
    --yes                     Skip confirmation for bulk operations
    --dry-run                 Show what would be done without making changes
    -h, --help                Show this help message

EXAMPLES:
    # Single ACR
    $(basename "$0") --acr myacr --rg mygroup

    # Multiple ACRs in same resource group
    $(basename "$0") --acr "acr1 acr2 acr3" --rg mygroup

    # ACRs across different resource groups
    $(basename "$0") --acr acr1 --rg group1 --acr acr2 --rg group2

    # All ACRs in a resource group
    $(basename "$0") --rg mygroup --yes

    # All ACRs in subscription
    $(basename "$0") --subscription --yes

    # Azure Cloud - Reader role on subscriptions
    $(basename "$0") --cloud-sub 11111111-1111-1111-1111-111111111111

    # Azure Cloud - multiple subscriptions
    $(basename "$0") --cloud-sub 11111111-1111-1111-1111-111111111111 --cloud-sub 22222222-2222-2222-2222-222222222222

    # Both ACR and Azure Cloud
    $(basename "$0") --acr myacr --rg mygroup --cloud-sub 11111111-1111-1111-1111-111111111111

    # Interactive mode
    $(basename "$0")
EOF
    exit 0
}

log_info() { echo "[INFO] $*"; }
log_error() { echo "[ERROR] $*" >&2; }
log_success() { echo "[OK] $*"; }
log_dry() { echo "[DRY-RUN] $*"; }

validate_azure_login() {
    if ! az account show &>/dev/null; then
        log_error "Not logged in to Azure. Run 'az login' first."
        exit 1
    fi
    local sub_name
    sub_name=$(az account show --query "name" -o tsv)
    log_info "Azure login validated (subscription: $sub_name)"
}

validate_acr_exists() {
    local acr_name=$1
    local rg=$2
    if ! az acr show -n "$acr_name" -g "$rg" &>/dev/null; then
        log_error "ACR '$acr_name' not found in resource group '$rg'"
        return 1
    fi
}

create_service_principal() {
    log_info "Ensuring service principal exists for Backline AI..."
    
    if az ad sp show --id "$BACKLINE_APP_ID" &>/dev/null; then
        log_info "Service principal already exists"
    else
        if [[ "$DRY_RUN" == true ]]; then
            log_dry "Would create service principal for app $BACKLINE_APP_ID"
        elif az ad sp create --id "$BACKLINE_APP_ID" &>/dev/null; then
            log_success "Service principal created"
        else
            log_error "Failed to create service principal"
            exit 1
        fi
    fi
}

assign_acr_pull() {
    local acr_name=$1
    local rg=$2
    
    local acr_id
    acr_id=$(az acr show -n "$acr_name" -g "$rg" --query "id" -o tsv)
    
    # Check if role already assigned
    if az role assignment list --assignee "$BACKLINE_APP_ID" --scope "$acr_id" --role "AcrPull" --query "[0].id" -o tsv 2>/dev/null | grep -q .; then
        log_info "AcrPull already assigned to '$acr_name', skipping"
    else
        if [[ "$DRY_RUN" == true ]]; then
            log_dry "Would assign AcrPull to '$acr_name' ($acr_id)"
        elif az role assignment create --assignee "$BACKLINE_APP_ID" --role "AcrPull" --scope "$acr_id" &>/dev/null; then
            log_success "AcrPull granted on '$acr_name'"
        else
            log_error "Failed to assign AcrPull on '$acr_name'"
            return 1
        fi
    fi
}

validate_guid() {
    local value=$1
    local label=$2
    if [[ ! "$value" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
        log_error "Invalid GUID format for $label: $value"
        return 1
    fi
}

assign_reader_role() {
    local sub_id=$1
    local scope="/subscriptions/$sub_id"

    # Check if role already assigned
    if az role assignment list --assignee "$BACKLINE_APP_ID" --scope "$scope" --role "Reader" --query "[0].id" -o tsv 2>/dev/null | grep -q .; then
        log_info "Reader already assigned on subscription '$sub_id', skipping"
    else
        if [[ "$DRY_RUN" == true ]]; then
            log_dry "Would assign Reader to subscription '$sub_id'"
        elif az role assignment create --assignee "$BACKLINE_APP_ID" --role "Reader" --scope "$scope" &>/dev/null; then
            log_success "Reader granted on subscription '$sub_id'"
        else
            log_error "Failed to assign Reader on subscription '$sub_id'"
            return 1
        fi
    fi
}

discover_acrs_in_rg() {
    local rg=$1
    az acr list -g "$rg" --query "[].name" -o tsv 2>/dev/null || echo ""
}

discover_acrs_in_subscription() {
    az acr list --query "[].{name:name, rg:resourceGroup}" -o tsv 2>/dev/null || echo ""
}

interactive_mode() {
    echo ""
    echo "=== Backline AI Azure Integration Setup ==="
    echo ""
    echo "Select mode:"
    echo "  1) Single ACR or multiple ACRs in one resource group"
    echo "  2) All ACRs in a resource group"
    echo "  3) All ACRs in subscription"
    echo "  4) Azure Cloud - Reader role on subscriptions"
    echo ""
    read -rp "Choice [1-4]: " choice

    case $choice in
        1)
            read -rp "Enter ACR name(s) (space-delimited): " acr_input
            read -rp "Enter Resource Group: " rg_input
            for acr in $acr_input; do
                ACR_NAMES+=("$acr")
                RESOURCE_GROUPS+=("$rg_input")
            done
            ;;
        2)
            read -rp "Enter Resource Group: " rg_input
            read -rp "This will add all ACRs in '$rg_input'. Continue? (y/n): " confirm
            [[ "$confirm" != "y"* ]] && { echo "Cancelled."; exit 0; }
            YES_FLAG=true  # User confirmed interactively

            local acrs
            acrs=$(discover_acrs_in_rg "$rg_input")
            if [[ -z "$acrs" ]]; then
                log_error "No ACRs found in resource group '$rg_input'"
                exit 1
            fi
            for acr in $acrs; do
                ACR_NAMES+=("$acr")
                RESOURCE_GROUPS+=("$rg_input")
            done
            ;;
        3)
            read -rp "This will add ALL ACRs in the subscription. Continue? (y/n): " confirm
            [[ "$confirm" != "y"* ]] && { echo "Cancelled."; exit 0; }
            SUBSCRIPTION_MODE=true
            YES_FLAG=true  # User confirmed interactively
            ;;
        4)
            read -rp "Enter Subscription ID(s) (space-delimited): " sub_input
            for sub_id in $sub_input; do
                validate_guid "$sub_id" "subscription ID" || exit 1
                CLOUD_SUBSCRIPTION_IDS+=("$sub_id")
            done
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --acr)
                [[ $# -lt 2 || "$2" == --* ]] && { log_error "--acr requires a value"; exit 1; }
                CURRENT_ACR="$2"
                shift 2
                ;;
            --rg|--resource-group)
                [[ $# -lt 2 || "$2" == --* ]] && { log_error "--rg requires a value"; exit 1; }
                local rg="$2"
                if [[ -n "$CURRENT_ACR" ]]; then
                    # Expand space-delimited ACR names
                    for acr in $CURRENT_ACR; do
                        ACR_NAMES+=("$acr")
                        RESOURCE_GROUPS+=("$rg")
                    done
                    CURRENT_ACR=""
                else
                    # RG without ACR = all ACRs in that RG
                    local acrs
                    acrs=$(discover_acrs_in_rg "$rg")
                    if [[ -z "$acrs" ]]; then
                        log_error "No ACRs found in resource group '$rg'"
                        exit 1
                    fi
                    for acr in $acrs; do
                        ACR_NAMES+=("$acr")
                        RESOURCE_GROUPS+=("$rg")
                    done
                fi
                shift 2
                ;;
            --subscription)
                SUBSCRIPTION_MODE=true
                shift
                ;;
            --cloud-sub)
                [[ $# -lt 2 || "$2" == --* ]] && { log_error "--cloud-sub requires a subscription ID"; exit 1; }
                validate_guid "$2" "subscription ID" || exit 1
                CLOUD_SUBSCRIPTION_IDS+=("$2")
                shift 2
                ;;
            --yes)
                YES_FLAG=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    # Check for unpaired --acr
    if [[ -n "$CURRENT_ACR" ]]; then
        log_error "--acr requires a following --rg"
        exit 1
    fi
}

main() {
    if [[ $# -eq 0 ]]; then
        interactive_mode
    else
        parse_args "$@"
    fi
    
    # Validate bulk operations require --yes (unless dry-run)
    if [[ "$DRY_RUN" != true ]]; then
        if [[ "$SUBSCRIPTION_MODE" == true ]] && [[ "$YES_FLAG" != true ]]; then
            log_error "Subscription-wide operation requires --yes flag"
            exit 1
        fi
        
        if [[ ${#ACR_NAMES[@]} -gt 1 ]] && [[ "$YES_FLAG" != true ]]; then
            # Check if this came from RG-only mode (bulk)
            local unique_rgs
            unique_rgs=$(printf '%s\n' "${RESOURCE_GROUPS[@]}" | sort -u | wc -l)
            if [[ $unique_rgs -eq 1 ]] && [[ ${#ACR_NAMES[@]} -gt 3 ]]; then
                log_error "Bulk operations (resource group-wide) require --yes flag"
                exit 1
            fi
        fi
    fi
    
    validate_azure_login
    
    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        echo "========== DRY RUN MODE =========="
        echo "No changes will be made"
        echo "=================================="
    fi
    
    create_service_principal
    
    local has_acr=false
    local has_cloud=false

    if [[ "$SUBSCRIPTION_MODE" == true ]] || [[ ${#ACR_NAMES[@]} -gt 0 ]]; then
        has_acr=true
    fi
    if [[ ${#CLOUD_SUBSCRIPTION_IDS[@]} -gt 0 ]]; then
        has_cloud=true
    fi

    if [[ "$has_acr" != true ]] && [[ "$has_cloud" != true ]]; then
        log_error "No ACRs or cloud subscriptions specified"
        exit 1
    fi

    if [[ "$has_acr" == true ]]; then
        echo ""
        log_info "Processing ACR integrations..."

        if [[ "$SUBSCRIPTION_MODE" == true ]]; then
            while IFS=$'\t' read -r acr rg; do
                [[ -z "$acr" ]] && continue
                assign_acr_pull "$acr" "$rg"
            done < <(discover_acrs_in_subscription)
        else
            for i in "${!ACR_NAMES[@]}"; do
                local acr="${ACR_NAMES[$i]}"
                local rg="${RESOURCE_GROUPS[$i]}"

                if ! validate_acr_exists "$acr" "$rg"; then
                    continue
                fi
                assign_acr_pull "$acr" "$rg"
            done
        fi
    fi

    if [[ "$has_cloud" == true ]]; then
        echo ""
        log_info "Processing Azure Cloud integrations (Reader role)..."

        for sub_id in "${CLOUD_SUBSCRIPTION_IDS[@]}"; do
            assign_reader_role "$sub_id"
        done
    fi

    echo ""
    log_success "Integration complete"
    echo ""
    echo "Backline App ID: $BACKLINE_APP_ID"
    echo "Tenant ID: $(az account show --query tenantId -o tsv)"
}

main "$@"

