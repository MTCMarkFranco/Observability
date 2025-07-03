# Load Generation Script for Azure Native vs Dynatrace Comparison
# This script generates realistic load patterns to test both monitoring solutions

param(
    [Parameter(Mandatory=$true)]
    [string]$AppServiceUrl,
    
    [Parameter(Mandatory=$false)]
    [int]$DurationMinutes = 30,
    
    [Parameter(Mandatory=$false)]
    [int]$ConcurrentUsers = 10,
    
    [Parameter(Mandatory=$false)]
    [int]$RequestsPerMinute = 60,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeErrorScenarios,
    
    [Parameter(Mandatory=$false)]
    [switch]$VerboseOutput
)

# Set error action preference
$ErrorActionPreference = "Continue"

Write-Host "🚀 Starting Load Generation for Observability Demo" -ForegroundColor Green
Write-Host "📋 Parameters:" -ForegroundColor Yellow
Write-Host "  - Target URL: $AppServiceUrl" -ForegroundColor White
Write-Host "  - Duration: $DurationMinutes minutes" -ForegroundColor White
Write-Host "  - Concurrent Users: $ConcurrentUsers" -ForegroundColor White
Write-Host "  - Requests/Minute: $RequestsPerMinute" -ForegroundColor White
Write-Host "  - Include Errors: $IncludeErrorScenarios" -ForegroundColor White

# Initialize statistics
$script:TotalRequests = 0
$script:SuccessfulRequests = 0
$script:FailedRequests = 0
$script:TotalResponseTime = 0
$script:StartTime = Get-Date

# Ensure URL ends without trailing slash
$AppServiceUrl = $AppServiceUrl.TrimEnd('/')

# Test connectivity first
Write-Host "🔍 Testing connectivity..." -ForegroundColor Yellow
try {
    $healthCheck = Invoke-WebRequest -Uri "$AppServiceUrl/health" -TimeoutSec 10 -UseBasicParsing
    if ($healthCheck.StatusCode -eq 200) {
        Write-Host "✅ Application is healthy and accessible" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Application returned status: $($healthCheck.StatusCode)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "❌ Cannot reach application at $AppServiceUrl" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Please ensure the application is deployed and running." -ForegroundColor Yellow
    exit 1
}

# Define test scenarios
$scenarios = @(
    @{
        Name = "Get All Orders"
        Method = "GET"
        Endpoint = "/api/orders"
        Weight = 30
        ExpectedDuration = 200
    },
    @{
        Name = "Get Specific Order"
        Method = "GET"
        Endpoint = "/api/orders/{orderId}"
        Weight = 25
        ExpectedDuration = 150
        ParameterGen = { Get-Random -Minimum 1 -Maximum 100 }
    },
    @{
        Name = "Create Order"
        Method = "POST"
        Endpoint = "/api/orders"
        Weight = 20
        ExpectedDuration = 500
        BodyGen = {
            @{
                customerId = Get-Random -Minimum 1 -Maximum 5
                productId = Get-Random -Minimum 1 -Maximum 5
                quantity = Get-Random -Minimum 1 -Maximum 10
            } | ConvertTo-Json
        }
    },
    @{
        Name = "Update Order Status"
        Method = "PUT"
        Endpoint = "/api/orders/{orderId}/status"
        Weight = 15
        ExpectedDuration = 300
        ParameterGen = { Get-Random -Minimum 1 -Maximum 100 }
        BodyGen = {
            $statuses = @("Confirmed", "Processing", "Shipped", "Delivered")
            @{
                status = $statuses[(Get-Random -Maximum $statuses.Length)]
            } | ConvertTo-Json
        }
    },
    @{
        Name = "CPU Intensive Demo"
        Method = "GET"
        Endpoint = "/api/demo/cpu-intensive"
        Weight = 5
        ExpectedDuration = 1000
    },
    @{
        Name = "Memory Intensive Demo"
        Method = "GET"
        Endpoint = "/api/demo/memory-intensive"
        Weight = 3
        ExpectedDuration = 800
    },
    @{
        Name = "External Dependency"
        Method = "GET"
        Endpoint = "/api/demo/external-dependency"
        Weight = 2
        ExpectedDuration = 2000
    }
)

# Add error scenarios if requested
if ($IncludeErrorScenarios) {
    $scenarios += @{
        Name = "Simulate Error"
        Method = "GET"
        Endpoint = "/api/demo/simulate-error"
        Weight = 5
        ExpectedDuration = 100
        ExpectError = $true
    }
}

# Create weighted scenario list
$weightedScenarios = @()
foreach ($scenario in $scenarios) {
    for ($i = 0; $i -lt $scenario.Weight; $i++) {
        $weightedScenarios += $scenario
    }
}

# Function to execute a single request
function Invoke-TestRequest {
    param($Scenario, $UserAgent)
    
    $script:TotalRequests++
    $startTime = Get-Date
    
    try {
        # Build URL
        $url = $AppServiceUrl + $Scenario.Endpoint
        
        # Replace parameters if needed
        if ($Scenario.ParameterGen) {
            $parameter = & $Scenario.ParameterGen
            $url = $url -replace '\{[^}]+\}', $parameter
        }
        
        # Prepare request parameters
        $requestParams = @{
            Uri = $url
            Method = $Scenario.Method
            TimeoutSec = 30
            UseBasicParsing = $true
            Headers = @{
                "User-Agent" = $UserAgent
                "Accept" = "application/json"
            }
        }
        
        # Add body if needed
        if ($Scenario.BodyGen) {
            $body = & $Scenario.BodyGen
            $requestParams.Body = $body
            $requestParams.Headers["Content-Type"] = "application/json"
        }
        
        # Execute request
        $response = Invoke-WebRequest @requestParams
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds
        
        $script:SuccessfulRequests++
        $script:TotalResponseTime += $duration
        
        if ($VerboseOutput) {
            Write-Host "  ✅ $($Scenario.Name): $($response.StatusCode) ($([math]::Round($duration, 0))ms)" -ForegroundColor Green
        }
        
        return @{
            Success = $true
            StatusCode = $response.StatusCode
            Duration = $duration
            Scenario = $Scenario.Name
        }
    }
    catch {
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds
        
        if ($Scenario.ExpectError) {
            $script:SuccessfulRequests++
            if ($VerboseOutput) {
                Write-Host "  ✅ $($Scenario.Name): Expected Error ($([math]::Round($duration, 0))ms)" -ForegroundColor Yellow
            }
        } else {
            $script:FailedRequests++
            if ($VerboseOutput) {
                Write-Host "  ❌ $($Scenario.Name): $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        return @{
            Success = $Scenario.ExpectError
            StatusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode } else { "Error" }
            Duration = $duration
            Scenario = $Scenario.Name
            Error = $_.Exception.Message
        }
    }
}

# Function to simulate a user session
function Start-UserSession {
    param($UserId, $SessionDuration)
    
    $userAgent = "LoadTest-User-$UserId/1.0"
    $sessionStart = Get-Date
    $sessionEnd = $sessionStart.AddMinutes($SessionDuration)
    
    Write-Host "👤 Starting user session $UserId (until $($sessionEnd.ToString('HH:mm:ss')))" -ForegroundColor Cyan
    
    while ((Get-Date) -lt $sessionEnd) {
        # Select a random scenario
        $scenario = $weightedScenarios | Get-Random
        
        # Execute request
        Invoke-TestRequest -Scenario $scenario -UserAgent $userAgent | Out-Null
        
        # Random delay between requests (simulate user think time)
        $thinkTime = Get-Random -Minimum 1 -Maximum 10
        Start-Sleep -Seconds $thinkTime
        
        # Occasionally do a burst of requests (simulate real user behavior)
        if ((Get-Random -Maximum 100) -lt 10) {
            $burstCount = Get-Random -Minimum 2 -Maximum 5
            for ($i = 0; $i -lt $burstCount; $i++) {
                $burstScenario = $weightedScenarios | Get-Random
                Invoke-TestRequest -Scenario $burstScenario -UserAgent $userAgent | Out-Null
                Start-Sleep -Milliseconds (Get-Random -Minimum 500 -Maximum 2000)
            }
        }
    }
    
    Write-Host "👤 User session $UserId completed" -ForegroundColor Gray
}

# Function to display statistics
function Show-Statistics {
    $elapsed = (Get-Date) - $script:StartTime
    $avgResponseTime = if ($script:SuccessfulRequests -gt 0) { $script:TotalResponseTime / $script:SuccessfulRequests } else { 0 }
    $requestsPerSecond = if ($elapsed.TotalSeconds -gt 0) { $script:TotalRequests / $elapsed.TotalSeconds } else { 0 }
    $successRate = if ($script:TotalRequests -gt 0) { ($script:SuccessfulRequests / $script:TotalRequests) * 100 } else { 0 }
    
    Write-Host "`n📊 Current Statistics:" -ForegroundColor Yellow
    Write-Host "  - Total Requests: $($script:TotalRequests)" -ForegroundColor White
    Write-Host "  - Successful: $($script:SuccessfulRequests)" -ForegroundColor Green
    Write-Host "  - Failed: $($script:FailedRequests)" -ForegroundColor Red
    Write-Host "  - Success Rate: $([math]::Round($successRate, 2))%" -ForegroundColor White
    Write-Host "  - Avg Response Time: $([math]::Round($avgResponseTime, 2))ms" -ForegroundColor White
    Write-Host "  - Requests/Second: $([math]::Round($requestsPerSecond, 2))" -ForegroundColor White
    Write-Host "  - Elapsed Time: $($elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor White
}

# Start load generation
Write-Host "🎯 Starting load generation..." -ForegroundColor Yellow

# Create user session jobs
$jobs = @()
$sessionDuration = $DurationMinutes / $ConcurrentUsers * 1.2  # Overlap sessions slightly

for ($i = 1; $i -le $ConcurrentUsers; $i++) {
    $job = Start-Job -ScriptBlock {
        param($UserId, $SessionDuration, $FunctionDef, $AppServiceUrl, $WeightedScenarios, $VerboseOutput)
        
        # Define the function in the job scope
        Invoke-Expression $FunctionDef
        
        # Initialize job-specific counters
        $script:TotalRequests = 0
        $script:SuccessfulRequests = 0
        $script:FailedRequests = 0
        $script:TotalResponseTime = 0
        
        # Run user session
        Start-UserSession -UserId $UserId -SessionDuration $SessionDuration
        
        # Return statistics
        return @{
            UserId = $UserId
            TotalRequests = $script:TotalRequests
            SuccessfulRequests = $script:SuccessfulRequests
            FailedRequests = $script:FailedRequests
            TotalResponseTime = $script:TotalResponseTime
        }
    } -ArgumentList $i, $sessionDuration, (Get-Content Function:\Invoke-TestRequest), $AppServiceUrl, $weightedScenarios, $VerboseOutput
    
    $jobs += $job
    
    # Stagger user session starts
    Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 5)
}

# Monitor progress
$endTime = (Get-Date).AddMinutes($DurationMinutes)
$lastStatsTime = Get-Date

Write-Host "⏱️  Load test will run until $($endTime.ToString('HH:mm:ss'))" -ForegroundColor Yellow
Write-Host "📈 Monitoring progress (Ctrl+C to stop early)..." -ForegroundColor Yellow

try {
    while ((Get-Date) -lt $endTime -and ($jobs | Where-Object { $_.State -eq "Running" }).Count -gt 0) {
        Start-Sleep -Seconds 10
        
        # Show statistics every minute
        if (((Get-Date) - $lastStatsTime).TotalMinutes -ge 1) {
            $completedJobs = $jobs | Where-Object { $_.State -eq "Completed" }
            $runningJobs = $jobs | Where-Object { $_.State -eq "Running" }
            
            Write-Host "`n🔄 Progress Update:" -ForegroundColor Cyan
            Write-Host "  - Active Users: $($runningJobs.Count)" -ForegroundColor White
            Write-Host "  - Completed Users: $($completedJobs.Count)" -ForegroundColor White
            
            $lastStatsTime = Get-Date
        }
    }
}
catch {
    Write-Host "`n⏹️  Load test interrupted by user" -ForegroundColor Yellow
}

# Wait for all jobs to complete
Write-Host "⏳ Waiting for all user sessions to complete..." -ForegroundColor Yellow
$jobs | Wait-Job -Timeout 60 | Out-Null

# Collect results
Write-Host "📊 Collecting results..." -ForegroundColor Yellow
$allResults = @()

foreach ($job in $jobs) {
    try {
        $result = Receive-Job -Job $job
        if ($result) {
            $allResults += $result
        }
    }
    catch {
        Write-Host "⚠️  Failed to get results from user $($job.Id): $($_.Exception.Message)" -ForegroundColor Yellow
    }
    finally {
        Remove-Job -Job $job -Force
    }
}

# Calculate final statistics
$totalRequests = ($allResults | Measure-Object -Property TotalRequests -Sum).Sum
$totalSuccessful = ($allResults | Measure-Object -Property SuccessfulRequests -Sum).Sum
$totalFailed = ($allResults | Measure-Object -Property FailedRequests -Sum).Sum
$totalResponseTime = ($allResults | Measure-Object -Property TotalResponseTime -Sum).Sum

$finalElapsed = (Get-Date) - $script:StartTime
$avgResponseTime = if ($totalSuccessful -gt 0) { $totalResponseTime / $totalSuccessful } else { 0 }
$requestsPerSecond = if ($finalElapsed.TotalSeconds -gt 0) { $totalRequests / $finalElapsed.TotalSeconds } else { 0 }
$successRate = if ($totalRequests -gt 0) { ($totalSuccessful / $totalRequests) * 100 } else { 0 }

# Create load test summary
$loadTestSummary = @{
    TestDate = Get-Date
    Configuration = @{
        TargetUrl = $AppServiceUrl
        DurationMinutes = $DurationMinutes
        ConcurrentUsers = $ConcurrentUsers
        RequestsPerMinute = $RequestsPerMinute
        IncludeErrorScenarios = $IncludeErrorScenarios
    }
    Results = @{
        TotalRequests = $totalRequests
        SuccessfulRequests = $totalSuccessful
        FailedRequests = $totalFailed
        SuccessRate = [math]::Round($successRate, 2)
        AverageResponseTime = [math]::Round($avgResponseTime, 2)
        RequestsPerSecond = [math]::Round($requestsPerSecond, 2)
        TestDuration = $finalElapsed.ToString()
    }
    ScenariosUsed = $scenarios | Select-Object Name, Weight, ExpectedDuration
    UserResults = $allResults
}

$summaryFile = Join-Path $PSScriptRoot "..\load-test-results.json"
$loadTestSummary | ConvertTo-Json -Depth 10 | Set-Content $summaryFile

# Display final results
Write-Host "`n🎉 Load Test Completed!" -ForegroundColor Green
Write-Host "📊 Final Statistics:" -ForegroundColor Yellow
Write-Host "  - Total Requests: $totalRequests" -ForegroundColor White
Write-Host "  - Successful: $totalSuccessful" -ForegroundColor Green
Write-Host "  - Failed: $totalFailed" -ForegroundColor Red
Write-Host "  - Success Rate: $([math]::Round($successRate, 2))%" -ForegroundColor White
Write-Host "  - Avg Response Time: $([math]::Round($avgResponseTime, 2))ms" -ForegroundColor White
Write-Host "  - Requests/Second: $([math]::Round($requestsPerSecond, 2))" -ForegroundColor White
Write-Host "  - Total Duration: $($finalElapsed.ToString('hh\:mm\:ss'))" -ForegroundColor White

Write-Host "💾 Results saved to: $summaryFile" -ForegroundColor Cyan

Write-Host "🔍 Next steps:" -ForegroundColor Yellow
Write-Host "  1. Review monitoring data in Azure Monitor/Application Insights" -ForegroundColor White
Write-Host "  2. Review monitoring data in Dynatrace" -ForegroundColor White
Write-Host "  3. Compare insights and alerting between platforms" -ForegroundColor White
Write-Host "  4. Run comparison analysis script" -ForegroundColor White

Write-Host "✅ Load generation completed successfully!" -ForegroundColor Green
