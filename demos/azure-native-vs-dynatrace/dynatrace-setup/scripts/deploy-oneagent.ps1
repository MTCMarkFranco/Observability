# Dynatrace OneAgent Deployment Script
# This script deploys Dynatrace OneAgent for the observability demo

param(
    [Parameter(Mandatory=$true)]
    [string]$DynatraceEnvironmentUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$ApiToken,
    
    [Parameter(Mandatory=$true)]
    [string]$DataIngestToken,
    
    [Parameter(Mandatory=$false)]
    [string]$NetworkZone = "azure-demo",
    
    [Parameter(Mandatory=$false)]
    [string]$HostGroup = "observability-demo",
    
    [Parameter(Mandatory=$false)]
    [string]$ApplicationName = "ObservabilityDemo",
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "Demo"
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "🚀 Starting Dynatrace OneAgent Deployment" -ForegroundColor Green
Write-Host "📋 Parameters:" -ForegroundColor Yellow
Write-Host "  - Environment URL: $DynatraceEnvironmentUrl" -ForegroundColor White
Write-Host "  - Network Zone: $NetworkZone" -ForegroundColor White
Write-Host "  - Host Group: $HostGroup" -ForegroundColor White
Write-Host "  - Application: $ApplicationName" -ForegroundColor White
Write-Host "  - Environment: $Environment" -ForegroundColor White

# Extract environment ID from URL
$environmentId = if ($DynatraceEnvironmentUrl -match "https://([^.]+)\.") { $matches[1] } else { $null }
if (-not $environmentId) {
    Write-Host "❌ Could not extract environment ID from URL: $DynatraceEnvironmentUrl" -ForegroundColor Red
    exit 1
}

Write-Host "🔍 Detected Environment ID: $environmentId" -ForegroundColor Cyan

# Create download directory
$downloadDir = Join-Path $env:TEMP "dynatrace-oneagent"
if (-not (Test-Path $downloadDir)) {
    New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
}

# Download OneAgent installer
Write-Host "⬇️  Downloading OneAgent installer..." -ForegroundColor Yellow
$installerUrl = "$DynatraceEnvironmentUrl/api/v1/deployment/installer/agent/windows/default/latest"
$installerPath = Join-Path $downloadDir "Dynatrace-OneAgent-Windows.exe"

try {
    $headers = @{
        "Authorization" = "Api-Token $ApiToken"
    }
    
    Invoke-WebRequest -Uri $installerUrl -Headers $headers -OutFile $installerPath
    
    if (Test-Path $installerPath) {
        $fileSize = (Get-Item $installerPath).Length / 1MB
        Write-Host "✅ OneAgent installer downloaded ($([math]::Round($fileSize, 2)) MB)" -ForegroundColor Green
    } else {
        throw "Installer file not found after download"
    }
}
catch {
    Write-Host "❌ Failed to download OneAgent installer" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Prepare installation parameters
$installParams = @(
    "--set-server=$DynatraceEnvironmentUrl/communication",
    "--set-tenant=$environmentId",
    "--set-tenant-token=$DataIngestToken",
    "--set-network-zone=$NetworkZone",
    "--set-host-group=$HostGroup",
    "--set-host-property=Environment=$Environment",
    "--set-host-property=Application=$ApplicationName",
    "--set-host-property=Platform=Azure",
    "--set-host-property=Demo=true",
    "--set-app-log-content-access=true",
    "--set-infra-only=false",
    "/quiet"
)

# Install OneAgent
Write-Host "📦 Installing OneAgent..." -ForegroundColor Yellow
Write-Host "   This may take several minutes..." -ForegroundColor Gray

try {
    $process = Start-Process -FilePath $installerPath -ArgumentList $installParams -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -eq 0) {
        Write-Host "✅ OneAgent installed successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ OneAgent installation failed with exit code: $($process.ExitCode)" -ForegroundColor Red
        
        # Common exit codes
        switch ($process.ExitCode) {
            1 { Write-Host "   Generic error occurred" -ForegroundColor Red }
            2 { Write-Host "   Invalid command line arguments" -ForegroundColor Red }
            3 { Write-Host "   OneAgent is already installed" -ForegroundColor Yellow }
            4 { Write-Host "   Insufficient privileges" -ForegroundColor Red }
            5 { Write-Host "   Invalid tenant token" -ForegroundColor Red }
            6 { Write-Host "   Cannot connect to Dynatrace server" -ForegroundColor Red }
            default { Write-Host "   Unknown error code" -ForegroundColor Red }
        }
        
        if ($process.ExitCode -ne 3) {
            exit $process.ExitCode
        }
    }
}
catch {
    Write-Host "❌ Failed to install OneAgent" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Wait for OneAgent to start
Write-Host "⏳ Waiting for OneAgent to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Check OneAgent status
Write-Host "🔍 Checking OneAgent status..." -ForegroundColor Yellow

try {
    $oneAgentService = Get-Service -Name "Dynatrace OneAgent" -ErrorAction SilentlyContinue
    
    if ($oneAgentService) {
        Write-Host "✅ OneAgent service found: $($oneAgentService.Status)" -ForegroundColor Green
        
        if ($oneAgentService.Status -eq "Running") {
            Write-Host "✅ OneAgent is running successfully" -ForegroundColor Green
        } else {
            Write-Host "⚠️  OneAgent service is not running" -ForegroundColor Yellow
            Write-Host "   Attempting to start service..." -ForegroundColor Gray
            Start-Service -Name "Dynatrace OneAgent"
            Write-Host "✅ OneAgent service started" -ForegroundColor Green
        }
    } else {
        Write-Host "⚠️  OneAgent service not found" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "⚠️  Could not check OneAgent service status" -ForegroundColor Yellow
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Check if OneAgent is communicating
Write-Host "📡 Verifying OneAgent communication..." -ForegroundColor Yellow

try {
    $oneAgentLogPath = "${env:ProgramFiles}\dynatrace\oneagent\log\oneagent.log"
    
    if (Test-Path $oneAgentLogPath) {
        $logContent = Get-Content $oneAgentLogPath -Tail 50 | Out-String
        
        if ($logContent -match "connection established" -or $logContent -match "successful") {
            Write-Host "✅ OneAgent communication verified" -ForegroundColor Green
        } else {
            Write-Host "⚠️  OneAgent communication status unclear" -ForegroundColor Yellow
            Write-Host "   Check logs at: $oneAgentLogPath" -ForegroundColor Gray
        }
    } else {
        Write-Host "⚠️  OneAgent log file not found" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "⚠️  Could not verify OneAgent communication" -ForegroundColor Yellow
}

# Create configuration summary
Write-Host "📊 Creating configuration summary..." -ForegroundColor Yellow

$configSummary = @{
    DeploymentTime = Get-Date
    DynatraceEnvironmentUrl = $DynatraceEnvironmentUrl
    EnvironmentId = $environmentId
    NetworkZone = $NetworkZone
    HostGroup = $HostGroup
    ApplicationName = $ApplicationName
    Environment = $Environment
    InstallerPath = $installerPath
    InstallationParameters = $installParams
    HostProperties = @{
        Environment = $Environment
        Application = $ApplicationName
        Platform = "Azure"
        Demo = "true"
    }
}

$configSummaryFile = Join-Path $PSScriptRoot "..\dynatrace-config-summary.json"
$configSummary | ConvertTo-Json -Depth 10 | Set-Content $configSummaryFile

Write-Host "💾 Configuration summary saved to: $configSummaryFile" -ForegroundColor Cyan

# Clean up installer
Write-Host "🧹 Cleaning up installer..." -ForegroundColor Yellow
Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
Remove-Item $downloadDir -Force -Recurse -ErrorAction SilentlyContinue

Write-Host "🎉 Dynatrace OneAgent deployment completed!" -ForegroundColor Green
Write-Host "📋 Summary:" -ForegroundColor Yellow
Write-Host "  - OneAgent installed and running" -ForegroundColor White
Write-Host "  - Host Group: $HostGroup" -ForegroundColor White
Write-Host "  - Network Zone: $NetworkZone" -ForegroundColor White
Write-Host "  - Application: $ApplicationName" -ForegroundColor White

Write-Host "🔍 Next steps:" -ForegroundColor Yellow
Write-Host "  1. Configure monitoring rules and alerts: .\configure-monitoring.ps1" -ForegroundColor White
Write-Host "  2. Deploy the sample application" -ForegroundColor White
Write-Host "  3. Generate test traffic" -ForegroundColor White
Write-Host "  4. Review data in Dynatrace UI" -ForegroundColor White

Write-Host "🌐 Access your Dynatrace environment:" -ForegroundColor Yellow
Write-Host "  - Environment URL: $DynatraceEnvironmentUrl" -ForegroundColor Cyan
Write-Host "  - Host & Infrastructure: $DynatraceEnvironmentUrl/#newhosts" -ForegroundColor Cyan
Write-Host "  - Applications: $DynatraceEnvironmentUrl/#applications" -ForegroundColor Cyan
Write-Host "  - Services: $DynatraceEnvironmentUrl/#services" -ForegroundColor Cyan

Write-Host "⚠️  Important notes:" -ForegroundColor Yellow
Write-Host "  - It may take 5-10 minutes for data to appear in Dynatrace UI" -ForegroundColor White
Write-Host "  - Ensure your application is running to see full monitoring data" -ForegroundColor White
Write-Host "  - Check Dynatrace UI for host visibility and monitoring status" -ForegroundColor White

Write-Host "✅ Dynatrace OneAgent deployment completed successfully!" -ForegroundColor Green
