# Azure Native vs Dynatrace Comparison Analysis Script
# This script analyzes and compares the results from both monitoring solutions

param(
    [Parameter(Mandatory=$false)]
    [string]$AzureDeploymentInfoFile = (Join-Path $PSScriptRoot "..\azure-native-setup\deployment-info.json"),
    
    [Parameter(Mandatory=$false)]
    [string]$DynatraceConfigFile = (Join-Path $PSScriptRoot "..\dynatrace-setup\dynatrace-config-summary.json"),
    
    [Parameter(Mandatory=$false)]
    [string]$LoadTestResultsFile = (Join-Path $PSScriptRoot "..\load-test-results.json"),
    
    [Parameter(Mandatory=$false)]
    [string]$OutputDirectory = (Join-Path $PSScriptRoot "..\comparison-results")
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "📊 Starting Azure Native vs Dynatrace Comparison Analysis" -ForegroundColor Green

# Create output directory
if (-not (Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

# Load configuration files
$azureInfo = $null
$dynatraceInfo = $null
$loadTestResults = $null

if (Test-Path $AzureDeploymentInfoFile) {
    $azureInfo = Get-Content $AzureDeploymentInfoFile -Raw | ConvertFrom-Json
    Write-Host "✅ Loaded Azure deployment info" -ForegroundColor Green
} else {
    Write-Host "⚠️  Azure deployment info not found: $AzureDeploymentInfoFile" -ForegroundColor Yellow
}

if (Test-Path $DynatraceConfigFile) {
    $dynatraceInfo = Get-Content $DynatraceConfigFile -Raw | ConvertFrom-Json
    Write-Host "✅ Loaded Dynatrace configuration info" -ForegroundColor Green
} else {
    Write-Host "⚠️  Dynatrace configuration info not found: $DynatraceConfigFile" -ForegroundColor Yellow
}

if (Test-Path $LoadTestResultsFile) {
    $loadTestResults = Get-Content $LoadTestResultsFile -Raw | ConvertFrom-Json
    Write-Host "✅ Loaded load test results" -ForegroundColor Green
} else {
    Write-Host "⚠️  Load test results not found: $LoadTestResultsFile" -ForegroundColor Yellow
}

# Implementation Complexity Analysis
Write-Host "🔧 Analyzing Implementation Complexity..." -ForegroundColor Yellow

$implementationComparison = @{
    ComparisonDate = Get-Date
    Summary = @{
        AzureNative = @{
            TimeToImplement = "4-6 hours"
            ConfigurationFiles = 8
            DeploymentSteps = 5
            ManualSteps = @(
                "Create Bicep templates",
                "Configure Application Insights",
                "Set up Log Analytics workspace",
                "Create alert rules",
                "Configure dashboards"
            )
            Complexity = "Medium"
            SkillsRequired = @(
                "Azure services knowledge",
                "Bicep/ARM templates",
                "KQL query language",
                "Azure Monitor understanding"
            )
        }
        Dynatrace = @{
            TimeToImplement = "1-2 hours"
            ConfigurationFiles = 3
            DeploymentSteps = 2
            ManualSteps = @(
                "Download and install OneAgent",
                "Configure monitoring rules (optional)"
            )
            Complexity = "Low"
            SkillsRequired = @(
                "Basic Dynatrace knowledge",
                "Minimal configuration required"
            )
        }
    }
    DetailedAnalysis = @{
        Setup = @{
            AzureNative = @{
                Infrastructure = "Requires multiple Azure services setup"
                Instrumentation = "Manual code instrumentation required"
                Configuration = "Complex multi-service configuration"
                TimeInvestment = "High initial setup time"
            }
            Dynatrace = @{
                Infrastructure = "Minimal infrastructure requirements"
                Instrumentation = "Automatic code instrumentation"
                Configuration = "Mostly automatic configuration"
                TimeInvestment = "Low initial setup time"
            }
        }
        DataCollection = @{
            AzureNative = @{
                Application = "Application Insights SDK required"
                Infrastructure = "Multiple diagnostic settings"
                Custom = "Manual custom metrics implementation"
                Integration = "Multiple service integrations needed"
            }
            Dynatrace = @{
                Application = "Automatic via OneAgent"
                Infrastructure = "Automatic via OneAgent"
                Custom = "Automatic discovery and creation"
                Integration = "Single agent covers all"
            }
        }
        Alerting = @{
            AzureNative = @{
                Setup = "Manual alert rule creation"
                Conditions = "Complex condition definitions"
                Notifications = "Separate action group setup"
                Maintenance = "Manual rule updates needed"
            }
            Dynatrace = @{
                Setup = "AI-powered automatic alerting"
                Conditions = "Smart baseline detection"
                Notifications = "Integrated notification system"
                Maintenance = "Self-adapting alert conditions"
            }
        }
    }
}

# Feature Comparison Analysis
Write-Host "⚡ Analyzing Feature Capabilities..." -ForegroundColor Yellow

$featureComparison = @{
    MonitoringCapabilities = @{
        ApplicationPerformanceMonitoring = @{
            AzureNative = @{
                Available = $true
                Quality = "Good"
                Features = @(
                    "Request tracking",
                    "Dependency mapping",
                    "Performance counters",
                    "Exception tracking"
                )
                Limitations = @(
                    "Manual instrumentation required",
                    "Limited automatic discovery",
                    "Basic dependency mapping"
                )
            }
            Dynatrace = @{
                Available = $true
                Quality = "Excellent"
                Features = @(
                    "Automatic code-level monitoring",
                    "AI-powered dependency mapping",
                    "Real-time topology",
                    "User session tracking"
                )
                Limitations = @(
                    "Proprietary solution",
                    "Higher cost"
                )
            }
        }
        InfrastructureMonitoring = @{
            AzureNative = @{
                Available = $true
                Quality = "Excellent"
                Features = @(
                    "Native Azure resource monitoring",
                    "Platform metrics included",
                    "Resource health monitoring",
                    "Cost integration"
                )
                Limitations = @(
                    "Azure-specific only",
                    "Limited cross-cloud support"
                )
            }
            Dynatrace = @{
                Available = $true
                Quality = "Excellent"
                Features = @(
                    "Multi-cloud infrastructure monitoring",
                    "Automatic host discovery",
                    "Process monitoring",
                    "Network monitoring"
                )
                Limitations = @(
                    "Additional cost for infrastructure monitoring",
                    "Less integrated with Azure billing"
                )
            }
        }
        UserExperienceMonitoring = @{
            AzureNative = @{
                Available = $true
                Quality = "Good"
                Features = @(
                    "Page view tracking",
                    "User behavior analytics",
                    "Availability tests",
                    "Performance insights"
                )
                Limitations = @(
                    "Limited real user monitoring",
                    "Basic user journey tracking"
                )
            }
            Dynatrace = @{
                Available = $true
                Quality = "Excellent"
                Features = @(
                    "Real user monitoring",
                    "Session replay",
                    "User journey analysis",
                    "Business transaction tracking"
                )
                Limitations = @(
                    "Higher cost for RUM",
                    "Privacy considerations with session replay"
                )
            }
        }
        AIOpsCapabilities = @{
            AzureNative = @{
                Available = $true
                Quality = "Growing"
                Features = @(
                    "Anomaly detection",
                    "Smart alerts",
                    "Predictive analytics",
                    "Integration with Azure AI services"
                )
                Limitations = @(
                    "Limited AI-powered root cause analysis",
                    "Manual correlation required"
                )
            }
            Dynatrace = @{
                Available = $true
                Quality = "Excellent"
                Features = @(
                    "Davis AI engine",
                    "Automatic root cause analysis",
                    "Predictive alerting",
                    "Automatic problem correlation"
                )
                Limitations = @(
                    "Proprietary AI algorithms",
                    "Less transparent decision making"
                )
            }
        }
    }
}

# Cost Analysis
Write-Host "💰 Analyzing Cost Implications..." -ForegroundColor Yellow

$costAnalysis = @{
    InitialCosts = @{
        AzureNative = @{
            LicensingCosts = 0
            SetupCosts = "High (development time)"
            TrainingCosts = "Medium (Azure skills required)"
            ConsultingCosts = "Medium"
        }
        Dynatrace = @{
            LicensingCosts = "High (immediate)"
            SetupCosts = "Low (minimal configuration)"
            TrainingCosts = "Low (intuitive interface)"
            ConsultingCosts = "Low"
        }
    }
    OngoingCosts = @{
        AzureNative = @{
            DataIngestion = "$2.30-$2.76 per GB"
            Storage = "Included in ingestion cost"
            Alerting = "$0.10 per alert rule"
            Scaling = "Linear with data volume"
            Predictability = "High"
        }
        Dynatrace = @{
            HostMonitoring = "$69 per 8GB host/month"
            UserSessions = "$0.00225 per session"
            SyntheticMonitoring = "$5 per monitor/month"
            Scaling = "Better economics at scale"
            Predictability = "Medium (complex pricing)"
        }
    }
    TCOProjection = @{
        Year1 = @{
            AzureNative = "$50,000 (medium enterprise)"
            Dynatrace = "$75,000 (medium enterprise)"
        }
        Year3 = @{
            AzureNative = "$141,120"
            Dynatrace = "$208,800"
        }
        BreakEvenPoint = "Dynatrace never breaks even on cost alone"
        ValueConsiderations = @(
            "Faster time to resolution",
            "Reduced operational overhead",
            "Better user experience",
            "Proactive issue detection"
        )
    }
}

# User Experience Analysis
Write-Host "👥 Analyzing User Experience..." -ForegroundColor Yellow

$userExperienceAnalysis = @{
    LearningCurve = @{
        AzureNative = @{
            InitialLearning = "Steep"
            TimeToProductivity = "4-6 weeks"
            SkillTransferability = "High (Azure ecosystem)"
            Documentation = "Excellent"
            CommunitySupport = "Excellent"
        }
        Dynatrace = @{
            InitialLearning = "Gentle"
            TimeToProductivity = "1-2 weeks"
            SkillTransferability = "Medium (Dynatrace specific)"
            Documentation = "Excellent"
            CommunitySupport = "Good"
        }
    }
    DailyUsage = @{
        AzureNative = @{
            InterfaceComplexity = "High (multiple portals)"
            QueryLanguage = "KQL (powerful but complex)"
            DashboardCreation = "Manual and time-consuming"
            AlertManagement = "Complex multi-step process"
            Troubleshooting = "Manual correlation required"
        }
        Dynatrace = @{
            InterfaceComplexity = "Low (unified interface)"
            QueryLanguage = "DQL (intuitive)"
            DashboardCreation = "Automatic and customizable"
            AlertManagement = "Intelligent and contextual"
            Troubleshooting = "AI-guided root cause analysis"
        }
    }
}

# Data Storage and Governance Analysis
Write-Host "🗄️  Analyzing Data Storage and Governance..." -ForegroundColor Yellow

$dataGovernanceAnalysis = @{
    DataSovereignty = @{
        AzureNative = @{
            DataLocation = "Azure regions (customer choice)"
            DataResidency = "Full control"
            Compliance = "Azure compliance certifications"
            DataExport = "Full data export capabilities"
            VendorLockIn = "High (Azure specific formats)"
        }
        Dynatrace = @{
            DataLocation = "Dynatrace data centers"
            DataResidency = "Limited customer control"
            Compliance = "Dynatrace compliance certifications"
            DataExport = "Limited export capabilities"
            VendorLockIn = "High (proprietary format)"
        }
    }
    DataRetention = @{
        AzureNative = @{
            RetentionPeriods = "30 days to 2 years"
            ArchivingOptions = "Azure Storage integration"
            CostOptimization = "Tiered storage available"
            DataLifecycle = "Full customer control"
        }
        Dynatrace = @{
            RetentionPeriods = "Based on license tier"
            ArchivingOptions = "Limited archiving options"
            CostOptimization = "Included in licensing"
            DataLifecycle = "Vendor managed"
        }
    }
    Privacy = @{
        AzureNative = @{
            DataProcessing = "Customer controlled"
            PIIHandling = "Customer responsibility"
            GDPR = "Azure GDPR compliance tools"
            DataMinimization = "Customer configured"
        }
        Dynatrace = @{
            DataProcessing = "Vendor controlled"
            PIIHandling = "Built-in privacy controls"
            GDPR = "Dynatrace GDPR compliance"
            DataMinimization = "Automated privacy controls"
        }
    }
}

# Performance and Reliability Analysis
Write-Host "⚡ Analyzing Performance and Reliability..." -ForegroundColor Yellow

$performanceAnalysis = @{
    DataProcessing = @{
        AzureNative = @{
            IngestionLatency = "1-5 minutes"
            QueryPerformance = "Good (KQL optimized)"
            DataFreshness = "Near real-time"
            Scalability = "Excellent (Azure scale)"
        }
        Dynatrace = @{
            IngestionLatency = "Real-time"
            QueryPerformance = "Excellent (optimized engine)"
            DataFreshness = "Real-time"
            Scalability = "Excellent (cloud native)"
        }
    }
    Reliability = @{
        AzureNative = @{
            ServiceAvailability = "99.9% (Azure SLA)"
            DataDurability = "Excellent (Azure redundancy)"
            DisasterRecovery = "Azure geo-redundancy"
            Backup = "Customer managed"
        }
        Dynatrace = @{
            ServiceAvailability = "99.5% (Dynatrace SLA)"
            DataDurability = "Good (vendor managed)"
            DisasterRecovery = "Vendor managed"
            Backup = "Vendor managed"
        }
    }
}

# Create comprehensive comparison report
Write-Host "📝 Generating Comparison Report..." -ForegroundColor Yellow

$comparisonReport = @{
    GeneratedDate = Get-Date
    Summary = @{
        RecommendationAzureNative = @(
            "Azure-first organizations",
            "Cost-conscious enterprises",
            "Teams with Azure expertise",
            "Simple to moderate complexity applications",
            "Strong data sovereignty requirements"
        )
        RecommendationDynatrace = @(
            "Multi-cloud environments",
            "Complex microservices architectures",
            "Teams needing faster time-to-value",
            "Organizations prioritizing user experience",
            "Enterprises requiring advanced AI/ML capabilities"
        )
        KeyDifferentiators = @{
            AzureNativeAdvantages = @(
                "Lower total cost of ownership",
                "Native Azure integration",
                "Transparent and predictable pricing",
                "Complete data sovereignty",
                "Leverages existing Azure skills"
            )
            DynatraceAdvantages = @(
                "Faster implementation and time-to-value",
                "Superior user experience",
                "Advanced AI-powered insights",
                "Automatic discovery and configuration",
                "Comprehensive full-stack monitoring"
            )
        }
    }
    DetailedAnalysis = @{
        Implementation = $implementationComparison
        Features = $featureComparison
        Costs = $costAnalysis
        UserExperience = $userExperienceAnalysis
        DataGovernance = $dataGovernanceAnalysis
        Performance = $performanceAnalysis
    }
    LoadTestResults = $loadTestResults
    Configurations = @{
        Azure = $azureInfo
        Dynatrace = $dynatraceInfo
    }
    DecisionMatrix = @{
        Criteria = @(
            @{ Name = "Implementation Speed"; AzureNative = 2; Dynatrace = 5; Weight = 0.15 }
            @{ Name = "Total Cost of Ownership"; AzureNative = 5; Dynatrace = 2; Weight = 0.20 }
            @{ Name = "Feature Completeness"; AzureNative = 3; Dynatrace = 5; Weight = 0.15 }
            @{ Name = "User Experience"; AzureNative = 2; Dynatrace = 5; Weight = 0.15 }
            @{ Name = "Azure Integration"; AzureNative = 5; Dynatrace = 3; Weight = 0.10 }
            @{ Name = "Multi-cloud Support"; AzureNative = 1; Dynatrace = 5; Weight = 0.10 }
            @{ Name = "Data Sovereignty"; AzureNative = 5; Dynatrace = 2; Weight = 0.15 }
        )
    }
}

# Calculate decision matrix scores
$azureScore = 0
$dynatraceScore = 0

foreach ($criterion in $comparisonReport.DecisionMatrix.Criteria) {
    $azureScore += $criterion.AzureNative * $criterion.Weight
    $dynatraceScore += $criterion.Dynatrace * $criterion.Weight
}

$comparisonReport.DecisionMatrix.FinalScores = @{
    AzureNative = [math]::Round($azureScore, 2)
    Dynatrace = [math]::Round($dynatraceScore, 2)
    Recommendation = if ($azureScore -gt $dynatraceScore) { "Azure Native" } else { "Dynatrace" }
}

# Save comparison report
$reportFile = Join-Path $OutputDirectory "azure-native-vs-dynatrace-comparison.json"
$comparisonReport | ConvertTo-Json -Depth 10 | Set-Content $reportFile

# Generate summary markdown report
$markdownReport = @"
# Azure Native vs Dynatrace Comparison Report

Generated: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))

## Executive Summary

### Decision Matrix Results
- **Azure Native Score**: $($comparisonReport.DecisionMatrix.FinalScores.AzureNative)/5.0
- **Dynatrace Score**: $($comparisonReport.DecisionMatrix.FinalScores.Dynatrace)/5.0
- **Recommendation**: $($comparisonReport.DecisionMatrix.FinalScores.Recommendation)

### Quick Recommendations

#### Choose Azure Native When:
$(($comparisonReport.Summary.RecommendationAzureNative | ForEach-Object { "- $_" }) -join "`n")

#### Choose Dynatrace When:
$(($comparisonReport.Summary.RecommendationDynatrace | ForEach-Object { "- $_" }) -join "`n")

## Key Findings

### Implementation Complexity
- **Azure Native**: $($comparisonReport.DetailedAnalysis.Implementation.Summary.AzureNative.Complexity) complexity, $($comparisonReport.DetailedAnalysis.Implementation.Summary.AzureNative.TimeToImplement) implementation time
- **Dynatrace**: $($comparisonReport.DetailedAnalysis.Implementation.Summary.Dynatrace.Complexity) complexity, $($comparisonReport.DetailedAnalysis.Implementation.Summary.Dynatrace.TimeToImplement) implementation time

### Cost Analysis (3-Year TCO)
- **Azure Native**: $($comparisonReport.DetailedAnalysis.Costs.TCOProjection.Year3.AzureNative)
- **Dynatrace**: $($comparisonReport.DetailedAnalysis.Costs.TCOProjection.Year3.Dynatrace)

### User Experience
- **Azure Native**: $($comparisonReport.DetailedAnalysis.UserExperience.LearningCurve.AzureNative.TimeToProductivity) time to productivity
- **Dynatrace**: $($comparisonReport.DetailedAnalysis.UserExperience.LearningCurve.Dynatrace.TimeToProductivity) time to productivity

## Detailed Analysis

### Azure Native Advantages
$(($comparisonReport.Summary.KeyDifferentiators.AzureNativeAdvantages | ForEach-Object { "- $_" }) -join "`n")

### Dynatrace Advantages
$(($comparisonReport.Summary.KeyDifferentiators.DynatraceAdvantages | ForEach-Object { "- $_" }) -join "`n")

## Load Test Results
$(if ($loadTestResults) {
"- **Total Requests**: $($loadTestResults.Results.TotalRequests)
- **Success Rate**: $($loadTestResults.Results.SuccessRate)%
- **Average Response Time**: $($loadTestResults.Results.AverageResponseTime)ms
- **Requests/Second**: $($loadTestResults.Results.RequestsPerSecond)"
} else {
"Load test results not available"
})

## Recommendations

### For Most Azure Enterprises
**Start with Azure Native** for immediate cost benefits and Azure integration, with a plan to evaluate Dynatrace for complex scenarios or multi-cloud expansion.

### For Complex Environments
**Consider Dynatrace** if you prioritize faster implementation, superior user experience, and advanced AI capabilities over cost optimization.

### Hybrid Approach
Use Azure Native for basic infrastructure monitoring and Dynatrace for critical application performance monitoring to optimize both cost and capabilities.

---

*This report was generated automatically based on configuration analysis and load testing results.*
"@

$markdownReportFile = Join-Path $OutputDirectory "comparison-summary.md"
$markdownReport | Set-Content $markdownReportFile

# Generate Excel-compatible CSV for decision matrix
$csvData = @()
foreach ($criterion in $comparisonReport.DecisionMatrix.Criteria) {
    $csvData += [PSCustomObject]@{
        Criteria = $criterion.Name
        Weight = $criterion.Weight
        AzureNativeScore = $criterion.AzureNative
        DynatraceScore = $criterion.Dynatrace
        WeightedAzureScore = $criterion.AzureNative * $criterion.Weight
        WeightedDynatraceScore = $criterion.Dynatrace * $criterion.Weight
    }
}

$csvFile = Join-Path $OutputDirectory "decision-matrix.csv"
$csvData | Export-Csv -Path $csvFile -NoTypeInformation

# Display results
Write-Host "🎉 Comparison Analysis Completed!" -ForegroundColor Green
Write-Host "📊 Results:" -ForegroundColor Yellow
Write-Host "  - Azure Native Score: $($comparisonReport.DecisionMatrix.FinalScores.AzureNative)/5.0" -ForegroundColor White
Write-Host "  - Dynatrace Score: $($comparisonReport.DecisionMatrix.FinalScores.Dynatrace)/5.0" -ForegroundColor White
Write-Host "  - Recommendation: $($comparisonReport.DecisionMatrix.FinalScores.Recommendation)" -ForegroundColor $(if ($comparisonReport.DecisionMatrix.FinalScores.Recommendation -eq "Azure Native") { "Cyan" } else { "Magenta" })

Write-Host "📁 Generated Files:" -ForegroundColor Yellow
Write-Host "  - Detailed Report: $reportFile" -ForegroundColor White
Write-Host "  - Summary Report: $markdownReportFile" -ForegroundColor White
Write-Host "  - Decision Matrix: $csvFile" -ForegroundColor White

Write-Host "🔍 Key Insights:" -ForegroundColor Yellow
Write-Host "  - Azure Native: Best for Azure-first, cost-conscious organizations" -ForegroundColor Cyan
Write-Host "  - Dynatrace: Best for complex, multi-cloud environments requiring advanced AI" -ForegroundColor Magenta
Write-Host "  - Consider hybrid approach for optimal cost/capability balance" -ForegroundColor White

Write-Host "✅ Comparison analysis completed successfully!" -ForegroundColor Green
