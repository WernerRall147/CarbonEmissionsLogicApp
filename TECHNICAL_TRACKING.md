# Carbon Emissions Logic App - Technical Tracking Document

## Project Overview
Building an Azure Logic App to automatically extract Azure Carbon Optimization emissions data on a monthly schedule and save as CSV files in Azure Blob Storage.

**Start Date:** June 10, 2025  
**Project Repository:** c:\Users\weral\Git\CarbonEmissionsLogicApp  

## Project Structure
```
CarbonEmissionsLogicApp/
├── README.md (existing - project documentation)
├── TECHNICAL_TRACKING.md (this file)
├── LICENSE (existing)
├── Resources/ (existing - documentation)
├── src/ (to be created)
│   ├── logic-app/ (Logic App workflow definitions)
│   ├── infrastructure/ (Bicep/ARM templates)
│   └── scripts/ (deployment scripts)
└── docs/ (additional documentation)
```

## Implementation Plan

### Phase 1: Project Setup ✅
- [x] Create technical tracking document
- [x] Create folder structure
- [x] Set up infrastructure templates
- [x] Create Logic App workflow definition

### Phase 2: Logic App Development ✅
- [x] Create workflow definition JSON
- [x] Configure recurrence trigger (monthly on 20th)
- [x] Add HTTP actions for Carbon APIs
- [x] Implement data transformation (JSON to CSV)
- [x] Configure blob storage integration
- [x] Add error handling and logging

### Phase 3: Infrastructure as Code ✅
- [x] Create Bicep template for resources
- [x] Include Storage Account with container
- [x] Configure Logic App with managed identity
- [x] Set up RBAC role assignments
- [x] Create deployment scripts

### Phase 4: Testing & Deployment 🔄
- [ ] Deploy to Azure for testing
- [ ] Validate API calls and permissions
- [ ] Test CSV generation and blob storage
- [ ] Verify error handling
- [ ] Document final deployment steps

## Changes Log

### 2025-06-10
**10:XX AM** - Project initialization
- Created TECHNICAL_TRACKING.md for change tracking
- Analyzed README.md requirements
- Planning folder structure and implementation approach

**Key Requirements Identified:**
1. Monthly recurrence trigger (20th of each month)
2. Two main API calls:
   - queryCarbonEmissionDataAvailableDateRange (optional validation)
   - carbonEmissionReports (ItemDetailReport & MonthlySummaryReport)
3. JSON to CSV transformation with specific column mappings
4. Azure Blob Storage integration with managed identity
5. Comprehensive error handling and retry policies

**API Endpoints:**
- Date Range: POST https://management.azure.com/providers/Microsoft.Carbon/queryCarbonEmissionDataAvailableDateRange?api-version=2025-04-01
- Reports: POST https://management.azure.com/providers/Microsoft.Carbon/carbonEmissionReports?api-version=2025-04-01

**Required RBAC Roles:**
- Carbon Optimization Reader (fa0d39e6-28e5-40cf-8521-1eb320653a4c)
- Storage Blob Data Contributor (ba92f5b4-2d11-453d-a403-e96b0029c9fe)

**11:XX AM** - Core Infrastructure Development
- ✅ Created folder structure (src/, docs/, logic-app/, infrastructure/, scripts/)
- ✅ Developed Logic App workflow definition (workflow-corrected.json)
- ✅ Created comprehensive Bicep template (main.bicep) with:
  - Storage Account with secure configuration
  - Logic App with system-assigned managed identity
  - Blob container for CSV storage
  - RBAC role assignments for proper permissions
  - Complete workflow definition embedded in Bicep
- ✅ Created parameters file (main.parameters.json)
- ✅ Created Azure Developer CLI configuration (azure.yaml)
- ✅ Developed PowerShell deployment script (Deploy-CarbonEmissionsLogicApp.ps1)
- ✅ Created comprehensive deployment guide documentation

**Files Created:**
1. `TECHNICAL_TRACKING.md` - This tracking document
2. `src/logic-app/workflow-corrected.json` - Logic App workflow definition
3. `src/infrastructure/main.bicep` - Main Bicep template with all resources
4. `src/infrastructure/main.parameters.json` - Deployment parameters
5. `azure.yaml` - Azure Developer CLI configuration
6. `src/scripts/Deploy-CarbonEmissionsLogicApp.ps1` - PowerShell deployment script
7. `docs/deployment-guide.md` - Comprehensive deployment documentation

**Architecture Implemented:**
- **Security**: Managed identity authentication, no stored secrets
- **Storage**: Standard_LRS storage account with Azure AD auth only
- **Logic App**: Consumption tier with monthly recurrence trigger
- **RBAC**: Automated role assignments for Carbon API and Storage access
- **Monitoring**: Built-in retry policies and error handling

**Deployment Options Available:**
1. Azure Developer CLI: `azd up` (simplest)
2. PowerShell script: `Deploy-CarbonEmissionsLogicApp.ps1`
3. Manual Azure CLI deployment

## Technical Decisions

### Logic App Type
- **Decision:** Use Consumption Logic App for simplicity and one-click deployment
- **Rationale:** Easier to embed full definition in ARM template vs Standard which requires separate App Service plan

### Authentication
- **Decision:** System-assigned Managed Identity
- **Rationale:** No stored secrets, automatic token management, easier RBAC assignment

### Storage Approach
- **Decision:** Azure Blob Storage with managed identity authentication
- **Rationale:** Secure, scalable, supports both connector and REST API approaches

### CSV Format
Following portal export format:
- **Subscription Details:** Subscription_Name, Subscription_Id, Latest_Month_Emissions_kgCO2E, Previous_Month_Emissions_kgCO2E
- **Trends:** Month, TotalEmissions, Scope1, Scope2, Scope3, CarbonIntensity

## Issues & Resolutions

*To be updated as issues arise during implementation*

## Resources & References

- [Azure Logic Apps Documentation](https://docs.microsoft.com/en-us/azure/logic-apps/)
- [Azure Carbon Optimization API](https://docs.microsoft.com/en-us/rest/api/carbon/)
- [Logic Apps Managed Identity](https://docs.microsoft.com/en-us/azure/logic-apps/create-managed-service-identity)
- [Azure RBAC Built-in Roles](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles)

---
*Last Updated: June 10, 2025*
