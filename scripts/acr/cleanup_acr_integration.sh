#!/usr/bin/env bash
set -euo pipefail

# Backline AI ACR Integration - Cleanup Script
# Removes service principal or specific ACR permissions

readonly BACKLINE_APP_ID="3fc75f55-e53f-4950-9127-665106cded58"

# Arrays to collect ACR/RG pairs
declare -a ACR_NAMES=()
declare -a RESOURCE_GROUPS=()
ALL_MODE=false
YES_FLAG=false
DRY_RUN=false
CURRENT_ACR=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Remove Backline AI access from Azure Container Registries.

OPTIONS:
    --all                     Remove service principal completely (all ACR access)
    --acr <name>              ACR name(s), space-delimited for multiple in same RG
    --rg, --resource-group <name>  Resource group for preceding --acr
    --yes                     Skip confirmation for destructive operations
    --dry-run                 Show what would be done without making changes
    -h, --help                Show this help message

EXAMPLES:
    # Remove service principal completely
    $(basename "$0") --all --yes

    # Remove specific ACR
    $(basename "$0") --acr myacr --rg mygroup

    # Remove multiple ACRs in same resource group
    $(basename "$0") --acr "acr1 acr2" --rg mygroup

    # ACRs across different resource groups
    $(basename "$0") --acr acr1 --rg group1 --acr acr2 --rg group2

    # Remove all ACRs in resource group from integration
    $(basename "$0") --rg mygroup --yes

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

get_sp_object_id() {
    az ad sp show --id "$BACKLINE_APP_ID" --query "id" -o tsv 2>/dev/null || echo ""
}

discover_acrs_in_rg() {
    local rg=$1
    az acr list -g "$rg" --query "[].name" -o tsv 2>/dev/null || echo ""
}

remove_acr_role() {
    local acr_name=$1
    local rg=$2
    
    local acr_id
    acr_id=$(az acr show -n "$acr_name" -g "$rg" --query "id" -o tsv 2>/dev/null || echo "")
    
    if [[ -z "$acr_id" ]]; then
        log_error "ACR '$acr_name' not found in resource group '$rg'"
        return 1
    fi
    
    # Get role assignment for this ACR
    local role_id
    role_id=$(az role assignment list --assignee "$BACKLINE_APP_ID" --scope "$acr_id" --role "AcrPull" --query "[0].id" -o tsv 2>/dev/null || echo "")
    
    if [[ -z "$role_id" ]]; then
        log_info "No AcrPull role found on '$acr_name', skipping"
    else
        if [[ "$DRY_RUN" == true ]]; then
            log_dry "Would remove AcrPull from '$acr_name' ($acr_id)"
        elif az role assignment delete --ids "$role_id" &>/dev/null; then
            log_success "Removed AcrPull from '$acr_name'"
        else
            log_error "Failed to remove AcrPull from '$acr_name'"
            return 1
        fi
    fi
}

remove_all_roles_and_sp() {
    local sp_object_id
    sp_object_id=$(get_sp_object_id)
    
    if [[ -z "$sp_object_id" ]]; then
        log_info "Service principal not found, nothing to clean up"
        return 0
    fi
    
    log_info "Found service principal: $sp_object_id"
    
    # Remove all role assignments
    log_info "Removing all role assignments..."
    local role_ids
    role_ids=$(az role assignment list --assignee "$BACKLINE_APP_ID" --all --query "[].id" -o tsv 2>/dev/null || echo "")
    
    if [[ -n "$role_ids" ]]; then
        while IFS= read -r role_id; do
            [[ -z "$role_id" ]] && continue
            if [[ "$DRY_RUN" == true ]]; then
                log_dry "Would remove role assignment: $role_id"
            elif az role assignment delete --ids "$role_id" &>/dev/null; then
                log_success "Removed role assignment"
            else
                log_error "Failed to remove role assignment: $role_id"
            fi
        done <<< "$role_ids"
    else
        log_info "No role assignments found"
    fi
    
    # Delete service principal
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "Would delete service principal $BACKLINE_APP_ID"
    else
        log_info "Removing service principal..."
        if az ad sp delete --id "$BACKLINE_APP_ID" &>/dev/null; then
            log_success "Service principal deleted"
        else
            log_error "Failed to delete service principal (may already be deleted)"
        fi
    fi
}

interactive_mode() {
    echo ""
    echo "=== Backline AI ACR Integration Cleanup ==="
    echo ""
    echo "Select mode:"
    echo "  1) Remove specific ACR(s) from integration"
    echo "  2) Remove all ACRs in a resource group from integration"
    echo "  3) Remove service principal completely (removes all access)"
    echo ""
    read -rp "Choice [1-3]: " choice
    
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
            read -rp "This will remove all ACRs in '$rg_input' from integration. Continue? (y/n): " confirm
            [[ "$confirm" != "y"* ]] && { echo "Cancelled."; exit 0; }
            
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
            read -rp "This will DELETE the service principal and ALL ACR access. Continue? (y/n): " confirm
            [[ "$confirm" != "y"* ]] && { echo "Cancelled."; exit 0; }
            ALL_MODE=true
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
            --all)
                ALL_MODE=true
                shift
                ;;
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
    
    # Validate destructive operations require --yes (unless dry-run)
    if [[ "$DRY_RUN" != true ]]; then
        if [[ "$ALL_MODE" == true ]] && [[ "$YES_FLAG" != true ]]; then
            log_error "--all requires --yes flag (destructive operation)"
            exit 1
        fi
        
        # Check for RG-wide bulk removal
        if [[ ${#ACR_NAMES[@]} -gt 3 ]] && [[ "$YES_FLAG" != true ]]; then
            local unique_rgs
            unique_rgs=$(printf '%s\n' "${RESOURCE_GROUPS[@]}" | sort -u | wc -l)
            if [[ $unique_rgs -eq 1 ]]; then
                log_error "Bulk removal requires --yes flag"
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
    
    echo ""
    
    if [[ "$ALL_MODE" == true ]]; then
        log_info "Removing service principal and all ACR access..."
        remove_all_roles_and_sp
    else
        if [[ ${#ACR_NAMES[@]} -eq 0 ]]; then
            log_error "No ACRs specified. Use --acr/--rg or --all"
            exit 1
        fi
        
        log_info "Removing ACR permissions..."
        for i in "${!ACR_NAMES[@]}"; do
            local acr="${ACR_NAMES[$i]}"
            local rg="${RESOURCE_GROUPS[$i]}"
            remove_acr_role "$acr" "$rg"
        done
    fi
    
    echo ""
    log_success "Cleanup complete"
}

main "$@"

