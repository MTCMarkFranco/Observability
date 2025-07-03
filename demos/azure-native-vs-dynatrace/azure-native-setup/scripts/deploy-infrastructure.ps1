# Azure Native Infrastructure Deployment Script
# This script deploys the complete Azure infrastructure for the observability demo

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$Location = "East US",
    
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$EnvironmentName = "demo",
    
    [Parameter(Mandatory=$false)]
    [string]$ApplicationName = "observability-demo"
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "🚀 Starting Azure Native Infrastructure Deployment" -ForegroundColor Green
Write-Host "📋 Parameters:" -ForegroundColor Yellow
Write-Host "  - Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "  - Location: $Location" -ForegroundColor White
Write-Host "  - Subscription: $SubscriptionId" -ForegroundColor White
Write-Host "  - Environment: $EnvironmentName" -ForegroundColor White
Write-Host "  - Application: $ApplicationName" -ForegroundColor White

# Check if Azure CLI is installed
try {
    $azVersion = az version --output tsv 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI not found"
    }
    Write-Host "✅ Azure CLI is installed" -ForegroundColor Green
}
catch {
    Write-Host "❌ Azure CLI is not installed. Please install it first." -ForegroundColor Red
    Write-Host "   Download from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" -ForegroundColor Yellow
    exit 1
}

# Check if user is logged in
try {
    $currentUser = az account show --query user.name --output tsv 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Not logged in"
    }
    Write-Host "✅ Logged in as: $currentUser" -ForegroundColor Green
}
catch {
    Write-Host "❌ Not logged in to Azure. Please run 'az login' first." -ForegroundColor Red
    exit 1
}

# Set subscription
Write-Host "🔧 Setting subscription..." -ForegroundColor Yellow
az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to set subscription" -ForegroundColor Red
    exit 1
}

# Create resource group
Write-Host "🏗️  Creating resource group..." -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to create resource group" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Resource group created: $ResourceGroupName" -ForegroundColor Green

# Deploy Bicep template
Write-Host "📦 Deploying infrastructure..." -ForegroundColor Yellow
$deploymentName = "azure-native-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$templateFile = Join-Path $PSScriptRoot "..\infrastructure\main.bicep"
$parametersFile = Join-Path $PSScriptRoot "..\infrastructure\main.parameters.json"

# Update parameters file with actual values
$parametersContent = Get-Content $parametersFile -Raw | ConvertFrom-Json
$parametersContent.parameters.environmentName.value = $EnvironmentName
$parametersContent.parameters.applicationName.value = $ApplicationName
$parametersContent.parameters.location.value = $Location

# Generate a secure password for SQL
$sqlPassword = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 16 | % {[char]$_}) + "!"
$parametersContent.parameters.sqlAdminPassword.value = $sqlPassword

# Save updated parameters
$parametersContent | ConvertTo-Json -Depth 10 | Set-Content $parametersFile

Write-Host "🔐 Generated SQL password (save this securely): $sqlPassword" -ForegroundColor Cyan

# Deploy the template
az deployment group create `
    --resource-group $ResourceGroupName `
    --name $deploymentName `
    --template-file $templateFile `
    --parameters $parametersFile `
    --verbose

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to deploy infrastructure" -ForegroundColor Red
    exit 1
}

# Get deployment outputs
Write-Host "📊 Retrieving deployment outputs..." -ForegroundColor Yellow
$outputs = az deployment group show `
    --resource-group $ResourceGroupName `
    --name $deploymentName `
    --query properties.outputs `
    --output json | ConvertFrom-Json

# Display important information
Write-Host "🎉 Deployment completed successfully!" -ForegroundColor Green
Write-Host "📋 Resource Information:" -ForegroundColor Yellow
Write-Host "  - App Service URL: $($outputs.appServiceUrl.value)" -ForegroundColor White
Write-Host "  - Application Insights Key: $($outputs.applicationInsightsInstrumentationKey.value)" -ForegroundColor White
Write-Host "  - Log Analytics Workspace: $($outputs.logAnalyticsWorkspaceName.value)" -ForegroundColor White
Write-Host "  - SQL Server: $($outputs.sqlServerName.value)" -ForegroundColor White
Write-Host "  - SQL Database: $($outputs.sqlDatabaseName.value)" -ForegroundColor White
Write-Host "  - Redis Cache: $($outputs.redisCacheName.value)" -ForegroundColor White

# Save deployment information
$deploymentInfo = @{
    DeploymentName = $deploymentName
    ResourceGroupName = $ResourceGroupName
    Location = $Location
    EnvironmentName = $EnvironmentName
    ApplicationName = $ApplicationName
    SqlAdminPassword = $sqlPassword
    Outputs = $outputs
    DeploymentTime = Get-Date
}

$deploymentInfoFile = Join-Path $PSScriptRoot "..\deployment-info.json"
$deploymentInfo | ConvertTo-Json -Depth 10 | Set-Content $deploymentInfoFile
Write-Host "💾 Deployment information saved to: $deploymentInfoFile" -ForegroundColor Cyan

Write-Host "🔍 Next steps:" -ForegroundColor Yellow
Write-Host "  1. Configure monitoring alerts: .\configure-monitoring.ps1" -ForegroundColor White
Write-Host "  2. Deploy the sample application to App Service" -ForegroundColor White
Write-Host "  3. Run load tests to generate telemetry" -ForegroundColor White

Write-Host "✅ Azure Native infrastructure deployment completed!" -ForegroundColor Green
