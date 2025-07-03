#!/usr/bin/env pwsh

param(
    [Parameter(Mandatory = $true)]
    [int]$ServiceCount,
    
    [Parameter(Mandatory = $true)]
    [int]$DataVolumeGB,
    
    [Parameter(Mandatory = $false)]
    [int]$TeamSize = 5,
    
    [Parameter(Mandatory = $false)]
    [int]$RetentionMonths = 6,
    
    [Parameter(Mandatory = $false)]
    [int]$AlertsPerMonth = 100,
    
    [Parameter(Mandatory = $false)]
    [int]$DashboardCount = 10,
    
    [Parameter(Mandatory = $false)]
    [bool]$ComplianceRequired = $false,
    
    [Parameter(Mandatory = $false)]
    [string]$Region = "East US",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Development", "Staging", "Production")]
    [string]$Environment = "Production"
)

# Cost calculation functions

function Calculate-OpenTelemetryInfrastructure {
    param($ServiceCount, $DataVolumeGB, $RetentionMonths)
    
    # Collector hosting costs based on service count
    $collectorCost = switch ($ServiceCount) {
        { $_ -le 10 } { 500 }
        { $_ -le 50 } { 1500 }
        { $_ -le 100 } { 3000 }
        default { 5000 }
    }
    
    # Storage backend costs (Prometheus + long-term storage)
    $storageGBMonth = $DataVolumeGB * $RetentionMonths
    $storageCost = switch ($storageGBMonth) {
        { $_ -le 5000 } { 800 }
        { $_ -le 20000 } { 2500 }
        { $_ -le 50000 } { 6000 }
        default { 12000 }
    }
    
    # Visualization tools (Grafana)
    $visualizationCost = switch ($ServiceCount) {
        { $_ -le 10 } { 200 }
        { $_ -le 50 } { 500 }
        { $_ -le 100 } { 1000 }
        default { 2000 }
    }
    
    # Alerting infrastructure (Alertmanager)
    $alertingCost = [math]::Max(200, $AlertsPerMonth * 0.5)
    
    return @{
        Collector = $collectorCost
        Storage = $storageCost
        Visualization = $visualizationCost
        Alerting = $alertingCost
        Total = $collectorCost + $storageCost + $visualizationCost + $alertingCost
    }
}

function Calculate-OpenTelemetryOperational {
    param($ServiceCount, $TeamSize, $ComplianceRequired)
    
    # Personnel costs (specialized skills required)
    $personnelFTE = switch ($ServiceCount) {
        { $_ -le 10 } { 0.5 }
        { $_ -le 50 } { 1.0 }
        { $_ -le 100 } { 1.5 }
        default { 2.0 }
    }
    
    $avgSalaryMonthly = 12000  # Senior DevOps/SRE engineer
    $personnelCost = $personnelFTE * $avgSalaryMonthly
    
    # Training costs (higher due to complexity)
    $trainingCost = switch ($TeamSize) {
        { $_ -le 3 } { 1500 }
        { $_ -le 8 } { 3000 }
        { $_ -le 15 } { 5000 }
        default { 8000 }
    }
    
    # Support costs (community + optional commercial)
    $supportCost = if ($ComplianceRequired) { 4000 } else { 1000 }
    
    return @{
        Personnel = $personnelCost
        Training = $trainingCost
        Support = $supportCost
        Total = $personnelCost + $trainingCost + $supportCost
    }
}

function Calculate-AzureNativeServices {
    param($DataVolumeGB, $RetentionMonths, $AlertsPerMonth, $ServiceCount)
    
    # Application Insights costs
    $aiIngestionCost = $DataVolumeGB * 2.30  # $2.30/GB
    $aiRetentionCost = ($DataVolumeGB * $RetentionMonths) * 0.12  # $0.12/GB/month
    $aiTotalCost = $aiIngestionCost + $aiRetentionCost
    
    # Log Analytics costs
    $laIngestionCost = $DataVolumeGB * 2.76  # $2.76/GB (slightly higher than AI)
    $laRetentionCost = ($DataVolumeGB * $RetentionMonths) * 0.12
    $laTotalCost = $laIngestionCost + $laRetentionCost
    
    # Azure Monitor costs
    $metricsCost = $ServiceCount * 10 * 0.25  # Assume 10 metrics per service at $0.25/metric
    $alertsCost = $AlertsPerMonth * 0.10  # $0.10 per alert evaluation
    $amTotalCost = $metricsCost + $alertsCost
    
    return @{
        ApplicationInsights = $aiTotalCost
        LogAnalytics = $laTotalCost
        AzureMonitor = $amTotalCost
        Total = $aiTotalCost + $laTotalCost + $amTotalCost
    }
}

function Calculate-AzureNativeOperational {
    param($ServiceCount, $TeamSize, $ComplianceRequired)
    
    # Personnel costs (lower skill requirement)
    $personnelFTE = switch ($ServiceCount) {
        { $_ -le 10 } { 0.25 }
        { $_ -le 50 } { 0.5 }
        { $_ -le 100 } { 0.75 }
        default { 1.0 }
    }
    
    $avgSalaryMonthly = 10000  # Cloud engineer (lower than specialized OpenTelemetry)
    $personnelCost = $personnelFTE * $avgSalaryMonthly
    
    # Training costs (Azure-specific, well documented)
    $trainingCost = switch ($TeamSize) {
        { $_ -le 3 } { 500 }
        { $_ -le 8 } { 1000 }
        { $_ -le 15 } { 2000 }
        default { 3000 }
    }
    
    # Support costs (Microsoft support)
    $supportCost = if ($ComplianceRequired) { 3000 } else { 1000 }
    
    return @{
        Personnel = $personnelCost
        Training = $trainingCost
        Support = $supportCost
        Total = $personnelCost + $trainingCost + $supportCost
    }
}

# Main calculation
Write-Host "OpenTelemetry vs Azure Native - TCO Analysis" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Input Parameters:" -ForegroundColor Yellow
Write-Host "- Services: $ServiceCount"
Write-Host "- Data Volume: $($DataVolumeGB.ToString('N0')) GB/month"
Write-Host "- Team Size: $TeamSize engineers"
Write-Host "- Retention: $RetentionMonths months"
Write-Host "- Environment: $Environment"
Write-Host "- Compliance Required: $ComplianceRequired"
Write-Host ""

# Calculate OpenTelemetry costs
$otelInfra = Calculate-OpenTelemetryInfrastructure -ServiceCount $ServiceCount -DataVolumeGB $DataVolumeGB -RetentionMonths $RetentionMonths
$otelOps = Calculate-OpenTelemetryOperational -ServiceCount $ServiceCount -TeamSize $TeamSize -ComplianceRequired $ComplianceRequired

Write-Host "OpenTelemetry Costs (Monthly):" -ForegroundColor Green
Write-Host "------------------------------" -ForegroundColor Green
Write-Host "Infrastructure:"
Write-Host "  - Collector Hosting: $($otelInfra.Collector.ToString('C0'))"
Write-Host "  - Storage Backend: $($otelInfra.Storage.ToString('C0'))"
Write-Host "  - Visualization: $($otelInfra.Visualization.ToString('C0'))"
Write-Host "  - Alerting: $($otelInfra.Alerting.ToString('C0'))"
Write-Host "  Subtotal: $($otelInfra.Total.ToString('C0'))" -ForegroundColor White

Write-Host "Operational:"
Write-Host "  - Personnel: $($otelOps.Personnel.ToString('C0'))"
Write-Host "  - Training: $($otelOps.Training.ToString('C0'))"
Write-Host "  - Support: $($otelOps.Support.ToString('C0'))"
Write-Host "  Subtotal: $($otelOps.Total.ToString('C0'))" -ForegroundColor White

$otelTotal = $otelInfra.Total + $otelOps.Total
Write-Host ""
Write-Host "Total OpenTelemetry: $($otelTotal.ToString('C0'))/month" -ForegroundColor Green -BackgroundColor Black
Write-Host ""

# Calculate Azure Native costs
$azureServices = Calculate-AzureNativeServices -DataVolumeGB $DataVolumeGB -RetentionMonths $RetentionMonths -AlertsPerMonth $AlertsPerMonth -ServiceCount $ServiceCount
$azureOps = Calculate-AzureNativeOperational -ServiceCount $ServiceCount -TeamSize $TeamSize -ComplianceRequired $ComplianceRequired

Write-Host "Azure Native Costs (Monthly):" -ForegroundColor Blue
Write-Host "-----------------------------" -ForegroundColor Blue
Write-Host "Services:"
Write-Host "  - Application Insights: $($azureServices.ApplicationInsights.ToString('C0'))"
Write-Host "  - Log Analytics: $($azureServices.LogAnalytics.ToString('C0'))"
Write-Host "  - Azure Monitor: $($azureServices.AzureMonitor.ToString('C0'))"
Write-Host "  Subtotal: $($azureServices.Total.ToString('C0'))" -ForegroundColor White

Write-Host "Operational:"
Write-Host "  - Personnel: $($azureOps.Personnel.ToString('C0'))"
Write-Host "  - Training: $($azureOps.Training.ToString('C0'))"
Write-Host "  - Support: $($azureOps.Support.ToString('C0'))"
Write-Host "  Subtotal: $($azureOps.Total.ToString('C0'))" -ForegroundColor White

$azureTotal = $azureServices.Total + $azureOps.Total
Write-Host ""
Write-Host "Total Azure Native: $($azureTotal.ToString('C0'))/month" -ForegroundColor Blue -BackgroundColor Black
Write-Host ""

# Summary and analysis
Write-Host "Summary:" -ForegroundColor Magenta
Write-Host "--------" -ForegroundColor Magenta
Write-Host "OpenTelemetry: $($otelTotal.ToString('C0'))/month ($((($otelTotal * 12)).ToString('C0'))/year)"
Write-Host "Azure Native:  $($azureTotal.ToString('C0'))/month ($((($azureTotal * 12)).ToString('C0'))/year)"
Write-Host ""

$difference = $azureTotal - $otelTotal
$percentDiff = [math]::Abs($difference) / [math]::Min($otelTotal, $azureTotal) * 100

if ($difference -gt 0) {
    Write-Host "Azure Native costs $($difference.ToString('C0')) more than OpenTelemetry ($($percentDiff.ToString('N1'))%)" -ForegroundColor Red
    Write-Host "Potential annual savings with OpenTelemetry: $(($difference * 12).ToString('C0'))" -ForegroundColor Green
    $winner = "OpenTelemetry"
} else {
    $difference = [math]::Abs($difference)
    Write-Host "OpenTelemetry costs $($difference.ToString('C0')) more than Azure Native ($($percentDiff.ToString('N1'))%)" -ForegroundColor Red
    Write-Host "Potential annual savings with Azure Native: $(($difference * 12).ToString('C0'))" -ForegroundColor Green
    $winner = "Azure Native"
}

Write-Host ""
Write-Host "Cost Winner: $winner" -ForegroundColor Yellow -BackgroundColor Black

# Break-even analysis for OpenTelemetry
if ($winner -eq "OpenTelemetry") {
    $setupCost = [math]::Max(25000, $ServiceCount * 500)  # Estimate setup cost
    $monthlyLift = $difference
    $breakEvenMonths = [math]::Ceiling($setupCost / $monthlyLift)
    $threeYearSavings = ($monthlyLift * 36) - $setupCost
    
    Write-Host ""
    Write-Host "Break-even Analysis:" -ForegroundColor Cyan
    Write-Host "- OpenTelemetry setup cost: $($setupCost.ToString('C0'))"
    Write-Host "- Break-even period: $breakEvenMonths months"
    Write-Host "- 3-year savings: $($threeYearSavings.ToString('C0'))"
}

# Recommendations
Write-Host ""
Write-Host "Recommendations:" -ForegroundColor Yellow
Write-Host "----------------" -ForegroundColor Yellow

if ($ServiceCount -le 20 -and $DataVolumeGB -le 1000) {
    Write-Host "✅ Recommended: Azure Native" -ForegroundColor Green
    Write-Host "   - Lower complexity for smaller scale"
    Write-Host "   - Faster time to value"
    Write-Host "   - Less operational overhead"
} elseif ($ServiceCount -ge 100 -or $DataVolumeGB -ge 5000) {
    Write-Host "✅ Recommended: OpenTelemetry" -ForegroundColor Green
    Write-Host "   - Better cost scaling at large volumes"
    Write-Host "   - More flexibility and control"
    Write-Host "   - Vendor independence"
} else {
    Write-Host "⚠️  Recommended: Hybrid Approach" -ForegroundColor Yellow
    Write-Host "   - Start with Azure Native for immediate needs"
    Write-Host "   - Pilot OpenTelemetry for select workloads"
    Write-Host "   - Plan gradual migration based on results"
}

Write-Host ""
Write-Host "💡 Note: Actual costs may vary based on specific requirements, usage patterns, and negotiated rates." -ForegroundColor Gray
