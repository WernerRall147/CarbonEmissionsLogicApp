# Carbon Emissions Logic App - Quick Start

## 🚀 Deploy in 3 Steps

### 1. Prerequisites
- Azure CLI installed and logged in (`az login`)
- Contributor access to Azure subscription
- Subscription IDs with Carbon Optimization data

### 2. Quick Deploy with Azure Developer CLI
```bash
# Clone and initialize
git clone [your-repo]
cd CarbonEmissionsLogicApp

# Deploy everything
azd up
```

### 3. Configure Subscriptions
Edit `src/infrastructure/main.parameters.json` and add your subscription IDs:
```json
"subscriptionIds": {
  "value": ["your-subscription-id-1", "your-subscription-id-2"]
}
```

Then redeploy: `azd up`

## 📊 What Gets Deployed
- **Logic App**: Runs monthly on 20th at midnight UTC
- **Storage Account**: Stores CSV exports securely
- **RBAC**: Automatic permissions for Carbon APIs and Storage

## 📁 Output Files
Monthly CSV files in blob storage:
- `EmissionDetails-Subscription-{MonthYear}.csv` - Per-subscription emissions
- `EmissionTrends-{MonthYear}.csv` - 12-month trend data

## 📖 Full Documentation
See [docs/deployment-guide.md](docs/deployment-guide.md) for complete instructions.

## 🔧 Alternative Deployment
Use PowerShell script:
```powershell
.\src\scripts\Deploy-CarbonEmissionsLogicApp.ps1 -SubscriptionIds @("your-sub-id")
```

---
**📞 Need Help?** Check the [troubleshooting section](docs/deployment-guide.md#troubleshooting) in the deployment guide.
