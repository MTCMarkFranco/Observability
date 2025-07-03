# Azure Observability Foundation Deployment Script
# This script deploys the core observability infrastructure to Azure

param(
    [string]$EnvironmentName = "demo",
    [string]$OrganizationName = "contoso",
    [string]$Location = "East US",
    [switch]$EnableSentinel = $false
)

# Generate a random suffix for unique resource names
$randomSuffix = Get-Random -Minimum 1000 -Maximum 9999
$resourceGroupName = "rg-observability-$EnvironmentName-$randomSuffix"

Write-Host "[START] Starting Azure Observability Foundation Deployment" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host "Environment: $EnvironmentName" -ForegroundColor Yellow
Write-Host "Organization: $OrganizationName" -ForegroundColor Yellow
Write-Host "Location: $Location" -ForegroundColor Yellow
Write-Host "Resource Group: $resourceGroupName" -ForegroundColor Yellow
Write-Host "Enable Sentinel: $EnableSentinel" -ForegroundColor Yellow
Write-Host ""

# Check if user is logged in to Azure
Write-Host "[CHECK] Checking Azure CLI login status..." -ForegroundColor Blue
try {
    $account = az account show --query "name" -o tsv 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] You are not logged in to Azure CLI. Please run 'az login' first." -ForegroundColor Red
        exit 1
    }
    Write-Host "[SUCCESS] Logged in to Azure as: $account" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Error checking Azure CLI login. Please ensure Azure CLI is installed and you are logged in." -ForegroundColor Red
    exit 1
}

# Get current subscription
$subscriptionInfo = az account show --query '{name:name, id:id}' -o json | ConvertFrom-Json
Write-Host "[INFO] Using subscription: $($subscriptionInfo.name) ($($subscriptionInfo.id))" -ForegroundColor Yellow
Write-Host ""

# Create resource group
Write-Host "[CREATE] Creating resource group: $resourceGroupName" -ForegroundColor Blue
az group create --name $resourceGroupName --location $Location --output table

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to create resource group" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCCESS] Resource group created successfully" -ForegroundColor Green
Write-Host ""

# Create temporary parameters file with updated values
$tempParamsFile = "main.parameters.temp.json"
$originalParamsPath = "main.parameters.json"

# Read the original parameters file
$paramsContent = Get-Content $originalParamsPath | ConvertFrom-Json

# Update parameter values
$paramsContent.parameters.environmentName.value = $EnvironmentName
$paramsContent.parameters.organizationName.value = $OrganizationName
$paramsContent.parameters.enableSentinel.value = $EnableSentinel.IsPresent
$paramsContent.parameters.tags.value.Environment = $EnvironmentName

# Save temporary parameters file
$paramsContent | ConvertTo-Json -Depth 10 | Set-Content $tempParamsFile

Write-Host "[CONFIG] Updated deployment parameters:" -ForegroundColor Blue
Write-Host "  - Environment Name: $EnvironmentName" -ForegroundColor White
Write-Host "  - Organization Name: $OrganizationName" -ForegroundColor White
Write-Host "  - Enable Sentinel: $EnableSentinel" -ForegroundColor White
Write-Host ""

# Deploy the main template
Write-Host "[DEPLOY] Starting Bicep template deployment..." -ForegroundColor Blue
Write-Host "This may take 10-15 minutes to complete..." -ForegroundColor Yellow
Write-Host ""

$deploymentName = "observability-foundation-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

try {
    az deployment group create `
        --resource-group $resourceGroupName `
        --template-file "main.bicep" `
        --parameters "@$tempParamsFile" `
        --name $deploymentName `
        --output table

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Deployment failed" -ForegroundColor Red
        Write-Host "[INFO] Check the Azure portal for detailed error information" -ForegroundColor Yellow
        Write-Host "[INFO] Resource Group: $resourceGroupName" -ForegroundColor Yellow
        Write-Host "[INFO] Deployment Name: $deploymentName" -ForegroundColor Yellow
        exit 1
    }
}
finally {
    # Clean up temporary file
    if (Test-Path $tempParamsFile) {
        Remove-Item $tempParamsFile
    }
}

Write-Host ""
Write-Host "[SUCCESS] Deployment completed successfully!" -ForegroundColor Green
Write-Host ""

# Get deployment outputs
Write-Host "[OUTPUTS] Retrieving deployment outputs..." -ForegroundColor Blue
$outputs = az deployment group show --resource-group $resourceGroupName --name $deploymentName --query "properties.outputs" -o json | ConvertFrom-Json

Write-Host ""
Write-Host "[SUMMARY] Deployment Summary" -ForegroundColor Green
Write-Host "===================" -ForegroundColor Green
Write-Host "Resource Group: $resourceGroupName" -ForegroundColor Yellow
Write-Host "Log Analytics Workspace: $($outputs.logAnalyticsWorkspaceName.value)" -ForegroundColor Yellow
Write-Host "Application Insights: $($outputs.applicationInsightsId.value -split '/')[-1]" -ForegroundColor Yellow
Write-Host "Sentinel Enabled: $($outputs.sentinelEnabled.value)" -ForegroundColor Yellow
Write-Host ""

Write-Host "[INFO] Important Information" -ForegroundColor Green
Write-Host "======================" -ForegroundColor Green
Write-Host "Application Insights Connection String:" -ForegroundColor Blue
Write-Host $outputs.applicationInsightsConnectionString.value -ForegroundColor White
Write-Host ""
Write-Host "Log Analytics Customer ID:" -ForegroundColor Blue
Write-Host $outputs.logAnalyticsCustomerId.value -ForegroundColor White
Write-Host ""

# Save outputs to file
$outputsFile = "deployment-outputs-$EnvironmentName-$randomSuffix.json"
$outputs | ConvertTo-Json -Depth 10 | Set-Content $outputsFile
Write-Host "[SUCCESS] Deployment outputs saved to: $outputsFile" -ForegroundColor Green
Write-Host ""

Write-Host "[COMPLETE] Azure Observability Foundation is now ready!" -ForegroundColor Green
Write-Host ""
Write-Host "[NEXT] Next Steps:" -ForegroundColor Blue
Write-Host "1. Configure data collection rules for your VMs" -ForegroundColor White
Write-Host "2. Install Azure Monitor Agent on target machines" -ForegroundColor White
Write-Host "3. Configure Application Insights in your applications" -ForegroundColor White
Write-Host "4. Set up custom dashboards and alerts" -ForegroundColor White
if ($EnableSentinel) {
    Write-Host "5. Configure Sentinel data connectors in the Azure portal" -ForegroundColor White
}
Write-Host ""
Write-Host "[DOCS] Documentation: Check the demos/ folder for detailed setup guides" -ForegroundColor Blue
