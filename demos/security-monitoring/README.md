# Security Monitoring with Azure Sentinel Demo

This demo demonstrates comprehensive security monitoring setup using Azure Sentinel, including data connectors, analytics rules, and incident response workflows.

## Prerequisites

- Azure subscription with Security Admin permissions
- Azure Sentinel workspace (created via infra templates)
- Microsoft Defender for Cloud enabled
- Various Azure resources for monitoring

## Demo Overview

This demonstration covers:
1. Azure Sentinel workspace configuration
2. Data connector setup and configuration
3. Security analytics rules and detection
4. Incident response and investigation
5. Threat hunting and advanced analytics

## Step 1: Sentinel Workspace Setup

### 1.1 Enable Sentinel on Log Analytics Workspace

```bash
# Enable Sentinel
az sentinel workspace create \
  --resource-group myResourceGroup \
  --workspace-name myLogAnalyticsWorkspace
```

### 1.2 Configure Data Retention

```bash
# Set data retention for security logs
az monitor log-analytics workspace update \
  --resource-group myResourceGroup \
  --workspace-name myLogAnalyticsWorkspace \
  --retention-time 90
```

## Step 2: Data Connectors Configuration

### 2.1 Azure Activity Connector

```bash
# Enable Azure Activity connector
az sentinel data-connector create \
  --resource-group myResourceGroup \
  --workspace-name myLogAnalyticsWorkspace \
  --kind "AzureActivity" \
  --subscription-id "{subscription-id}"
```

### 2.2 Office 365 Connector Setup

Navigate to Sentinel > Data connectors > Office 365 and configure:
- Exchange logs
- SharePoint logs  
- Teams logs

### 2.3 Azure AD Connector

```json
{
  "kind": "AzureActiveDirectory",
  "properties": {
    "tenantId": "{tenant-id}",
    "dataTypes": {
      "signInLogs": {
        "state": "Enabled"
      },
      "auditLogs": {
        "state": "Enabled"
      }
    }
  }
}
```

### 2.4 Security Events Connector

```bash
# Configure Windows Security Events
az vm extension set \
  --resource-group myResourceGroup \
  --vm-name myWindowsVM \
  --name MicrosoftMonitoringAgent \
  --publisher Microsoft.EnterpriseCloud.Monitoring \
  --settings '{"workspaceId":"{workspace-id}"}' \
  --protected-settings '{"workspaceKey":"{workspace-key}"}'
```

## Step 3: Analytics Rules

### 3.1 Brute Force Attack Detection

```kql
// Brute force login attempts
SigninLogs
| where TimeGenerated > ago(1h)
| where ResultType != "0"
| summarize FailedAttempts = count() by UserPrincipalName, IPAddress, bin(TimeGenerated, 5m)
| where FailedAttempts >= 5
| project TimeGenerated, UserPrincipalName, IPAddress, FailedAttempts
```

Analytics Rule Configuration:
```json
{
  "displayName": "Multiple Failed Login Attempts",
  "description": "Detects multiple failed login attempts from same IP",
  "severity": "Medium",
  "enabled": true,
  "query": "SigninLogs | where TimeGenerated > ago(1h) | where ResultType != \"0\" | summarize FailedAttempts = count() by UserPrincipalName, IPAddress, bin(TimeGenerated, 5m) | where FailedAttempts >= 5",
  "queryFrequency": "PT5M",
  "queryPeriod": "PT1H",
  "triggerOperator": "GreaterThan",
  "triggerThreshold": 0
}
```

### 3.2 Suspicious Admin Activity

```kql
// Unusual admin operations
AuditLogs
| where TimeGenerated > ago(24h)
| where Category == "RoleManagement"
| where OperationName contains "Add member to role"
| where TargetResources[0].modifiedProperties[0].newValue contains "Admin"
| project TimeGenerated, InitiatedBy, OperationName, TargetResources
```

### 3.3 Data Exfiltration Detection

```kql
// Large data downloads
OfficeActivity
| where TimeGenerated > ago(24h)
| where Operation == "FileDownloaded"
| summarize TotalDownloads = count(), TotalSize = sum(Size) by UserId, ClientIP
| where TotalDownloads > 100 or TotalSize > 1000000
| project UserId, ClientIP, TotalDownloads, TotalSize
```

## Step 4: Custom Detections

### 4.1 Machine Learning Anomaly Detection

```kql
// Anomalous login patterns using ML
let baseline = SigninLogs
| where TimeGenerated between (ago(30d) .. ago(1d))
| summarize BaselineLogins = count() by UserPrincipalName, bin(TimeGenerated, 1h), Location
| summarize AvgLogins = avg(BaselineLogins), StdDev = stdev(BaselineLogins) by UserPrincipalName, Location;

SigninLogs
| where TimeGenerated > ago(1h)
| summarize CurrentLogins = count() by UserPrincipalName, Location
| join baseline on UserPrincipalName, Location
| extend Threshold = AvgLogins + (2 * StdDev)
| where CurrentLogins > Threshold
| project UserPrincipalName, Location, CurrentLogins, Threshold
```

### 4.2 Geolocation Anomaly

```kql
// Impossible travel detection
let timeFrame = 1h;
let velocityThreshold = 1000; // km/h

SigninLogs
| where TimeGenerated > ago(timeFrame)
| where ResultType == "0"
| project TimeGenerated, UserPrincipalName, Location, IPAddress
| sort by UserPrincipalName, TimeGenerated
| serialize
| extend PrevLocation = prev(Location, 1), PrevTime = prev(TimeGenerated, 1)
| where UserPrincipalName == prev(UserPrincipalName, 1)
| extend TimeDiff = datetime_diff('minute', TimeGenerated, PrevTime)
| where TimeDiff > 0 and Location != PrevLocation
| extend Velocity = geo_distance_2points(Location.coordinates[1], Location.coordinates[0], 
                                         PrevLocation.coordinates[1], PrevLocation.coordinates[0]) / TimeDiff * 60
| where Velocity > velocityThreshold
| project TimeGenerated, UserPrincipalName, Location, PrevLocation, Velocity
```

## Step 5: Workbooks and Dashboards

### 5.1 Security Overview Workbook

```json
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "SecurityEvent\n| where TimeGenerated > ago(24h)\n| summarize count() by Activity\n| order by count_ desc\n| take 10",
        "size": 1,
        "title": "Top Security Events (24h)"
      }
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "SigninLogs\n| where TimeGenerated > ago(24h)\n| where ResultType != \"0\"\n| summarize FailedLogins = count() by bin(TimeGenerated, 1h)\n| render timechart",
        "size": 1,
        "title": "Failed Login Attempts Over Time"
      }
    }
  ]
}
```

### 5.2 Threat Intelligence Dashboard

```kql
// Threat intelligence indicators
ThreatIntelligenceIndicator
| where TimeGenerated > ago(7d)
| summarize count() by ThreatType, ConfidenceLevel
| render piechart
```

## Step 6: Incident Response

### 6.1 Automated Response with Logic Apps

```json
{
  "definition": {
    "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
    "triggers": {
      "When_Azure_Sentinel_incident_creation_rule_was_triggered": {
        "type": "ApiConnectionWebhook",
        "inputs": {
          "host": {
            "connection": {
              "name": "@parameters('$connections')['azuresentinel']['connectionId']"
            }
          },
          "body": {
            "callback_url": "@{listCallbackUrl()}"
          },
          "path": "/incident-creation"
        }
      }
    },
    "actions": {
      "Compose_Alert_Details": {
        "type": "Compose",
        "inputs": {
          "IncidentId": "@triggerBody()?['WorkspaceSubscriptionId']",
          "IncidentTitle": "@triggerBody()?['IncidentTitle']",
          "Severity": "@triggerBody()?['Severity']",
          "Status": "@triggerBody()?['Status']"
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
          "body": {
            "message": {
              "subject": "Security Incident: @{triggerBody()?['IncidentTitle']}",
              "body": {
                "content": "A new security incident has been detected: @{outputs('Compose_Alert_Details')}"
              }
            }
          },
          "path": "/teams/channel/message"
        }
      }
    }
  }
}
```

### 6.2 Investigation Queries

```kql
// User activity investigation
let suspiciousUser = "user@domain.com";
let timeRange = 24h;

union
(SigninLogs | where TimeGenerated > ago(timeRange) | where UserPrincipalName == suspiciousUser),
(AuditLogs | where TimeGenerated > ago(timeRange) | where InitiatedBy.user.userPrincipalName == suspiciousUser),
(OfficeActivity | where TimeGenerated > ago(timeRange) | where UserId == suspiciousUser)
| sort by TimeGenerated desc
```

## Step 7: Threat Hunting

### 7.1 Proactive Hunting Queries

```kql
// Hunt for PowerShell execution
SecurityEvent
| where TimeGenerated > ago(7d)
| where EventID == 4688
| where CommandLine contains "powershell"
| where CommandLine contains "-enc" or CommandLine contains "-encoded"
| project TimeGenerated, Computer, Account, CommandLine
```

### 7.2 Network Anomaly Hunting

```kql
// Unusual network connections
CommonSecurityLog
| where TimeGenerated > ago(24h)
| where DeviceVendor == "Palo Alto Networks"
| where DeviceAction == "allow"
| summarize Connections = count() by SourceIP, DestinationPort
| where Connections > 1000
| order by Connections desc
```

### 7.3 File Hash Analysis

```kql
// Suspicious file executions
DeviceFileEvents
| where TimeGenerated > ago(7d)
| where ActionType == "FileCreated"
| where FileName endswith ".exe" or FileName endswith ".dll"
| summarize FileCount = count() by SHA256, FileName
| where FileCount == 1  // Files appearing only once might be suspicious
| project SHA256, FileName, FileCount
```

## Step 8: Advanced Analytics

### 8.1 User and Entity Behavior Analytics (UEBA)

```kql
// Baseline user behavior
let UserBaseline = SigninLogs
| where TimeGenerated between (ago(30d) .. ago(1d))
| where ResultType == "0"
| summarize 
    TypicalHours = make_set(hourofday(TimeGenerated)),
    TypicalLocations = make_set(Location),
    TypicalDevices = make_set(DeviceDetail.deviceId)
    by UserPrincipalName;

// Current activity comparison
SigninLogs
| where TimeGenerated > ago(1d)
| where ResultType == "0"
| join UserBaseline on UserPrincipalName
| extend 
    UnusualHour = not(hourofday(TimeGenerated) in (TypicalHours)),
    UnusualLocation = not(Location in (TypicalLocations)),
    UnusualDevice = not(DeviceDetail.deviceId in (TypicalDevices))
| where UnusualHour or UnusualLocation or UnusualDevice
| project TimeGenerated, UserPrincipalName, Location, DeviceDetail, UnusualHour, UnusualLocation, UnusualDevice
```

### 8.2 Attack Timeline Reconstruction

```kql
// Multi-stage attack correlation
let SuspiciousIP = "192.168.1.100";
let TimeWindow = 2h;

union
(SigninLogs | where ClientIP == SuspiciousIP | project TimeGenerated, EventType = "Login", Details = strcat("User: ", UserPrincipalName)),
(AuditLogs | where InitiatedBy.user.ipAddress == SuspiciousIP | project TimeGenerated, EventType = "AdminAction", Details = OperationName),
(SecurityEvent | where EventID == 4625 and IpAddress == SuspiciousIP | project TimeGenerated, EventType = "FailedLogin", Details = Account)
| sort by TimeGenerated asc
| extend TimeDiff = datetime_diff('minute', TimeGenerated, prev(TimeGenerated))
| where TimeDiff <= 120  // Events within 2 hours
```

## Step 9: Compliance and Reporting

### 9.1 Compliance Dashboard

```kql
// Security compliance metrics
let ComplianceChecks = SecurityEvent
| where TimeGenerated > ago(24h)
| extend ComplianceStatus = case(
    EventID == 4624, "Successful Login",
    EventID == 4625, "Failed Login", 
    EventID == 4648, "Logon with Explicit Credentials",
    "Other"
);

ComplianceChecks
| summarize EventCount = count() by ComplianceStatus
| extend ComplianceScore = case(
    ComplianceStatus == "Failed Login", EventCount * -1,
    ComplianceStatus == "Successful Login", EventCount * 1,
    0
)
| render piechart
```

### 9.2 Automated Reporting

```bash
# Export security incidents for reporting
az sentinel incident list \
  --resource-group myResourceGroup \
  --workspace-name myLogAnalyticsWorkspace \
  --query '[].{Title:title,Severity:severity,Status:status,CreatedTime:createdTimeUtc}' \
  --output table
```

## Best Practices Demonstrated

1. **Defense in Depth**: Multiple layers of security monitoring
2. **Automated Detection**: Machine learning and behavior analytics
3. **Rapid Response**: Automated incident response workflows
4. **Threat Intelligence**: Integration with external threat feeds
5. **Compliance**: Regulatory compliance monitoring and reporting

## Performance Optimization

### Query Optimization
```kql
// Optimized large dataset query
SecurityEvent
| where TimeGenerated > ago(1d)  // Time filter first
| where Computer startswith "DC"  // Most selective filter
| where EventID in (4624, 4625, 4648)  // Use 'in' for multiple values
| summarize count() by EventID, bin(TimeGenerated, 1h)
```

### Data Archiving Strategy
- Implement tiered storage for historical data
- Use summary tables for long-term trend analysis
- Archive detailed logs after compliance period

## Troubleshooting Guide

### Common Issues
- **Missing Data**: Check data connector configuration
- **False Positives**: Tune analytics rules thresholds
- **Performance**: Optimize KQL queries and data retention
- **Integration**: Verify API permissions and connections

## Next Steps

1. Implement custom threat intelligence feeds
2. Develop advanced hunting techniques
3. Create automated response playbooks
4. Integrate with SOAR platforms
5. Establish security metrics and KPIs

## Resources

- [Azure Sentinel Documentation](https://docs.microsoft.com/azure/sentinel/)
- [KQL Quick Reference](https://docs.microsoft.com/azure/data-explorer/kql-quick-reference)
- [Security Operations](https://docs.microsoft.com/azure/security/fundamentals/operational-security)
- [Incident Response](https://docs.microsoft.com/azure/sentinel/tutorial-respond-threats-playbook)
