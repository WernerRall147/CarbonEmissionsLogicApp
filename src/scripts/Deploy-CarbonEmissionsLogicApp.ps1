# Carbon Emissions Logic App Deployment Script
# This script deploys the Azure Logic App for automated carbon emissions data export

param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-carbon-emissions-dev",
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "East US 2",
    
    [Parameter(Mandatory = $false)]
    [string]$EnvironmentName = "dev",
    
    [Parameter(Mandatory = $false)]
    [string]$ProjectName = "carbon-emissions",
    
    [Parameter(Mandatory = $false)]
    [string[]]$SubscriptionIds = @(),
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf = $false
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "🌱 Carbon Emissions Logic App Deployment" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# Validate Azure CLI installation and login
try {
    $account = az account show --query "user.name" -o tsv 2>$null
    if (-not $account) {
        throw "Not logged in"
    }
    Write-Host "✅ Logged into Azure as: $account" -ForegroundColor Green
}
catch {
    Write-Error "❌ Please run 'az login' to authenticate with Azure first"
    exit 1
}

# Validate Bicep CLI
try {
    az bicep version 2>$null | Out-Null
    Write-Host "✅ Bicep CLI is available" -ForegroundColor Green
}
catch {
    Write-Host "⚠️  Installing Bicep CLI..." -ForegroundColor Yellow
    az bicep install
}

# Get current subscription
$currentSubscription = az account show --query "id" -o tsv
Write-Host "🔍 Current subscription: $currentSubscription" -ForegroundColor Cyan

# Prompt for subscription IDs if not provided
if ($SubscriptionIds.Count -eq 0) {
    Write-Host "`n📋 You need to specify which subscriptions to export carbon data for." -ForegroundColor Yellow
    Write-Host "Current subscription: $currentSubscription" -ForegroundColor Cyan
    
    $useCurrentSub = Read-Host "Use current subscription? (y/n)"
    if ($useCurrentSub -eq 'y' -or $useCurrentSub -eq 'Y') {
        $SubscriptionIds = @($currentSubscription)
    }
    else {
        Write-Host "Please provide subscription IDs as a parameter: -SubscriptionIds @('sub1', 'sub2')" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "📊 Target subscriptions for carbon data export:" -ForegroundColor Cyan
$SubscriptionIds | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }

# Create resource group if it doesn't exist
Write-Host "`n🏗️  Checking resource group: $ResourceGroupName" -ForegroundColor Yellow
$rgExists = az group exists --name $ResourceGroupName
if ($rgExists -eq "false") {
    Write-Host "📦 Creating resource group: $ResourceGroupName" -ForegroundColor Yellow
    az group create --name $ResourceGroupName --location $Location --tags "project=$ProjectName" "environment=$EnvironmentName"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "❌ Failed to create resource group"
        exit 1
    }
    Write-Host "✅ Resource group created successfully" -ForegroundColor Green
}
else {
    Write-Host "✅ Resource group already exists" -ForegroundColor Green
}

# Build Bicep template to validate
Write-Host "`n🔧 Validating Bicep template..." -ForegroundColor Yellow
$bicepPath = "src/infrastructure/main.bicep"
$parametersPath = "src/infrastructure/main.parameters.json"

if (-not (Test-Path $bicepPath)) {
    Write-Error "❌ Bicep template not found: $bicepPath"
    exit 1
}

az bicep build --file $bicepPath
if ($LASTEXITCODE -ne 0) {
    Write-Error "❌ Bicep template validation failed"
    exit 1
}
Write-Host "✅ Bicep template is valid" -ForegroundColor Green

# Generate deployment name
$deploymentName = "carbon-emissions-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# Prepare deployment parameters
$subscriptionIdsJson = ($SubscriptionIds | ConvertTo-Json -Compress)

# Create temporary parameters file with subscription IDs
$tempParamsPath = "main.parameters.temp.json"
$paramsContent = @{
    '$schema' = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
    contentVersion = "1.0.0.0"
    parameters = @{
        projectName = @{ value = $ProjectName }
        environmentName = @{ value = $EnvironmentName }
        location = @{ value = $Location }
        subscriptionIds = @{ value = $SubscriptionIds }
        scheduleDay = @{ value = 20 }
        containerName = @{ value = "carbon-emissions-reports" }
        carbonApiVersion = @{ value = "2025-04-01" }
    }
} | ConvertTo-Json -Depth 5

$paramsContent | Out-File -FilePath $tempParamsPath -Encoding utf8

try {
    if ($WhatIf) {
        Write-Host "`n🔍 Running what-if deployment analysis..." -ForegroundColor Yellow
        az deployment group what-if `
            --name $deploymentName `
            --resource-group $ResourceGroupName `
            --template-file $bicepPath `
            --parameters $tempParamsPath
    }
    else {
        Write-Host "`n🚀 Starting deployment..." -ForegroundColor Yellow
        Write-Host "Deployment name: $deploymentName" -ForegroundColor Cyan
        
        $deployment = az deployment group create `
            --name $deploymentName `
            --resource-group $ResourceGroupName `
            --template-file $bicepPath `
            --parameters $tempParamsPath `
            --output json | ConvertFrom-Json
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "❌ Deployment failed"
            exit 1
        }
        
        Write-Host "`n✅ Deployment completed successfully!" -ForegroundColor Green
        Write-Host "🔗 Resources deployed:" -ForegroundColor Cyan
        Write-Host "  - Logic App: $($deployment.properties.outputs.logicAppName.value)" -ForegroundColor White
        Write-Host "  - Storage Account: $($deployment.properties.outputs.storageAccountName.value)" -ForegroundColor White
        Write-Host "  - Container: $($deployment.properties.outputs.containerName.value)" -ForegroundColor White
        
        Write-Host "`n📋 Next steps:" -ForegroundColor Yellow
        Write-Host "1. 🔐 Verify RBAC assignments for Carbon Optimization Reader role" -ForegroundColor White
        Write-Host "2. 🧪 Test the Logic App manually in Azure Portal" -ForegroundColor White
        Write-Host "3. 📅 Logic App is scheduled to run on the 20th of each month" -ForegroundColor White
        Write-Host "4. 📊 CSV files will be created in the blob container" -ForegroundColor White
    }
}
finally {
    # Clean up temporary parameters file
    if (Test-Path $tempParamsPath) {
        Remove-Item $tempParamsPath -Force
    }
}

Write-Host "`n🎉 Script completed!" -ForegroundColor Green
