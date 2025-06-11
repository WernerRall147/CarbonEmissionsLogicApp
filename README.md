# Azure Carbon Emissions Logic App

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template)

Automated monthly exports of Azure Carbon Optimization emissions data using Azure Logic Apps. Replicates the Azure Portal's "Export to CSV" functionality, saving carbon emissions reports as CSV files in Azure Blob Storage.

## 🌱 What This Does

- **Automated Monthly Exports**: Runs on the 20th of each month at midnight UTC
- **Dual Report Types**: Subscription-level details + 12-month trends with scope breakdown
- **Secure & Managed**: Uses Azure Managed Identity (no stored credentials)
- **Production Ready**: Infrastructure-as-Code deployment with proper RBAC

## 🚀 Quick Start

### Prerequisites
- Azure CLI and Azure Developer CLI (`azd`) installed
- Contributor access to target Azure subscription(s)
- Subscriptions with Carbon Optimization data available

### Deploy in 3 Steps

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd CarbonEmissionsLogicApp
   ```

2. **Configure target subscriptions**
   
   Edit `src/infrastructure/main.parameters.json`:
   ```json
   {
     "parameters": {
       "subscriptionIds": {
         "value": ["your-subscription-id-1", "your-subscription-id-2"]
       }
     }
   }
   ```

3. **Deploy everything**
   ```bash
   azd up
   ```

That's it! The Logic App will now run monthly and export CSV files to Azure Blob Storage.

## 📊 What Gets Deployed

| Resource | Purpose |
|----------|---------|
| **Logic App** | Monthly workflow automation (Consumption tier) |
| **Storage Account** | CSV file storage with managed identity auth |
| **Blob Container** | Organized file storage (`carbon-emissions-reports`) |
| **RBAC Assignments** | Carbon Optimization Reader + Storage Blob Data Contributor |

## 📁 Output Files

**Subscription Details**: `EmissionDetails-Subscription-{MonthYear}.csv`
```csv
Subscription_Name,Subscription_Id,Latest_Month_Emissions_kgCO2E,Previous_Month_Emissions_kgCO2E
Management,xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx,0.981892316510078,0.945248053765905
```

**Monthly Trends**: `EmissionTrends-{MonthYear}.csv`
```csv
Month,TotalEmissions,Scope1,Scope2,Scope3,CarbonIntensity
Apr 2024,0.1,0,0,0.1,13.1
May 2024,0.1,0,0,0.1,12.8
```

## 🔧 Alternative Deployment

**PowerShell Script**:
```powershell
.\src\scripts\Deploy-CarbonEmissionsLogicApp.ps1 -SubscriptionIds @("your-subscription-id")
```

**Manual Azure CLI**: See [docs/deployment-guide.md](docs/deployment-guide.md)

## 📚 Documentation

- **[Deployment Guide](docs/deployment-guide.md)** - Detailed deployment instructions
- **[Technical Documentation](TECHNICAL_TRACKING.md)** - Architecture and implementation details

## 🛡️ Security

- **No Stored Secrets**: Uses Azure Managed Identity for all authentication
- **Least Privilege**: Minimal required permissions (Carbon Optimization Reader)
- **Audit Trail**: All actions logged in Azure Monitor
- **Encryption**: Data encrypted in transit and at rest

## 🚨 Troubleshooting

- **Date Range Errors**: The Carbon API has 2-3 month data lag. Logic App automatically adjusts.
- **Permission Errors**: Ensure Logic App managed identity has `Carbon Optimization Reader` role on target subscriptions.
- **Storage Access**: Verify managed identity has `Storage Blob Data Contributor` role on storage account.

See [full troubleshooting guide](docs/deployment-guide.md#troubleshooting) for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch  
3. Test your changes
4. Submit a pull request

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 📞 Support

1. Check the [troubleshooting guide](docs/deployment-guide.md#troubleshooting)
2. Review [GitHub Issues](../../issues)
3. Create a new issue with detailed information

---

**🌱 Making Azure carbon reporting easier, one automated export at a time!**
