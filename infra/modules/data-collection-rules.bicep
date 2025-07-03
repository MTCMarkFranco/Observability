@description('Creates data collection rules for Azure Monitor')
param workspaceResourceId string
param location string = resourceGroup().location
param tags object = {}

@description('Data collection rule for Windows VMs')
resource windowsDataCollectionRule 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: 'dcr-windows-vm-monitoring'
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
            '\\LogicalDisk(_Total)\\Disk Reads/sec'
            '\\LogicalDisk(_Total)\\Disk Writes/sec'
            '\\LogicalDisk(_Total)\\Avg. Disk sec/Transfer'
            '\\LogicalDisk(_Total)\\Avg. Disk sec/Read'
            '\\LogicalDisk(_Total)\\Avg. Disk sec/Write'
            '\\LogicalDisk(_Total)\\% Free Space'
            '\\Network Interface(*)\\Bytes Total/sec'
            '\\Process(_Total)\\Working Set'
            '\\Process(_Total)\\Virtual Bytes'
          ]
          name: 'perfCounterDataSource60'
        }
      ]
      windowsEventLogs: [
        {
          streams: ['Microsoft-WindowsEvent']
          xPathQueries: [
            'Security!*[System[(Level=1 or Level=2 or Level=3 or Level=4 or Level=0)]]'
            'Application!*[System[(Level=1 or Level=2 or Level=3)]]'
            'System!*[System[(Level=1 or Level=2 or Level=3)]]'
          ]
          name: 'windowsEventLogsDataSource'
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
        transformKql: 'source | where ObjectName == "Processor" and CounterName == "% Processor Time" and InstanceName == "_Total"'
        outputStream: 'Microsoft-Perf'
      }
      {
        streams: ['Microsoft-WindowsEvent']
        destinations: ['la-workspace']
        transformKql: 'source | where Channel == "Security" and EventID in (4624, 4625, 4648, 4720, 4722, 4732)'
        outputStream: 'Microsoft-WindowsEvent'
      }
    ]
  }
}

@description('Data collection rule for Linux VMs')
resource linuxDataCollectionRule 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: 'dcr-linux-vm-monitoring'
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
            'Processor(*)\\% Idle Time'
            'Processor(*)\\% User Time'
            'Processor(*)\\% System Time'
            'Memory(*)\\Available MBytes Memory'
            'Memory(*)\\% Available Memory'
            'Memory(*)\\Used Memory MBytes'
            'Memory(*)\\% Used Memory'
            'Logical Disk(*)\\% Free Inodes'
            'Logical Disk(*)\\% Used Inodes'
            'Logical Disk(*)\\Free Megabytes'
            'Logical Disk(*)\\% Free Space'
            'Logical Disk(*)\\% Used Space'
            'Logical Disk(*)\\Disk Transfers/sec'
            'Logical Disk(*)\\Disk Reads/sec'
            'Logical Disk(*)\\Disk Writes/sec'
            'Network(*)\\Total Bytes Transmitted'
            'Network(*)\\Total Bytes Received'
            'Network(*)\\Total Bytes'
          ]
          name: 'perfCounterDataSource60'
        }
      ]
      syslog: [
        {
          streams: ['Microsoft-Syslog']
          facilityNames: ['auth', 'authpriv', 'cron', 'daemon', 'mark', 'kern', 'local0', 'local1', 'local2', 'local3', 'local4', 'local5', 'local6', 'local7', 'lpr', 'mail', 'news', 'syslog', 'user', 'uucp']
          logLevels: ['Debug', 'Info', 'Notice', 'Warning', 'Error', 'Critical', 'Alert', 'Emergency']
          name: 'sysLogsDataSource-debugLevel'
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
        transformKql: 'source | where Facility in ("auth", "authpriv", "daemon", "kern")'
        outputStream: 'Microsoft-Syslog'
      }
    ]
  }
}

@description('Data collection rule for application logs')
resource applicationDataCollectionRule 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: 'dcr-application-monitoring'
  location: location
  tags: tags
  properties: {
    dataSources: {
      logFiles: [
        {
          streams: ['Custom-ApplicationLogs']
          filePatterns: [
            '/var/log/myapp/*.log'
            'C:\\Logs\\MyApp\\*.log'
          ]
          format: 'text'
          name: 'applicationLogsDataSource'
          settings: {
            text: {
              recordStartTimestampFormat: 'ISO 8601'
            }
          }
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
        streams: ['Custom-ApplicationLogs']
        destinations: ['la-workspace']
        transformKql: 'source | extend TimeGenerated = now()'
        outputStream: 'Custom-ApplicationLogs_CL'
      }
    ]
    streamDeclarations: {
      'Custom-ApplicationLogs': {
        columns: [
          {
            name: 'TimeGenerated'
            type: 'datetime'
          }
          {
            name: 'RawData'
            type: 'string'
          }
        ]
      }
    }
  }
}

// Outputs
output windowsDataCollectionRuleId string = windowsDataCollectionRule.id
output linuxDataCollectionRuleId string = linuxDataCollectionRule.id
output applicationDataCollectionRuleId string = applicationDataCollectionRule.id
