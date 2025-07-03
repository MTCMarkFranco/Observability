# Azure Monitor

## Overview

Azure Monitor is the comprehensive monitoring solution that provides a complete view of your applications, infrastructure, and network across Azure and hybrid environments.

---

## What is Azure Monitor?

Azure Monitor is a unified monitoring platform that:
- **Collects** telemetry from all layers of your architecture
- **Analyzes** data to identify trends and anomalies
- **Responds** to critical conditions with automated actions
- **Visualizes** insights through rich dashboards and workbooks

---

## Azure Monitor Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Data Sources                             │
├─────────────────┬─────────────────┬─────────────────────────┤
│  Applications   │ Infrastructure  │    Platform Services    │
│                 │                │                         │
│ ┌─────────────┐ │ ┌─────────────┐ │ ┌─────────────────────┐ │
│ │Custom Metrics│ │ │Host Metrics │ │ │ Activity Logs      │ │
│ │Custom Logs  │ │ │Guest Metrics│ │ │ Resource Logs       │ │
│ │Traces       │ │ │Network Logs │ │ │ Platform Metrics    │ │
│ └─────────────┘ │ └─────────────┘ │ └─────────────────────┘ │
└─────────────────┴─────────────────┴─────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  Azure Monitor                             │
│                                                             │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │
│ │   Metrics   │ │    Logs     │ │      Insights          │ │
│ │             │ │             │ │                         │ │
│ │ • Time-series│ │• Log Analytics│ │ • Application Insights │ │
│ │ • Real-time │ │• KQL Queries │ │ • VM Insights          │ │
│ │ • Alerting  │ │• Workbooks   │ │ • Container Insights    │ │
│ └─────────────┘ └─────────────┘ └─────────────────────────┘ │
│                                                             │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │
│ │   Alerts    │ │ Dashboards  │ │     Integrations       │ │
│ │             │ │             │ │                         │ │
│ │ • Smart     │ │• Custom     │ │ • Power BI             │ │
│ │ • Metric    │ │• Templates  │ │ • Event Hubs           │ │
│ │ • Log       │ │• Sharing    │ │ • Logic Apps           │ │
│ └─────────────┘ └─────────────┘ └─────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## Key Components

### 1. Metrics
**Real-time numerical data** collected at regular intervals

- **Platform Metrics** - Automatically collected from Azure resources
- **Custom Metrics** - Application-specific measurements
- **Guest Metrics** - OS-level performance counters

```kql
// Example: CPU utilization alert
AzureMetrics
| where ResourceProvider == "MICROSOFT.COMPUTE"
| where MetricName == "Percentage CPU"
| where Average > 80
| summarize max(Average) by Resource, bin(TimeGenerated, 5m)
```

### 2. Logs
**Detailed event and diagnostic information**

- **Activity Logs** - Subscription-level events
- **Resource Logs** - Service-specific operational data
- **Custom Logs** - Application and system logs

### 3. Alerts
**Proactive notifications** based on conditions

- **Metric Alerts** - Threshold-based notifications
- **Log Alerts** - Query-based complex conditions
- **Smart Detection** - AI-powered anomaly detection

---

## Alert Types and Use Cases

### Metric Alerts
Best for: Real-time monitoring of numeric values

```json
{
  "alertName": "High CPU Usage",
  "condition": {
    "metricName": "Percentage CPU",
    "operator": "GreaterThan",
    "threshold": 80,
    "timeAggregation": "Average"
  },
  "evaluationFrequency": "PT1M",
  "windowSize": "PT5M"
}
```

### Log Alerts
Best for: Complex scenarios requiring data analysis

```kql
// Alert on application errors
AppServiceHTTPLogs
| where ScStatus >= 500
| summarize ErrorCount = count() by bin(TimeGenerated, 5m)
| where ErrorCount > 10
```

### Activity Log Alerts
Best for: Monitoring administrative actions

```json
{
  "alertName": "Resource Group Deletion",
  "condition": {
    "field": "operationName",
    "equals": "Microsoft.Resources/subscriptions/resourcegroups/delete"
  }
}
```

---

## Workbooks and Dashboards

### Azure Workbooks
**Interactive reports** with rich visualizations

Features:
- Parameterized queries
- Conditional formatting
- Time range controls
- Multiple data sources

```json
{
  "workbook": {
    "name": "Infrastructure Overview",
    "sections": [
      {
        "type": "metrics",
        "title": "CPU and Memory",
        "query": "Perf | where CounterName in ('% Processor Time', '% Used Memory')"
      },
      {
        "type": "logs",
        "title": "Error Analysis",
        "query": "Event | where EventLevelName == 'Error'"
      }
    ]
  }
}
```

### Azure Dashboards
**Shared visualizations** for teams

- Pin charts from multiple services
- Role-based access control
- Mobile-friendly views
- Real-time updates

---

## Action Groups and Automated Responses

### Action Types
- **Email/SMS/Voice** - Human notifications
- **Webhook** - HTTP callbacks
- **Logic Apps** - Complex workflows
- **Azure Functions** - Custom code execution
- **Runbooks** - PowerShell automation

### Example: Auto-scaling Response
```json
{
  "actionGroup": {
    "name": "ScaleOutGroup",
    "actions": [
      {
        "type": "webhook",
        "name": "ScaleWebhook",
        "webhookUri": "https://api.example.com/scale",
        "payload": {
          "resourceId": "[resourceId]",
          "action": "scaleOut",
          "instanceCount": 2
        }
      }
    ]
  }
}
```

---

## Monitor Insights

### Application Insights
- End-to-end application monitoring
- Dependency tracking
- Performance profiling
- Availability testing

### VM Insights
- Performance monitoring for virtual machines
- Process and dependency mapping
- Health diagnostics
- Capacity planning

### Container Insights
- Kubernetes cluster monitoring
- Pod and node performance
- Container logs aggregation
- Resource utilization tracking

---

## Advanced Features

### Smart Detection
AI-powered anomaly detection that automatically:
- Identifies unusual patterns
- Reduces alert noise
- Adapts to application behavior
- Provides contextual insights

### Application Performance Management (APM)
- **Dependency Maps** - Visualize service relationships
- **Live Metrics** - Real-time application health
- **Profiler** - Identify performance bottlenecks
- **Snapshot Debugger** - Debug production issues

---

## Query and Analysis

### KQL (Kusto Query Language)
Powerful query language for log analysis:

```kql
// Performance analysis across multiple VMs
Perf
| where TimeGenerated > ago(1h)
| where CounterName == "% Processor Time"
| summarize AvgCPU = avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
| render timechart
```

### Cross-resource Queries
Analyze data across multiple resources:

```kql
// Correlate VM performance with application errors
union
    (Perf | where CounterName == "% Processor Time"),
    (AppTraces | where SeverityLevel >= 3)
| summarize Events = count() by bin(TimeGenerated, 10m), Type
```

---

## Cost Optimization

### Data Retention Management
- **Default retention** - 90 days for logs
- **Custom retention** - Per table configuration
- **Data export** - Long-term archival to storage

### Sampling and Filtering
```kql
// Reduce data ingestion with sampling
Traces
| where rand() < 0.1  // 10% sampling
| where SeverityLevel >= 2  // Warnings and above only
```

### Capacity Reservations
- Predictable pricing for large data volumes
- Significant discounts for committed usage
- Available for Log Analytics workspaces

---

## Integration Patterns

### Event-Driven Architecture
```
Alert → Event Hub → Logic App → ServiceNow
                 → Azure Function → Database
                 → Event Grid → Teams Notification
```

### Hybrid Monitoring
- **Azure Arc** - Monitor on-premises resources
- **Azure Monitor Agent** - Unified data collection
- **Private Link** - Secure connectivity

### Third-Party Integrations
- **Grafana** - Open-source dashboards
- **Prometheus** - Metrics collection and alerting
- **Splunk** - Enterprise log analysis

---

## Security and Compliance

### RBAC (Role-Based Access Control)
- **Monitoring Reader** - View metrics and alerts
- **Monitoring Contributor** - Modify monitoring settings
- **Log Analytics Reader** - Query log data
- **Custom Roles** - Granular permissions

### Data Privacy
- **Data location** - Region-specific storage
- **Encryption** - At rest and in transit
- **Data export** - Compliance and archival
- **GDPR compliance** - Data subject rights

---

## Best Practices

### Alert Strategy
1. **Alert Fatigue Prevention**
   - Set appropriate thresholds
   - Use action groups effectively
   - Implement alert suppression

2. **Alert Hierarchy**
   - Critical: Immediate response required
   - Warning: Investigation needed
   - Information: Awareness only

### Monitoring Design
1. **Comprehensive Coverage**
   - Infrastructure metrics
   - Application performance
   - Business metrics
   - Security events

2. **Baseline Establishment**
   - Normal performance patterns
   - Seasonal variations
   - Growth trends

### Dashboard Strategy
1. **Role-Based Views**
   - Executive dashboards
   - Operations dashboards
   - Developer dashboards

2. **Information Hierarchy**
   - High-level KPIs
   - Drill-down capabilities
   - Contextual information

---

## Troubleshooting Common Issues

### Missing Metrics
```kql
// Check diagnostic settings
AzureActivity
| where OperationNameValue contains "diagnostic"
| where ActivityStatusValue == "Success"
| project TimeGenerated, ResourceId, OperationNameValue
```

### Alert Not Firing
```kql
// Verify alert rule logic
AzureMetrics
| where ResourceId == "/subscriptions/.../myresource"
| where MetricName == "Percentage CPU"
| where TimeGenerated > ago(1h)
| project TimeGenerated, Average, Maximum
```

### Performance Issues
```kql
// Monitor query performance
Usage
| where DataType == "Query"
| summarize AvgDuration = avg(Duration) by bin(TimeGenerated, 1h)
| render timechart
```

---

## Next Steps

1. **Deploy Foundation** - Set up monitoring workspace
2. **Configure Data Sources** - Enable diagnostic settings
3. **Create Dashboards** - Build operational views
4. **Set Up Alerts** - Implement proactive monitoring
5. **Optimize Performance** - Fine-tune queries and retention
6. **Integrate Applications** - Add custom telemetry
