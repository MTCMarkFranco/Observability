@description('Environment name')
param environmentName string

@description('Location for resources')
param location string = resourceGroup().location

@description('Log Analytics workspace resource ID')
param workspaceResourceId string

@description('Application Insights resource ID')
param applicationInsightsResourceId string

@description('Tags to apply to resources')
param tags object = {}

// Infrastructure Overview Workbook
resource infrastructureWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid('infrastructure-workbook-${environmentName}')
  location: location
  tags: tags
  kind: 'shared'
  properties: {
    displayName: 'Infrastructure Overview - ${environmentName}'
    serializedData: string(infrastructureWorkbookContent)
    version: '1.0'
    sourceId: workspaceResourceId
    category: 'workbook'
  }
}

// Application Performance Workbook
resource applicationWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid('application-workbook-${environmentName}')
  location: location
  tags: tags
  kind: 'shared'
  properties: {
    displayName: 'Application Performance - ${environmentName}'
    serializedData: string(applicationWorkbookContent)
    version: '1.0'
    sourceId: applicationInsightsResourceId
    category: 'workbook'
  }
}

// Variables containing workbook JSON content
var infrastructureWorkbookContent = {
  version: 'Notebook/1.0'
  items: [
    {
      type: 1
      content: {
        json: '# Infrastructure Overview Dashboard\n\nThis workbook provides an overview of your infrastructure monitoring data.'
      }
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'Heartbeat\n| where TimeGenerated > ago(24h)\n| summarize LastHeartbeat = max(TimeGenerated) by Computer\n| extend Status = iff(LastHeartbeat > ago(5m), "Online", "Offline")\n| summarize OnlineCount = countif(Status == "Online"), OfflineCount = countif(Status == "Offline")\n| extend Total = OnlineCount + OfflineCount\n| project OnlineCount, OfflineCount, Total'
        size: 3
        title: 'Server Status Summary'
        timeContext: {
          durationMs: 86400000
        }
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
      }
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'Perf\n| where TimeGenerated > ago(1h)\n| where ObjectName == "Processor" and CounterName == "% Processor Time" and InstanceName == "_Total"\n| summarize AvgCPU = avg(CounterValue) by Computer\n| order by AvgCPU desc\n| take 10'
        size: 0
        title: 'Top 10 Servers by CPU Usage'
        timeContext: {
          durationMs: 3600000
        }
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
      }
    }
  ]
  isLocked: false
  fallbackResourceIds: [
    workspaceResourceId
  ]
}

var applicationWorkbookContent = {
  version: 'Notebook/1.0'
  items: [
    {
      type: 1
      content: {
        json: '# Application Performance Dashboard\n\nThis workbook provides insights into your application performance and health.'
      }
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'requests\n| where timestamp > ago(24h)\n| summarize RequestCount = count(), AvgDuration = avg(duration), FailureRate = countif(success == false) * 100.0 / count()\n| project RequestCount, AvgDuration, FailureRate'
        size: 3
        title: 'Application Summary (24h)'
        timeContext: {
          durationMs: 86400000
        }
        queryType: 0
        resourceType: 'microsoft.insights/components'
      }
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'requests\n| where timestamp > ago(1h)\n| summarize RequestCount = count() by bin(timestamp, 5m)\n| render timechart'
        size: 0
        title: 'Request Rate Over Time'
        timeContext: {
          durationMs: 3600000
        }
        queryType: 0
        resourceType: 'microsoft.insights/components'
      }
    }
  ]
  isLocked: false
  fallbackResourceIds: [
    applicationInsightsResourceId
  ]
}

// Outputs
output infrastructureWorkbookId string = infrastructureWorkbook.id
output applicationWorkbookId string = applicationWorkbook.id
