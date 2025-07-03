@description('Log Analytics workspace resource ID')
param workspaceResourceId string

@description('Application Insights resource ID')
param applicationInsightsResourceId string

@description('User Assigned Identity principal ID')
param userAssignedIdentityPrincipalId string

// Log Analytics Contributor role for the managed identity
resource logAnalyticsContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(workspaceResourceId, userAssignedIdentityPrincipalId, 'LogAnalyticsContributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '92aaf0da-9dab-42b6-94a3-d43ce8d16293') // Log Analytics Contributor
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Application Insights Component Contributor role for the managed identity
resource appInsightsContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(applicationInsightsResourceId, userAssignedIdentityPrincipalId, 'AppInsightsContributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ae349356-3a1b-4a5e-921d-050484c6347e') // Application Insights Component Contributor
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Monitoring Contributor role for the managed identity
resource monitoringContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, userAssignedIdentityPrincipalId, 'MonitoringContributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '749f88d5-cbae-40b8-bcfc-e573ddc772fa') // Monitoring Contributor
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output logAnalyticsRoleAssignmentId string = logAnalyticsContributorRoleAssignment.id
output appInsightsRoleAssignmentId string = appInsightsContributorRoleAssignment.id
output monitoringRoleAssignmentId string = monitoringContributorRoleAssignment.id
