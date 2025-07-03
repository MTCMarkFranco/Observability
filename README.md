# Azure Observability Landing Zone

This repository provides comprehensive guidance, demos, and best practices for implementing observability in Azure landing zones. It covers the full spectrum of observability from proactive monitoring to security operations.

## 🎯 Overview

This repository demonstrates how to build observability into Azure landing zones, covering:

- **Proactive Alerts** - Early warning systems and intelligent alerting
- **Root Cause Analysis** - Detailed investigation capabilities 
- **Operational Support** - Day-to-day operations and debugging
- **Security Operations** - Security monitoring and threat detection

## 📁 Repository Structure

```
├── slides/                    # Presentation materials for each observability area
│   ├── 01-observability-overview/
│   ├── 02-log-analytics/
│   ├── 03-azure-monitor/
│   ├── 04-application-insights/
│   ├── 05-opentelemetry/
│   ├── 06-security-monitoring/
│   └── 07-best-practices/
├── demos/                     # Hands-on demonstrations and sample code
│   ├── log-analytics-setup/          # Complete Log Analytics workspace setup
│   ├── azure-monitor-config/         # Azure Monitor configuration examples
│   ├── application-insights-integration/ # Application Insights integration guide
│   ├── opentelemetry-samples/        # OpenTelemetry sample applications
│   ├── security-monitoring/          # Security monitoring with Azure Sentinel
│   └── end-to-end-scenario/          # Comprehensive e-commerce observability demo
├── infra/                     # Infrastructure as Code (Bicep templates)
│   ├── observability-foundation/     # Core observability infrastructure
│   ├── modules/                      # Reusable Bicep modules
│   │   ├── data-collection-rules.bicep
│   │   └── alert-rules.bicep
│   └── README.md                     # Infrastructure deployment guide
└── docs/                      # Additional documentation and best practices
    ├── architecture/                 # Architecture patterns and design guidance
    ├── troubleshooting/             # Comprehensive troubleshooting guide
    ├── best-practices-guide.md      # Best practices for each service
    └── reference/                   # Reference materials and links
```

## 🚀 Getting Started

1. **Review the Slides**: Start with the presentation materials in the `slides/` folder
2. **Explore the Demos**: Follow the guided walkthroughs in the `demos/` folder
3. **Deploy Infrastructure**: Use the Bicep templates in the `infra/` folder
4. **Reference Documentation**: Check `docs/` for additional guidance

## 📋 Prerequisites

- Azure Subscription with appropriate permissions
- Azure CLI installed and configured
- PowerShell 7+ or Azure Cloud Shell
- Visual Studio Code (recommended)
- .NET 8 SDK (for sample applications)

## 🔧 Quick Setup

```powershell
# Clone the repository
git clone <repository-url>
cd Observability

# Deploy the foundational infrastructure
az deployment group create \
  --resource-group rg-observability-demo \
  --template-file infra/observability-foundation/main.bicep \
  --parameters @infra/observability-foundation/main.parameters.json
```

## 📚 Learning Path

1. **Foundation** - Observability Overview and Azure Monitor basics
2. **Data Collection** - Log Analytics and data ingestion
3. **Application Monitoring** - Application Insights and custom telemetry
4. **Advanced Telemetry** - OpenTelemetry integration
5. **Security Monitoring** - Security operations and threat detection
6. **Best Practices** - Implementation guidelines and optimization

## 🎯 Key Demos

### 1. Log Analytics Setup
Complete walkthrough of Log Analytics workspace configuration, including data collection rules and basic alerting.

### 2. Azure Monitor Configuration
Comprehensive Azure Monitor setup covering metrics, alerts, and dashboard creation for various Azure resources.

### 3. Application Insights Integration
End-to-end application monitoring setup with custom telemetry, dependency tracking, and performance monitoring.

### 4. OpenTelemetry Samples
Sample .NET console application demonstrating OpenTelemetry implementation with Azure Monitor integration.

### 5. Security Monitoring
Azure Sentinel implementation with data connectors, analytics rules, and incident response workflows.

### 6. End-to-End Scenario
Complete e-commerce application observability demonstration covering all aspects from infrastructure to security.

## 🛠️ Infrastructure Components

The infrastructure templates provide:
- **Log Analytics Workspace** - Centralized log collection and analysis
- **Application Insights** - Application performance monitoring
- **Action Groups** - Alert notification management
- **Data Collection Rules** - Automated data ingestion configuration
- **Alert Rules** - Comprehensive alerting for various scenarios
- **Azure Sentinel** - Security information and event management (optional)

## 📖 Documentation

### Architecture Guidance
- [Architecture Patterns](docs/architecture/README.md) - Design patterns and best practices
- [Troubleshooting Guide](docs/troubleshooting/README.md) - Common issues and solutions
- [Best Practices Guide](docs/best-practices-guide.md) - Service-specific recommendations

### Quick References
- KQL query examples
- Alert rule templates
- Dashboard configurations
- Troubleshooting procedures

## 🚀 Get Started

1. **Review Slides**: Start with [Observability Overview](slides/01-observability-overview/README.md)
2. **Deploy Infrastructure**: Use the [Observability Foundation](infra/observability-foundation/README.md) template
3. **Follow Demos**: Begin with [Log Analytics Setup](demos/log-analytics-setup/README.md)
4. **Implement Monitoring**: Add [Application Insights Integration](demos/application-insights-integration/README.md)
5. **Advanced Features**: Explore [OpenTelemetry Samples](demos/opentelemetry-samples/README.md)
6. **Security**: Implement [Security Monitoring](demos/security-monitoring/README.md)

## 🤝 Contributing

Please read our contributing guidelines and submit pull requests for improvements.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
