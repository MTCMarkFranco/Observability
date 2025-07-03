# End-to-End Observability Scenario Demo

This comprehensive demo demonstrates a complete observability implementation for a modern microservices application, covering all aspects from infrastructure monitoring to application performance management and security monitoring.

## Scenario Overview

**Business Context**: E-commerce platform with microservices architecture
**Components**: Web frontend, API gateway, order service, payment service, inventory service, notification service
**Observability Goals**: 
- Proactive monitoring and alerting
- Root cause analysis capabilities
- Performance optimization insights
- Security threat detection
- Operational excellence

## Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Frontend  │    │  API Gateway    │    │ Order Service   │
│   (React SPA)   │────│  (Azure APIM)   │────│  (.NET Core)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                       │
                                │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│Payment Service  │    │Inventory Service│    │Notification Svc │
│  (Node.js)      │────│   (Python)      │────│   (Azure Func)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                │
                    ┌─────────────────┐
                    │   Database      │
                    │ (Azure SQL DB)  │
                    └─────────────────┘
```

## Prerequisites

- Azure subscription with contributor access
- Azure CLI installed and configured
- Docker Desktop installed
- kubectl configured for AKS
- Completed infrastructure deployment (from infra folder)

## Demo Steps

### Step 1: Deploy Infrastructure Foundation

```bash
# Deploy the observability foundation
cd infra/observability-foundation
az deployment group create \
  --resource-group rg-observability-demo \
  --template-file main.bicep \
  --parameters @main.parameters.json
```

### Step 2: Deploy Sample Application

#### 2.1 Deploy to Azure Container Apps

```bash
# Build and push container images
az acr build --registry myregistry --image ecommerce/web-frontend:v1.0 ./src/web-frontend
az acr build --registry myregistry --image ecommerce/order-service:v1.0 ./src/order-service
az acr build --registry myregistry --image ecommerce/payment-service:v1.0 ./src/payment-service
az acr build --registry myregistry --image ecommerce/inventory-service:v1.0 ./src/inventory-service

# Deploy container apps
az deployment group create \
  --resource-group rg-observability-demo \
  --template-file container-apps.bicep \
  --parameters @container-apps.parameters.json
```

#### 2.2 Configure Application Insights

Each service is configured with Application Insights SDK:

**Order Service (.NET Core)**
```csharp
// Program.cs
builder.Services.AddApplicationInsightsTelemetry(options =>
{
    options.ConnectionString = builder.Configuration.GetConnectionString("ApplicationInsights");
});

// Add custom telemetry
builder.Services.AddScoped<IOrderTelemetryService, OrderTelemetryService>();
```

**Payment Service (Node.js)**
```javascript
// app.js
const appInsights = require('applicationinsights');
appInsights.setup(process.env.APPLICATIONINSIGHTS_CONNECTION_STRING)
    .setAutoDependencyCorrelation(true)
    .setAutoCollectRequests(true)
    .start();
```

**Inventory Service (Python)**
```python
# app.py
from opencensus.ext.azure.trace_exporter import AzureExporter
from opencensus.ext.flask.flask_middleware import FlaskMiddleware

middleware = FlaskMiddleware(
    app,
    exporter=AzureExporter(connection_string=os.environ.get('APPLICATIONINSIGHTS_CONNECTION_STRING'))
)
```

### Step 3: Configure Monitoring and Alerting

#### 3.1 Set Up Custom Dashboards

Create workbooks for different stakeholders:

**Business Dashboard**
```json
{
  "items": [
    {
      "type": "kql",
      "query": "customEvents | where name == 'OrderCompleted' | summarize Orders = count() by bin(timestamp, 1h)",
      "title": "Orders per Hour"
    },
    {
      "type": "kql", 
      "query": "customEvents | where name == 'PaymentProcessed' | summarize Revenue = sum(todouble(customMeasurements.Amount)) by bin(timestamp, 1d)",
      "title": "Daily Revenue"
    }
  ]
}
```

**Operations Dashboard**
```json
{
  "items": [
    {
      "type": "kql",
      "query": "requests | summarize AvgResponseTime = avg(duration), RequestCount = count() by bin(timestamp, 5m)",
      "title": "Application Performance"
    },
    {
      "type": "kql",
      "query": "exceptions | summarize ErrorCount = count() by problemId | order by ErrorCount desc",
      "title": "Top Errors"
    }
  ]
}
```

#### 3.2 Configure Alerts

**High-Priority Alerts**
```bash
# Payment service failure alert
az monitor metrics alert create \
  --name "Payment Service Failure Rate" \
  --resource-group rg-observability-demo \
  --condition "avg requests/failed > 5" \
  --description "Alert when payment service failure rate exceeds 5 per minute"

# Database connection alert
az monitor scheduled-query create \
  --name "Database Connection Issues" \
  --condition-query "dependencies | where type == 'SQL' | where success == false | summarize count()"
```

### Step 4: Implement Distributed Tracing

#### 4.1 Cross-Service Correlation

**Order Service Implementation**
```csharp
public class OrderController : ControllerBase
{
    private readonly ILogger<OrderController> _logger;
    private readonly TelemetryClient _telemetryClient;
    
    [HttpPost]
    public async Task<IActionResult> CreateOrder([FromBody] CreateOrderRequest request)
    {
        using var activity = Activity.Current?.Source.StartActivity("CreateOrder");
        activity?.SetTag("order.customerId", request.CustomerId);
        activity?.SetTag("order.items", request.Items.Count);
        
        try
        {
            // Process payment
            var paymentResult = await _paymentService.ProcessPaymentAsync(request.Payment);
            activity?.SetTag("payment.transactionId", paymentResult.TransactionId);
            
            // Update inventory
            await _inventoryService.ReserveItemsAsync(request.Items);
            
            // Create order
            var order = await _orderService.CreateOrderAsync(request);
            
            // Send notification
            await _notificationService.SendOrderConfirmationAsync(order);
            
            _telemetryClient.TrackEvent("OrderCompleted", new Dictionary<string, string>
            {
                ["OrderId"] = order.Id.ToString(),
                ["CustomerId"] = request.CustomerId
            });
            
            return Ok(order);
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            _logger.LogError(ex, "Failed to create order for customer {CustomerId}", request.CustomerId);
            throw;
        }
    }
}
```

#### 4.2 Correlation Queries

**End-to-End Transaction Trace**
```kql
// Find all operations for a specific order
let orderId = "12345";
union
    (requests | where customDimensions.OrderId == orderId),
    (dependencies | where customDimensions.OrderId == orderId),
    (customEvents | where customDimensions.OrderId == orderId),
    (exceptions | where customDimensions.OrderId == orderId)
| sort by timestamp asc
| project timestamp, itemType, name, operation_Name, success, duration
```

### Step 5: Performance Monitoring

#### 5.1 Application Performance Monitoring

**Key Performance Indicators**
```kql
// Response time trends
requests
| where timestamp > ago(24h)
| summarize 
    AvgResponseTime = avg(duration),
    P95ResponseTime = percentile(duration, 95),
    P99ResponseTime = percentile(duration, 99)
    by bin(timestamp, 1h), operation_Name
| render timechart
```

**Dependency Performance**
```kql
// Database performance analysis
dependencies
| where type == "SQL"
| where timestamp > ago(24h)
| summarize 
    AvgDuration = avg(duration),
    CallCount = count(),
    SuccessRate = avg(iff(success, 1.0, 0.0)) * 100
    by target, name
| order by AvgDuration desc
```

#### 5.2 Infrastructure Monitoring

**Resource Utilization**
```kql
// Container resource usage
Perf
| where ObjectName == "K8SContainer"
| where CounterName == "cpuUsageNanoCores"
| where TimeGenerated > ago(24h)
| summarize AvgCPU = avg(CounterValue) by Computer, InstanceName
| order by AvgCPU desc
```

### Step 6: Security Monitoring

#### 6.1 Threat Detection

**Suspicious Activity Detection**
```kql
// Unusual login patterns
customEvents
| where name == "UserLogin"
| where timestamp > ago(1h)
| extend Hour = hourofday(timestamp)
| summarize LoginCount = count() by user_Id, client_IP, Hour
| join kind=leftanti (
    customEvents
    | where name == "UserLogin"
    | where timestamp between (ago(7d) .. ago(1h))
    | extend Hour = hourofday(timestamp)
    | summarize TypicalLogins = avg(todouble(1)) by user_Id, Hour
    | where TypicalLogins > 0
) on user_Id, Hour
| project user_Id, client_IP, Hour, LoginCount
```

**API Abuse Detection**
```kql
// High request rate from single IP
requests
| where timestamp > ago(1h)
| summarize RequestCount = count() by client_IP, bin(timestamp, 5m)
| where RequestCount > 1000
| project timestamp, client_IP, RequestCount
```

#### 6.2 Security Alerts

Configure alerts for:
- Unusual authentication patterns
- High error rates indicating potential attacks
- Suspicious API usage patterns
- Data access anomalies

### Step 7: Operational Workflows

#### 7.1 Incident Response

**Automated Incident Creation**
```json
{
  "logic_app_workflow": {
    "triggers": {
      "alert_triggered": {
        "type": "HTTP",
        "inputs": {
          "schema": {
            "alert_context": "object",
            "alert_severity": "string"
          }
        }
      }
    },
    "actions": {
      "create_incident": {
        "type": "ServiceNow",
        "inputs": {
          "method": "POST",
          "body": {
            "short_description": "@{triggerBody().alert_context.condition.allOf[0].metricName} threshold exceeded",
            "urgency": "@{if(equals(triggerBody().alert_severity, 'Sev0'), 1, 3)}"
          }
        }
      }
    }
  }
}
```

#### 7.2 Automated Remediation

**Auto-scaling Based on Metrics**
```bash
# Configure auto-scaling for container apps
az containerapp revision set \
  --name order-service \
  --resource-group rg-observability-demo \
  --min-replicas 2 \
  --max-replicas 10 \
  --scale-rule-name "http-scale-rule" \
  --scale-rule-type "http" \
  --scale-rule-metadata concurrentRequests=100
```

### Step 8: Business Intelligence

#### 8.1 Business Metrics

**Customer Journey Analytics**
```kql
// Customer conversion funnel
customEvents
| where timestamp > ago(7d)
| where name in ("ProductViewed", "AddedToCart", "CheckoutStarted", "OrderCompleted")
| summarize EventCount = count() by name, bin(timestamp, 1d)
| render columnchart
```

**Revenue Analytics**
```kql
// Revenue by product category
customEvents
| where name == "OrderCompleted"
| where timestamp > ago(30d)
| extend OrderValue = todouble(customMeasurements.OrderValue)
| extend ProductCategory = tostring(customDimensions.ProductCategory)
| summarize TotalRevenue = sum(OrderValue) by ProductCategory
| order by TotalRevenue desc
```

#### 8.2 Performance Optimization

**Slow Query Identification**
```kql
// Find slow database queries
dependencies
| where type == "SQL"
| where duration > 5000  // 5 seconds
| where timestamp > ago(24h)
| summarize SlowQueryCount = count() by data, target
| order by SlowQueryCount desc
```

## Testing Scenarios

### Scenario 1: High Load Testing

1. Generate load using Azure Load Testing
2. Monitor application performance metrics
3. Observe auto-scaling behavior
4. Analyze bottlenecks and optimize

### Scenario 2: Failure Simulation

1. Simulate payment service failures
2. Observe circuit breaker behavior
3. Track error propagation
4. Verify alert notifications

### Scenario 3: Security Incident

1. Simulate suspicious login attempts
2. Observe security alert triggers
3. Follow incident response procedures
4. Verify threat detection accuracy

## Success Metrics

### Operational Metrics
- Mean Time to Detection (MTTD): < 5 minutes
- Mean Time to Resolution (MTTR): < 30 minutes
- System Availability: > 99.9%
- Alert Accuracy: > 95%

### Performance Metrics
- API Response Time: < 200ms (95th percentile)
- Database Query Time: < 100ms (average)
- Error Rate: < 0.1%
- Customer Satisfaction: > 4.5/5

### Security Metrics
- Threat Detection Rate: > 99%
- False Positive Rate: < 5%
- Incident Response Time: < 15 minutes
- Compliance Score: 100%

## Troubleshooting Guide

### Common Issues

1. **Missing Telemetry Data**
   - Check Application Insights connection strings
   - Verify SDK configuration
   - Check firewall rules

2. **High Alert Noise**
   - Adjust alert thresholds
   - Implement smart alerting
   - Use alert correlation

3. **Performance Issues**
   - Optimize KQL queries
   - Implement data retention policies
   - Use summarized data for historical analysis

### Debugging Steps

1. Verify data ingestion
2. Check alert rule configuration
3. Validate dashboard queries
4. Test automated workflows

## Best Practices Demonstrated

1. **Comprehensive Coverage**: End-to-end monitoring across all layers
2. **Proactive Monitoring**: Predictive analytics and anomaly detection
3. **Automated Response**: Self-healing systems and automated remediation
4. **Business Alignment**: Monitoring tied to business objectives
5. **Security Integration**: Security monitoring as part of observability
6. **Operational Excellence**: Standardized procedures and runbooks

## Next Steps

1. Implement machine learning for anomaly detection
2. Add chaos engineering practices
3. Extend monitoring to edge locations
4. Implement cost optimization based on usage patterns
5. Create custom visualizations for stakeholders

## Resources

- [Azure Monitor Best Practices](https://docs.microsoft.com/azure/azure-monitor/best-practices)
- [Application Insights](https://docs.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- [Container Apps Monitoring](https://docs.microsoft.com/azure/container-apps/monitor)
- [OpenTelemetry](https://opentelemetry.io/docs/)
