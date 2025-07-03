@description('Environment name')
param environmentName string

@description('Location for resources')
param location string = resourceGroup().location

@description('Log Analytics workspace resource ID')
param workspaceResourceId string

@description('Critical action group resource ID')
param criticalActionGroupId string

@description('Warning action group resource ID')
param warningActionGroupId string

@description('Tags to apply to resources')
param tags object = {}

// High CPU Usage Alert
resource highCpuAlert 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = {
  name: 'alert-high-cpu-${environmentName}'
  location: location
  tags: tags
  properties: {
    displayName: 'High CPU Usage'
    description: 'Alert when CPU usage exceeds 80% for more than 5 minutes'
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
          query: 'Perf | where ObjectName == "Processor" and CounterName == "% Processor Time" and InstanceName == "_Total" | where CounterValue > 80 | summarize AggregatedValue = avg(CounterValue) by Computer'
          timeAggregation: 'Average'
          metricMeasureColumn: 'AggregatedValue'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: ['*']
            }
          ]
          operator: 'GreaterThan'
          threshold: 80
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        warningActionGroupId
      ]
    }
  }
}

// Low Memory Alert
resource lowMemoryAlert 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = {
  name: 'alert-low-memory-${environmentName}'
  location: location
  tags: tags
  properties: {
    displayName: 'Low Available Memory'
    description: 'Alert when available memory is less than 10%'
    severity: 1
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    scopes: [
      workspaceResourceId
    ]
    criteria: {
      allOf: [
        {
          query: 'Perf | where ObjectName == "Memory" and CounterName == "Available MBytes" | extend AvailableMemoryPercentage = CounterValue / 1024 * 100 | where AvailableMemoryPercentage < 10 | summarize AggregatedValue = avg(AvailableMemoryPercentage) by Computer'
          timeAggregation: 'Average'
          metricMeasureColumn: 'AggregatedValue'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: ['*']
            }
          ]
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
        criticalActionGroupId
      ]
    }
  }
}

// Disk Space Alert
resource lowDiskSpaceAlert 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = {
  name: 'alert-low-disk-space-${environmentName}'
  location: location
  tags: tags
  properties: {
    displayName: 'Low Disk Space'
    description: 'Alert when disk free space is less than 10%'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT15M'
    windowSize: 'PT30M'
    scopes: [
      workspaceResourceId
    ]
    criteria: {
      allOf: [
        {
          query: 'Perf | where ObjectName == "LogicalDisk" and CounterName == "% Free Space" and InstanceName != "_Total" | where CounterValue < 10 | summarize AggregatedValue = avg(CounterValue) by Computer, InstanceName'
          timeAggregation: 'Average'
          metricMeasureColumn: 'AggregatedValue'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: ['*']
            }
            {
              name: 'InstanceName'
              operator: 'Include'
              values: ['*']
            }
          ]
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
        warningActionGroupId
      ]
    }
  }
}

// Service Down Alert
resource serviceDownAlert 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = {
  name: 'alert-service-down-${environmentName}'
  location: location
  tags: tags
  properties: {
    displayName: 'Service Down'
    description: 'Alert when services are not sending heartbeats'
    severity: 0
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT10M'
    scopes: [
      workspaceResourceId
    ]
    criteria: {
      allOf: [
        {
          query: 'Heartbeat | summarize Count = count() by Computer | where Count == 0'
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
        criticalActionGroupId
      ]
    }
  }
}

// Outputs
output highCpuAlertId string = highCpuAlert.id
output lowMemoryAlertId string = lowMemoryAlert.id
output lowDiskSpaceAlertId string = lowDiskSpaceAlert.id
output serviceDownAlertId string = serviceDownAlert.id
