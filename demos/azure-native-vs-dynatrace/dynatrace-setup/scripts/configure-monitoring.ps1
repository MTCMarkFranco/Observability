# Dynatrace Monitoring Configuration Script
# This script configures monitoring rules, alerts, and dashboards for Dynatrace

param(
    [Parameter(Mandatory=$true)]
    [string]$DynatraceEnvironmentUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$ApiToken,
    
    [Parameter(Mandatory=$false)]
    [string]$ConfigSummaryFile = (Join-Path $PSScriptRoot "..\dynatrace-config-summary.json"),
    
    [Parameter(Mandatory=$false)]
    [string]$AlertingProfilesFile = (Join-Path $PSScriptRoot "..\monitoring\alerting-profiles.json"),
    
    [Parameter(Mandatory=$false)]
    [string]$ManagementZonesFile = (Join-Path $PSScriptRoot "..\monitoring\management-zones.json")
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "🔧 Starting Dynatrace Monitoring Configuration" -ForegroundColor Green

# Load configuration files
if (Test-Path $ConfigSummaryFile) {
    $dynatraceConfigSummary = Get-Content $ConfigSummaryFile -Raw | ConvertFrom-Json
    Write-Host "✅ Loaded configuration summary" -ForegroundColor Green
} else {
    Write-Host "⚠️  Configuration summary file not found: $ConfigSummaryFile" -ForegroundColor Yellow
    Write-Host "   Some configurations may not be applied correctly" -ForegroundColor Yellow
}

if (Test-Path $AlertingProfilesFile) {
    $alertingProfiles = Get-Content $AlertingProfilesFile -Raw | ConvertFrom-Json
    Write-Host "✅ Loaded alerting profiles configuration" -ForegroundColor Green
} else {
    Write-Host "❌ Alerting profiles file not found: $AlertingProfilesFile" -ForegroundColor Red
    exit 1
}

if (Test-Path $ManagementZonesFile) {
    $managementZones = Get-Content $ManagementZonesFile -Raw | ConvertFrom-Json
    Write-Host "✅ Loaded management zones configuration" -ForegroundColor Green
} else {
    Write-Host "❌ Management zones file not found: $ManagementZonesFile" -ForegroundColor Red
    exit 1
}

# Set up API headers
$headers = @{
    "Authorization" = "Api-Token $ApiToken"
    "Content-Type" = "application/json"
}

# Helper function to make API calls
function Invoke-DynatraceApi {
    param(
        [string]$Method,
        [string]$Endpoint,
        [string]$Body = $null
    )
    
    $url = "$DynatraceEnvironmentUrl/api$Endpoint"
    
    try {
        if ($Body) {
            $response = Invoke-RestMethod -Uri $url -Method $Method -Headers $headers -Body $Body
        } else {
            $response = Invoke-RestMethod -Uri $url -Method $Method -Headers $headers
        }
        return $response
    }
    catch {
        Write-Host "❌ API call failed: $Method $Endpoint" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            Write-Host "   Response: $responseBody" -ForegroundColor Red
        }
        return $null
    }
}

# Test API connectivity
Write-Host "🔍 Testing API connectivity..." -ForegroundColor Yellow
$clusterVersion = Invoke-DynatraceApi -Method "GET" -Endpoint "/v1/config/clusterversion"
if ($clusterVersion) {
    Write-Host "✅ API connectivity verified - Dynatrace version: $($clusterVersion.version)" -ForegroundColor Green
} else {
    Write-Host "❌ Cannot connect to Dynatrace API" -ForegroundColor Red
    exit 1
}

# Create Management Zones
Write-Host "🏗️  Creating Management Zones..." -ForegroundColor Yellow
foreach ($zone in $managementZones.managementZones) {
    Write-Host "  Creating management zone: $($zone.name)" -ForegroundColor Cyan
    
    $body = $zone | ConvertTo-Json -Depth 10
    $result = Invoke-DynatraceApi -Method "POST" -Endpoint "/config/v1/managementZones" -Body $body
    
    if ($result) {
        Write-Host "    ✅ Created: $($zone.name)" -ForegroundColor Green
    } else {
        Write-Host "    ❌ Failed to create: $($zone.name)" -ForegroundColor Red
    }
}

# Create Auto-tagging Rules
Write-Host "🏷️  Creating Auto-tagging Rules..." -ForegroundColor Yellow
foreach ($tag in $managementZones.tags) {
    Write-Host "  Creating auto-tag: $($tag.name)" -ForegroundColor Cyan
    
    $body = $tag | ConvertTo-Json -Depth 10
    $result = Invoke-DynatraceApi -Method "POST" -Endpoint "/config/v1/autoTags" -Body $body
    
    if ($result) {
        Write-Host "    ✅ Created: $($tag.name)" -ForegroundColor Green
    } else {
        Write-Host "    ❌ Failed to create: $($tag.name)" -ForegroundColor Red
    }
}

# Create Alerting Profiles
Write-Host "🚨 Creating Alerting Profiles..." -ForegroundColor Yellow
foreach ($alertProfile in $alertingProfiles.alertingProfiles) {
    Write-Host "  Creating alerting profile: $($alertProfile.displayName)" -ForegroundColor Cyan
    
    $body = $alertProfile | ConvertTo-Json -Depth 10
    $result = Invoke-DynatraceApi -Method "POST" -Endpoint "/config/v1/alertingProfiles" -Body $body
    
    if ($result) {
        Write-Host "    ✅ Created: $($alertProfile.displayName)" -ForegroundColor Green
    } else {
        Write-Host "    ❌ Failed to create: $($alertProfile.displayName)" -ForegroundColor Red
    }
}

# Create Notification Configurations
Write-Host "📢 Creating Notification Configurations..." -ForegroundColor Yellow
foreach ($notification in $alertingProfiles.notifications) {
    Write-Host "  Creating notification: $($notification.name)" -ForegroundColor Cyan
    
    $body = $notification | ConvertTo-Json -Depth 10
    $result = Invoke-DynatraceApi -Method "POST" -Endpoint "/config/v1/notifications" -Body $body
    
    if ($result) {
        Write-Host "    ✅ Created: $($notification.name)" -ForegroundColor Green
    } else {
        Write-Host "    ❌ Failed to create: $($notification.name)" -ForegroundColor Red
    }
}

# Create Custom Events
Write-Host "🎯 Creating Custom Events..." -ForegroundColor Yellow
foreach ($customEvent in $alertingProfiles.customEvents) {
    Write-Host "  Creating custom event: $($customEvent.name)" -ForegroundColor Cyan
    
    $body = $customEvent | ConvertTo-Json -Depth 10
    $result = Invoke-DynatraceApi -Method "POST" -Endpoint "/config/v1/customEvents" -Body $body
    
    if ($result) {
        Write-Host "    ✅ Created: $($customEvent.name)" -ForegroundColor Green
    } else {
        Write-Host "    ❌ Failed to create: $($customEvent.name)" -ForegroundColor Red
    }
}

# Create Dashboards
Write-Host "📊 Creating Dashboards..." -ForegroundColor Yellow
foreach ($dashboard in $alertingProfiles.dashboards) {
    Write-Host "  Creating dashboard: $($dashboard.name)" -ForegroundColor Cyan
    
    $body = $dashboard | ConvertTo-Json -Depth 10
    $result = Invoke-DynatraceApi -Method "POST" -Endpoint "/config/v1/dashboards" -Body $body
    
    if ($result) {
        Write-Host "    ✅ Created: $($dashboard.name)" -ForegroundColor Green
    } else {
        Write-Host "    ❌ Failed to create: $($dashboard.name)" -ForegroundColor Red
    }
}

# Create Request Naming Rules
Write-Host "🔤 Creating Request Naming Rules..." -ForegroundColor Yellow
foreach ($rule in $managementZones.requestNaming) {
    Write-Host "  Creating request naming rule: $($rule.name)" -ForegroundColor Cyan
    
    $body = $rule | ConvertTo-Json -Depth 10
    $result = Invoke-DynatraceApi -Method "POST" -Endpoint "/config/v1/requestNamingRules" -Body $body
    
    if ($result) {
        Write-Host "    ✅ Created: $($rule.name)" -ForegroundColor Green
    } else {
        Write-Host "    ❌ Failed to create: $($rule.name)" -ForegroundColor Red
    }
}

# Configure Application Detection Rules
Write-Host "🎯 Configuring Application Detection..." -ForegroundColor Yellow
$dynatraceConfig = Get-Content (Join-Path $PSScriptRoot "..\infrastructure\dynatrace-config.json") -Raw | ConvertFrom-Json

foreach ($rule in $dynatraceConfig.dynatrace.monitoring.applicationDetection.rules) {
    Write-Host "  Creating application detection rule: $($rule.name)" -ForegroundColor Cyan
    
    $body = $rule | ConvertTo-Json -Depth 10
    $result = Invoke-DynatraceApi -Method "POST" -Endpoint "/config/v1/applicationDetectionRules" -Body $body
    
    if ($result) {
        Write-Host "    ✅ Created: $($rule.name)" -ForegroundColor Green
    } else {
        Write-Host "    ❌ Failed to create: $($rule.name)" -ForegroundColor Red
    }
}

# Configure Request Attributes
Write-Host "📝 Configuring Request Attributes..." -ForegroundColor Yellow
foreach ($attribute in $dynatraceConfig.dynatrace.requestAttributes) {
    Write-Host "  Creating request attribute: $($attribute.name)" -ForegroundColor Cyan
    
    $body = $attribute | ConvertTo-Json -Depth 10
    $result = Invoke-DynatraceApi -Method "POST" -Endpoint "/config/v1/requestAttributes" -Body $body
    
    if ($result) {
        Write-Host "    ✅ Created: $($attribute.name)" -ForegroundColor Green
    } else {
        Write-Host "    ❌ Failed to create: $($attribute.name)" -ForegroundColor Red
    }
}

# Configure Calculated Metrics
Write-Host "🧮 Configuring Calculated Metrics..." -ForegroundColor Yellow
foreach ($metric in $dynatraceConfig.dynatrace.calculatedMetrics) {
    Write-Host "  Creating calculated metric: $($metric.name)" -ForegroundColor Cyan
    
    $body = $metric | ConvertTo-Json -Depth 10
    $result = Invoke-DynatraceApi -Method "POST" -Endpoint "/config/v1/calculatedMetrics/service" -Body $body
    
    if ($result) {
        Write-Host "    ✅ Created: $($metric.name)" -ForegroundColor Green
    } else {
        Write-Host "    ❌ Failed to create: $($metric.name)" -ForegroundColor Red
    }
}

# Get existing entities for validation
Write-Host "🔍 Validating Configuration..." -ForegroundColor Yellow

# Check Management Zones
$existingZones = Invoke-DynatraceApi -Method "GET" -Endpoint "/config/v1/managementZones"
if ($existingZones) {
    Write-Host "  Management Zones: $($existingZones.values.Count) configured" -ForegroundColor Green
}

# Check Alerting Profiles
$existingProfiles = Invoke-DynatraceApi -Method "GET" -Endpoint "/config/v1/alertingProfiles"
if ($existingProfiles) {
    Write-Host "  Alerting Profiles: $($existingProfiles.values.Count) configured" -ForegroundColor Green
}

# Check Dashboards
$existingDashboards = Invoke-DynatraceApi -Method "GET" -Endpoint "/config/v1/dashboards"
if ($existingDashboards) {
    Write-Host "  Dashboards: $($existingDashboards.dashboards.Count) configured" -ForegroundColor Green
}

# Create monitoring summary
Write-Host "📊 Creating monitoring summary..." -ForegroundColor Yellow

$monitoringSummary = @{
    ConfigurationDate = Get-Date
    DynatraceEnvironmentUrl = $DynatraceEnvironmentUrl
    ConfiguredComponents = @{
        ManagementZones = $managementZones.managementZones.Count
        AlertingProfiles = $alertingProfiles.alertingProfiles.Count
        Notifications = $alertingProfiles.notifications.Count
        CustomEvents = $alertingProfiles.customEvents.Count
        Dashboards = $alertingProfiles.dashboards.Count
        AutoTags = $managementZones.tags.Count
        RequestNamingRules = $managementZones.requestNaming.Count
        ApplicationDetectionRules = $dynatraceConfig.dynatrace.monitoring.applicationDetection.rules.Count
        RequestAttributes = $dynatraceConfig.dynatrace.requestAttributes.Count
        CalculatedMetrics = $dynatraceConfig.dynatrace.calculatedMetrics.Count
    }
    MonitoringCapabilities = @{
        ApplicationPerformanceMonitoring = $true
        InfrastructureMonitoring = $true
        UserExperienceMonitoring = $true
        LogMonitoring = $true
        SyntheticMonitoring = $false
        BusinessAnalytics = $true
    }
    KeyFeatures = @(
        "Automatic discovery and topology mapping",
        "AI-powered root cause analysis (Davis AI)",
        "Real-time performance monitoring",
        "Proactive alerting and notifications",
        "Custom dashboards and reporting",
        "Deep code-level visibility",
        "Multi-dimensional analysis",
        "Automated baseline learning"
    )
    AccessUrls = @{
        MainDashboard = "$DynatraceEnvironmentUrl/#dashboard"
        Applications = "$DynatraceEnvironmentUrl/#applications"
        Services = "$DynatraceEnvironmentUrl/#services"
        Hosts = "$DynatraceEnvironmentUrl/#newhosts"
        Problems = "$DynatraceEnvironmentUrl/#problems"
        LogViewer = "$DynatraceEnvironmentUrl/#logs"
        UserSessions = "$DynatraceEnvironmentUrl/#usersessions"
        Smartscape = "$DynatraceEnvironmentUrl/#smartscape"
    }
    NextSteps = @(
        "Deploy sample application",
        "Generate test traffic",
        "Review automatic discovery results",
        "Validate alerting rules",
        "Explore AI-powered insights",
        "Configure synthetic monitoring (optional)"
    )
}

$monitoringSummaryFile = Join-Path $PSScriptRoot "..\dynatrace-monitoring-summary.json"
$monitoringSummary | ConvertTo-Json -Depth 10 | Set-Content $monitoringSummaryFile

Write-Host "🎉 Dynatrace monitoring configuration completed!" -ForegroundColor Green
Write-Host "📋 Summary:" -ForegroundColor Yellow
Write-Host "  - Management Zones: $($managementZones.managementZones.Count)" -ForegroundColor White
Write-Host "  - Alerting Profiles: $($alertingProfiles.alertingProfiles.Count)" -ForegroundColor White
Write-Host "  - Notifications: $($alertingProfiles.notifications.Count)" -ForegroundColor White
Write-Host "  - Custom Events: $($alertingProfiles.customEvents.Count)" -ForegroundColor White
Write-Host "  - Dashboards: $($alertingProfiles.dashboards.Count)" -ForegroundColor White
Write-Host "  - Auto-tags: $($managementZones.tags.Count)" -ForegroundColor White

Write-Host "💾 Monitoring summary saved to: $monitoringSummaryFile" -ForegroundColor Cyan

Write-Host "🔍 Next steps:" -ForegroundColor Yellow
Write-Host "  1. Deploy the sample application" -ForegroundColor White
Write-Host "  2. Generate test traffic" -ForegroundColor White
Write-Host "  3. Review automatic discovery in Dynatrace UI" -ForegroundColor White
Write-Host "  4. Validate alerting and notifications" -ForegroundColor White
Write-Host "  5. Explore AI-powered insights" -ForegroundColor White

Write-Host "🌐 Access your Dynatrace environment:" -ForegroundColor Yellow
Write-Host "  - Main Dashboard: $DynatraceEnvironmentUrl/#dashboard" -ForegroundColor Cyan
Write-Host "  - Applications: $DynatraceEnvironmentUrl/#applications" -ForegroundColor Cyan
Write-Host "  - Services: $DynatraceEnvironmentUrl/#services" -ForegroundColor Cyan
Write-Host "  - Infrastructure: $DynatraceEnvironmentUrl/#newhosts" -ForegroundColor Cyan
Write-Host "  - Problems: $DynatraceEnvironmentUrl/#problems" -ForegroundColor Cyan

Write-Host "⚡ Dynatrace Advantages:" -ForegroundColor Yellow
Write-Host "  - Automatic discovery and dependency mapping" -ForegroundColor White
Write-Host "  - AI-powered root cause analysis" -ForegroundColor White
Write-Host "  - Single agent deployment" -ForegroundColor White
Write-Host "  - No manual instrumentation required" -ForegroundColor White
Write-Host "  - Real-time topology visualization" -ForegroundColor White

Write-Host "✅ Dynatrace monitoring configuration completed successfully!" -ForegroundColor Green
