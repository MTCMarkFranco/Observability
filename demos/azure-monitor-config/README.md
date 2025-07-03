# Azure Monitor Configuration Demo

This demo walks through configuring Azure Monitor for comprehensive resource monitoring, including metrics, alerts, and dashboards.

## Prerequisites

- Azure subscription with appropriate permissions
- Resources deployed and ready for monitoring
- Azure CLI or PowerShell installed

## Demo Overview

This demonstration covers:
1. Setting up Azure Monitor for various resource types
2. Configuring custom metrics and alerts
3. Creating monitoring dashboards
4. Setting up action groups and notifications

## Step 1: Resource Monitoring Setup

### 1.1 Enable Diagnostic Settings

```bash
# Enable diagnostic settings for a storage account
az monitor diagnostic-settings create \
  --resource "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Storage/storageAccounts/{storage-name}" \
  --name "storage-diagnostics" \
  --workspace "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.OperationalInsights/workspaces/{workspace-name}" \
  --logs '[{"category":"StorageRead","enabled":true,"retentionPolicy":{"enabled":false,"days":0}},{"category":"StorageWrite","enabled":true,"retentionPolicy":{"enabled":false,"days":0}}]' \
  --metrics '[{"category":"Transaction","enabled":true,"retentionPolicy":{"enabled":false,"days":0}}]'
```

### 1.2 Configure VM Monitoring

```bash
# Install Azure Monitor Agent on VM
az vm extension set \
  --resource-group myResourceGroup \
  --vm-name myVM \
  --name AzureMonitorWindowsAgent \
  --publisher Microsoft.Azure.Monitor \
  --version 1.0
```

## Step 2: Custom Metrics and Alerts

### 2.1 Create Custom Metric Alert

```bash
# Create a metric alert for high CPU usage
az monitor metrics alert create \
  --name "High CPU Alert" \
  --resource-group myResourceGroup \
  --scopes "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Compute/virtualMachines/{vm-name}" \
  --condition "avg Percentage CPU > 80" \
  --description "Alert when CPU usage exceeds 80%" \
  --evaluation-frequency 5m \
  --window-size 15m \
  --severity 2 \
  --action-group "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Insights/actionGroups/{action-group-name}"
```

### 2.2 Application Gateway Metrics

```bash
# Monitor Application Gateway backend health
az monitor metrics alert create \
  --name "Backend Health Alert" \
  --resource-group myResourceGroup \
  --scopes "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Network/applicationGateways/{ag-name}" \
  --condition "avg HealthyHostCount < 1" \
  --description "Alert when no healthy backend hosts" \
  --evaluation-frequency 1m \
  --window-size 5m \
  --severity 1
```

## Step 3: Dashboard Creation

### 3.1 Azure Portal Dashboard

Create a custom dashboard with the following tiles:
- Resource health overview
- Key performance metrics
- Recent alerts and notifications
- Cost analysis

### 3.2 Workbooks for Advanced Visualization

```json
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "AzureMetrics\n| where ResourceProvider == \"MICROSOFT.COMPUTE\"\n| where MetricName == \"Percentage CPU\"\n| summarize avg(Average) by bin(TimeGenerated, 5m), Resource\n| render timechart",
        "size": 0,
        "title": "CPU Usage Trend",
        "timeContext": {
          "durationMs": 3600000
        }
      }
    }
  ]
}
```

## Step 4: Automation and Scaling

### 4.1 Auto-scaling Configuration

```bash
# Configure VM Scale Set auto-scaling
az monitor autoscale create \
  --resource-group myResourceGroup \
  --resource "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Compute/virtualMachineScaleSets/{vmss-name}" \
  --min-count 2 \
  --max-count 10 \
  --count 3
```

### 4.2 Scale Rules

```bash
# Add scale-out rule
az monitor autoscale rule create \
  --resource-group myResourceGroup \
  --autoscale-name myAutoscaleSetting \
  --condition "Percentage CPU > 70 avg 5m" \
  --scale out 1
```

## Step 5: Integration with Logic Apps

### 5.1 Automated Remediation

```json
{
  "definition": {
    "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
    "triggers": {
      "When_a_HTTP_request_is_received": {
        "type": "Request",
        "kind": "Http"
      }
    },
    "actions": {
      "Restart_VM": {
        "type": "ApiConnection",
        "inputs": {
          "host": {
            "connection": {
              "name": "@parameters('$connections')['azurevm']['connectionId']"
            }
          },
          "method": "post",
          "path": "/subscriptions/@{encodeURIComponent('{subscription-id}')}/resourceGroups/@{encodeURIComponent('{resource-group}')}/providers/Microsoft.Compute/virtualMachines/@{encodeURIComponent('{vm-name}')}/restart"
        }
      }
    }
  }
}
```

## Monitoring KQL Queries

### Resource Health Query
```kql
AzureActivity
| where CategoryValue == "ResourceHealth"
| summarize count() by ResourceGroup, Resource, ActivityStatusValue
| order by count_ desc
```

### Performance Baseline
```kql
Perf
| where ObjectName == "Processor" and CounterName == "% Processor Time"
| summarize avg(CounterValue) by Computer, bin(TimeGenerated, 1h)
| render timechart
```

## Best Practices Demonstrated

1. **Layered Monitoring**: Multiple levels of monitoring from infrastructure to application
2. **Proactive Alerting**: Threshold-based and anomaly detection alerts
3. **Automated Response**: Integration with Logic Apps for remediation
4. **Cost Optimization**: Right-sizing based on monitoring data
5. **Documentation**: Clear monitoring procedures and runbooks

## Troubleshooting Common Issues

### Missing Metrics
- Verify diagnostic settings are enabled
- Check workspace permissions
- Validate data collection rules

### Alert Fatigue
- Adjust thresholds based on baseline data
- Use dynamic thresholds for varying workloads
- Implement alert suppression rules

## Next Steps

1. Implement custom dashboards for your specific use cases
2. Set up automated scaling based on business metrics
3. Integrate with ITSM tools for incident management
4. Develop runbooks for common scenarios

## Resources

- [Azure Monitor Documentation](https://docs.microsoft.com/azure/azure-monitor/)
- [Monitoring Best Practices](https://docs.microsoft.com/azure/azure-monitor/best-practices)
- [KQL Quick Reference](https://docs.microsoft.com/azure/data-explorer/kql-quick-reference)
