# Configuration Parameters

This directory contains configuration files for Azure integration scripts.

## params.sh

The [params.sh](params.sh) file contains all required configuration parameters. Different customer environments can be managed using separate git branches with environment-specific parameter values.

### Parameters

#### Backline AI EKS OIDC Configuration

These parameters identify Backline AI's infrastructure:

**`AWS_REGION`**
- **Description**: AWS region where Backline AI is deployed
- **Example**: `"us-east-1"`, `"us-west-2"`, `"eu-west-1"`
- **Format**: Standard AWS region identifier

**`OIDC_ID`**
- **Description**: Backline AI's EKS OIDC provider ID (unique identifier from the OIDC issuer URL)
- **Format**: The last part of the OIDC issuer URL after `/id/`
- **Example**: If issuer is `https://oidc.eks.us-east-1.amazonaws.com/id/ABCD1234567890`, use `"ABCD1234567890"`

**`EKS_NAMESPACE`**
- **Description**: Kubernetes namespace in Backline AI where the service account exists
- **Default**: `"backline"`

**`EKS_SERVICE_ACCOUNT`**
- **Description**: Kubernetes service account name in Backline AI that will authenticate to customer Azure ACR
- **Default**: `"integrationhub"`

#### Azure AD Application Configuration

This parameter defines the Azure AD application that will be created in customer's Azure tenant:

**`APP_NAME`**
- **Description**: Display name for the Azure AD Application Registration in customer's Azure AD
- **Default**: `"BACKLINE-AI-ACR-FIC"`
- **Customization**: Can be customized per customer to match their naming conventions

## Example Configuration

```bash
#!/usr/bin/env bash
# Environment-specific configuration

# EKS OIDC Config
AWS_REGION="us-east-1"
OIDC_ID="ABCD1234567890EXAMPLE"
EKS_NAMESPACE="backline"
EKS_SERVICE_ACCOUNT="integrationhub"

# App Registration display name
APP_NAME="BACKLINE-AI-ACR-FIC"
```

## Validation

All parameters are validated by the installation script before execution. If any required parameter is empty, the script will:
- Display an error message indicating which parameter is missing
- Provide guidance on the expected format
- Exit without making any changes
