# Azure Workbooks vs Dynatrace Analytics: Metrics and Reporting Mapping

This document maps common Dynatrace analytics and reports to equivalent Azure Workbooks, using data available in a Log Analytics workspace. For each analytics/report type, you’ll find the recommended Azure Workbook, the Log Analytics data source, and example KQL queries to build the view.

---

## Mapping Table: Dynatrace Analytics to Azure Workbooks

| Dynatrace Report/Analytics           | Azure Workbook Equivalent                | Data Source (Log Analytics Table) | Example KQL/Workbook View                                                                                  |
|--------------------------------------|------------------------------------------|-------------------------------|-----------------------------------------------------------------------------------------------------------|
| **Application Performance (APM)**    | Application Insights Performance Workbook | `requests`, `dependencies`    | `requests | summarize avg(duration), count() by name | render barchart`<br>Visualize response times, failure rates.         |
| **Service Flow/Dependency Map**      | Application Map Workbook                 | `dependencies`, `requests`    | `dependencies | summarize count() by target, type | render sankey`<br>Show service-to-service call flows.                |
| **Error Analysis**                   | Application Insights Failures Workbook   | `exceptions`, `requests`      | `exceptions | summarize count() by type, outerMessage | render piechart`<br>Show top error types and trends.                 |
| **Infrastructure Monitoring**        | VM Insights Performance Workbook         | `Perf`, `Heartbeat`           | `Perf | where ObjectName == 'Processor' | summarize avg(CounterValue) by Computer, bin(TimeGenerated, 5m)`     |
| **Host Health/Resource Utilization** | VM Insights Health Workbook              | `Perf`, `Heartbeat`           | `Perf | where ObjectName == 'Memory' | summarize avg(CounterValue) by Computer, bin(TimeGenerated, 5m)`     |
| **Network Monitoring**               | VM Insights Connections Workbook         | `VMConnection`                | `VMConnection | summarize count() by RemoteIp, Direction | render piechart`                                                    |
| **Log Analytics**                    | Log Search Workbook                      | `AzureDiagnostics`, custom    | `AzureDiagnostics | where Category == 'AppServiceConsoleLogs' | summarize count() by Level`                                         |
| **Alerting/Incidents**               | Alerts Workbook                          | `Alert`                       | `Alert | summarize count() by AlertName, Severity | render columnchart`                                                 |
| **User Experience (RUM)**            | Application Insights Users Workbook      | `pageViews`, `browserTimings` | `pageViews | summarize count() by user_Id, countryOrRegion | render map`                                                         |
| **Synthetic Monitoring**             | Availability Workbook                    | `availabilityResults`         | `availabilityResults | summarize avg(duration), count() by testName, result | render barchart`                                                     |
| **AI/Root Cause Analysis**           | Failure/Anomaly Detection Workbook       | `exceptions`, `requests`      | Use built-in anomaly detection in workbook visualizations, e.g., `series_decompose_anomalies()`            |

---

## Example Workbook Sections and KQL Queries

### Application Performance
- **Response Time Trend:**
  ```kusto
  requests
  | summarize avg(duration) by bin(TimeGenerated, 5m)
  | render timechart
  ```
- **Top Endpoints by Failure Rate:**
  ```kusto
  requests
  | summarize failures = countif(success == 'False'), total = count() by name
  | extend failureRate = failures * 1.0 / total
  | top 10 by failureRate desc
  | render barchart
  ```

### Infrastructure Health
- **CPU Utilization by Host:**
  ```kusto
  Perf
  | where ObjectName == 'Processor' and CounterName == '% Processor Time'
  | summarize avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
  | render timechart
  ```
- **Memory Utilization by Host:**
  ```kusto
  Perf
  | where ObjectName == 'Memory' and CounterName == 'Available MBytes'
  | summarize avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
  | render timechart
  ```

### Error Analysis
- **Top Exception Types:**
  ```kusto
  exceptions
  | summarize count() by type
  | top 10 by count_
  | render piechart
  ```
- **Exception Trend Over Time:**
  ```kusto
  exceptions
  | summarize count() by bin(TimeGenerated, 5m)
  | render timechart
  ```

### User Experience (RUM)
- **Page Load Time by Country:**
  ```kusto
  pageViews
  | summarize avg(duration) by countryOrRegion
  | render map
  ```
- **User Session Count:**
  ```kusto
  pageViews
  | summarize sessions = dcount(session_Id) by bin(TimeGenerated, 1h)
  | render timechart
  ```

---

## How to Build These Workbooks

1. Go to **Azure Monitor > Workbooks** in the Azure portal.
2. Start a new workbook or use a template.
3. Add sections for each analytic/report you want to mimic.
4. Use the KQL queries above as starting points for each visualization.
5. Save and share the workbook with your team.

---

**Tip:** For more templates and advanced visualizations, see the [Azure Workbooks documentation](https://learn.microsoft.com/en-us/azure/azure-monitor/visualize/workbooks-overview) and the [Azure Monitor Workbooks GitHub community](https://github.com/microsoft/Application-Insights-Workbooks).
