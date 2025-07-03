# Setup Validation Script for Azure Native vs Dynatrace Demo
# This script validates that both monitoring solutions are properly configured

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = $PSScriptRoot,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipAzureValidation,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipDynatraceValidation,
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "🔍 Starting Setup Validation for Azure Native vs Dynatrace Demo" -ForegroundColor Green

# Initialize validation results
$validationResults = @{
    Azure = @{
        Prerequisites = @()
        Infrastructure = @()
        Monitoring = @()
        Application = @()
    }
    Dynatrace = @{
        Prerequisites = @()
        Infrastructure = @()
        Monitoring = @()
        Application = @()
    }
    Overall = @{
        Success = $false
        Warnings = @()
        Errors = @()
    }
}

# Helper function to add validation result
function Add-ValidationResult {
    param(
        [string]$Category,
        [string]$SubCategory,
        [string]$Test,
        [string]$Status,
        [string]$Message
    )
    
    $result = @{
        Test = $Test
        Status = $Status
        Message = $Message
        Timestamp = Get-Date
    }
    
    $validationResults[$Category][$SubCategory] += $result
    
    if ($Status -eq "PASS") {
        Write-Host "✅ $Test" -ForegroundColor Green
    } elseif ($Status -eq "WARN") {
        Write-Host "⚠️  $Test - $Message" -ForegroundColor Yellow
    } else {
        Write-Host "❌ $Test - $Message" -ForegroundColor Red
    }
}

# Azure Validation Functions
function Test-AzurePrerequisites {
    Write-Host "`n🔧 Validating Azure Prerequisites..." -ForegroundColor Cyan
    
    # Check Azure CLI
    try {
        $azVersion = az version --output json 2>$null | ConvertFrom-Json
        if ($azVersion) {
            Add-ValidationResult "Azure" "Prerequisites" "Azure CLI Installation" "PASS" "Version: $($azVersion.'azure-cli')"
        } else {
            Add-ValidationResult "Azure" "Prerequisites" "Azure CLI Installation" "FAIL" "Azure CLI not found"
        }
    } catch {
        Add-ValidationResult "Azure" "Prerequisites" "Azure CLI Installation" "FAIL" "Azure CLI not found"
    }
    
    # Check Azure CLI Login
    try {
        $account = az account show --output json 2>$null | ConvertFrom-Json
        if ($account) {
            Add-ValidationResult "Azure" "Prerequisites" "Azure CLI Authentication" "PASS" "Logged in as: $($account.user.name)"
        } else {
            Add-ValidationResult "Azure" "Prerequisites" "Azure CLI Authentication" "FAIL" "Not logged in to Azure"
        }
    } catch {
        Add-ValidationResult "Azure" "Prerequisites" "Azure CLI Authentication" "FAIL" "Not logged in to Azure"
    }
    
    # Check .NET SDK
    try {
        $dotnetVersion = dotnet --version 2>$null
        if ($dotnetVersion) {
            Add-ValidationResult "Azure" "Prerequisites" ".NET SDK Installation" "PASS" "Version: $dotnetVersion"
        } else {
            Add-ValidationResult "Azure" "Prerequisites" ".NET SDK Installation" "FAIL" ".NET SDK not found"
        }
    } catch {
        Add-ValidationResult "Azure" "Prerequisites" ".NET SDK Installation" "FAIL" ".NET SDK not found"
    }
    
    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -ge 7) {
        Add-ValidationResult "Azure" "Prerequisites" "PowerShell Version" "PASS" "Version: $psVersion"
    } else {
        Add-ValidationResult "Azure" "Prerequisites" "PowerShell Version" "WARN" "PowerShell 7+ recommended, current: $psVersion"
    }
}

function Test-AzureInfrastructure {
    Write-Host "`n🏗️  Validating Azure Infrastructure..." -ForegroundColor Cyan
    
    # Check if parameters file exists
    $parametersFile = Join-Path $ConfigPath "..\azure-native-setup\infrastructure\main.parameters.json"
    if (Test-Path $parametersFile) {
        Add-ValidationResult "Azure" "Infrastructure" "Parameters File" "PASS" "Found: $parametersFile"
        
        # Validate parameters file content
        try {
            $parameters = Get-Content $parametersFile -Raw | ConvertFrom-Json
            if ($parameters.parameters.subscriptionId.value -ne "YOUR_SUBSCRIPTION_ID_HERE") {
                Add-ValidationResult "Azure" "Infrastructure" "Parameters Configuration" "PASS" "Subscription ID configured"
            } else {
                Add-ValidationResult "Azure" "Infrastructure" "Parameters Configuration" "FAIL" "Subscription ID not configured"
            }
        } catch {
            Add-ValidationResult "Azure" "Infrastructure" "Parameters Configuration" "FAIL" "Invalid JSON in parameters file"
        }
    } else {
        Add-ValidationResult "Azure" "Infrastructure" "Parameters File" "FAIL" "Parameters file not found"
    }
    
    # Check if Bicep template exists
    $bicepFile = Join-Path $ConfigPath "..\azure-native-setup\infrastructure\main.bicep"
    if (Test-Path $bicepFile) {
        Add-ValidationResult "Azure" "Infrastructure" "Bicep Template" "PASS" "Found: $bicepFile"
    } else {
        Add-ValidationResult "Azure" "Infrastructure" "Bicep Template" "FAIL" "Bicep template not found"
    }
}

function Test-AzureMonitoring {
    Write-Host "`n📊 Validating Azure Monitoring Configuration..." -ForegroundColor Cyan
    
    # Check deployment info file
    $deploymentFile = Join-Path $ConfigPath "..\azure-native-setup\deployment-info.json"
    if (Test-Path $deploymentFile) {
        Add-ValidationResult "Azure" "Monitoring" "Deployment Info" "PASS" "Found: $deploymentFile"
        
        try {
            $deploymentInfo = Get-Content $deploymentFile -Raw | ConvertFrom-Json
            if ($deploymentInfo.applicationInsights.connectionString) {
                Add-ValidationResult "Azure" "Monitoring" "Application Insights" "PASS" "Connection string configured"
            } else {
                Add-ValidationResult "Azure" "Monitoring" "Application Insights" "WARN" "Connection string not found"
            }
        } catch {
            Add-ValidationResult "Azure" "Monitoring" "Application Insights" "FAIL" "Invalid deployment info file"
        }
    } else {
        Add-ValidationResult "Azure" "Monitoring" "Deployment Info" "WARN" "Deployment not completed yet"
    }
}

# Dynatrace Validation Functions
function Test-DynatracePrerequisites {
    Write-Host "`n🔧 Validating Dynatrace Prerequisites..." -ForegroundColor Cyan
    
    # Check kubectl
    try {
        $kubectlVersion = kubectl version --client --output=json 2>$null | ConvertFrom-Json
        if ($kubectlVersion) {
            Add-ValidationResult "Dynatrace" "Prerequisites" "kubectl Installation" "PASS" "Version: $($kubectlVersion.clientVersion.gitVersion)"
        } else {
            Add-ValidationResult "Dynatrace" "Prerequisites" "kubectl Installation" "FAIL" "kubectl not found"
        }
    } catch {
        Add-ValidationResult "Dynatrace" "Prerequisites" "kubectl Installation" "FAIL" "kubectl not found"
    }
    
    # Check Helm (if using Helm deployment)
    try {
        $helmVersion = helm version --template="{{.Version}}" 2>$null
        if ($helmVersion) {
            Add-ValidationResult "Dynatrace" "Prerequisites" "Helm Installation" "PASS" "Version: $helmVersion"
        } else {
            Add-ValidationResult "Dynatrace" "Prerequisites" "Helm Installation" "WARN" "Helm not found (optional)"
        }
    } catch {
        Add-ValidationResult "Dynatrace" "Prerequisites" "Helm Installation" "WARN" "Helm not found (optional)"
    }
}

function Test-DynatraceInfrastructure {
    Write-Host "`n🏗️  Validating Dynatrace Infrastructure..." -ForegroundColor Cyan
    
    # Check configuration file
    $configFile = Join-Path $ConfigPath "..\dynatrace-setup\infrastructure\dynatrace-config.json"
    if (Test-Path $configFile) {
        Add-ValidationResult "Dynatrace" "Infrastructure" "Configuration File" "PASS" "Found: $configFile"
        
        try {
            $config = Get-Content $configFile -Raw | ConvertFrom-Json
            if ($config.environment.url -ne "https://YOUR_TENANT.live.dynatrace.com") {
                Add-ValidationResult "Dynatrace" "Infrastructure" "Environment Configuration" "PASS" "Tenant URL configured"
            } else {
                Add-ValidationResult "Dynatrace" "Infrastructure" "Environment Configuration" "FAIL" "Tenant URL not configured"
            }
            
            if ($config.environment.apiToken -ne "YOUR_API_TOKEN_HERE") {
                Add-ValidationResult "Dynatrace" "Infrastructure" "API Token Configuration" "PASS" "API token configured"
            } else {
                Add-ValidationResult "Dynatrace" "Infrastructure" "API Token Configuration" "FAIL" "API token not configured"
            }
        } catch {
            Add-ValidationResult "Dynatrace" "Infrastructure" "Configuration File" "FAIL" "Invalid JSON in configuration file"
        }
    } else {
        Add-ValidationResult "Dynatrace" "Infrastructure" "Configuration File" "FAIL" "Configuration file not found"
    }
    
    # Check OneAgent deployment manifest
    $oneAgentFile = Join-Path $ConfigPath "..\dynatrace-setup\infrastructure\oneagent-deployment.yaml"
    if (Test-Path $oneAgentFile) {
        Add-ValidationResult "Dynatrace" "Infrastructure" "OneAgent Manifest" "PASS" "Found: $oneAgentFile"
    } else {
        Add-ValidationResult "Dynatrace" "Infrastructure" "OneAgent Manifest" "FAIL" "OneAgent deployment manifest not found"
    }
}

function Test-DynatraceMonitoring {
    Write-Host "`n📊 Validating Dynatrace Monitoring Configuration..." -ForegroundColor Cyan
    
    # Check configuration summary
    $summaryFile = Join-Path $ConfigPath "..\dynatrace-setup\dynatrace-config-summary.json"
    if (Test-Path $summaryFile) {
        Add-ValidationResult "Dynatrace" "Monitoring" "Configuration Summary" "PASS" "Found: $summaryFile"
    } else {
        Add-ValidationResult "Dynatrace" "Monitoring" "Configuration Summary" "WARN" "Configuration not completed yet"
    }
    
    # Check monitoring profiles
    $alertingFile = Join-Path $ConfigPath "..\dynatrace-setup\monitoring\alerting-profiles.json"
    if (Test-Path $alertingFile) {
        Add-ValidationResult "Dynatrace" "Monitoring" "Alerting Profiles" "PASS" "Found: $alertingFile"
    } else {
        Add-ValidationResult "Dynatrace" "Monitoring" "Alerting Profiles" "WARN" "Alerting profiles not found"
    }
}

# Application Validation Functions
function Test-SampleApplication {
    Write-Host "`n🚀 Validating Sample Application..." -ForegroundColor Cyan
    
    # Check sample app files
    $appFile = Join-Path $ConfigPath "..\sample-app\SampleApp.csproj"
    if (Test-Path $appFile) {
        Add-ValidationResult "Azure" "Application" "Sample App Project" "PASS" "Found: $appFile"
        Add-ValidationResult "Dynatrace" "Application" "Sample App Project" "PASS" "Found: $appFile"
    } else {
        Add-ValidationResult "Azure" "Application" "Sample App Project" "FAIL" "Sample app project not found"
        Add-ValidationResult "Dynatrace" "Application" "Sample App Project" "FAIL" "Sample app project not found"
    }
    
    # Check if app can be built
    try {
        $buildPath = Join-Path $ConfigPath "..\sample-app"
        Push-Location $buildPath
        dotnet build --verbosity quiet 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Add-ValidationResult "Azure" "Application" "Build Validation" "PASS" "Sample app builds successfully"
            Add-ValidationResult "Dynatrace" "Application" "Build Validation" "PASS" "Sample app builds successfully"
        } else {
            Add-ValidationResult "Azure" "Application" "Build Validation" "FAIL" "Sample app build failed"
            Add-ValidationResult "Dynatrace" "Application" "Build Validation" "FAIL" "Sample app build failed"
        }
        Pop-Location
    } catch {
        Add-ValidationResult "Azure" "Application" "Build Validation" "FAIL" "Unable to build sample app"
        Add-ValidationResult "Dynatrace" "Application" "Build Validation" "FAIL" "Unable to build sample app"
    }
}

# Main Validation Logic
try {
    # Run Azure validations
    if (-not $SkipAzureValidation) {
        Test-AzurePrerequisites
        Test-AzureInfrastructure
        Test-AzureMonitoring
    }
    
    # Run Dynatrace validations
    if (-not $SkipDynatraceValidation) {
        Test-DynatracePrerequisites
        Test-DynatraceInfrastructure
        Test-DynatraceMonitoring
    }
    
    # Run Application validations
    Test-SampleApplication
    
    # Generate summary
    Write-Host "`n📋 Validation Summary" -ForegroundColor Green
    Write-Host "==================" -ForegroundColor Green
    
    $totalTests = 0
    $passedTests = 0
    $warnedTests = 0
    $failedTests = 0
    
    foreach ($category in $validationResults.Keys) {
        if ($category -eq "Overall") { continue }
        
        foreach ($subCategory in $validationResults[$category].Keys) {
            foreach ($result in $validationResults[$category][$subCategory]) {
                $totalTests++
                switch ($result.Status) {
                    "PASS" { $passedTests++ }
                    "WARN" { $warnedTests++ }
                    "FAIL" { $failedTests++ }
                }
            }
        }
    }
    
    Write-Host "Total Tests: $totalTests" -ForegroundColor White
    Write-Host "Passed: $passedTests" -ForegroundColor Green
    Write-Host "Warnings: $warnedTests" -ForegroundColor Yellow
    Write-Host "Failed: $failedTests" -ForegroundColor Red
    
    # Determine overall status
    if ($failedTests -eq 0) {
        if ($warnedTests -eq 0) {
            Write-Host "`n✅ All validations passed! Ready to run the demo." -ForegroundColor Green
            $validationResults.Overall.Success = $true
        } else {
            Write-Host "`n⚠️  All critical validations passed with warnings. Demo can proceed." -ForegroundColor Yellow
            $validationResults.Overall.Success = $true
        }
    } else {
        Write-Host "`n❌ Some validations failed. Please address the issues before running the demo." -ForegroundColor Red
        $validationResults.Overall.Success = $false
    }
    
    # Save validation results
    $outputFile = Join-Path $ConfigPath "..\validation-results.json"
    $validationResults | ConvertTo-Json -Depth 5 | Out-File $outputFile -Encoding UTF8
    Write-Host "`nValidation results saved to: $outputFile" -ForegroundColor Cyan
    
} catch {
    Write-Host "`n❌ Validation script encountered an error: $($_.Exception.Message)" -ForegroundColor Red
    $validationResults.Overall.Success = $false
    $validationResults.Overall.Errors += $_.Exception.Message
}

# Return exit code based on validation results
if ($validationResults.Overall.Success) {
    exit 0
} else {
    exit 1
}
