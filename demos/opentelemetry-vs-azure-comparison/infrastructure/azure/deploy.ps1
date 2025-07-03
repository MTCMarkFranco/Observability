#!/usr/bin/env pwsh

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$Location,
    
    [Parameter(Mandatory = $false)]
    [string]$Environment = "demo",
    
    [Parameter(Mandatory = $false)]
    [string]$ResourcePrefix = "observability-comparison",
    
    [Parameter(Mandatory = $true)]
    [SecureString]$SqlAdminPassword
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "🚀 Starting deployment of Azure resources for OpenTelemetry vs Azure Native comparison" -ForegroundColor Green

# Check if Azure CLI is logged in
$account = az account show --query "name" -o tsv 2>$null
if (-not $account) {
    Write-Host "❌ Please login to Azure CLI first: az login" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Using Azure account: $account" -ForegroundColor Green

# Create resource group if it doesn't exist
$rgExists = az group exists --name $ResourceGroupName
if ($rgExists -eq "false") {
    Write-Host "📦 Creating resource group: $ResourceGroupName" -ForegroundColor Yellow
    az group create --name $ResourceGroupName --location $Location
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to create resource group" -ForegroundColor Red
        exit 1
    }
}

# Deploy the Bicep template
Write-Host "🔧 Deploying Bicep template..." -ForegroundColor Yellow

$deploymentName = "observability-comparison-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# Convert SecureString to plain text for Azure CLI
$plainTextPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SqlAdminPassword))

$deploymentResult = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file "main.bicep" `
    --parameters `
        environment=$Environment `
        resourcePrefix=$ResourcePrefix `
        sqlAdminPassword=$plainTextPassword `
    --name $deploymentName `
    --query "properties.outputs" `
    --output json

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to deploy Bicep template" -ForegroundColor Red
    exit 1
}

# Parse deployment outputs
$outputs = $deploymentResult | ConvertFrom-Json

Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📊 Deployment Results:" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Cyan
Write-Host "Application Insights Connection String: $($outputs.applicationInsightsConnectionString.value)" -ForegroundColor White
Write-Host "OpenTelemetry App Service URL: $($outputs.appServiceOTelUrl.value)" -ForegroundColor White
Write-Host "Azure Native App Service URL: $($outputs.appServiceNativeUrl.value)" -ForegroundColor White
Write-Host "SQL Server: $($outputs.sqlServerName.value)" -ForegroundColor White
Write-Host "SQL Database: $($outputs.sqlDatabaseName.value)" -ForegroundColor White
Write-Host ""

# Create outputs file for use in other scripts
$outputsFile = "deployment-outputs.json"
$deploymentResult | Out-File -FilePath $outputsFile -Encoding utf8
Write-Host "📄 Deployment outputs saved to: $outputsFile" -ForegroundColor Green

Write-Host ""
Write-Host "🎯 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Copy the Application Insights connection string to your appsettings.json"
Write-Host "2. Run the demo applications locally or deploy to the created App Services"
Write-Host "3. Generate load using the load testing scripts"
Write-Host "4. Compare the observability experiences in both Azure Monitor and your OpenTelemetry stack"
Write-Host ""
Write-Host "🔗 Useful Links:" -ForegroundColor Yellow
Write-Host "- Azure Portal: https://portal.azure.com"
Write-Host "- Application Insights: https://portal.azure.com/#blade/HubsExtension/BrowseResource/resourceType/Microsoft.Insights%2Fcomponents"
Write-Host "- Log Analytics: https://portal.azure.com/#blade/HubsExtension/BrowseResource/resourceType/Microsoft.OperationalInsights%2Fworkspaces"
