# Log Analytics in Azure

## Overview

Log Analytics is the central data platform for observability in Azure, providing powerful query capabilities and centralized log storage for your entire environment.

---

## What is Log Analytics?

Log Analytics is a service in Azure Monitor that:
- **Collects** log and performance data from multiple sources
- **Stores** data in highly scalable workspaces
- **Analyzes** data using Kusto Query Language (KQL)
- **Visualizes** insights through workbooks and dashboards

---

## Key Components

### Log Analytics Workspace
- Central repository for log data
- Configurable retention policies
- RBAC for data access control
- Multiple subscription support

### Data Sources
- **Azure Resources** - Activity logs, diagnostic settings
- **Virtual Machines** - Azure Monitor Agent, Log Analytics Agent
- **Applications** - Application Insights, custom logs
- **Security** - Azure Security Center, Azure Sentinel
- **Network** - NSG flow logs, VPN diagnostics

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Data Sources                             │
├─────────────────┬─────────────────┬─────────────────────────┤
│   Azure VMs     │  Web Apps      │    Azure Resources      │
│                 │                │                         │
│ ┌─────────────┐ │ ┌─────────────┐ │ ┌─────────────────────┐ │
│ │Azure Monitor│ │ │App Insights │ │ │ Diagnostic Settings │ │
│ │   Agent     │ │ │             │ │ │                     │ │
│ └─────────────┘ │ └─────────────┘ │ └─────────────────────┘ │
└─────────────────┴─────────────────┴─────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Log Analytics Workspace                       │
│                                                             │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │
│ │   Tables    │ │    KQL      │ │      Workbooks         │ │
│ │             │ │   Engine    │ │                         │ │
│ │ • AzureActivity│ │           │ │ • Custom dashboards     │ │
│ │ • Heartbeat │ │ • Queries   │ │ • Performance reports   │ │
│ │ • Perf      │ │ • Alerts    │ │ • Security insights     │ │
│ │ • Syslog    │ │ • Functions │ │                         │ │
│ └─────────────┘ └─────────────┘ └─────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## Common Tables and Use Cases

### System Performance
```kql
// CPU utilization over time
Perf
| where CounterName == "% Processor Time"
| where InstanceName == "_Total"
| summarize avg(CounterValue) by bin(TimeGenerated, 5m), Computer
| render timechart
```

### Security Events
```kql
// Failed login attempts
SecurityEvent
| where EventID == 4625
| summarize count() by Account, Computer, bin(TimeGenerated, 1h)
| order by count_ desc
```

### Application Logs
```kql
// Application errors by severity
AppServiceConsoleLogs
| where ResultDescription contains "ERROR"
| summarize count() by bin(TimeGenerated, 1h)
| render timechart
```

---

## Data Collection Rules (DCRs)

### Benefits of DCRs
- **Flexible Data Collection** - Define exactly what data to collect
- **Cost Optimization** - Reduce ingestion costs by filtering data
- **Multiple Destinations** - Send data to different workspaces
- **Transformation** - Clean and enrich data during ingestion

### DCR Structure
```json
{
  "name": "myDataCollectionRule",
  "location": "East US",
  "properties": {
    "dataSources": {
      "performanceCounters": [
        {
          "name": "cpuCounter",
          "counterSpecifiers": ["\\Processor(_Total)\\% Processor Time"],
          "samplingFrequencyInSeconds": 60
        }
      ]
    },
    "destinations": {
      "logAnalytics": [
        {
          "workspaceResourceId": "/subscriptions/.../workspaces/myworkspace",
          "name": "myWorkspace"
        }
      ]
    }
  }
}
```

---

## Query Optimization Best Practices

### Performance Tips
1. **Filter Early** - Use `where` clauses as early as possible
2. **Limit Results** - Use `take` or `top` for large datasets
3. **Summarize Efficiently** - Use appropriate time bins
4. **Index Usage** - Leverage indexed columns (TimeGenerated, Type)

### Example: Optimized Query
```kql
// ❌ Inefficient
SecurityEvent
| summarize count() by EventID
| where EventID == 4625

// ✅ Efficient  
SecurityEvent
| where EventID == 4625
| summarize count() by bin(TimeGenerated, 1h)
```

---

## Cost Management

### Data Retention Strategies
- **Hot Tier** - 0-8 days (high performance)
- **Cold Tier** - 8+ days (lower cost)
- **Archive Tier** - Long-term storage (lowest cost)

### Cost Optimization Techniques
1. **Data Collection Rules** - Filter unnecessary data
2. **Custom Retention** - Set different retention per table
3. **Data Export** - Move old data to cheaper storage
4. **Capacity Reservations** - Predictable pricing for large volumes

---

## Security and Compliance

### Access Control
- **Workspace-level** - Read/write access to entire workspace
- **Table-level** - Granular permissions per data type
- **Row-level** - Filter data based on user context

### Compliance Features
- **Data Residency** - Control where data is stored
- **Encryption** - Data encrypted at rest and in transit
- **Audit Logs** - Track all workspace access and queries
- **Data Export** - Support for compliance reporting

---

## Integration with Other Services

### Azure Monitor
- Metrics and logs correlation
- Unified alerting platform
- Workbook integration

### Azure Sentinel
- Security information and event management
- Advanced threat detection
- Automated response capabilities

### Power BI
- Custom dashboards and reports
- Executive-level reporting
- Self-service analytics

---

## Best Practices

### Workspace Design
- **One workspace per environment** - Development, staging, production
- **Centralized logging** - Single workspace for multiple applications
- **Appropriate retention** - Balance cost and compliance needs

### Query Development
- **Use functions** - Reusable query logic
- **Parameterize queries** - Dynamic filtering and grouping
- **Test performance** - Monitor query execution times

### Data Management
- **Regular cleanup** - Remove unnecessary custom logs
- **Monitor costs** - Set up billing alerts
- **Document queries** - Maintain query library

---

## Common Troubleshooting Scenarios

### Missing Data
```kql
// Check agent connectivity
Heartbeat
| where Computer == "myserver"
| summarize max(TimeGenerated) by Computer
```

### Performance Issues
```kql
// Query performance analysis
Usage
| where DataType == "Query"
| summarize avg(Quantity) by bin(TimeGenerated, 1h)
| render timechart
```

### Cost Analysis
```kql
// Data ingestion by table
Usage
| where IsBillable == true
| summarize TotalGB = sum(Quantity) / 1024 by DataType
| order by TotalGB desc
```

---

## Next Steps

1. **Deploy Workspace** - Create Log Analytics workspace
2. **Configure Data Sources** - Set up agents and diagnostic settings
3. **Learn KQL** - Master query language fundamentals
4. **Create Dashboards** - Build monitoring workbooks
5. **Set Up Alerts** - Implement proactive monitoring
6. **Optimize Costs** - Implement data retention strategies
