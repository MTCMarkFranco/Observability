# Infrastructure as Code for Observability

This folder contains Bicep templates for deploying the complete observability infrastructure on Azure.

## Templates Overview

- **observability-foundation** - Core monitoring infrastructure
- **monitoring-workspace** - Advanced Log Analytics and Application Insights setup
- **security-monitoring** - Microsoft Sentinel and security monitoring

## Quick Deployment

### Deploy Complete Observability Stack

```powershell
# Set variables
$resourceGroupName = "rg-observability-production"
$location = "East US"
$environment = "production"

# Create resource group
az group create --name $resourceGroupName --location $location

# Deploy foundation
az deployment group create \
  --resource-group $resourceGroupName \
  --template-file ./observability-foundation/main.bicep \
  --parameters @./observability-foundation/main.parameters.json \
  --parameters environmentName=$environment

# Deploy monitoring workspace
az deployment group create \
  --resource-group $resourceGroupName \
  --template-file ./monitoring-workspace/main.bicep \
  --parameters @./monitoring-workspace/main.parameters.json \
  --parameters environmentName=$environment

# Deploy security monitoring
az deployment group create \
  --resource-group $resourceGroupName \
  --template-file ./security-monitoring/main.bicep \
  --parameters @./security-monitoring/main.parameters.json \
  --parameters environmentName=$environment
```

### Environment-Specific Deployments

```powershell
# Development environment (cost-optimized)
az deployment group create \
  --resource-group "rg-observability-dev" \
  --template-file ./observability-foundation/main.bicep \
  --parameters environmentName=development \
  --parameters logAnalyticsSkuName=PerGB2018 \
  --parameters retentionInDays=30 \
  --parameters dailyQuotaGb=1

# Production environment (full features)
az deployment group create \
  --resource-group "rg-observability-prod" \
  --template-file ./observability-foundation/main.bicep \
  --parameters environmentName=production \
  --parameters logAnalyticsSkuName=PerGB2018 \
  --parameters retentionInDays=730 \
  --parameters dailyQuotaGb=-1 \
  --parameters enableSentinel=true
```

## Template Structure

Each template folder contains:
- `main.bicep` - Main template file
- `main.parameters.json` - Parameter file
- `modules/` - Reusable modules
- `README.md` - Specific deployment instructions

## Common Parameters

| Parameter | Description | Default | Options |
|-----------|-------------|---------|---------|
| `environmentName` | Environment name | `dev` | `dev`, `test`, `prod` |
| `location` | Azure region | Resource group location | Any valid Azure region |
| `retentionInDays` | Log retention period | `90` | `30-730` |
| `dailyQuotaGb` | Daily ingestion limit | `-1` (unlimited) | Number or `-1` |
| `enableSentinel` | Deploy Microsoft Sentinel | `false` | `true`, `false` |

## Cost Considerations

### Development Environment
- 30-day retention
- 1GB daily quota
- Basic alerting only
- No Sentinel

### Production Environment  
- 2-year retention
- Unlimited quota
- Full alerting suite
- Microsoft Sentinel enabled

## Next Steps

1. Choose appropriate environment template
2. Customize parameters for your needs
3. Deploy using Azure CLI or Azure DevOps
4. Configure applications to send telemetry
5. Set up dashboards and alerts
