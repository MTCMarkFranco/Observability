@description('The name of the environment (e.g., dev, staging, prod)')
param environmentName string = 'demo'

@description('The primary location for all resources')
param location string = resourceGroup().location

@description('The name of the application')
param applicationName string = 'observability-demo'

@description('The SKU for the Log Analytics workspace')
param logAnalyticsSkuName string = 'PerGB2018'

@description('The retention period for Log Analytics in days')
param logAnalyticsRetentionDays int = 30

@description('The daily quota for Log Analytics in GB')
param logAnalyticsDailyQuotaGb int = 10

@description('The SKU for SQL Database')
param sqlDatabaseSkuName string = 'Basic'

@description('The SKU for App Service Plan')
param appServicePlanSkuName string = 'B1'

@description('The admin username for SQL Server')
param sqlAdminUsername string = 'sqladmin'

@description('The admin password for SQL Server')
@secure()
param sqlAdminPassword string

// Variables
var resourcePrefix = '${applicationName}-${environmentName}'
var resourceSuffix = uniqueString(resourceGroup().id)

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${resourcePrefix}-logs-${resourceSuffix}'
  location: location
  properties: {
    sku: {
      name: logAnalyticsSkuName
    }
    retentionInDays: logAnalyticsRetentionDays
    workspaceCapping: {
      dailyQuotaGb: logAnalyticsDailyQuotaGb
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: {
    Environment: environmentName
    Application: applicationName
  }
}

// Application Insights
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${resourcePrefix}-ai-${resourceSuffix}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    SamplingPercentage: 100
  }
  tags: {
    Environment: environmentName
    Application: applicationName
  }
}

// SQL Server
resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: '${resourcePrefix}-sql-${resourceSuffix}'
  location: location
  properties: {
    administratorLogin: sqlAdminUsername
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    publicNetworkAccess: 'Enabled'
  }
  tags: {
    Environment: environmentName
    Application: applicationName
  }
}

// SQL Database
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: '${applicationName}DB'
  location: location
  sku: {
    name: sqlDatabaseSkuName
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 1073741824 // 1GB
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: false
    readScale: 'Disabled'
    requestedBackupStorageRedundancy: 'Local'
  }
  tags: {
    Environment: environmentName
    Application: applicationName
  }
}

// SQL Server Firewall Rules
resource sqlServerFirewallRule 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Redis Cache
resource redisCache 'Microsoft.Cache/redis@2023-08-01' = {
  name: '${resourcePrefix}-redis-${resourceSuffix}'
  location: location
  properties: {
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 0
    }
    redisConfiguration: {
      'maxmemory-policy': 'allkeys-lru'
    }
    enableNonSslPort: false
    publicNetworkAccess: 'Enabled'
  }
  tags: {
    Environment: environmentName
    Application: applicationName
  }
}

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${resourcePrefix}-plan-${resourceSuffix}'
  location: location
  sku: {
    name: appServicePlanSkuName
  }
  properties: {
    reserved: false
  }
  tags: {
    Environment: environmentName
    Application: applicationName
  }
}

// App Service
resource appService 'Microsoft.Web/sites@2023-12-01' = {
  name: '${resourcePrefix}-app-${resourceSuffix}'
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      netFrameworkVersion: 'v8.0'
      metadata: [
        {
          name: 'CURRENT_STACK'
          value: 'dotnet'
        }
      ]
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_Mode'
          value: 'Recommended'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_PreemptSdk'
          value: 'Disabled'
        }
        {
          name: 'APPINSIGHTS_PROFILERFEATURE_VERSION'
          value: '1.0.0'
        }
        {
          name: 'APPINSIGHTS_SNAPSHOTFEATURE_VERSION'
          value: '1.0.0'
        }
        {
          name: 'ConnectionStrings__DefaultConnection'
          value: 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Database=${sqlDatabase.name};User ID=${sqlAdminUsername};Password=${sqlAdminPassword};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
        }
        {
          name: 'ConnectionStrings__Redis'
          value: '${redisCache.properties.hostName}:${redisCache.properties.sslPort},password=${redisCache.listKeys().primaryKey},ssl=True,abortConnect=False'
        }
        {
          name: 'ConnectionStrings__ApplicationInsights'
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'ExternalServices__PaymentService__BaseUrl'
          value: 'https://httpbin.org'
        }
        {
          name: 'ExternalServices__ShippingService__BaseUrl'
          value: 'https://httpbin.org'
        }
      ]
    }
  }
  tags: {
    Environment: environmentName
    Application: applicationName
  }
}

// Diagnostic Settings for App Service
resource appServiceDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${appService.name}-diagnostics'
  scope: appService
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: logAnalyticsRetentionDays
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: logAnalyticsRetentionDays
        }
      }
    ]
  }
}

// Diagnostic Settings for SQL Database
resource sqlDatabaseDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${sqlDatabase.name}-diagnostics'
  scope: sqlDatabase
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: logAnalyticsRetentionDays
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: logAnalyticsRetentionDays
        }
      }
    ]
  }
}

// Action Group for Alerts
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: '${resourcePrefix}-alerts-${resourceSuffix}'
  location: 'Global'
  properties: {
    groupShortName: 'DemoAlerts'
    enabled: true
    emailReceivers: [
      {
        name: 'Admin'
        emailAddress: 'admin@example.com'
        useCommonAlertSchema: true
      }
    ]
    smsReceivers: []
    webhookReceivers: []
    azureAppPushReceivers: []
    automationRunbookReceivers: []
    voiceReceivers: []
    logicAppReceivers: []
    azureFunctionReceivers: []
    armRoleReceivers: []
  }
  tags: {
    Environment: environmentName
    Application: applicationName
  }
}

// Outputs
output resourceGroupName string = resourceGroup().name
output applicationInsightsConnectionString string = applicationInsights.properties.ConnectionString
output applicationInsightsInstrumentationKey string = applicationInsights.properties.InstrumentationKey
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
output sqlServerName string = sqlServer.name
output sqlDatabaseName string = sqlDatabase.name
output appServiceName string = appService.name
output appServiceUrl string = 'https://${appService.properties.defaultHostName}'
output redisCacheName string = redisCache.name
output actionGroupId string = actionGroup.id
