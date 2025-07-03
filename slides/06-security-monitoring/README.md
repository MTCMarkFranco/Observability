# Security Monitoring and Operations

## Overview

Security monitoring in Azure provides comprehensive threat detection, security posture assessment, and automated response capabilities across your entire cloud environment and hybrid infrastructure.

---

## What is Security Monitoring?

Security monitoring encompasses:
- **Threat Detection** - Identifying malicious activities and potential breaches
- **Security Posture Management** - Continuous assessment of security configurations
- **Compliance Monitoring** - Ensuring adherence to regulatory requirements
- **Incident Response** - Automated and manual response to security events
- **Forensic Analysis** - Post-incident investigation and root cause analysis

---

## Azure Security Monitoring Stack

```
┌─────────────────────────────────────────────────────────────┐
│                    Data Sources                             │
├─────────────────┬─────────────────┬─────────────────────────┤
│  Azure Resources│  On-Premises   │    Third-Party          │
│                 │                │                         │
│ ┌─────────────┐ │ ┌─────────────┐ │ ┌─────────────────────┐ │
│ │ Activity    │ │ │ Sysmon      │ │ │ Office 365         │ │
│ │ Logs        │ │ │ Windows     │ │ │ AWS CloudTrail     │ │
│ │ NSG Flows   │ │ │ Security    │ │ │ Third-party SIEMs  │ │
│ │ Key Vault   │ │ │ Events      │ │ │                     │ │
│ └─────────────┘ │ └─────────────┘ │ └─────────────────────┘ │
└─────────────────┴─────────────────┴─────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                Microsoft Sentinel                          │
│                                                             │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │
│ │   Data      │ │ Analytics   │ │      Hunting           │ │
│ │ Connectors  │ │   Rules     │ │                         │ │
│ │             │ │             │ │ • KQL Queries          │ │
│ │ • Built-in  │ │ • ML-based  │ │ • Threat Intelligence  │ │
│ │ • Custom    │ │ • Scheduled │ │ • Workbooks            │ │
│ │ • API-based │ │ • Fusion    │ │ • Notebooks            │ │
│ └─────────────┘ └─────────────┘ └─────────────────────────┘ │
│                                                             │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │
│ │ Incidents   │ │ Automation  │ │      Investigation     │ │
│ │             │ │             │ │                         │ │
│ │ • Triage    │ │ • Playbooks │ │ • Entity Analysis      │ │
│ │ • Assignment│ │ • Logic Apps│ │ • Timeline View        │ │
│ │ • Workflows │ │ • Functions │ │ • Graph Connections    │ │
│ └─────────────┘ └─────────────┘ └─────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## Microsoft Sentinel

### Core Capabilities
- **SIEM (Security Information and Event Management)** - Centralized security data collection
- **SOAR (Security Orchestration and Automated Response)** - Workflow automation
- **UEBA (User and Entity Behavior Analytics)** - ML-powered anomaly detection
- **Threat Intelligence** - Integration with global threat feeds

### Data Connectors
```json
{
  "connectors": [
    {
      "name": "Azure Activity",
      "type": "built-in",
      "description": "Azure subscription-level activities"
    },
    {
      "name": "Azure Security Center",
      "type": "built-in", 
      "description": "Security alerts and recommendations"
    },
    {
      "name": "Office 365",
      "type": "built-in",
      "description": "Exchange, SharePoint, Teams activities"
    },
    {
      "name": "Windows Security Events",
      "type": "agent-based",
      "description": "Windows event logs via Log Analytics agent"
    },
    {
      "name": "Custom API",
      "type": "custom",
      "description": "Third-party security tools via REST API"
    }
  ]
}
```

---

## Security Analytics Rules

### Scheduled Rules
```kql
// Detect suspicious sign-in patterns
SigninLogs
| where TimeGenerated > ago(1h)
| where ResultType != 0 // Failed sign-ins
| summarize FailedAttempts = count() by UserPrincipalName, IPAddress, bin(TimeGenerated, 5m)
| where FailedAttempts > 10
| join kind=inner (
    SigninLogs
    | where TimeGenerated > ago(1h)
    | where ResultType == 0 // Successful sign-in
    | where TimeGenerated > ago(5m)
) on UserPrincipalName
| project TimeGenerated, UserPrincipalName, FailedAttempts, IPAddress, Location
```

### Machine Learning Rules
```kql
// Anomalous data transfer detection
AzureNetworkAnalytics_CL
| where TimeGenerated > ago(1h)
| where FlowDirection_s == "O" // Outbound
| summarize TotalBytes = sum(TotalBytes_d) by SourceIP = SrcIP_s, bin(TimeGenerated, 10m)
| where TotalBytes > 1000000000 // > 1GB
| sort by TotalBytes desc
```

### Fusion Rules
Advanced multi-stage attack detection combining:
- Multiple weak signals
- Time-based correlation
- Entity behavior analysis
- Threat intelligence matching

---

## Threat Hunting

### Hypothesis-Driven Hunting
```kql
// Hunt for potential data exfiltration
AzureActivity
| where TimeGenerated > ago(7d)
| where OperationNameValue contains "export" or OperationNameValue contains "backup"
| where ActivityStatusValue == "Success"
| extend UserDetails = parse_json(Authorization)
| extend Actor = UserDetails.evidence.principalId
| summarize Operations = count(), UniqueResources = dcount(ResourceId) by Actor, bin(TimeGenerated, 1d)
| where Operations > 10 or UniqueResources > 5
| sort by Operations desc
```

### Advanced Persistent Threat (APT) Detection
```kql
// Detect lateral movement patterns
SecurityEvent
| where TimeGenerated > ago(24h)
| where EventID == 4624 // Successful logon
| where LogonType in (3, 10) // Network or RemoteInteractive
| summarize LogonCount = count(), UniqueComputers = dcount(Computer) by Account, bin(TimeGenerated, 1h)
| where UniqueComputers > 3 and LogonCount > 10
| sort by UniqueComputers desc
```

### Behavioral Analytics
```kql
// Detect unusual user access patterns
AuditLogs
| where TimeGenerated > ago(30d)
| where OperationName == "Add member to group"
| extend UserAdded = tostring(TargetResources[0].userPrincipalName)
| extend GroupName = tostring(TargetResources[1].displayName)
| extend Actor = tostring(InitiatedBy.user.userPrincipalName)
| summarize GroupsModified = dcount(GroupName), UsersAdded = dcount(UserAdded) by Actor, bin(TimeGenerated, 1d)
| where GroupsModified > 5 or UsersAdded > 10
```

---

## Security Workbooks and Dashboards

### Executive Security Dashboard
```json
{
  "workbook": {
    "name": "Security Executive Dashboard",
    "sections": [
      {
        "title": "Security Posture Overview",
        "visualizations": [
          {
            "type": "scorecard",
            "query": "SecurityRecommendation | summarize TotalRecommendations = count(), HighSeverity = countif(RecommendationSeverity == 'High')",
            "title": "Security Recommendations"
          },
          {
            "type": "piechart", 
            "query": "SecurityAlert | summarize count() by AlertSeverity",
            "title": "Alert Distribution by Severity"
          }
        ]
      },
      {
        "title": "Threat Landscape",
        "visualizations": [
          {
            "type": "timechart",
            "query": "SecurityIncident | summarize count() by bin(TimeGenerated, 1d), Severity",
            "title": "Security Incidents Trend"
          }
        ]
      }
    ]
  }
}
```

### SOC Analyst Workbook
```kql
// Active incidents requiring attention
SecurityIncident
| where Status in ("New", "Active")
| where Severity in ("High", "Medium")
| extend DaysOpen = datetime_diff('day', now(), CreatedTime)
| sort by Severity desc, DaysOpen desc
| project Title, Severity, Owner, DaysOpen, LastModifiedTime
| take 20
```

---

## Automated Response and Playbooks

### Logic App Playbook Example
```json
{
  "definition": {
    "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
    "triggers": {
      "When_a_response_to_an_Azure_Sentinel_alert_is_triggered": {
        "type": "ApiConnectionWebhook",
        "inputs": {
          "host": {
            "connection": {
              "name": "@parameters('$connections')['azuresentinel']['connectionId']"
            }
          }
        }
      }
    },
    "actions": {
      "Disable_User_Account": {
        "type": "ApiConnection",
        "inputs": {
          "host": {
            "connection": {
              "name": "@parameters('$connections')['azuread']['connectionId']"
            }
          },
          "method": "patch",
          "path": "/v1.0/users/@{triggerBody()?['Entities']?[0]?['Name']}",
          "body": {
            "accountEnabled": false
          }
        },
        "runAfter": {
          "Get_User_Details": ["Succeeded"]
        }
      },
      "Send_Teams_Notification": {
        "type": "ApiConnection",
        "inputs": {
          "host": {
            "connection": {
              "name": "@parameters('$connections')['teams']['connectionId']"
            }
          },
          "method": "post",
          "path": "/flowbot/actions/notification/recipientsCustom",
          "body": {
            "messageBody": "Security Alert: User @{triggerBody()?['Entities']?[0]?['Name']} has been disabled due to suspicious activity.",
            "messageTitle": "Security Incident Response",
            "recipients": "soc-team@company.com"
          }
        }
      }
    }
  }
}
```

### Azure Function Response
```csharp
[FunctionName("IsolateCompromisedVM")]
public static async Task<IActionResult> Run(
    [HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequest req,
    ILogger log)
{
    var requestBody = await new StreamReader(req.Body).ReadToEndAsync();
    var alertData = JsonSerializer.Deserialize<SentinelAlert>(requestBody);
    
    // Extract VM information from alert
    var vmResourceId = alertData.Entities
        .FirstOrDefault(e => e.Type == "host")?.Name;
    
    if (string.IsNullOrEmpty(vmResourceId))
    {
        return new BadRequestObjectResult("No VM found in alert");
    }
    
    try
    {
        // Create Network Security Group rule to isolate VM
        var nsgRule = new SecurityRule
        {
            Name = $"IsolateVM-{DateTime.UtcNow:yyyyMMddHHmmss}",
            Priority = 100,
            Direction = SecurityRuleDirection.Inbound,
            Access = SecurityRuleAccess.Deny,
            Protocol = "*",
            SourceAddressPrefix = "*",
            SourcePortRange = "*",
            DestinationAddressPrefix = vmResourceId,
            DestinationPortRange = "*"
        };
        
        // Apply the rule (simplified - actual implementation would use Azure SDK)
        log.LogInformation($"VM {vmResourceId} has been isolated");
        
        return new OkObjectResult(new { 
            message = "VM successfully isolated",
            vmId = vmResourceId,
            isolationTime = DateTime.UtcNow
        });
    }
    catch (Exception ex)
    {
        log.LogError($"Failed to isolate VM: {ex.Message}");
        return new StatusCodeResult(500);
    }
}
```

---

## Compliance and Reporting

### Regulatory Compliance Monitoring
```kql
// PCI DSS Compliance - Monitor access to cardholder data
AuditLogs
| where TimeGenerated > ago(30d)
| where TargetResources has "payment" or TargetResources has "card"
| extend Actor = tostring(InitiatedBy.user.userPrincipalName)
| extend Resource = tostring(TargetResources[0].displayName)
| extend Operation = OperationName
| project TimeGenerated, Actor, Resource, Operation, Result
| sort by TimeGenerated desc
```

### GDPR Data Access Tracking
```kql
// Track personal data access
AzureActivity
| where TimeGenerated > ago(7d)
| where ResourceProvider == "Microsoft.Storage"
| where OperationNameValue contains "read"
| extend Actor = Caller
| where ResourceId contains "personaldata" or ResourceId contains "gdpr"
| project TimeGenerated, Actor, ResourceId, OperationNameValue, HTTPRequest
```

### Automated Compliance Reporting
```csharp
public class ComplianceReporter
{
    private readonly LogAnalyticsClient _logAnalyticsClient;
    
    public async Task<ComplianceReport> GenerateSOC2Report(DateTime startDate, DateTime endDate)
    {
        var queries = new Dictionary<string, string>
        {
            ["AccessControls"] = @"
                AuditLogs
                | where TimeGenerated between (datetime({0}) .. datetime({1}))
                | where OperationName contains 'Add' or OperationName contains 'Remove'
                | summarize Changes = count() by OperationName, bin(TimeGenerated, 1d)",
            
            ["EncryptionCompliance"] = @"
                AzureActivity
                | where TimeGenerated between (datetime({0}) .. datetime({1}))
                | where ResourceProvider == 'Microsoft.Storage'
                | where OperationNameValue contains 'encryption'
                | summarize count() by ActivityStatusValue",
            
            ["MonitoringCoverage"] = @"
                Heartbeat
                | where TimeGenerated between (datetime({0}) .. datetime({1}))
                | summarize Agents = dcount(Computer) by bin(TimeGenerated, 1d)"
        };
        
        var report = new ComplianceReport { StartDate = startDate, EndDate = endDate };
        
        foreach (var query in queries)
        {
            var formattedQuery = string.Format(query.Value, startDate, endDate);
            var results = await _logAnalyticsClient.QueryAsync(formattedQuery);
            report.Sections[query.Key] = results;
        }
        
        return report;
    }
}
```

---

## Zero Trust Security Monitoring

### Identity and Access Monitoring
```kql
// Monitor conditional access policy compliance
SigninLogs
| where TimeGenerated > ago(1d)
| where ConditionalAccessStatus != "success"
| extend User = UserPrincipalName
| extend Device = DeviceDetail.displayName
| extend Location = Location.city
| extend Policy = ConditionalAccessPolicies[0].displayName
| project TimeGenerated, User, Device, Location, Policy, ConditionalAccessStatus
| sort by TimeGenerated desc
```

### Device Compliance Monitoring
```kql
// Monitor non-compliant device access
SigninLogs
| where TimeGenerated > ago(7d)
| where DeviceDetail.isCompliant == false
| extend User = UserPrincipalName
| extend DeviceId = DeviceDetail.deviceId
| extend DeviceOS = DeviceDetail.operatingSystem
| summarize AccessCount = count() by User, DeviceId, DeviceOS
| where AccessCount > 5
| sort by AccessCount desc
```

---

## Performance and Cost Optimization

### Data Retention Strategy
```json
{
  "retentionPolicies": {
    "SecurityEvent": "730", // 2 years for security events
    "AuditLogs": "2555",    // 7 years for audit logs (compliance)
    "SigninLogs": "90",     // 90 days for sign-in logs
    "AzureActivity": "365", // 1 year for activity logs
    "Syslog": "30"          // 30 days for syslog
  }
}
```

### Cost Monitoring
```kql
// Monitor Sentinel data ingestion costs
Usage
| where TimeGenerated > ago(30d)
| where IsBillable == true
| extend DataTypeCost = case(
    DataType == "SecurityEvent", Quantity * 0.30,
    DataType == "AuditLogs", Quantity * 0.30,
    DataType == "SigninLogs", Quantity * 0.30,
    Quantity * 0.25 // Default rate
)
| summarize TotalCost = sum(DataTypeCost), TotalGB = sum(Quantity)/1024 by DataType
| sort by TotalCost desc
```

---

## Integration with SIEM/SOAR Tools

### Splunk Integration
```bash
# Configure Splunk Universal Forwarder for Azure logs
[monitor:///var/log/azure-sentinel]
disabled = false
index = azure_security
sourcetype = azure:sentinel:json

[tcpout]
defaultGroup = azure_indexers
```

### QRadar Integration
```python
# Python script to forward Sentinel alerts to QRadar
import requests
import json
from azure.monitor.query import LogsQueryClient

def forward_to_qradar(alert_data):
    qradar_endpoint = "https://qradar.company.com/api/siem/events"
    headers = {
        "SEC": "your-qradar-token",
        "Content-Type": "application/json"
    }
    
    qradar_event = {
        "event_time": alert_data["TimeGenerated"],
        "event_category": "Security Alert",
        "severity": map_severity(alert_data["AlertSeverity"]),
        "source_ip": alert_data.get("SourceIP", "unknown"),
        "description": alert_data["AlertName"]
    }
    
    response = requests.post(qradar_endpoint, 
                           headers=headers, 
                           data=json.dumps(qradar_event))
    
    return response.status_code == 200
```

---

## Best Practices

### Detection Engineering
1. **Layered Detection** - Multiple detection methods for each threat
2. **False Positive Reduction** - Continuous tuning of rules
3. **Context Enrichment** - Adding business context to alerts
4. **Detection Coverage** - MITRE ATT&CK framework mapping

### Incident Response
1. **Clear Escalation Paths** - Define roles and responsibilities
2. **Automated Triage** - Use AI/ML for initial assessment
3. **Evidence Preservation** - Maintain audit trails
4. **Post-Incident Analysis** - Learn from each incident

### SOC Operations
1. **Shift Handover Procedures** - Consistent communication
2. **Metric-Driven Operations** - KPIs for SOC effectiveness
3. **Continuous Training** - Keep analysts updated on threats
4. **Tool Integration** - Seamless workflow across tools

---

## Security Metrics and KPIs

### Detection Metrics
```kql
// Mean Time to Detection (MTTD)
SecurityIncident
| where TimeGenerated > ago(30d)
| extend DetectionTime = datetime_diff('minute', FirstActivityTime, CreatedTime)
| summarize AvgMTTD = avg(DetectionTime) by bin(TimeGenerated, 1d)
| render timechart
```

### Response Metrics
```kql
// Mean Time to Response (MTTR)
SecurityIncident
| where TimeGenerated > ago(30d)
| where Status == "Closed"
| extend ResponseTime = datetime_diff('hour', CreatedTime, ClosedTime)
| summarize AvgMTTR = avg(ResponseTime) by Severity
```

### Coverage Metrics
```kql
// Detection rule effectiveness
SecurityAlert
| where TimeGenerated > ago(7d)
| summarize Alerts = count(), TruePositives = countif(Status != "Dismissed") by AlertName
| extend EffectivenessRate = TruePositives * 100.0 / Alerts
| sort by EffectivenessRate desc
```

---

## Next Steps

1. **Deploy Sentinel** - Set up Microsoft Sentinel workspace
2. **Configure Connectors** - Connect data sources
3. **Create Analytics Rules** - Implement detection logic
4. **Build Playbooks** - Automate response workflows
5. **Train SOC Team** - Develop operational procedures
6. **Optimize Performance** - Tune rules and reduce costs
