@description('Environment name (dev, test, prod)')
param environmentName string = 'demo'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Log Analytics workspace name')
param workspaceName string

@description('Log Analytics workspace retention in days')
param retentionInDays int = 90

@description('Daily quota in GB (-1 for unlimited)')
param dailyQuotaGb int = -1

@description('Tags to apply to all resources')
param tags object = {
  Environment: environmentName
  Purpose: 'Observability-Demo'
  CreatedBy: 'Demo-Script'
}

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    features: {
      immediatePurgeDataOn30Days: environmentName == 'dev'
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: dailyQuotaGb
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Data Collection Rule for Performance Monitoring
resource performanceDataCollectionRule 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: 'dcr-${environmentName}-performance'
  location: location
  tags: tags
  properties: {
    description: 'Data collection rule for performance counters and Windows events'
    dataSources: {
      performanceCounters: [
        {
          name: 'perfCounterDataSource60'
          samplingFrequencyInSeconds: 60
          counterSpecifiers: [
            '\\Processor(_Total)\\% Processor Time'
            '\\Memory\\Available MBytes'
            '\\Memory\\% Committed Bytes In Use'
            '\\LogicalDisk(_Total)\\Disk Reads/sec'
            '\\LogicalDisk(_Total)\\Disk Writes/sec'
            '\\LogicalDisk(_Total)\\% Free Space'
            '\\Network Interface(*)\\Bytes Total/sec'
            '\\Process(_Total)\\Thread Count'
            '\\Process(_Total)\\Handle Count'
          ]
          streams: [
            'Microsoft-Perf'
          ]
        }
      ]
      windowsEventLogs: [
        {
          name: 'eventLogsDataSource'
          streams: [
            'Microsoft-Event'
          ]
          xPathQueries: [
            'Application!*[System[(Level=1 or Level=2 or Level=3)]]'
            'System!*[System[(Level=1 or Level=2 or Level=3)]]'
            'Security!*[System[(EventID=4625 or EventID=4624 or EventID=4648)]]'
          ]
        }
      ]
      syslog: [
        {
          name: 'syslogDataSource'
          streams: [
            'Microsoft-Syslog'
          ]
          facilityNames: [
            'auth'
            'authpriv'
            'cron'
            'daemon'
            'kern'
            'syslog'
            'user'
          ]
          logLevels: [
            'Debug'
            'Info'
            'Notice'
            'Warning'
            'Error'
            'Critical'
            'Alert'
            'Emergency'
          ]
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          name: 'la-destination'
          workspaceResourceId: logAnalyticsWorkspace.id
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-Perf'
          'Microsoft-Event'
          'Microsoft-Syslog'
        ]
        destinations: [
          'la-destination'
        ]
      }
    ]
  }
}

// Action Group for Alerts
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-${environmentName}-critical'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'Critical'
    enabled: true
    emailReceivers: [
      {
        name: 'Admin Email'
        emailAddress: 'admin@company.com'
        useCommonAlertSchema: true
      }
    ]
    webhookReceivers: [
      {
        name: 'Teams Webhook'
        serviceUri: 'https://outlook.office.com/webhook/your-webhook-url'
        useCommonAlertSchema: true
      }
    ]
  }
}

// Sample Alert Rules
resource highCpuAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'alert-${environmentName}-high-cpu'
  location: location
  tags: tags
  properties: {
    description: 'Alert when CPU usage exceeds 80% for 10 minutes'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT10M'
    criteria: {
      allOf: [
        {
          query: 'Perf | where CounterName == "% Processor Time" and InstanceName == "_Total" | summarize AggregatedValue = avg(CounterValue) by bin(TimeGenerated, 5m), Computer'
          timeAggregation: 'Average'
          metricMeasureColumn: 'AggregatedValue'
          operator: 'GreaterThan'
          threshold: 80
          failingPeriods: {
            numberOfEvaluationPeriods: 2
            minFailingPeriodsToAlert: 2
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroup.id
      ]
    }
    scopes: [
      logAnalyticsWorkspace.id
    ]
  }
}

resource lowDiskSpaceAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'alert-${environmentName}-low-disk-space'
  location: location
  tags: tags
  properties: {
    description: 'Alert when disk free space is below 10%'
    severity: 1
    enabled: true
    evaluationFrequency: 'PT15M'
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          query: 'Perf | where CounterName == "% Free Space" | summarize AggregatedValue = avg(CounterValue) by bin(TimeGenerated, 5m), Computer, InstanceName'
          timeAggregation: 'Average'
          metricMeasureColumn: 'AggregatedValue'
          operator: 'LessThan'
          threshold: 10
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroup.id
      ]
    }
    scopes: [
      logAnalyticsWorkspace.id
    ]
  }
}

resource failedLoginsAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'alert-${environmentName}-failed-logins'
  location: location
  tags: tags
  properties: {
    description: 'Alert when more than 5 failed logins occur in 5 minutes'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: 'SecurityEvent | where EventID == 4625 | summarize AggregatedValue = count() by bin(TimeGenerated, 5m), Computer'
          timeAggregation: 'Total'
          metricMeasureColumn: 'AggregatedValue'
          operator: 'GreaterThan'
          threshold: 5
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroup.id
      ]
    }
    scopes: [
      logAnalyticsWorkspace.id
    ]
  }
}

// Outputs
output workspaceId string = logAnalyticsWorkspace.id
output workspaceName string = logAnalyticsWorkspace.name
output workspaceKey string = logAnalyticsWorkspace.listKeys().primarySharedKey
output workspaceResourceId string = logAnalyticsWorkspace.id
output dataCollectionRuleId string = performanceDataCollectionRule.id
output actionGroupId string = actionGroup.id
