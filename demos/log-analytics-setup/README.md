# Log Analytics Workspace Setup Demo

This demo walks through setting up a Log Analytics workspace and configuring data collection for comprehensive observability.

## Prerequisites

- Azure CLI installed and authenticated
- PowerShell 7+ or Azure Cloud Shell
- Contributor access to Azure subscription
- Resource group for observability resources

## Demo Overview

1. **Deploy Log Analytics Workspace** - Create the central logging platform
2. **Configure Data Collection Rules** - Set up automated data ingestion
3. **Enable Diagnostic Settings** - Connect Azure resources to the workspace
4. **Install Monitoring Agents** - Set up VM and container monitoring
5. **Create Sample Queries** - Demonstrate KQL capabilities
6. **Set Up Basic Alerts** - Implement proactive monitoring

## Step 1: Deploy Infrastructure

### Deploy Using Bicep Template

```powershell
# Set variables
$resourceGroupName = "rg-observability-demo"
$location = "East US"
$workspaceName = "law-demo-$(Get-Random -Maximum 9999)"

# Create resource group
az group create --name $resourceGroupName --location $location

# Deploy Log Analytics workspace
az deployment group create \
  --resource-group $resourceGroupName \
  --template-file ./templates/log-analytics-workspace.bicep \
  --parameters @./templates/log-analytics-workspace.parameters.json \
  --parameters workspaceName=$workspaceName
```

### Alternative: Deploy Using Azure CLI

```powershell
# Create Log Analytics workspace
$workspace = az monitor log-analytics workspace create \
  --resource-group $resourceGroupName \
  --workspace-name $workspaceName \
  --location $location \
  --sku PerGB2018 \
  --retention-time 90 \
  --query "id" -o tsv

Write-Host "Log Analytics Workspace ID: $workspace"

# Get workspace key for agents
$workspaceKey = az monitor log-analytics workspace get-shared-keys \
  --resource-group $resourceGroupName \
  --workspace-name $workspaceName \
  --query "primarySharedKey" -o tsv

Write-Host "Workspace Key: $workspaceKey"
```

## Step 2: Configure Data Collection Rules

### Create Performance Counter Collection Rule

```powershell
# Create DCR for performance monitoring
$dcrConfig = @"
{
  "location": "$location",
  "properties": {
    "dataSources": {
      "performanceCounters": [
        {
          "name": "perfCounterDataSource60",
          "samplingFrequencyInSeconds": 60,
          "counterSpecifiers": [
            "\\Processor(_Total)\\% Processor Time",
            "\\Memory\\Available MBytes",
            "\\Memory\\% Committed Bytes In Use",
            "\\LogicalDisk(_Total)\\Disk Reads/sec",
            "\\LogicalDisk(_Total)\\Disk Writes/sec",
            "\\LogicalDisk(_Total)\\% Free Space",
            "\\Network Interface(*)\\Bytes Total/sec"
          ],
          "streams": ["Microsoft-Perf"]
        }
      ],
      "windowsEventLogs": [
        {
          "name": "eventLogsDataSource",
          "streams": ["Microsoft-Event"],
          "xPathQueries": [
            "Application!*[System[(Level=1 or Level=2 or Level=3)]]",
            "System!*[System[(Level=1 or Level=2 or Level=3)]]",
            "Security!*[System[(EventID=4625 or EventID=4624)]]"
          ]
        }
      ]
    },
    "destinations": {
      "logAnalytics": [
        {
          "name": "la-destination",
          "workspaceResourceId": "$workspace"
        }
      ]
    },
    "dataFlows": [
      {
        "streams": ["Microsoft-Perf", "Microsoft-Event"],
        "destinations": ["la-destination"]
      }
    ]
  }
}
"@

$dcrConfig | Out-File -FilePath "dcr-config.json"

# Create the DCR
az monitor data-collection rule create \
  --resource-group $resourceGroupName \
  --name "dcr-demo-performance" \
  --rule-file "dcr-config.json"
```

## Step 3: Enable Diagnostic Settings

### Enable Activity Logs

```powershell
# Get subscription ID
$subscriptionId = az account show --query "id" -o tsv

# Enable Activity Log collection
az monitor diagnostic-settings subscription create \
  --name "activity-logs-to-workspace" \
  --location $location \
  --workspace $workspace \
  --logs '[
    {
      "category": "Administrative",
      "enabled": true
    },
    {
      "category": "Security", 
      "enabled": true
    },
    {
      "category": "Alert",
      "enabled": true
    },
    {
      "category": "Policy",
      "enabled": true
    }
  ]'
```

### Enable Resource Diagnostics (Example: Storage Account)

```powershell
# Create a demo storage account
$storageAccountName = "sademo$(Get-Random -Maximum 9999)"
az storage account create \
  --name $storageAccountName \
  --resource-group $resourceGroupName \
  --location $location \
  --sku Standard_LRS

# Get storage account resource ID
$storageId = az storage account show \
  --name $storageAccountName \
  --resource-group $resourceGroupName \
  --query "id" -o tsv

# Enable diagnostic settings for storage account
az monitor diagnostic-settings create \
  --name "storage-diagnostics" \
  --resource $storageId \
  --workspace $workspace \
  --logs '[
    {
      "category": "StorageRead",
      "enabled": true
    },
    {
      "category": "StorageWrite", 
      "enabled": true
    },
    {
      "category": "StorageDelete",
      "enabled": true
    }
  ]' \
  --metrics '[
    {
      "category": "Transaction",
      "enabled": true
    }
  ]'
```

## Step 4: Install Monitoring Agents

### Install Azure Monitor Agent on Windows VM

```powershell
# Assuming you have a Windows VM, get its resource ID
$vmResourceId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachines/myWindowsVM"

# Install Azure Monitor Agent extension
az vm extension set \
  --resource-group $resourceGroupName \
  --vm-name "myWindowsVM" \
  --name AzureMonitorWindowsAgent \
  --publisher Microsoft.Azure.Monitor \
  --enable-auto-upgrade true

# Associate DCR with the VM
az monitor data-collection rule association create \
  --name "dcr-association" \
  --rule-id "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Insights/dataCollectionRules/dcr-demo-performance" \
  --resource $vmResourceId
```

### Install Container Insights for AKS (if applicable)

```powershell
# Enable Container Insights on existing AKS cluster
az aks enable-addons \
  --resource-group $resourceGroupName \
  --name "myAKSCluster" \
  --addons monitoring \
  --workspace-resource-id $workspace
```

## Step 5: Sample KQL Queries

### Basic Data Exploration

```kql
// Check data ingestion
Heartbeat
| where TimeGenerated > ago(1h)
| summarize count() by Computer, bin(TimeGenerated, 5m)
| render timechart

// Performance overview
Perf
| where TimeGenerated > ago(1h)
| where CounterName in ("% Processor Time", "Available MBytes")
| summarize avg(CounterValue) by CounterName, Computer, bin(TimeGenerated, 5m)
| render timechart

// Event log analysis
Event
| where TimeGenerated > ago(1h)
| where EventLevelName in ("Error", "Warning")
| summarize count() by EventLevelName, Computer, bin(TimeGenerated, 10m)
| render timechart

// Activity log analysis
AzureActivity
| where TimeGenerated > ago(1h)
| where ActivityStatusValue == "Failed"
| summarize count() by OperationNameValue, ResourceProvider
| order by count_ desc
```

### Advanced Analysis Queries

```kql
// Disk space monitoring
Perf
| where TimeGenerated > ago(1h)
| where CounterName == "% Free Space"
| where CounterValue < 20  // Less than 20% free space
| project TimeGenerated, Computer, InstanceName, CounterValue
| order by CounterValue asc

// Failed login attempts
SecurityEvent
| where TimeGenerated > ago(1h)
| where EventID == 4625  // Failed logon
| summarize FailedAttempts = count() by Account, WorkstationName, IpAddress
| where FailedAttempts > 3
| order by FailedAttempts desc

// Resource utilization correlation
Perf
| where TimeGenerated > ago(1h)
| where CounterName in ("% Processor Time", "% Committed Bytes In Use")
| summarize avg(CounterValue) by CounterName, Computer, bin(TimeGenerated, 5m)
| evaluate pivot(CounterName, avg_CounterValue)
| extend UtilizationScore = todouble(List_% Processor Time) + todouble(List_% Committed Bytes In Use)
| where UtilizationScore > 150  // High combined utilization
| project TimeGenerated, Computer, CpuUsage = List_% Processor Time, MemoryUsage = List_% Committed Bytes In Use, UtilizationScore
```

## Step 6: Create Basic Alerts

### High CPU Usage Alert

```powershell
# Create action group
$actionGroupId = az monitor action-group create \
  --resource-group $resourceGroupName \
  --name "ag-demo-alerts" \
  --short-name "DemoAlerts" \
  --email-receivers name="Admin" email="admin@company.com" \
  --query "id" -o tsv

# Create CPU usage alert
az monitor scheduled-query create \
  --resource-group $resourceGroupName \
  --name "High CPU Usage" \
  --description "Alert when CPU usage exceeds 80% for 10 minutes" \
  --condition "avg(CounterValue) > 80" \
  --condition-query "Perf | where CounterName == '% Processor Time' and InstanceName == '_Total'" \
  --evaluation-frequency "5m" \
  --window-size "10m" \
  --severity 2 \
  --workspace $workspace \
  --action-groups $actionGroupId
```

### Failed Login Alert

```powershell
# Create failed login alert
az monitor scheduled-query create \
  --resource-group $resourceGroupName \
  --name "Multiple Failed Logins" \
  --description "Alert when more than 5 failed logins occur in 5 minutes" \
  --condition "count() > 5" \
  --condition-query "SecurityEvent | where EventID == 4625" \
  --evaluation-frequency "5m" \
  --window-size "5m" \
  --severity 1 \
  --workspace $workspace \
  --action-groups $actionGroupId
```

## Step 7: Create Custom Workbook

Save the following JSON as `demo-workbook.json`:

```json
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "# Infrastructure Monitoring Dashboard\n\nThis workbook provides an overview of your infrastructure health and performance."
      },
      "name": "title"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "Heartbeat\n| where TimeGenerated > ago(1h)\n| summarize LastHeartbeat = max(TimeGenerated) by Computer\n| extend Status = case(\n    LastHeartbeat > ago(5m), \"Healthy\",\n    LastHeartbeat > ago(15m), \"Warning\",\n    \"Critical\"\n)\n| summarize count() by Status",
        "size": 3,
        "title": "Server Health Status",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "visualization": "piechart"
      },
      "name": "server-health"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "Perf\n| where TimeGenerated > ago(1h)\n| where CounterName == \"% Processor Time\"\n| where InstanceName == \"_Total\"\n| summarize avg(CounterValue) by Computer, bin(TimeGenerated, 5m)\n| render timechart",
        "size": 0,
        "title": "CPU Usage Trends",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces"
      },
      "name": "cpu-trends"
    }
  ],
  "styleSettings": {},
  "fromTemplateId": "sentinel-UserWorkbook"
}
```

Import the workbook:

```powershell
az monitor app-insights workbook create \
  --resource-group $resourceGroupName \
  --name "Infrastructure Monitoring" \
  --display-name "Infrastructure Monitoring Dashboard" \
  --source-id $workspace \
  --category "workbook" \
  --template-data '@demo-workbook.json'
```

## Step 8: Verify Data Collection

### Check Data Ingestion

```powershell
# Run KQL query to verify data collection
$query = "union withsource=TableName *
| where TimeGenerated > ago(1h)
| summarize count() by TableName
| order by count_ desc"

az monitor log-analytics query \
  --workspace $workspace \
  --analytics-query $query
```

### Monitor Workspace Usage

```kql
// Check data ingestion by table
Usage
| where TimeGenerated > ago(24h)
| summarize DataMB = sum(Quantity) by DataType
| order by DataMB desc
| render barchart

// Monitor query performance
Usage
| where TimeGenerated > ago(24h) 
| where DataType == "Query"
| summarize AvgDuration = avg(Duration) by bin(TimeGenerated, 1h)
| render timechart
```

## Cleanup Resources

```powershell
# Remove the resource group and all resources
az group delete --name $resourceGroupName --yes --no-wait
```

## Next Steps

1. **Explore Additional Data Sources** - Connect more Azure services
2. **Create Custom Log Tables** - Ingest application-specific data
3. **Implement Advanced Analytics** - Use machine learning capabilities
4. **Set Up Automated Reports** - Create scheduled workbook exports
5. **Integrate with ITSM** - Connect alerts to ServiceNow or similar tools

## Troubleshooting

### Common Issues

1. **No Data Appearing**
   - Check diagnostic settings are enabled
   - Verify agent installation status
   - Review DCR associations

2. **Query Performance Issues**
   - Use time filters in queries
   - Avoid unnecessary joins
   - Consider data sampling for large datasets

3. **High Costs**
   - Monitor data ingestion volumes
   - Implement data retention policies
   - Use sampling for high-volume data sources

### Useful Commands

```powershell
# Check workspace status
az monitor log-analytics workspace show \
  --resource-group $resourceGroupName \
  --workspace-name $workspaceName

# List all tables in workspace
az monitor log-analytics workspace table list \
  --resource-group $resourceGroupName \
  --workspace-name $workspaceName

# Get workspace usage
az monitor log-analytics workspace get-usage \
  --resource-group $resourceGroupName \
  --workspace-name $workspaceName
```
