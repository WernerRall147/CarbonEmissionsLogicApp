# Carbon Emissions Logic App - Deployment Guide

## Overview

This guide walks through deploying the Azure Logic App for automated carbon emissions data export. The solution uses Infrastructure-as-Code (Bicep) to deploy all required Azure resources with proper security configuration.

## Prerequisites

### Required Tools
- **Azure CLI** (version 2.50.0 or later)
- **Bicep CLI** (installed via Azure CLI)
- **PowerShell** (for deployment scripts)
- **Azure Developer CLI (azd)** (optional, for simplified deployment)

### Required Permissions
- **Subscription Contributor** role on target Azure subscription
- **User Access Administrator** role (to assign RBAC roles)
- **Carbon Optimization Reader** role on subscriptions to export data from

### Azure Requirements
- Azure subscription with Carbon Optimization enabled
- Microsoft.Carbon resource provider registered
- Target subscriptions with carbon emissions data available

## Deployment Options

### Option 1: Azure Developer CLI (Recommended)

The simplest deployment method using Azure Developer CLI:

```bash
# Initialize and deploy
azd init --template carbon-emissions-logic-app
azd up
```

### Option 2: PowerShell Script

Use the provided PowerShell deployment script:

```powershell
# Navigate to project directory
cd c:\Users\weral\Git\CarbonEmissionsLogicApp

# Run deployment script with your subscription IDs
.\src\scripts\Deploy-CarbonEmissionsLogicApp.ps1 -SubscriptionIds @("your-subscription-id-1", "your-subscription-id-2")

# Or deploy with what-if analysis first
.\src\scripts\Deploy-CarbonEmissionsLogicApp.ps1 -SubscriptionIds @("your-subscription-id") -WhatIf
```

### Option 3: Manual Azure CLI Deployment

For manual control over the deployment:

```bash
# Login to Azure
az login

# Create resource group
az group create --name rg-carbon-emissions-dev --location "East US 2"

# Validate Bicep template
az deployment group validate \
  --resource-group rg-carbon-emissions-dev \
  --template-file src/infrastructure/main.bicep \
  --parameters src/infrastructure/main.parameters.json

# Deploy resources
az deployment group create \
  --name carbon-emissions-deployment \
  --resource-group rg-carbon-emissions-dev \
  --template-file src/infrastructure/main.bicep \
  --parameters src/infrastructure/main.parameters.json
```

## Configuration

### Update Parameters

Before deployment, update `src/infrastructure/main.parameters.json`:

```json
{
  "parameters": {
    "subscriptionIds": {
      "value": [        "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
        "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
      ]
    },
    "environmentName": {
      "value": "prod"
    },
    "scheduleDay": {
      "value": 20
    }
  }
}
```

### Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `subscriptionIds` | Array of subscription IDs to export data for | `[]` |
| `environmentName` | Environment (dev/test/prod) | `dev` |
| `location` | Azure region for resources | `East US 2` |
| `scheduleDay` | Day of month to run (1-28) | `20` |
| `containerName` | Blob container name | `carbon-emissions-reports` |

## Resources Deployed

The Bicep template deploys the following Azure resources:

### 1. Storage Account
- **Purpose**: Store CSV exports
- **SKU**: Standard_LRS
- **Security**: Azure AD authentication only, HTTPS required
- **Features**: Soft delete enabled, public access disabled

### 2. Blob Container
- **Name**: `carbon-emissions-reports` (configurable)
- **Access**: Private
- **Purpose**: Store monthly CSV files

### 3. Logic App (Consumption)
- **Schedule**: Monthly on specified day at midnight UTC
- **Identity**: System-assigned managed identity
- **Workflow**: Automated carbon data export and CSV generation

### 4. RBAC Role Assignments
- **Storage Blob Data Contributor**: Logic App → Storage Account
- **Carbon Optimization Reader**: Logic App → Target Subscriptions

## Post-Deployment Steps

### 1. Verify Deployment

Check that all resources are created:

```bash
# List resources in the resource group
az resource list --resource-group rg-carbon-emissions-dev --output table

# Check Logic App status
az logic workflow show --resource-group rg-carbon-emissions-dev --name [logic-app-name]
```

### 2. Test the Logic App

1. **Manual Trigger**: Go to Azure Portal → Logic App → Run trigger manually
2. **Check Logs**: Monitor run history for errors
3. **Verify CSV Output**: Check blob container for generated files

### 3. Monitor RBAC Assignments

Verify the Logic App has proper permissions:

```bash
# Check role assignments on storage account
az role assignment list --assignee [logic-app-principal-id] --scope [storage-account-id]

# Check role assignments on target subscriptions
az role assignment list --assignee [logic-app-principal-id] --subscription [target-subscription-id]
```

## CSV Output Format

The Logic App generates two CSV files monthly:

### Subscription Details CSV
**Filename**: `EmissionDetails-Subscription-{MonthYear}.csv`

| Column | Description |
|--------|-------------|
| Subscription_Name | Display name of subscription |
| Subscription_Id | Subscription GUID |
| Latest_Month_Emissions_kgCO2E | Emissions for the latest month |
| Previous_Month_Emissions_kgCO2E | Emissions for previous month |

### Monthly Trends CSV
**Filename**: `EmissionTrends-{MonthYear}.csv`

| Column | Description |
|--------|-------------|
| Month | Month and year (e.g., "May 2025") |
| TotalEmissions | Total emissions for the month |
| Scope1 | Scope 1 emissions (typically 0 for Azure) |
| Scope2 | Scope 2 emissions (typically 0 for Azure) |
| Scope3 | Scope 3 emissions (main Azure usage) |
| CarbonIntensity | Carbon intensity (gCO2/kWh) |

## Troubleshooting

### Common Issues

#### 1. RBAC Permission Errors
**Symptoms**: HTTP 403 errors in Logic App runs
**Solution**: 
- Verify Carbon Optimization Reader role assignment
- Check subscription access for the managed identity

#### 2. Storage Access Denied
**Symptoms**: Blob upload failures
**Solution**:
- Verify Storage Blob Data Contributor role assignment
- Ensure storage account allows managed identity access

#### 3. No Carbon Data Available
**Symptoms**: Empty API responses
**Solution**:
- Verify Microsoft.Carbon resource provider is registered
- Check if subscriptions have carbon data available
- Ensure data is published (typically by 19th of month)

#### 4. Logic App Trigger Not Working
**Symptoms**: Logic App doesn't run on schedule
**Solution**:
- Check Logic App is enabled
- Verify trigger schedule configuration
- Review run history for failures

### Debugging Steps

1. **Check Logic App Run History**:
   ```bash
   az logic workflow-run list --resource-group rg-carbon-emissions-dev --workflow-name [logic-app-name]
   ```

2. **View Detailed Run Information**:
   ```bash
   az logic workflow-run show --resource-group rg-carbon-emissions-dev --workflow-name [logic-app-name] --run-name [run-id]
   ```

3. **Monitor Application Insights** (if configured):
   - Check for HTTP request logs
   - Look for authentication failures
   - Monitor performance metrics

## Security Considerations

### Managed Identity Benefits
- No stored credentials or secrets
- Automatic token management
- Least privilege access through RBAC

### Network Security
- Storage account blocks public blob access
- Logic App uses HTTPS for all communications
- TLS 1.2 minimum for all connections

### Data Protection
- Soft delete enabled on blob storage
- Container-level access control
- Azure Activity Log for audit trail

## Maintenance

### Regular Tasks
1. **Monitor Logic App runs** monthly for failures
2. **Review CSV outputs** for data quality
3. **Check RBAC permissions** quarterly
4. **Update API version** as new versions become available

### Scaling Considerations
- Storage account supports up to 500 TiB
- Logic App Consumption has built-in scaling
- Consider archiving old CSV files after 1 year

### Cost Optimization
- Logic App Consumption: Pay per execution
- Storage costs: LRS is most cost-effective
- Consider lifecycle management for old blobs

## Support

For issues with this deployment:

1. Check the [troubleshooting section](#troubleshooting) above
2. Review Azure Activity Logs for detailed error messages
3. Consult Azure Logic Apps documentation for workflow issues
4. Contact Azure Support for Carbon Optimization API issues

## References

- [Azure Logic Apps Documentation](https://docs.microsoft.com/en-us/azure/logic-apps/)
- [Azure Carbon Optimization API](https://docs.microsoft.com/en-us/rest/api/carbon/)
- [Azure RBAC Documentation](https://docs.microsoft.com/en-us/azure/role-based-access-control/)
- [Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
