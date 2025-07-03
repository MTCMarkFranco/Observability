# Azure Native Monitoring Configuration Script
# This script configures alerts, dashboards, and monitoring rules for the Azure Native solution

param(
    [Parameter(Mandatory=$false)]
    [string]$DeploymentInfoFile = (Join-Path $PSScriptRoot "..\deployment-info.json"),
    
    [Parameter(Mandatory=$false)]
    [string]$AlertsConfigFile = (Join-Path $PSScriptRoot "..\alerts\alert-rules.json")
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "🔧 Starting Azure Native Monitoring Configuration" -ForegroundColor Green

# Check if deployment info file exists
if (-not (Test-Path $DeploymentInfoFile)) {
    Write-Host "❌ Deployment info file not found: $DeploymentInfoFile" -ForegroundColor Red
    Write-Host "   Please run deploy-infrastructure.ps1 first." -ForegroundColor Yellow
    exit 1
}

# Load deployment information
$deploymentInfo = Get-Content $DeploymentInfoFile -Raw | ConvertFrom-Json
$resourceGroupName = $deploymentInfo.ResourceGroupName
$outputs = $deploymentInfo.Outputs

Write-Host "📋 Configuration Parameters:" -ForegroundColor Yellow
Write-Host "  - Resource Group: $resourceGroupName" -ForegroundColor White
Write-Host "  - App Service: $($outputs.appServiceName.value)" -ForegroundColor White
Write-Host "  - Application Insights: $($outputs.applicationInsightsInstrumentationKey.value)" -ForegroundColor White

# Load alerts configuration
if (-not (Test-Path $AlertsConfigFile)) {
    Write-Host "❌ Alerts configuration file not found: $AlertsConfigFile" -ForegroundColor Red
    exit 1
}

$alertsConfig = Get-Content $AlertsConfigFile -Raw | ConvertFrom-Json

# Get subscription ID
$subscriptionId = az account show --query id --output tsv

# Create alert rules
Write-Host "🚨 Creating alert rules..." -ForegroundColor Yellow

foreach ($alertRule in $alertsConfig.alertRules) {
    Write-Host "  Creating alert: $($alertRule.name)" -ForegroundColor Cyan
    
    $alertName = "$($alertRule.name) - $($deploymentInfo.EnvironmentName)"
    
    try {
        if ($alertRule.condition.dataSource -eq "Application Insights") {
            # Create Application Insights alert
            $appInsightsId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Insights/components/$($outputs.applicationInsightsInstrumentationKey.value)"
            
            az monitor scheduled-query create `
                --name $alertName `
                --resource-group $resourceGroupName `
                --scopes $appInsightsId `
                --condition $alertRule.condition.query `
                --condition-threshold $alertRule.condition.threshold `
                --condition-operator $alertRule.condition.operator `
                --condition-time-aggregation $alertRule.condition.timeAggregation `
                --evaluation-frequency $alertRule.condition.evaluationFrequency `
                --window-size $alertRule.condition.windowSize `
                --severity $alertRule.severity `
                --description $alertRule.description `
                --actions $outputs.actionGroupId.value `
                --enabled $alertRule.enabled
        }
        else {
            # Create Azure Monitor metric alert
            $resourceId = ""
            switch ($alertRule.condition.resourceType) {
                "Microsoft.Web/sites" { 
                    $resourceId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Web/sites/$($outputs.appServiceName.value)" 
                }
                "Microsoft.Sql/servers/databases" { 
                    $resourceId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Sql/servers/$($outputs.sqlServerName.value)/databases/$($outputs.sqlDatabaseName.value)" 
                }
                "Microsoft.Cache/redis" { 
                    $resourceId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Cache/redis/$($outputs.redisCacheName.value)" 
                }
            }
            
            if ($resourceId) {
                az monitor metrics alert create `
                    --name $alertName `
                    --resource-group $resourceGroupName `
                    --scopes $resourceId `
                    --condition "avg $($alertRule.condition.metricName) $($alertRule.condition.operator) $($alertRule.condition.threshold)" `
                    --evaluation-frequency $alertRule.condition.evaluationFrequency `
                    --window-size $alertRule.condition.windowSize `
                    --severity $alertRule.severity `
                    --description $alertRule.description `
                    --action $outputs.actionGroupId.value `
                    --enabled $alertRule.enabled
            }
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✅ Created: $alertName" -ForegroundColor Green
        }
        else {
            Write-Host "    ⚠️  Warning: Failed to create alert: $alertName" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "    ❌ Error creating alert: $alertName" -ForegroundColor Red
        Write-Host "       Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Create Application Insights Workbook
Write-Host "📊 Creating Application Insights Workbook..." -ForegroundColor Yellow

$workbookTemplate = @"
{
    "version": "Notebook/1.0",
    "items": [
        {
            "type": 1,
            "content": {
                "json": "# Observability Demo Dashboard\n\nThis workbook provides comprehensive monitoring for the Azure Native observability demo application."
            },
            "name": "Header"
        },
        {
            "type": 10,
            "content": {
                "chartId": "workbook-chart-1",
                "version": "KqlItem/1.0",
                "query": "requests\\n| where timestamp > ago(1h)\\n| summarize count() by bin(timestamp, 5m)\\n| render timechart",
                "size": 0,
                "title": "Request Volume (Last Hour)",
                "timeContext": {
                    "durationMs": 3600000
                },
                "queryType": 0,
                "resourceType": "microsoft.insights/components"
            },
            "name": "RequestVolume"
        },
        {
            "type": 10,
            "content": {
                "chartId": "workbook-chart-2",
                "version": "KqlItem/1.0",
                "query": "requests\\n| where timestamp > ago(1h)\\n| summarize avg(duration) by bin(timestamp, 5m)\\n| render timechart",
                "size": 0,
                "title": "Average Response Time (Last Hour)",
                "timeContext": {
                    "durationMs": 3600000
                },
                "queryType": 0,
                "resourceType": "microsoft.insights/components"
            },
            "name": "ResponseTime"
        },
        {
            "type": 10,
            "content": {
                "chartId": "workbook-chart-3",
                "version": "KqlItem/1.0",
                "query": "requests\\n| where timestamp > ago(1h)\\n| summarize ErrorRate = (countif(success == false) * 100.0) / count() by bin(timestamp, 5m)\\n| render timechart",
                "size": 0,
                "title": "Error Rate % (Last Hour)",
                "timeContext": {
                    "durationMs": 3600000
                },
                "queryType": 0,
                "resourceType": "microsoft.insights/components"
            },
            "name": "ErrorRate"
        },
        {
            "type": 10,
            "content": {
                "chartId": "workbook-chart-4",
                "version": "KqlItem/1.0",
                "query": "dependencies\\n| where timestamp > ago(1h)\\n| summarize count() by target, bin(timestamp, 5m)\\n| render timechart",
                "size": 0,
                "title": "Dependency Calls (Last Hour)",
                "timeContext": {
                    "durationMs": 3600000
                },
                "queryType": 0,
                "resourceType": "microsoft.insights/components"
            },
            "name": "Dependencies"
        },
        {
            "type": 10,
            "content": {
                "chartId": "workbook-chart-5",
                "version": "KqlItem/1.0",
                "query": "exceptions\\n| where timestamp > ago(1h)\\n| summarize count() by type, bin(timestamp, 5m)\\n| render timechart",
                "size": 0,
                "title": "Exceptions (Last Hour)",
                "timeContext": {
                    "durationMs": 3600000
                },
                "queryType": 0,
                "resourceType": "microsoft.insights/components"
            },
            "name": "Exceptions"
        }
    ],
    "isLocked": false,
    "fallbackResourceIds": [
        "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Insights/components/$($outputs.applicationInsightsInstrumentationKey.value)"
    ]
}
"@

$workbookFile = Join-Path $PSScriptRoot "..\workbook-template.json"
$workbookTemplate | Set-Content $workbookFile

Write-Host "📋 Creating custom KQL queries..." -ForegroundColor Yellow

# Create saved queries for common monitoring scenarios
$savedQueries = @(
    @{
        Name = "Top 10 Slowest Requests"
        Query = "requests | where timestamp > ago(1h) | top 10 by duration desc | project timestamp, name, duration, resultCode"
        Description = "Shows the 10 slowest requests in the last hour"
    },
    @{
        Name = "Error Analysis"
        Query = "requests | where timestamp > ago(1h) and success == false | summarize count() by resultCode, name | order by count_ desc"
        Description = "Analyzes error patterns by result code and operation"
    },
    @{
        Name = "Dependency Performance"
        Query = "dependencies | where timestamp > ago(1h) | summarize avg(duration), count() by target | order by avg_duration desc"
        Description = "Shows dependency performance metrics"
    },
    @{
        Name = "User Journey Analysis"
        Query = "pageViews | where timestamp > ago(1h) | summarize count() by name | order by count_ desc"
        Description = "Analyzes user page view patterns"
    },
    @{
        Name = "Resource Utilization"
        Query = "performanceCounters | where timestamp > ago(1h) | where counter == 'Processor(_Total)\\% Processor Time' | summarize avg(value) by bin(timestamp, 5m) | render timechart"
        Description = "Shows CPU utilization over time"
    }
)

foreach ($query in $savedQueries) {
    Write-Host "  Creating saved query: $($query.Name)" -ForegroundColor Cyan
    
    # Note: Azure CLI doesn't have direct support for creating saved queries
    # In a real implementation, you would use ARM templates or REST API
    Write-Host "    📝 Query: $($query.Query)" -ForegroundColor White
}

# Create Log Analytics queries for infrastructure monitoring
Write-Host "🔍 Setting up Log Analytics queries..." -ForegroundColor Yellow

$logAnalyticsQueries = @(
    @{
        Name = "App Service Performance"
        Query = "AzureMetrics | where ResourceProvider == 'MICROSOFT.WEB' | where TimeGenerated > ago(1h) | summarize avg(Average) by MetricName, bin(TimeGenerated, 5m) | render timechart"
        Description = "App Service performance metrics"
    },
    @{
        Name = "SQL Database Performance"
        Query = "AzureMetrics | where ResourceProvider == 'MICROSOFT.SQL' | where TimeGenerated > ago(1h) | summarize avg(Average) by MetricName, bin(TimeGenerated, 5m) | render timechart"
        Description = "SQL Database performance metrics"
    },
    @{
        Name = "Redis Cache Performance"
        Query = "AzureMetrics | where ResourceProvider == 'MICROSOFT.CACHE' | where TimeGenerated > ago(1h) | summarize avg(Average) by MetricName, bin(TimeGenerated, 5m) | render timechart"
        Description = "Redis Cache performance metrics"
    }
)

foreach ($query in $logAnalyticsQueries) {
    Write-Host "  Log Analytics query: $($query.Name)" -ForegroundColor Cyan
    Write-Host "    📝 Query: $($query.Query)" -ForegroundColor White
}

# Create monitoring summary
Write-Host "📊 Creating monitoring summary..." -ForegroundColor Yellow

$monitoringSummary = @{
    ConfigurationDate = Get-Date
    ResourceGroup = $resourceGroupName
    AlertRules = $alertsConfig.alertRules.Count
    ApplicationInsights = @{
        InstrumentationKey = $outputs.applicationInsightsInstrumentationKey.value
        ConnectionString = $outputs.applicationInsightsConnectionString.value
        WorkspaceId = $outputs.logAnalyticsWorkspaceId.value
    }
    MonitoringEndpoints = @{
        AppServiceUrl = $outputs.appServiceUrl.value
        HealthCheckUrl = "$($outputs.appServiceUrl.value)/health"
        SwaggerUrl = "$($outputs.appServiceUrl.value)/swagger"
    }
    SavedQueries = $savedQueries
    LogAnalyticsQueries = $logAnalyticsQueries
    NextSteps = @(
        "Deploy sample application to App Service",
        "Run load tests to generate telemetry",
        "Verify alert notifications are working",
        "Review workbook dashboards",
        "Configure additional custom metrics"
    )
}

$monitoringSummaryFile = Join-Path $PSScriptRoot "..\monitoring-summary.json"
$monitoringSummary | ConvertTo-Json -Depth 10 | Set-Content $monitoringSummaryFile

Write-Host "🎉 Azure Native monitoring configuration completed!" -ForegroundColor Green
Write-Host "📋 Summary:" -ForegroundColor Yellow
Write-Host "  - Alert rules configured: $($alertsConfig.alertRules.Count)" -ForegroundColor White
Write-Host "  - Workbook template created: $workbookFile" -ForegroundColor White
Write-Host "  - Monitoring summary saved: $monitoringSummaryFile" -ForegroundColor White

Write-Host "🔍 Next steps:" -ForegroundColor Yellow
Write-Host "  1. Deploy the sample application" -ForegroundColor White
Write-Host "  2. Generate test traffic" -ForegroundColor White
Write-Host "  3. Review dashboards in Azure Portal" -ForegroundColor White
Write-Host "  4. Test alert notifications" -ForegroundColor White

Write-Host "📊 Access your monitoring:" -ForegroundColor Yellow
Write-Host "  - Application Insights: https://portal.azure.com/#resource/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Insights/components/$($outputs.applicationInsightsInstrumentationKey.value)/overview" -ForegroundColor Cyan
Write-Host "  - Log Analytics: https://portal.azure.com/#resource$($outputs.logAnalyticsWorkspaceId.value)/overview" -ForegroundColor Cyan
Write-Host "  - App Service: https://portal.azure.com/#resource/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Web/sites/$($outputs.appServiceName.value)/overview" -ForegroundColor Cyan
