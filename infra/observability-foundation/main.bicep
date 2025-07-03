@description('Environment name (dev, test, prod)')
param environmentName string = 'dev'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Organization name for resource naming')
param organizationName string = 'contoso'

@description('Log Analytics workspace SKU')
@allowed(['Free', 'PerNode', 'PerGB2018', 'Standalone', 'Standard', 'Premium'])
param logAnalyticsSkuName string = 'PerGB2018'

@description('Log Analytics workspace retention in days')
@minValue(30)
@maxValue(730)
param retentionInDays int = 90

@description('Daily quota in GB (-1 for unlimited)')
param dailyQuotaGb int = -1

@description('Enable Microsoft Sentinel')
param enableSentinel bool = false

@description('Enable Container Insights')
param enableContainerInsights bool = true

@description('Enable VM Insights')
param enableVmInsights bool = true

@description('Tags to apply to all resources')
param tags object = {
  Environment: environmentName
  Purpose: 'Observability'
  ManagedBy: 'Platform-Team'
}

// Variables
var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 6)
var logAnalyticsWorkspaceName = 'law-${organizationName}-${environmentName}-${uniqueSuffix}'
var applicationInsightsName = 'ai-${organizationName}-${environmentName}-${uniqueSuffix}'
var actionGroupName = 'ag-${organizationName}-${environmentName}-critical'
var userAssignedIdentityName = 'id-${organizationName}-${environmentName}-monitoring'

// User Assigned Managed Identity for monitoring
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: userAssignedIdentityName
  location: location
  tags: tags
}

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    sku: {
      name: logAnalyticsSkuName
    }
    retentionInDays: retentionInDays
    features: {
      immediatePurgeDataOn30Days: environmentName == 'dev'
      enableLogAccessUsingOnlyResourcePermissions: true
      clusterResourceId: null
    }
    workspaceCapping: {
      dailyQuotaGb: dailyQuotaGb
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Application Insights
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
    Flow_Type: 'Redfield'
    Request_Source: 'rest'
    RetentionInDays: retentionInDays
    ImmediatePurgeDataOn30Days: environmentName == 'dev'
    DisableIpMasking: false
    DisableLocalAuth: true // Use AAD authentication only
  }
}

// Data Collection Rules
module dataCollectionRules 'modules/data-collection-rules.bicep' = {
  name: 'dataCollectionRules'
  params: {
    environmentName: environmentName
    location: location
    workspaceResourceId: logAnalyticsWorkspace.id
    userAssignedIdentityId: userAssignedIdentity.id
    tags: tags
  }
}

// Action Groups for different severity levels
resource criticalActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'Critical'
    enabled: true
    emailReceivers: environmentName == 'prod' ? [
      {
        name: 'SOC Team'
        emailAddress: 'soc-team@${organizationName}.com'
        useCommonAlertSchema: true
      }
      {
        name: 'Platform Team'
        emailAddress: 'platform-team@${organizationName}.com'
        useCommonAlertSchema: true
      }
    ] : [
      {
        name: 'Dev Team'
        emailAddress: 'dev-team@${organizationName}.com'
        useCommonAlertSchema: true
      }
    ]
    smsReceivers: environmentName == 'prod' ? [
      {
        name: 'On-Call Engineer'
        countryCode: '1'
        phoneNumber: '+15551234567'
      }
    ] : []
    webhookReceivers: [
      {
        name: 'Teams Webhook'
        serviceUri: 'https://outlook.office.com/webhook/YOUR-WEBHOOK-URL'
        useCommonAlertSchema: true
      }
    ]
    azureFunctionReceivers: []
    logicAppReceivers: []
  }
}

resource warningActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: replace(actionGroupName, 'critical', 'warning')
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'Warning'
    enabled: true
    emailReceivers: [
      {
        name: 'Platform Team'
        emailAddress: 'platform-team@${organizationName}.com'
        useCommonAlertSchema: true
      }
    ]
    webhookReceivers: [
      {
        name: 'Teams Webhook'
        serviceUri: 'https://outlook.office.com/webhook/YOUR-WARNING-WEBHOOK-URL'
        useCommonAlertSchema: true
      }
    ]
  }
}

// Alert Rules
module alertRules 'modules/alert-rules.bicep' = {
  name: 'alertRules'
  params: {
    environmentName: environmentName
    location: location
    workspaceResourceId: logAnalyticsWorkspace.id
    criticalActionGroupId: criticalActionGroup.id
    warningActionGroupId: warningActionGroup.id
    tags: tags
  }
}

// Microsoft Sentinel (optional)
resource sentinel 'Microsoft.SecurityInsights/onboardingStates@2023-02-01' = if (enableSentinel) {
  scope: logAnalyticsWorkspace
  name: 'default'
  properties: {}
}

// Sentinel Data Connectors (if Sentinel is enabled)
module sentinelConnectors 'modules/sentinel-connectors.bicep' = if (enableSentinel) {
  name: 'sentinelConnectors'
  params: {
    workspaceName: logAnalyticsWorkspace.name
    location: location
    tags: tags
  }
}

// Workbooks
module workbooks 'modules/workbooks.bicep' = {
  name: 'workbooks'
  params: {
    environmentName: environmentName
    location: location
    workspaceResourceId: logAnalyticsWorkspace.id
    applicationInsightsResourceId: applicationInsights.id
    tags: tags
  }
}

// RBAC Assignments
module rbacAssignments 'modules/rbac-assignments.bicep' = {
  name: 'rbacAssignments'
  params: {
    workspaceResourceId: logAnalyticsWorkspace.id
    applicationInsightsResourceId: applicationInsights.id
    userAssignedIdentityPrincipalId: userAssignedIdentity.properties.principalId
  }
}

// Outputs
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
output logAnalyticsCustomerId string = logAnalyticsWorkspace.properties.customerId
output applicationInsightsId string = applicationInsights.id
output applicationInsightsInstrumentationKey string = applicationInsights.properties.InstrumentationKey
output applicationInsightsConnectionString string = applicationInsights.properties.ConnectionString
output criticalActionGroupId string = criticalActionGroup.id
output warningActionGroupId string = warningActionGroup.id
output userAssignedIdentityId string = userAssignedIdentity.id
output userAssignedIdentityPrincipalId string = userAssignedIdentity.properties.principalId
output userAssignedIdentityClientId string = userAssignedIdentity.properties.clientId
output sentinelEnabled bool = enableSentinel
