@description('Creates comprehensive alert rules for observability monitoring')
param workspaceResourceId string
param applicationInsightsResourceId string
param actionGroupResourceId string
param location string = resourceGroup().location
param tags object = {}

@description('Alert rule for high CPU usage')
resource highCpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-high-cpu-usage'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when CPU usage exceeds 80% for 5 minutes'
    severity: 2
    enabled: true
    scopes: [
      workspaceResourceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          threshold: 80
          name: 'Metric1'
          metricNamespace: 'Microsoft.OperationalInsights/workspaces'
          metricName: 'Average_% Processor Time'
          operator: 'GreaterThan'
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroupResourceId
        webHookProperties: {}
      }
    ]
  }
}

@description('Alert rule for application errors')
resource applicationErrorsAlert 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = {
  name: 'alert-application-errors'
  location: location
  tags: tags
  properties: {
    displayName: 'High Application Error Rate'
    description: 'Alert when application error rate exceeds threshold'
    severity: 1
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    scopes: [
      applicationInsightsResourceId
    ]
    criteria: {
      allOf: [
        {
          query: '''
            exceptions
            | where timestamp > ago(15m)
            | summarize ErrorCount = count()
            | project ErrorCount
          '''
          timeAggregation: 'Count'
          metricMeasureColumn: 'ErrorCount'
          operator: 'GreaterThan'
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
        actionGroupResourceId
      ]
    }
  }
}

@description('Alert rule for slow response times')
resource slowResponseAlert 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = {
  name: 'alert-slow-response-times'
  location: location
  tags: tags
  properties: {
    displayName: 'Slow Application Response Times'
    description: 'Alert when average response time exceeds 5 seconds'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT10M'
    scopes: [
      applicationInsightsResourceId
    ]
    criteria: {
      allOf: [
        {
          query: '''
            requests
            | where timestamp > ago(10m)
            | summarize AvgResponseTime = avg(duration)
            | project AvgResponseTime
          '''
          timeAggregation: 'Average'
          metricMeasureColumn: 'AvgResponseTime'
          operator: 'GreaterThan'
          threshold: 5000
          failingPeriods: {
            numberOfEvaluationPeriods: 2
            minFailingPeriodsToAlert: 2
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroupResourceId
      ]
    }
  }
}

@description('Alert rule for memory usage')
resource highMemoryAlert 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = {
  name: 'alert-high-memory-usage'
  location: location
  tags: tags
  properties: {
    displayName: 'High Memory Usage'
    description: 'Alert when memory usage exceeds 90%'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    scopes: [
      workspaceResourceId
    ]
    criteria: {
      allOf: [
        {
          query: '''
            Perf
            | where ObjectName == "Memory" and CounterName == "% Committed Bytes In Use"
            | where TimeGenerated > ago(15m)
            | summarize AvgMemoryUsage = avg(CounterValue)
            | project AvgMemoryUsage
          '''
          timeAggregation: 'Average'
          metricMeasureColumn: 'AvgMemoryUsage'
          operator: 'GreaterThan'
          threshold: 90
          failingPeriods: {
            numberOfEvaluationPeriods: 3
            minFailingPeriodsToAlert: 2
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroupResourceId
      ]
    }
  }
}

@description('Alert rule for disk space')
resource lowDiskSpaceAlert 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = {
  name: 'alert-low-disk-space'
  location: location
  tags: tags
  properties: {
    displayName: 'Low Disk Space'
    description: 'Alert when disk free space is below 10%'
    severity: 1
    enabled: true
    evaluationFrequency: 'PT15M'
    windowSize: 'PT30M'
    scopes: [
      workspaceResourceId
    ]
    criteria: {
      allOf: [
        {
          query: '''
            Perf
            | where ObjectName == "LogicalDisk" and CounterName == "% Free Space"
            | where InstanceName != "_Total"
            | where TimeGenerated > ago(30m)
            | summarize MinFreeSpace = min(CounterValue) by Computer, InstanceName
            | where MinFreeSpace < 10
            | project Computer, InstanceName, MinFreeSpace
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroupResourceId
      ]
    }
  }
}

@description('Alert rule for failed login attempts')
resource failedLoginsAlert 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = {
  name: 'alert-failed-login-attempts'
  location: location
  tags: tags
  properties: {
    displayName: 'Multiple Failed Login Attempts'
    description: 'Alert when there are multiple failed login attempts from same IP'
    severity: 1
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT10M'
    scopes: [
      workspaceResourceId
    ]
    criteria: {
      allOf: [
        {
          query: '''
            SecurityEvent
            | where EventID == 4625
            | where TimeGenerated > ago(10m)
            | summarize FailedAttempts = count() by IpAddress, Account
            | where FailedAttempts >= 5
            | project IpAddress, Account, FailedAttempts
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroupResourceId
      ]
    }
  }
}

@description('Alert rule for database connection failures')
resource dbConnectionFailuresAlert 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = {
  name: 'alert-db-connection-failures'
  location: location
  tags: tags
  properties: {
    displayName: 'Database Connection Failures'
    description: 'Alert when database connections are failing'
    severity: 1
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT10M'
    scopes: [
      applicationInsightsResourceId
    ]
    criteria: {
      allOf: [
        {
          query: '''
            dependencies
            | where type == "SQL"
            | where success == false
            | where timestamp > ago(10m)
            | summarize FailureCount = count()
            | project FailureCount
          '''
          timeAggregation: 'Count'
          metricMeasureColumn: 'FailureCount'
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
        actionGroupResourceId
      ]
    }
  }
}

@description('Alert rule for anomalous user behavior')
resource anomalousUserBehaviorAlert 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = {
  name: 'alert-anomalous-user-behavior'
  location: location
  tags: tags
  properties: {
    displayName: 'Anomalous User Behavior'
    description: 'Alert on unusual user activity patterns'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT30M'
    windowSize: 'PT1H'
    scopes: [
      applicationInsightsResourceId
    ]
    criteria: {
      allOf: [
        {
          query: '''
            customEvents
            | where name == "UserLogin"
            | where timestamp > ago(1h)
            | extend Hour = hourofday(timestamp)
            | summarize LoginCount = count() by user_Id, Hour
            | join kind=leftanti (
                customEvents
                | where name == "UserLogin"
                | where timestamp between (ago(7d) .. ago(1d))
                | extend Hour = hourofday(timestamp)
                | summarize TypicalLogins = count() by user_Id, Hour
                | where TypicalLogins > 0
            ) on user_Id, Hour
            | project user_Id, Hour, LoginCount
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroupResourceId
      ]
    }
  }
}

// Outputs
output alertRuleIds array = [
  highCpuAlert.id
  applicationErrorsAlert.id
  slowResponseAlert.id
  highMemoryAlert.id
  lowDiskSpaceAlert.id
  failedLoginsAlert.id
  dbConnectionFailuresAlert.id
  anomalousUserBehaviorAlert.id
]
