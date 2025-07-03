# Observability Troubleshooting Guide

This guide provides comprehensive troubleshooting procedures for common observability issues in Azure environments.

## General Troubleshooting Methodology

### 1. Systematic Approach
1. **Identify the Problem**: What is not working as expected?
2. **Gather Information**: Collect logs, metrics, and configuration details
3. **Analyze Root Cause**: Use data to identify the underlying issue
4. **Implement Solution**: Apply appropriate fix or workaround
5. **Verify Resolution**: Confirm the issue is resolved
6. **Document Lessons**: Update documentation and procedures

### 2. Common Problem Categories
- Data ingestion issues
- Query performance problems
- Alert configuration errors
- Dashboard visualization problems
- Integration and connectivity issues
- Performance and scaling challenges

## Data Ingestion Issues

### Problem: Missing or Delayed Data

#### Symptoms
- No data appearing in Log Analytics
- Gaps in metric collection
- Delayed telemetry in Application Insights

#### Diagnostic Steps

1. **Check Agent Status**
```bash
# Check Azure Monitor Agent status
az vm extension show \
  --resource-group myResourceGroup \
  --vm-name myVM \
  --name AzureMonitorWindowsAgent
```

2. **Verify Data Collection Rules**
```kql
// Check data collection rule associations
DCRAssociationStatus
| where TimeGenerated > ago(1h)
| summarize count() by ResourceId, DataCollectionRuleName, Status
```

3. **Review Diagnostic Settings**
```bash
# List diagnostic settings
az monitor diagnostic-settings list \
  --resource "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Compute/virtualMachines/{vm-name}"
```

#### Common Causes and Solutions

| Cause | Solution |
|-------|----------|
| Agent not installed | Install Azure Monitor Agent |
| Incorrect permissions | Assign Log Analytics Contributor role |
| Network connectivity | Check firewall and NSG rules |
| Data collection rule missing | Create and associate DCR |
| Workspace key incorrect | Update agent configuration |

#### Resolution Steps

1. **Install/Update Agent**
```bash
# Install Azure Monitor Agent
az vm extension set \
  --resource-group myResourceGroup \
  --vm-name myVM \
  --name AzureMonitorWindowsAgent \
  --publisher Microsoft.Azure.Monitor
```

2. **Configure Data Collection**
```json
{
  "dataSources": {
    "performanceCounters": [{
      "name": "perfCounterDataSource",
      "streams": ["Microsoft-Perf"],
      "samplingFrequencyInSeconds": 60,
      "counterSpecifiers": [
        "\\Processor(_Total)\\% Processor Time",
        "\\Memory\\Available MBytes"
      ]
    }]
  }
}
```

### Problem: High Data Ingestion Costs

#### Symptoms
- Unexpected billing charges
- High daily ingestion volume
- Rapid workspace growth

#### Diagnostic Steps

1. **Analyze Ingestion by Table**
```kql
Usage
| where TimeGenerated > ago(30d)
| where IsBillable == true
| summarize TotalVolumeGB = sum(Quantity) / 1000 by DataType
| order by TotalVolumeGB desc
```

2. **Identify Top Data Sources**
```kql
Heartbeat
| where TimeGenerated > ago(24h)
| summarize count() by Computer, SourceComputerId
| order by count_ desc
```

#### Solutions

1. **Implement Sampling**
```csharp
// Application Insights sampling
services.Configure<TelemetryConfiguration>(config =>
{
    config.DefaultTelemetrySink.TelemetryProcessorChainBuilder
        .UseAdaptiveSampling(maxTelemetryItemsPerSecond: 5)
        .Build();
});
```

2. **Configure Data Retention**
```bash
# Set retention policy
az monitor log-analytics workspace update \
  --resource-group myResourceGroup \
  --workspace-name myWorkspace \
  --retention-time 30
```

## Query Performance Issues

### Problem: Slow or Timing Out Queries

#### Symptoms
- Queries taking longer than expected
- Timeout errors in workbooks
- Dashboard loading slowly

#### Diagnostic Steps

1. **Check Query Performance**
```kql
// Analyze query performance
let query = @"
    Heartbeat
    | where TimeGenerated > ago(7d)
    | summarize count() by Computer
";
print QueryText = query, StartTime = now();
// Execute your query here
print EndTime = now()
```

2. **Review Resource Usage**
```kql
// Check workspace resource utilization
_LogOperation
| where TimeGenerated > ago(24h)
| where Level == "Warning"
| project TimeGenerated, Detail
```

#### Optimization Strategies

1. **Time Range Optimization**
```kql
// Good: Specify time range early
Heartbeat
| where TimeGenerated > ago(24h)  // Filter first
| where Computer startswith "WEB"
| summarize count() by Computer

// Bad: No time filter
Heartbeat
| where Computer startswith "WEB"
| summarize count() by Computer
```

2. **Column Selection**
```kql
// Good: Select only needed columns
Heartbeat
| where TimeGenerated > ago(24h)
| project TimeGenerated, Computer, HeartbeatInterval
| summarize avg(HeartbeatInterval) by Computer

// Bad: Select all columns
Heartbeat
| where TimeGenerated > ago(24h)
| summarize avg(HeartbeatInterval) by Computer
```

3. **Effective Filtering**
```kql
// Good: Use specific filters
SecurityEvent
| where TimeGenerated > ago(24h)
| where EventID == 4624  // Specific event ID
| where Computer == "DC01"  // Specific computer
| summarize count()

// Bad: Generic filters
SecurityEvent
| where TimeGenerated > ago(24h)
| where EventID > 4000  // Range filter
| summarize count()
```

### Problem: Memory or CPU Limits Exceeded

#### Symptoms
- "Query exceeded memory limit" errors
- "Query exceeded CPU limit" errors
- Partial results returned

#### Solutions

1. **Implement Summarization**
```kql
// Summarize large datasets
Perf
| where TimeGenerated > ago(30d)
| where CounterName == "% Processor Time"
| summarize avg(CounterValue) by Computer, bin(TimeGenerated, 1h)
| order by TimeGenerated desc
```

2. **Use Sampling**
```kql
// Sample large datasets
SecurityEvent
| where TimeGenerated > ago(7d)
| sample 10000  // Sample 10,000 records
| summarize count() by EventID
```

## Alert Configuration Issues

### Problem: Alerts Not Firing

#### Symptoms
- Expected alerts not triggering
- Missing notifications
- Incorrect alert frequency

#### Diagnostic Steps

1. **Check Alert Rule Configuration**
```bash
# List alert rules
az monitor metrics alert list \
  --resource-group myResourceGroup \
  --output table
```

2. **Verify Alert History**
```bash
# Check alert history
az monitor activity-log list \
  --resource-group myResourceGroup \
  --caller "Microsoft.Insights/alertRules" \
  --start-time 2023-01-01T00:00:00Z
```

3. **Test Alert Conditions**
```kql
// Test alert query
exceptions
| where timestamp > ago(15m)
| summarize count()
| where count_ > 5  // Alert threshold
```

#### Common Issues and Solutions

| Issue | Solution |
|-------|----------|
| Incorrect query syntax | Validate KQL query |
| Wrong aggregation method | Review aggregation settings |
| Insufficient permissions | Assign Monitoring Contributor role |
| Action group misconfigured | Verify action group settings |
| Threshold too high/low | Adjust alert thresholds |

### Problem: Too Many False Positives

#### Symptoms
- Excessive alert notifications
- Alerts for expected behavior
- Alert fatigue among team members

#### Solutions

1. **Implement Dynamic Thresholds**
```bash
# Create dynamic threshold alert
az monitor metrics alert create \
  --name "Dynamic CPU Alert" \
  --resource-group myResourceGroup \
  --condition "avg Percentage CPU > dynamic medium 2 of 4" \
  --evaluation-frequency 5m \
  --window-size 15m
```

2. **Use Composite Alerts**
```json
{
  "allOf": [
    {
      "metricName": "Percentage CPU",
      "operator": "GreaterThan",
      "threshold": 80,
      "timeAggregation": "Average"
    },
    {
      "metricName": "Available Memory MBytes",
      "operator": "LessThan",
      "threshold": 500,
      "timeAggregation": "Average"
    }
  ]
}
```

## Dashboard and Visualization Issues

### Problem: Dashboard Loading Slowly

#### Symptoms
- Long dashboard load times
- Timeouts in workbooks
- Blank visualization tiles

#### Diagnostic Steps

1. **Check Query Performance**
```kql
// Identify slow queries
_LogOperation
| where TimeGenerated > ago(24h)
| where Category == "Query"
| where Level == "Warning"
| project TimeGenerated, Detail
```

2. **Review Dashboard Complexity**
- Count of visualizations
- Query complexity
- Time ranges used

#### Solutions

1. **Optimize Dashboard Queries**
```kql
// Use materialized views for complex queries
.create materialized-view DashboardMetrics on table Heartbeat
{
    Heartbeat
    | where TimeGenerated > ago(1d)
    | summarize count() by Computer, bin(TimeGenerated, 1h)
}
```

2. **Implement Caching**
```json
{
  "cacheSettings": {
    "enabled": true,
    "maxAge": "PT30M"
  }
}
```

### Problem: Incorrect Data Visualization

#### Symptoms
- Charts showing wrong data
- Missing data points
- Incorrect aggregations

#### Solutions

1. **Verify Data Types**
```kql
// Check data types
Heartbeat
| getschema
| project ColumnName, DataType
```

2. **Validate Aggregations**
```kql
// Test aggregation logic
Perf
| where TimeGenerated > ago(24h)
| where CounterName == "% Processor Time"
| summarize 
    AvgCPU = avg(CounterValue),
    MaxCPU = max(CounterValue),
    MinCPU = min(CounterValue)
    by Computer
```

## Integration and Connectivity Issues

### Problem: Application Insights Not Receiving Data

#### Symptoms
- No telemetry in Application Insights
- Missing dependency tracking
- Incomplete distributed traces

#### Diagnostic Steps

1. **Verify Connection String**
```csharp
// Check connection string configuration
var connectionString = configuration.GetConnectionString("ApplicationInsights");
Console.WriteLine($"Connection String: {connectionString}");
```

2. **Test Connectivity**
```csharp
// Test Application Insights connectivity
using var telemetryClient = new TelemetryClient();
telemetryClient.TrackTrace("Test message");
telemetryClient.Flush();
```

#### Solutions

1. **Configure SDK Properly**
```csharp
// .NET Core configuration
services.AddApplicationInsightsTelemetry(options =>
{
    options.ConnectionString = connectionString;
    options.EnableActiveTelemetryConfigurationSetup = true;
});
```

2. **Check Firewall Rules**
```bash
# Allow Application Insights endpoints
# dc.services.visualstudio.com
# rt.services.visualstudio.com
# live.applicationinsights.azure.com
```

### Problem: Data Source Connection Failures

#### Symptoms
- Intermittent data collection
- Connection timeout errors
- Authentication failures

#### Solutions

1. **Implement Retry Logic**
```csharp
// Implement retry with exponential backoff
var retryPolicy = Policy
    .Handle<HttpRequestException>()
    .WaitAndRetryAsync(
        retryCount: 3,
        sleepDurationProvider: retryAttempt => TimeSpan.FromSeconds(Math.Pow(2, retryAttempt)));
```

2. **Use Managed Identity**
```bash
# Configure managed identity for data sources
az vm identity assign \
  --resource-group myResourceGroup \
  --name myVM
```

## Performance and Scaling Issues

### Problem: Workspace Ingestion Limits

#### Symptoms
- "Daily quota exceeded" errors
- Throttling messages
- Data ingestion delays

#### Solutions

1. **Monitor Ingestion Limits**
```kql
// Check ingestion against limits
Usage
| where TimeGenerated > ago(1d)
| where IsBillable == true
| summarize TotalGB = sum(Quantity) / 1000
| extend DailyLimit = 50.0  // Your daily limit
| extend PercentUsed = (TotalGB / DailyLimit) * 100
```

2. **Implement Ingestion Controls**
```bash
# Set daily quota
az monitor log-analytics workspace update \
  --resource-group myResourceGroup \
  --workspace-name myWorkspace \
  --daily-quota-gb 50
```

### Problem: High Query Concurrency

#### Symptoms
- Query timeouts
- Slow dashboard performance
- Resource contention

#### Solutions

1. **Implement Query Throttling**
```kql
// Use query result caching
set query_results_cache_max_age = time(1h);
Heartbeat
| where TimeGenerated > ago(24h)
| summarize count() by Computer
```

2. **Optimize Query Scheduling**
```json
{
  "schedule": {
    "staggered": true,
    "maxConcurrent": 5,
    "interval": "PT5M"
  }
}
```

## Security and Compliance Issues

### Problem: Unauthorized Access to Monitoring Data

#### Symptoms
- Unexpected data access
- Compliance violations
- Audit findings

#### Solutions

1. **Implement RBAC**
```bash
# Assign monitoring reader role
az role assignment create \
  --assignee user@domain.com \
  --role "Monitoring Reader" \
  --scope "/subscriptions/{subscription-id}/resourceGroups/{rg-name}"
```

2. **Enable Audit Logging**
```bash
# Enable diagnostic settings for audit
az monitor diagnostic-settings create \
  --name audit-logs \
  --resource /subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.OperationalInsights/workspaces/{workspace-name} \
  --logs '[{"category":"Audit","enabled":true}]'
```

### Problem: Data Retention Compliance

#### Symptoms
- Compliance violations
- Data kept beyond policy
- Audit failures

#### Solutions

1. **Configure Retention Policies**
```bash
# Set table-specific retention
az monitor log-analytics workspace table update \
  --resource-group myResourceGroup \
  --workspace-name myWorkspace \
  --name SecurityEvent \
  --retention-time 730  # 2 years
```

2. **Implement Data Purge**
```kql
// Purge sensitive data
.purge table SecurityEvent records
| where TimeGenerated < ago(7d)
| where Account contains "test-"
```

## Emergency Procedures

### Complete Monitoring Outage

1. **Assess Impact**
   - Identify affected systems
   - Check backup monitoring
   - Notify stakeholders

2. **Implement Workarounds**
   - Use backup dashboards
   - Manual monitoring procedures
   - Alternative alert channels

3. **Restore Services**
   - Redeploy monitoring agents
   - Restore workspace configuration
   - Validate data flow

### Data Loss Recovery

1. **Assess Data Loss**
   - Identify time ranges affected
   - Check backup availability
   - Estimate recovery time

2. **Recover Data**
   - Restore from backups
   - Replay telemetry data
   - Validate data integrity

## Preventive Measures

### 1. Monitoring Health Checks

```kql
// Monitor monitoring system health
Heartbeat
| where TimeGenerated > ago(30m)
| summarize LastHeartbeat = max(TimeGenerated) by Computer
| where LastHeartbeat < ago(10m)
| project Computer, LastHeartbeat, Status = "Missing"
```

### 2. Automated Testing

```bash
# Test alert functionality
az monitor metrics alert test \
  --resource-group myResourceGroup \
  --rule-name "High CPU Alert"
```

### 3. Regular Maintenance

- Weekly dashboard review
- Monthly alert rule optimization
- Quarterly capacity planning
- Annual architecture review

## Tools and Resources

### Diagnostic Tools
- Azure Monitor Agent Health Tool
- Application Insights Profiler
- Log Analytics Query Performance Analyzer
- Azure Resource Graph Explorer

### Monitoring Tools
- Azure Service Health
- Azure Status Dashboard
- Resource Health Center
- Azure Advisor

### Documentation
- Azure Monitor Documentation
- KQL Reference Guide
- Troubleshooting Runbooks
- Best Practices Guides

## Getting Help

### Microsoft Support
- Azure Support Portal
- Community Forums
- Stack Overflow (azure-monitor tag)
- GitHub Issues for open-source tools

### Internal Resources
- Monitoring team contacts
- Escalation procedures
- Knowledge base articles
- Training materials

## Conclusion

Effective troubleshooting requires a systematic approach, good diagnostic tools, and comprehensive documentation. Regular testing and maintenance help prevent issues before they impact operations. When problems do occur, having well-documented procedures and escalation paths ensures quick resolution and minimal business impact.
