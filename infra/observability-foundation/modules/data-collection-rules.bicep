@description('Environment name')
param environmentName string

@description('Location for resources')
param location string = resourceGroup().location

@description('Log Analytics workspace resource ID')
param workspaceResourceId string

@description('Tags to apply to resources')
param tags object = {}

// Data Collection Rule for Windows VMs
resource windowsDataCollectionRule 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: 'dcr-windows-vm-${environmentName}'
  location: location
  tags: tags
  properties: {
    dataSources: {
      performanceCounters: [
        {
          streams: ['Microsoft-Perf']
          samplingFrequencyInSeconds: 60
          counterSpecifiers: [
            '\\Processor(_Total)\\% Processor Time'
            '\\Memory\\Available MBytes'
            '\\LogicalDisk(_Total)\\Disk Transfers/sec'
            '\\LogicalDisk(_Total)\\% Free Space'
            '\\Network Interface(*)\\Bytes Total/sec'
          ]
          name: 'perfCounterDataSource60'
        }
      ]
      // windowsEventLogs removed to avoid LAW table error
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: workspaceResourceId
          name: 'la-workspace'
        }
      ]
    }
    dataFlows: [
      {
        streams: ['Microsoft-Perf']
        destinations: ['la-workspace']
        transformKql: 'source'
        outputStream: 'Microsoft-Perf'
      }
      // Microsoft-WindowsEvent dataFlow removed
    ]
  }
}

// Data Collection Rule for Linux VMs
resource linuxDataCollectionRule 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: 'dcr-linux-vm-${environmentName}'
  location: location
  tags: tags
  properties: {
    dataSources: {
      performanceCounters: [
        {
          streams: ['Microsoft-Perf']
          samplingFrequencyInSeconds: 60
          counterSpecifiers: [
            'Processor(*)\\% Processor Time'
            'Memory(*)\\Available MBytes Memory'
            'Logical Disk(*)\\% Free Space'
            'Network(*)\\Total Bytes'
          ]
          name: 'perfCounterDataSource60'
        }
      ]
      syslog: [
        {
          streams: ['Microsoft-Syslog']
          facilityNames: ['auth', 'authpriv', 'cron', 'daemon', 'kern', 'local0', 'local1', 'local2', 'local3', 'local4', 'local5', 'local6', 'local7', 'lpr', 'mail', 'news', 'syslog', 'user', 'uucp']
          logLevels: ['Info', 'Notice', 'Warning', 'Error', 'Critical', 'Alert', 'Emergency']
          name: 'sysLogsDataSource'
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: workspaceResourceId
          name: 'la-workspace'
        }
      ]
    }
    dataFlows: [
      {
        streams: ['Microsoft-Perf']
        destinations: ['la-workspace']
        transformKql: 'source'
        outputStream: 'Microsoft-Perf'
      }
      {
        streams: ['Microsoft-Syslog']
        destinations: ['la-workspace']
        transformKql: 'source'
        outputStream: 'Microsoft-Syslog'
      }
    ]
  }
}

// Outputs
output windowsDataCollectionRuleId string = windowsDataCollectionRule.id
output linuxDataCollectionRuleId string = linuxDataCollectionRule.id
