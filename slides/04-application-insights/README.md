# Application Insights

## Overview

Application Insights is Azure's application performance management (APM) service that provides deep insights into your applications' performance, availability, and usage patterns.

---

## What is Application Insights?

Application Insights automatically:
- **Monitors** application performance and availability
- **Detects** performance anomalies and failures
- **Tracks** user behavior and usage patterns
- **Diagnoses** issues with detailed telemetry
- **Correlates** requests across distributed systems

---

## Application Insights Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                       │
├─────────────────┬─────────────────┬─────────────────────────┤
│   Web Apps      │   API Services  │    Background Jobs      │
│                 │                │                         │
│ ┌─────────────┐ │ ┌─────────────┐ │ ┌─────────────────────┐ │
│ │App Insights │ │ │App Insights │ │ │   App Insights     │ │
│ │   SDK       │ │ │    SDK      │ │ │     SDK            │ │
│ └─────────────┘ │ └─────────────┘ │ └─────────────────────┘ │
└─────────────────┴─────────────────┴─────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Application Insights Service                  │
│                                                             │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │
│ │ Telemetry   │ │ Analytics   │ │     Smart Detection    │ │
│ │ Collection  │ │   Engine    │ │                         │ │
│ │             │ │             │ │ • Anomaly Detection     │ │
│ │ • Requests  │ │ • KQL       │ │ • Failure Analysis      │ │
│ │ • Dependencies│ • Workbooks │ │ • Performance Issues    │ │
│ │ • Exceptions│ │ • Dashboards│ │ • Memory Leaks          │ │
│ │ • Custom    │ │ • Alerts    │ │                         │ │
│ └─────────────┘ └─────────────┘ └─────────────────────────┘ │
│                                                             │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │
│ │   Live      │ │ Application │ │      Availability      │ │
│ │  Metrics    │ │    Map      │ │       Testing          │ │
│ │             │ │             │ │                         │ │
│ │ • Real-time │ │• Dependencies│ │ • URL ping tests       │ │
│ │ • Streaming │ │• Performance│ │ • Multi-step tests     │ │
│ │ • Filtering │ │• Failures   │ │ • Global monitoring    │ │
│ └─────────────┘ └─────────────┘ └─────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## Key Telemetry Types

### 1. Requests
HTTP requests to your application

```csharp
// Automatic request tracking
services.AddApplicationInsightsTelemetry();

// Custom request tracking
telemetryClient.TrackRequest("ProcessOrder", DateTime.UtcNow, 
    TimeSpan.FromMilliseconds(156), "200", true);
```

### 2. Dependencies
External calls your application makes

```csharp
// Automatic dependency tracking for HTTP, SQL, etc.
// Custom dependency tracking
telemetryClient.TrackDependency("Azure Service Bus", "SendMessage", 
    "order-queue", DateTime.UtcNow, TimeSpan.FromMilliseconds(45), true);
```

### 3. Exceptions
Unhandled and custom exceptions

```csharp
try 
{
    // Application logic
}
catch (Exception ex)
{
    telemetryClient.TrackException(ex, new Dictionary<string, string>
    {
        {"UserId", userId},
        {"Operation", "ProcessPayment"}
    });
}
```

### 4. Custom Events and Metrics
Business-specific telemetry

```csharp
// Custom events
telemetryClient.TrackEvent("OrderCompleted", new Dictionary<string, string>
{
    {"OrderId", orderId},
    {"CustomerType", "Premium"}
});

// Custom metrics
telemetryClient.TrackMetric("OrderValue", orderAmount);
```

---

## Smart Detection and AI

### Automatic Anomaly Detection
- **Performance Degradation** - Response time increases
- **Failure Rate Anomalies** - Unexpected error spikes
- **Memory Leak Detection** - Growing memory usage patterns
- **Security Issues** - Suspicious activity patterns

### Proactive Diagnostics
```kql
// Example: Detect slow dependency calls
dependencies
| where timestamp > ago(1h)
| where duration > 5000  // 5 seconds
| summarize count() by name, bin(timestamp, 5m)
| where count_ > 10
```

---

## Application Map

### Dependency Visualization
Interactive map showing:
- **Component Health** - Color-coded status
- **Performance Metrics** - Average response times
- **Failure Rates** - Error percentages
- **Call Volumes** - Request counts

### Example Application Map Flow
```
[Frontend] → [API Gateway] → [User Service] → [SQL Database]
    ↓             ↓              ↓
[Cache]    [Auth Service]  [Event Hub]
```

---

## Live Metrics Stream

### Real-time Monitoring
- **Incoming Requests** - Live request rate and response times
- **Outgoing Dependencies** - External call performance
- **Overall Health** - Success rates and error counts
- **Custom Metrics** - Business KPIs in real-time

### Filtering Capabilities
```csharp
// Filter live metrics by custom dimensions
telemetryClient.TrackRequest("API Call", DateTime.UtcNow, 
    TimeSpan.FromMilliseconds(156), "200", true,
    new Dictionary<string, string> { {"Environment", "Production"} });
```

---

## Availability Testing

### URL Ping Tests
Simple uptime monitoring:

```json
{
  "name": "Homepage Availability",
  "url": "https://myapp.azurewebsites.net",
  "frequency": "PT5M",
  "locations": [
    "us-ca-sjc-azr", "us-tx-sn1-azr", "us-il-ch1-azr"
  ],
  "successCriteria": {
    "httpStatusCode": 200,
    "responseTime": "PT30S"
  }
}
```

### Multi-Step Web Tests
Complex user journey testing:

```csharp
[TestMethod]
public void LoginAndPlaceOrder()
{
    // Navigate to login page
    driver.Navigate().GoToUrl("https://myapp.com/login");
    
    // Perform login
    driver.FindElement(By.Id("username")).SendKeys("testuser");
    driver.FindElement(By.Id("password")).SendKeys("password");
    driver.FindElement(By.Id("loginButton")).Click();
    
    // Verify successful login and place order
    Assert.IsTrue(driver.FindElement(By.Id("welcomeMessage")).Displayed);
    
    // Additional test steps...
}
```

---

## Performance Profiling

### Application Insights Profiler
- **CPU Usage Analysis** - Identify hot code paths
- **Memory Allocation** - Track object creation patterns
- **Call Stack Analysis** - Understand execution flow
- **Performance Bottlenecks** - Find slow operations

### Snapshot Debugger
- **Exception Snapshots** - Debug production exceptions
- **Local Variable Inspection** - View variable values
- **Call Stack Exploration** - Trace execution path
- **Production Debugging** - No application restart required

---

## Kusto Queries for Application Insights

### Performance Analysis
```kql
// Top slowest requests
requests
| where timestamp > ago(1h)
| top 10 by duration desc
| project timestamp, name, duration, resultCode, url
```

### Error Analysis
```kql
// Error trends by operation
requests
| where timestamp > ago(24h)
| where success == false
| summarize ErrorCount = count() by name, bin(timestamp, 1h)
| render timechart
```

### User Analytics
```kql
// Active users by page
pageViews
| where timestamp > ago(7d)
| summarize Users = dcount(user_Id) by name
| order by Users desc
```

### Dependency Performance
```kql
// External dependency failures
dependencies
| where timestamp > ago(1h)
| where success == false
| summarize count() by name, resultCode
| order by count_ desc
```

---

## Custom Telemetry Implementation

### .NET Core Integration
```csharp
// Program.cs
builder.Services.AddApplicationInsightsTelemetry();

// Custom telemetry client
public class OrderService
{
    private readonly TelemetryClient _telemetryClient;
    
    public OrderService(TelemetryClient telemetryClient)
    {
        _telemetryClient = telemetryClient;
    }
    
    public async Task<Order> ProcessOrderAsync(string orderId)
    {
        using var operation = _telemetryClient.StartOperation<RequestTelemetry>("ProcessOrder");
        operation.Telemetry.Properties["OrderId"] = orderId;
        
        try
        {
            // Track custom metrics
            _telemetryClient.TrackMetric("OrderProcessing.Started", 1);
            
            var order = await _orderRepository.GetOrderAsync(orderId);
            
            // Track custom event
            _telemetryClient.TrackEvent("OrderRetrieved", new Dictionary<string, string>
            {
                {"OrderId", orderId},
                {"CustomerType", order.CustomerType}
            });
            
            return order;
        }
        catch (Exception ex)
        {
            operation.Telemetry.Success = false;
            _telemetryClient.TrackException(ex);
            throw;
        }
    }
}
```

### JavaScript/TypeScript Integration
```typescript
import { ApplicationInsights } from '@microsoft/applicationinsights-web';

const appInsights = new ApplicationInsights({
    config: {
        instrumentationKey: 'your-instrumentation-key',
        enableAutoRouteTracking: true,
        enableCorsCorrelation: true
    }
});

appInsights.loadAppInsights();

// Track custom events
appInsights.trackEvent({
    name: 'ButtonClicked',
    properties: {
        buttonName: 'purchaseButton',
        pageUrl: window.location.href
    }
});

// Track page views
appInsights.trackPageView({
    name: 'ProductPage',
    uri: '/products/12345'
});
```

---

## Integration with Development Workflow

### Visual Studio Integration
- **Live Metrics** during debugging
- **Exception Analysis** in IDE
- **Performance Insights** in code editor
- **Deployment Tracking** with releases

### DevOps Integration
```yaml
# Azure DevOps Pipeline
- task: AzureResourceManagerTemplateDeployment@3
  inputs:
    deploymentScope: 'Resource Group'
    azureResourceManagerConnection: '$(serviceConnection)'
    subscriptionId: '$(subscriptionId)'
    action: 'Create Or Update Resource Group'
    resourceGroupName: '$(resourceGroupName)'
    location: '$(location)'
    templateLocation: 'Linked artifact'
    csmFile: 'templates/appinsights.json'
    csmParametersFile: 'templates/appinsights.parameters.json'

- task: ApplicationInsightsAnnotation@1
  inputs:
    applicationInsightsResourceName: '$(appInsightsName)'
    resourceGroupName: '$(resourceGroupName)'
    releaseName: '$(Release.ReleaseName)'
```

---

## Cost Optimization

### Data Volume Management
```kql
// Monitor data ingestion by telemetry type
Usage
| where TimeGenerated > ago(7d)
| where IsBillable == true
| summarize DataGB = sum(Quantity) / 1024 by DataType
| order by DataGB desc
```

### Sampling Configuration
```csharp
// Adaptive sampling
services.Configure<TelemetryConfiguration>(config =>
{
    config.DefaultTelemetrySink.TelemetryProcessorChainBuilder
        .UseAdaptiveSampling(maxTelemetryItemsPerSecond: 5)
        .Build();
});

// Fixed-rate sampling
services.Configure<TelemetryConfiguration>(config =>
{
    config.DefaultTelemetrySink.TelemetryProcessorChainBuilder
        .UseSampling(samplingPercentage: 25.0)
        .Build();
});
```

---

## Security and Privacy

### Data Protection
- **IP Address Anonymization** - GDPR compliance
- **Custom Data Filtering** - Remove sensitive information
- **Role-Based Access** - Control data access
- **Data Export** - Compliance reporting

```csharp
// Filter sensitive data
public class SensitiveDataTelemetryProcessor : ITelemetryProcessor
{
    public void Process(ITelemetry item)
    {
        if (item is RequestTelemetry request && 
            request.Url.ToString().Contains("password"))
        {
            return; // Don't send sensitive requests
        }
        
        // Continue processing
        this.Next.Process(item);
    }
}
```

---

## Best Practices

### Telemetry Strategy
1. **Meaningful Names** - Use consistent naming conventions
2. **Appropriate Sampling** - Balance detail with cost
3. **Custom Properties** - Add business context
4. **Performance Impact** - Minimize overhead

### Monitoring Coverage
1. **Critical User Journeys** - End-to-end tracking
2. **Business Metrics** - KPIs and conversion rates
3. **System Health** - Dependencies and resources
4. **Error Scenarios** - Failure modes and recovery

### Alert Configuration
1. **Smart Detection** - Enable AI-powered alerts
2. **Custom Alerts** - Business-specific conditions
3. **Action Groups** - Appropriate response teams
4. **Alert Tuning** - Reduce noise and false positives

---

## Troubleshooting Common Issues

### Missing Telemetry
```csharp
// Verify instrumentation key
services.Configure<TelemetryConfiguration>(config =>
{
    config.InstrumentationKey = "your-key-here";
});

// Check telemetry channel
public void ConfigureServices(IServiceCollection services)
{
    services.AddApplicationInsightsTelemetry(options =>
    {
        options.DeveloperMode = true; // For debugging
    });
}
```

### Performance Impact
```ksharp
// Optimize telemetry collection
services.Configure<TelemetryConfiguration>(config =>
{
    // Reduce telemetry volume
    config.DefaultTelemetrySink.TelemetryProcessorChainBuilder
        .UseAdaptiveSampling(maxTelemetryItemsPerSecond: 2)
        .Build();
    
    // Use server telemetry channel for better performance
    config.TelemetryChannel = new ServerTelemetryChannel();
});
```

---

## Next Steps

1. **Instrument Applications** - Add Application Insights SDK
2. **Configure Telemetry** - Set up custom tracking
3. **Create Dashboards** - Build monitoring views
4. **Set Up Alerts** - Implement proactive monitoring
5. **Optimize Performance** - Fine-tune sampling and filtering
6. **Integrate with DevOps** - Add deployment tracking
