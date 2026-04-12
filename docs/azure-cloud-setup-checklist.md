# Azure Cloud Integration - Infrastructure Setup Checklist

One-time manual steps required on Backline's side before the Azure Cloud integration is functional.

## 1. Federated Credentials on App Registration

Add federated credential entries on the Backline App Registration (`3fc75f55-e53f-4950-9127-665106cded58`) trusting the **runner** service account for each EKS cluster.

The integrationhub pod already has its own federated credential entry for `system:serviceaccount:backline:integrationhub`. The runner needs its own entry because the Threat Analysis Agent runs as a Kubernetes Job under the runner service account and needs to acquire Azure AD tokens for MCP server authentication.

### Staging (us-west-1)

```bash
az ad app federated-credential create --id <app-object-id> --parameters '{
  "name": "eks-staging-us-west-1-runner",
  "issuer": "<staging-eks-cluster-oidc-issuer-url>",
  "subject": "system:serviceaccount:backline:runner",
  "audiences": ["sts.amazonaws.com"],
  "description": "EKS staging runner SA for Azure Cloud integration"
}'
```

### Production (us-east-1)

```bash
az ad app federated-credential create --id <app-object-id> --parameters '{
  "name": "eks-prod-us-east-1-runner",
  "issuer": "<prod-eks-cluster-oidc-issuer-url>",
  "subject": "system:serviceaccount:backline:runner",
  "audiences": ["sts.amazonaws.com"],
  "description": "EKS prod runner SA for Azure Cloud integration"
}'
```

**To find the EKS OIDC issuer URL:**
```bash
aws eks describe-cluster --name <cluster-name> --query "cluster.identity.oidc.issuer" --output text --profile <aws-profile>
```

## 2. App Registration API Permission

Add the Azure Resource Manager scope to the App Registration:

- Scope: `https://management.azure.com/.default`
- Type: Delegated permission on Azure Resource Manager

This can be done via Azure Portal:
1. Go to App Registrations > Backline AI app
2. API Permissions > Add a permission
3. Azure Service Management > user_impersonation
4. Grant admin consent

Or via CLI:
```bash
# Azure Service Management API ID: 797f4846-ba00-4fd7-ba43-dac1f8f63013
az ad app permission add --id <app-id> \
  --api 797f4846-ba00-4fd7-ba43-dac1f8f63013 \
  --api-permissions 41094075-9dad-400e-a0bd-54e686782033=Scope
```

## 3. cd-gitops Changes (PR Required)

- [x] `AZURE_CLOUD_APPLICATION_ID` env var added to integrationhub configmap (same App ID: `3fc75f55-e53f-4950-9127-665106cded58`)
- [x] Threat analysis agent job memory limits set (requests: 1Gi, limits: 3Gi) to accommodate Azure MCP server subprocesses (~50-80 MB RSS each)

## Verification

After completing the above steps:
1. Deploy the updated integrationhub (with Azure Cloud adapter code from Tasks 1-2)
2. Deploy the updated threat analysis agent (with Azure MCP provider from Task 3)
3. Create an Azure Cloud integration in the UI with a customer's Tenant ID and Subscription IDs
4. Run TestConnection — should successfully acquire token and list resource groups
5. Trigger a threat analysis run on a CVE — should see Azure MCP tools available in the agent's tool list
