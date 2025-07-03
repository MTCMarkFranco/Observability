# Troubleshooting Guide: Azure Native vs Dynatrace Demo

## 🔧 Common Issues and Solutions

### Azure Native Setup Issues

#### 1. Azure CLI Authentication Problems
**Problem**: `az login` fails or shows authentication errors
**Solutions**:
```powershell
# Clear existing credentials
az logout
az account clear

# Login with specific tenant
az login --tenant "your-tenant-id"

# Login with device code (for MFA)
az login --use-device-code

# Verify login
az account show
```

#### 2. Insufficient Permissions
**Problem**: "Authorization failed" errors during deployment
**Solutions**:
- Ensure your account has `Contributor` role on the subscription
- Check if custom policies are blocking resource creation
- Verify subscription limits haven't been exceeded

```powershell
# Check your role assignments
az role assignment list --assignee $(az account show --query user.name -o tsv)

# Check subscription limits
az vm list-usage --location "East US" --output table
```

#### 3. Application Insights Connection Issues
**Problem**: No telemetry data appearing in Application Insights
**Solutions**:
- Verify connection string is correctly configured
- Check application is actually sending telemetry
- Ensure firewall rules allow Application Insights endpoints

```powershell
# Test telemetry endpoint connectivity
Test-NetConnection -ComputerName "dc.services.visualstudio.com" -Port 443

# Check Application Insights configuration
az monitor app-insights component show --app "your-app-insights-name" --resource-group "your-rg"
```

#### 4. Log Analytics Query Issues
**Problem**: KQL queries returning no results or errors
**Solutions**:
- Verify data retention settings
- Check if logs are being ingested (may take 5-10 minutes)
- Validate KQL syntax

```kusto
// Check if any data exists
search *
| limit 10

// Check specific table
AppRequests
| where TimeGenerated > ago(1h)
| limit 10
```

### Dynatrace Setup Issues

#### 1. OneAgent Installation Problems
**Problem**: OneAgent fails to install or doesn't report data
**Solutions**:
- Check network connectivity to Dynatrace cluster
- Verify API tokens have correct permissions
- Ensure host meets OneAgent requirements

```powershell
# Test connectivity to Dynatrace
Test-NetConnection -ComputerName "your-tenant.live.dynatrace.com" -Port 443

# Check OneAgent logs (Linux)
sudo journalctl -u dynatrace-oneagent

# Check OneAgent logs (Windows)
Get-EventLog -LogName "Application" -Source "Dynatrace OneAgent"
```

#### 2. API Token Issues
**Problem**: "Authentication failed" errors when using Dynatrace API
**Solutions**:
- Verify API token is correctly configured
- Check token permissions include required scopes
- Ensure token hasn't expired

**Required API v2 scopes**:
- `entities.read`
- `metrics.read`
- `problems.read`
- `events.ingest`

#### 3. Management Zone Configuration
**Problem**: Resources not appearing in management zones
**Solutions**:
- Check management zone rules
- Verify entity naming conventions
- Review auto-tagging rules

```bash
# Get management zones via API
curl -X GET "https://your-tenant.live.dynatrace.com/api/v2/managementZones" \
  -H "Authorization: Api-Token your-token"
```

#### 4. Kubernetes Deployment Issues
**Problem**: OneAgent pods failing to start
**Solutions**:
- Check Kubernetes cluster permissions
- Verify cluster meets OneAgent requirements
- Review pod logs for specific errors

```bash
# Check OneAgent pod status
kubectl get pods -n dynatrace

# Check pod logs
kubectl logs -n dynatrace -l app=dynatrace-oneagent

# Check events
kubectl get events -n dynatrace
```

### Sample Application Issues

#### 1. Application Build Failures
**Problem**: Sample app fails to build or compile
**Solutions**:
- Verify .NET 8 SDK is installed
- Check NuGet package restore
- Ensure all dependencies are available

```powershell
# Check .NET version
dotnet --version

# Restore packages
dotnet restore

# Build with verbose output
dotnet build --verbosity normal
```

#### 2. Database Connection Issues
**Problem**: Application can't connect to database
**Solutions**:
- Verify connection string is correct
- Check database server is running
- Ensure firewall rules allow connections

```powershell
# Test database connectivity
Test-NetConnection -ComputerName "your-sql-server.database.windows.net" -Port 1433

# Check connection string
$connectionString = "Server=your-server;Database=your-db;..."
# Test with SqlConnection
```

#### 3. Application Startup Issues
**Problem**: Application fails to start or throws exceptions
**Solutions**:
- Check application logs
- Verify configuration settings
- Ensure all required services are available

```powershell
# Check IIS logs (if using IIS)
Get-EventLog -LogName "System" -Source "IIS*"

# Check application event logs
Get-EventLog -LogName "Application" -Source "ASP.NET*"
```

### Load Testing Issues

#### 1. Load Generation Script Failures
**Problem**: Load generation script encounters errors
**Solutions**:
- Verify application is running and accessible
- Check network connectivity
- Adjust load test parameters

```powershell
# Test application endpoint
Invoke-RestMethod -Uri "https://your-app.azurewebsites.net/health" -Method GET

# Check application status
curl -I https://your-app.azurewebsites.net
```

#### 2. Insufficient Load Generation
**Problem**: Load test doesn't generate enough traffic
**Solutions**:
- Increase concurrent users
- Extend test duration
- Add more complex scenarios

```powershell
# Run with higher load
.\scripts\generate-load.ps1 -Duration 60 -MaxUsers 500 -RampUpTime 300
```

### Comparison Script Issues

#### 1. Missing Configuration Files
**Problem**: Comparison script can't find required configuration files
**Solutions**:
- Verify deployment scripts completed successfully
- Check file paths and permissions
- Ensure configuration files were generated

```powershell
# Check if deployment info exists
Test-Path "azure-native-setup\deployment-info.json"
Test-Path "dynatrace-setup\dynatrace-config-summary.json"

# List all generated files
Get-ChildItem -Recurse -Include "*.json" | Where-Object {$_.Name -match "config|deployment"}
```

#### 2. API Access Issues
**Problem**: Comparison script can't retrieve metrics from monitoring systems
**Solutions**:
- Verify API credentials are valid
- Check network connectivity
- Ensure required permissions are granted

```powershell
# Test Azure REST API access
$accessToken = az account get-access-token --query accessToken -o tsv
$headers = @{Authorization = "Bearer $accessToken"}
Invoke-RestMethod -Uri "https://management.azure.com/subscriptions/your-sub/providers/Microsoft.Insights/components" -Headers $headers
```

## 🔍 Diagnostic Commands

### Azure Diagnostics
```powershell
# Check Azure CLI status
az account show
az version

# Check resource group status
az group show --name "your-rg"

# Check application insights status
az monitor app-insights component show --app "your-app-insights" --resource-group "your-rg"

# Check app service logs
az webapp log tail --name "your-app-service" --resource-group "your-rg"
```

### Dynatrace Diagnostics
```bash
# Check OneAgent status (Linux)
sudo /opt/dynatrace/oneagent/agent/tools/oneagentctl --get-host-info

# Check OneAgent status (Windows)
& "C:\Program Files\dynatrace\oneagent\agent\tools\oneagentctl.exe" --get-host-info

# Test API connectivity
curl -X GET "https://your-tenant.live.dynatrace.com/api/v2/entities" \
  -H "Authorization: Api-Token your-token"
```

### Application Diagnostics
```powershell
# Check .NET application health
dotnet --list-runtimes
dotnet --info

# Check application configuration
Get-Content "appsettings.json" | ConvertFrom-Json

# Check application logs
Get-EventLog -LogName "Application" -Newest 50
```

## 🚨 Emergency Procedures

### Stop All Load Testing
```powershell
# Kill all PowerShell processes running load tests
Get-Process -Name "powershell" | Where-Object {$_.ProcessName -match "generate-load"} | Stop-Process -Force
```

### Quick Cleanup
```powershell
# Clean up Azure resources
az group delete --name "rg-observability-demo" --yes --no-wait

# Clean up Dynatrace monitoring
kubectl delete namespace dynatrace
```

### Reset Demo Environment
```powershell
# Remove generated files
Remove-Item -Recurse -Force "azure-native-setup\deployment-info.json" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "dynatrace-setup\dynatrace-config-summary.json" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "comparison-results\*" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "validation-results.json" -ErrorAction SilentlyContinue

# Reset configuration files
Copy-Item "azure-native-setup\infrastructure\main.parameters.json.template" "azure-native-setup\infrastructure\main.parameters.json" -Force
Copy-Item "dynatrace-setup\infrastructure\dynatrace-config.json.template" "dynatrace-setup\infrastructure\dynatrace-config.json" -Force
```

## 📞 Getting Help

### Azure Support
- **Azure Support**: [Azure Portal Support](https://portal.azure.com/#blade/Microsoft_Azure_Support/HelpAndSupportBlade)
- **Azure CLI Issues**: [Azure CLI GitHub](https://github.com/Azure/azure-cli/issues)
- **Application Insights**: [Application Insights Documentation](https://docs.microsoft.com/azure/azure-monitor/app/app-insights-overview)

### Dynatrace Support
- **Dynatrace Support**: [Dynatrace Help Center](https://help.dynatrace.com/)
- **Community Forum**: [Dynatrace Community](https://community.dynatrace.com/)
- **OneAgent Issues**: [OneAgent Documentation](https://www.dynatrace.com/support/help/setup-and-configuration/dynatrace-oneagent)

### Demo-Specific Issues
- Check the main README.md for general setup instructions
- Review the QUICKSTART.md for step-by-step guidance
- Run the validation script: `.\scripts\validate-setup.ps1`
- Check the comparison results folder for error logs

## 📋 Validation Checklist

Before proceeding with the demo, ensure all these items are checked:

### Azure Prerequisites
- [ ] Azure CLI installed and configured
- [ ] Logged into correct Azure subscription
- [ ] Subscription has sufficient permissions
- [ ] .NET 8 SDK installed
- [ ] PowerShell 7.0+ installed

### Dynatrace Prerequisites
- [ ] Dynatrace tenant available
- [ ] API tokens configured with correct permissions
- [ ] Kubernetes cluster available (if using OneAgent)
- [ ] Network connectivity to Dynatrace cluster

### Application Prerequisites
- [ ] Sample application builds successfully
- [ ] Database connections configured
- [ ] Application starts without errors
- [ ] Health endpoint returns 200 OK

### Configuration Files
- [ ] Azure parameters file configured
- [ ] Dynatrace configuration file configured
- [ ] Connection strings updated
- [ ] API tokens and keys configured

Run the validation script to automate these checks:
```powershell
.\scripts\validate-setup.ps1
```
