# Quick Start Guide: Azure Native vs Dynatrace Demo

## 🚀 Prerequisites

### Azure Requirements
- Azure subscription with contributor access
- Azure CLI installed and configured
- PowerShell 7.0 or later
- .NET 8 SDK

### Dynatrace Requirements
- Dynatrace SaaS tenant (free trial available)
- Dynatrace API token with appropriate permissions
- Kubernetes cluster (AKS recommended)

## ⚡ Quick Demo Setup (15 minutes)

### Step 1: Clone and Configure
```powershell
# Navigate to the demo directory
cd "c:\Projects\Observability\demos\azure-native-vs-dynatrace"

# Copy configuration templates
Copy-Item "azure-native-setup\infrastructure\main.parameters.json.template" "azure-native-setup\infrastructure\main.parameters.json"
Copy-Item "dynatrace-setup\infrastructure\dynatrace-config.json.template" "dynatrace-setup\infrastructure\dynatrace-config.json"
```

### Step 2: Configure Azure Native Setup
Edit `azure-native-setup\infrastructure\main.parameters.json`:
```json
{
  "parameters": {
    "resourceGroupName": { "value": "rg-observability-demo" },
    "location": { "value": "East US" },
    "applicationName": { "value": "observability-demo" },
    "subscriptionId": { "value": "YOUR_SUBSCRIPTION_ID" }
  }
}
```

### Step 3: Configure Dynatrace Setup
Edit `dynatrace-setup\infrastructure\dynatrace-config.json`:
```json
{
  "environment": {
    "url": "https://YOUR_TENANT.live.dynatrace.com",
    "apiToken": "YOUR_API_TOKEN",
    "paasToken": "YOUR_PAAS_TOKEN"
  }
}
```

### Step 4: Deploy Azure Native Infrastructure
```powershell
# Run the Azure deployment script
.\azure-native-setup\scripts\deploy-infrastructure.ps1 -ResourceGroupName "rg-observability-demo" -Location "East US" -SubscriptionId "YOUR_SUBSCRIPTION_ID"
```

### Step 5: Deploy Dynatrace Monitoring
```powershell
# Run the Dynatrace deployment script
.\dynatrace-setup\scripts\deploy-oneagent.ps1 -Environment "YOUR_TENANT" -ApiToken "YOUR_API_TOKEN"
```

### Step 6: Deploy Sample Application
```powershell
# Build and deploy the sample application
cd sample-app
dotnet build
dotnet publish -c Release

# Deploy to Azure App Service (created in step 4)
az webapp deployment source config-zip --resource-group "rg-observability-demo" --name "app-observability-demo" --src "bin/Release/net8.0/publish.zip"
```

### Step 7: Generate Load and Compare
```powershell
# Generate test load
.\scripts\generate-load.ps1 -Duration 30 -MaxUsers 100

# Wait for data collection (5-10 minutes)
Start-Sleep -Seconds 600

# Run comparison analysis
.\scripts\run-comparison.ps1
```

## 📊 Results

After running the demo, you'll find comparison results in the `comparison-results` folder:
- `performance-metrics.json` - Raw performance data
- `cost-analysis.md` - Detailed cost comparison
- `feature-comparison.md` - Feature-by-feature analysis
- `summary-report.md` - Executive summary

## 🎯 Key Demo Scenarios

### Scenario 1: Performance Monitoring
- **Azure Native**: View response times in Application Insights
- **Dynatrace**: Analyze Purepath traces and AI insights
- **Compare**: Data richness and insight quality

### Scenario 2: Error Detection
- **Azure Native**: Set up alerts in Azure Monitor
- **Dynatrace**: Configure Davis AI for automatic detection
- **Compare**: Time to detection and root cause analysis

### Scenario 3: Infrastructure Monitoring
- **Azure Native**: Monitor VM/container metrics
- **Dynatrace**: View Smartscape topology
- **Compare**: Visualization and correlation capabilities

### Scenario 4: User Experience
- **Azure Native**: Analyze user flows in App Insights
- **Dynatrace**: Review real user monitoring data
- **Compare**: User journey insights and session analysis

## 🔧 Troubleshooting

### Common Issues

#### Azure CLI Authentication
```powershell
# If you encounter authentication issues
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

#### Dynatrace API Token Issues
- Ensure token has required permissions:
  - API v2 scopes: `metrics.read`, `entities.read`, `problems.read`
  - API v1 scopes: `DataExport`, `PluginUpload`

#### Application Deployment Issues
```powershell
# Check deployment status
az webapp deployment list --resource-group "rg-observability-demo" --name "app-observability-demo"

# View application logs
az webapp log tail --resource-group "rg-observability-demo" --name "app-observability-demo"
```

### Resource Cleanup
```powershell
# Clean up Azure resources
az group delete --name "rg-observability-demo" --yes --no-wait

# Clean up Dynatrace monitoring
.\dynatrace-setup\scripts\cleanup-monitoring.ps1
```

## 📚 Next Steps

1. **Review Results**: Analyze the generated comparison reports
2. **Customize Scenarios**: Modify the sample app for your specific use cases
3. **Scale Testing**: Increase load generation for more realistic scenarios
4. **Cost Optimization**: Experiment with different retention and sampling settings
5. **Advanced Features**: Explore specific capabilities like synthetic monitoring or security features

## 🆘 Support

- **Azure Issues**: Azure Support or Microsoft Documentation
- **Dynatrace Issues**: Dynatrace Support or Community Forum
- **Demo Issues**: Check the troubleshooting section or create an issue in the repository

## 💡 Tips for Success

1. **Start Small**: Begin with the quick demo before customizing
2. **Monitor Costs**: Keep an eye on Azure costs during testing
3. **Document Findings**: Take notes on differences you observe
4. **Team Involvement**: Include both development and operations teams
5. **Real Scenarios**: Test with your actual application patterns when possible
