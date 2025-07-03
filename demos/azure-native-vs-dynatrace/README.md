# Azure Native vs Dynatrace Demo

This demo provides side-by-side implementation examples comparing Azure Native observability with Dynatrace for the same sample application.

## 🎯 Demo Objectives

1. **Compare implementation complexity** between Azure Native and Dynatrace
2. **Demonstrate data collection differences** in configuration and setup
3. **Show cost implications** of different approaches
4. **Illustrate user experience differences** in monitoring and alerting

## 📁 Demo Structure

```
azure-native-vs-dynatrace/
├── README.md                          # This file
├── sample-app/                        # Sample .NET web application
│   ├── SampleApp.csproj
│   ├── Program.cs
│   ├── Controllers/
│   └── Models/
├── azure-native-setup/               # Azure Native implementation
│   ├── infrastructure/
│   │   ├── main.bicep
│   │   └── main.parameters.json
│   ├── instrumentation/
│   │   ├── application-insights-config.json
│   │   └── log-analytics-config.json
│   ├── alerts/
│   │   ├── alert-rules.json
│   │   └── action-groups.json
│   └── scripts/
│       ├── deploy-infrastructure.ps1
│       └── configure-monitoring.ps1
├── dynatrace-setup/                  # Dynatrace implementation
│   ├── infrastructure/
│   │   ├── dynatrace-config.json
│   │   └── oneagent-deployment.yaml
│   ├── monitoring/
│   │   ├── alerting-profiles.json
│   │   └── management-zones.json
│   └── scripts/
│       ├── deploy-oneagent.ps1
│       └── configure-monitoring.ps1
├── comparison-results/               # Comparison data
│   ├── performance-metrics.json
│   ├── cost-analysis.xlsx
│   └── feature-comparison.md
└── scripts/
    ├── generate-load.ps1
    ├── run-comparison.ps1
    └── cleanup.ps1
```

## 🚀 Quick Start

### Prerequisites
- Azure subscription with appropriate permissions
- Dynatrace environment (trial available)
- PowerShell 7.0 or later
- .NET 8.0 SDK
- Docker (optional, for containerized testing)

### Automated Setup (Recommended)

1. **Validate Prerequisites**
   ```powershell
   # Check that all prerequisites are met
   .\scripts\validate-setup.ps1
   ```

2. **Quick Configuration**
   ```powershell
   # Follow the detailed quick start guide
   Get-Content .\QUICKSTART.md
   ```

3. **Template Configuration**
   ```powershell
   # Copy and configure template files
   Copy-Item "azure-native-setup\infrastructure\main.parameters.json.template" "azure-native-setup\infrastructure\main.parameters.json"
   Copy-Item "dynatrace-setup\infrastructure\dynatrace-config.json.template" "dynatrace-setup\infrastructure\dynatrace-config.json"
   # Edit the files with your specific values
   ```

### Manual Setup

1. **Deploy Sample Application**
   ```powershell
   # Clone and deploy the sample app
   .\scripts\deploy-sample-app.ps1
   ```

2. **Set up Azure Native Monitoring**
   ```powershell
   # Deploy Azure Native infrastructure and configure monitoring
   .\azure-native-setup\scripts\deploy-infrastructure.ps1
   .\azure-native-setup\scripts\configure-monitoring.ps1
   ```

3. **Set up Dynatrace Monitoring**
   ```powershell
   # Deploy Dynatrace OneAgent and configure monitoring
   .\dynatrace-setup\scripts\deploy-oneagent.ps1
   .\dynatrace-setup\scripts\configure-monitoring.ps1
   ```

4. **Generate Load and Compare**
   ```powershell
   # Generate test load and collect comparison data
   .\scripts\generate-load.ps1
   .\scripts\run-comparison.ps1
   ```

## 📋 Validation and Results

After running the demo, you'll find comprehensive results in the `comparison-results/` folder:

- **`performance-metrics.json`** - Raw performance data from both solutions
- **`cost-analysis.md`** - Detailed 3-year TCO comparison
- **`feature-comparison.md`** - Feature-by-feature analysis
- **`summary-report.md`** - Executive summary with recommendations

## 📊 What You'll Learn

### Implementation Complexity
- **Azure Native**: Multiple services configuration, KQL queries, custom dashboards
- **Dynatrace**: Single agent deployment, automatic discovery, pre-built dashboards

### Data Collection Differences
- **Azure Native**: Manual instrumentation, custom metrics, log aggregation
- **Dynatrace**: Automatic instrumentation, AI-powered insights, topology mapping

### Cost Implications
- **Azure Native**: Per-GB ingestion costs, predictable scaling
- **Dynatrace**: Per-host licensing, comprehensive feature set

### User Experience
- **Azure Native**: Multiple Azure portals, KQL knowledge required
- **Dynatrace**: Single unified interface, intuitive navigation

## 🔧 Customization Options

### Modify Sample Application
- Add custom metrics and telemetry
- Implement different technology stacks
- Simulate various failure scenarios

### Adjust Monitoring Configuration
- Change alerting thresholds
- Modify data retention policies
- Configure custom dashboards

### Scale Testing
- Increase load generation
- Add multiple application instances
- Test with different Azure regions

## 📈 Expected Outcomes

After completing this demo, you'll have:
- Hands-on experience with both solutions
- Concrete cost comparison data
- Performance metrics for decision making
- Understanding of implementation effort required

## 🎯 Next Steps

1. **Review comparison results** in `comparison-results/`
2. **Analyze cost implications** using the provided spreadsheet
3. **Consider your specific requirements** based on the demo findings
4. **Plan pilot implementation** for your chosen solution
