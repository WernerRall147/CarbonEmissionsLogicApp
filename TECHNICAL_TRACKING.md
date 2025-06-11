# Carbon Emissions Logic App - Technical Documentation

## Project Overview
Automated Azure Logic App solution for monthly carbon emissions data export from Azure Carbon Optimization APIs to CSV files in Azure Blob Storage.

## 🏗️ Architecture

### Components
- **Logic App (Consumption)**: Monthly workflow automation
- **Storage Account**: Secure CSV file storage with managed identity
- **RBAC Integration**: Carbon Optimization Reader + Storage Blob Data Contributor
- **Azure Developer CLI**: Infrastructure as Code deployment

### Security Model
- **Managed Identity**: System-assigned, no stored credentials
- **Least Privilege**: Minimal required permissions
- **Azure AD Authentication**: All API calls use managed identity tokens

## 📁 Project Structure
```
CarbonEmissionsLogicApp/
├── README.md                      # Main documentation
├── QUICKSTART.md                  # 3-step deployment guide
├── TECHNICAL_TRACKING.md          # This file
├── azure.yaml                     # Azure Developer CLI config
├── src/
│   ├── logic-app/                 # Workflow definitions
│   │   ├── workflow.json          # Original workflow
│   │   └── workflow-corrected.json # Updated workflow
│   ├── infrastructure/            # Bicep templates
│   │   ├── main.bicep            # Main infrastructure template
│   │   └── main.parameters.json  # Deployment parameters
│   └── scripts/                   # Deployment scripts
│       └── Deploy-CarbonEmissionsLogicApp.ps1
├── docs/
│   └── deployment-guide.md        # Detailed deployment guide
└── Resources/                     # API documentation PDFs
```

## 🚀 Deployment Methods

### Primary: Azure Developer CLI (Recommended)
```bash
azd up
```

### Alternative: PowerShell Script
```powershell
.\src\scripts\Deploy-CarbonEmissionsLogicApp.ps1
```

### Manual: Azure CLI
See [deployment guide](docs/deployment-guide.md) for step-by-step instructions.

## 📊 Workflow Design

### Trigger
- **Schedule**: Monthly on 20th at midnight UTC
- **Reason**: Carbon data typically available by 19th of month

### Data Flow
1. **Date Range Check** (Optional): Validate data availability
2. **Subscription Report**: ItemDetailReport for current subscriptions
3. **Trend Report**: MonthlySummaryReport for 12-month history
4. **CSV Transform**: JSON to CSV with portal-matching format
5. **Blob Upload**: Store files with timestamp naming

### Error Handling
- **Retry Policies**: Exponential backoff for transient failures
- **Date Adjustment**: Automatically handles data lag (uses 2-month offset)
- **Logging**: All actions logged in Azure Monitor

## 🔧 Configuration

### Required Parameters
- `subscriptionIds`: Array of target subscription IDs
- `location`: Azure region for deployment
- `scheduleDay`: Day of month to run (default: 20)

### Auto-Generated
- `storageAccountName`: Unique name based on resource group
- `containerName`: `carbon-emissions-reports`
- `resourceToken`: Unique identifier for naming

## 📄 Output Files

### File Naming Convention
- **Subscription Details**: `EmissionDetails-Subscription-{MonthYear}.csv`
- **Trends**: `EmissionTrends-{MonthYear}.csv`
- **MonthYear Format**: `Apr2025` (3-letter month + year)

### CSV Schema
**Subscription Details:**
```csv
Subscription_Name,Subscription_Id,Latest_Month_Emissions_kgCO2E,Previous_Month_Emissions_kgCO2E
```

**Trends:**
```csv
Month,TotalEmissions,Scope1,Scope2,Scope3,CarbonIntensity
```

## 🛠️ Development History

### Phase 1: Planning & Setup ✅
- Project structure design
- API analysis and documentation review
- Security and RBAC planning

### Phase 2: Core Development ✅
- Logic App workflow creation with full error handling
- Bicep infrastructure template with managed identity
- Azure Developer CLI integration

### Phase 3: Deployment & Testing ✅
- Successful deployment to Azure
- RBAC configuration automation
- Date range issue resolution (API data lag)

### Phase 4: Documentation & Production Readiness ✅
- GitHub-ready documentation
- Removed confidential information
- Production-ready configuration

## 🔍 Technical Decisions

### Logic App Type: Consumption
**Rationale**: Easier ARM template integration, monthly schedule suitable for consumption model

### Authentication: System-Assigned Managed Identity
**Rationale**: No credential management, automatic token handling, easier RBAC

### Date Strategy: Conservative Offset
**Rationale**: Carbon API has 2-3 month data lag, using -2 months ensures data availability

### Storage: Azure Blob with RBAC
**Rationale**: Secure, auditable, integrates with managed identity

## 🐛 Known Issues & Solutions

### Date Range API Errors
**Issue**: Carbon API availability lags current date  
**Solution**: Use 2-month offset instead of 1-month

### CLI Command Compatibility
**Issue**: Logic App CLI commands vary by Azure CLI version  
**Solution**: Use REST API calls for monitoring and triggering

### Cross-Subscription RBAC
**Issue**: Bicep templates can't assign roles across subscriptions  
**Solution**: Post-deployment Azure CLI role assignments

## 📈 Monitoring & Maintenance

### Health Checks
- **Logic App Run History**: Monitor for failures
- **Blob Storage**: Verify monthly file creation
- **RBAC Permissions**: Ensure roles remain assigned

### Troubleshooting
- Check run history in Azure Portal
- Validate Carbon API data availability dates
- Verify managed identity permissions

## 🔗 Resource Links

- **Logic App Portal**: Available in azd environment values
- **Storage Account**: Available in azd environment values  
- **API Documentation**: [Azure Carbon Optimization REST API](https://docs.microsoft.com/en-us/rest/api/carbon/)
- **RBAC Reference**: [Azure Built-in Roles](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles)

---

## 🎯 Production Status: ✅ DEPLOYED & OPERATIONAL

**Current Environment**: Management subscription  
**Next Scheduled Run**: 20th of next month at midnight UTC  
**Monitoring**: Azure Portal Logic App run history

### Post-Deployment Validation Checklist
- [x] Infrastructure deployed successfully
- [x] Logic App workflow active
- [x] Managed identity configured
- [x] RBAC permissions assigned
- [x] Storage container created
- [x] Manual test execution completed
- [x] Date range logic corrected
- [x] Documentation completed

**Solution is production-ready for automated monthly carbon emissions reporting! 🌱**
