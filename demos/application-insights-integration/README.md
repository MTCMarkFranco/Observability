# Application Insights Integration Demo

This comprehensive demo shows how to integrate Application Insights with various application types and configure advanced monitoring scenarios.

## Prerequisites

- Azure subscription with contributor access
- Application Insights resource (created via infra templates)
- Sample applications for monitoring
- Visual Studio or VS Code with Azure extensions

## Demo Overview

This demonstration covers:
1. Application Insights SDK integration
2. Custom telemetry and metrics
3. Dependency tracking and correlation
4. Performance monitoring and optimization
5. User behavior analytics

## Step 1: SDK Integration

### 1.1 .NET Core Application

```csharp
// Program.cs
using Microsoft.ApplicationInsights.Extensibility;

var builder = WebApplication.CreateBuilder(args);

// Add Application Insights
builder.Services.AddApplicationInsightsTelemetry(options =>
{
    options.ConnectionString = builder.Configuration.GetConnectionString("ApplicationInsights");
});

// Configure sampling
builder.Services.Configure<TelemetryConfiguration>(config =>
{
    config.DefaultTelemetrySink.TelemetryProcessorChainBuilder
        .UseAdaptiveSampling(maxTelemetryItemsPerSecond: 1, excludedTypes: "Event")
        .Build();
});

var app = builder.Build();

app.MapGet("/", () => "Hello World!");
app.MapGet("/api/health", () => new { Status = "Healthy", Timestamp = DateTime.UtcNow });

app.Run();
```

### 1.2 JavaScript/Node.js Integration

```javascript
// app.js
const appInsights = require('applicationinsights');

// Initialize Application Insights
appInsights.setup('your-connection-string')
    .setAutoDependencyCorrelation(true)
    .setAutoCollectRequests(true)
    .setAutoCollectPerformance(true, true)
    .setAutoCollectExceptions(true)
    .setAutoCollectDependencies(true)
    .setAutoCollectConsole(true)
    .setUseDiskRetryCaching(true)
    .setSendLiveMetrics(false)
    .setDistributedTracingMode(appInsights.DistributedTracingModes.AI_AND_W3C)
    .start();

const client = appInsights.defaultClient;

const express = require('express');
const app = express();

app.get('/', (req, res) => {
    // Custom event tracking
    client.trackEvent({
        name: 'HomePage_Visited',
        properties: {
            userAgent: req.get('User-Agent'),
            path: req.path
        }
    });
    
    res.send('Hello from Application Insights Demo!');
});

app.listen(3000, () => {
    console.log('Server running on port 3000');
});
```

### 1.3 Python Flask Application

```python
# app.py
from flask import Flask, request
from opencensus.ext.azure.log_exporter import AzureLogHandler
from opencensus.ext.azure.trace_exporter import AzureExporter
from opencensus.ext.flask.flask_middleware import FlaskMiddleware
from opencensus.trace.samplers import ProbabilitySampler
import logging
import os

app = Flask(__name__)

# Configure Application Insights
connection_string = os.environ.get('APPLICATIONINSIGHTS_CONNECTION_STRING')

# Add telemetry middleware
middleware = FlaskMiddleware(
    app,
    exporter=AzureExporter(connection_string=connection_string),
    sampler=ProbabilitySampler(rate=1.0)
)

# Configure logging
logging.basicConfig(format='%(message)s')
logger = logging.getLogger(__name__)
logger.addHandler(AzureLogHandler(connection_string=connection_string))
logger.setLevel(logging.INFO)

@app.route('/')
def home():
    logger.info('Home page accessed', extra={'custom_dimensions': {'user_id': 'demo_user'}})
    return 'Hello from Python App with Application Insights!'

@app.route('/api/data')
def get_data():
    # Simulate processing time
    import time
    time.sleep(0.1)
    
    logger.info('Data API called')
    return {'data': 'sample_data', 'timestamp': str(time.time())}

if __name__ == '__main__':
    app.run(debug=True)
```

## Step 2: Custom Telemetry

### 2.1 Custom Events and Metrics

```csharp
// Custom telemetry in .NET
public class TelemetryService
{
    private readonly TelemetryClient _telemetryClient;

    public TelemetryService(TelemetryClient telemetryClient)
    {
        _telemetryClient = telemetryClient;
    }

    public void TrackBusinessEvent(string eventName, Dictionary<string, string> properties = null, Dictionary<string, double> metrics = null)
    {
        _telemetryClient.TrackEvent(eventName, properties, metrics);
    }

    public void TrackPerformanceMetric(string metricName, double value, IDictionary<string, string> properties = null)
    {
        _telemetryClient.GetMetric(metricName).TrackValue(value, properties);
    }

    public void TrackUserFlow(string operationName, string userId, TimeSpan duration)
    {
        var properties = new Dictionary<string, string>
        {
            ["UserId"] = userId,
            ["Duration"] = duration.TotalMilliseconds.ToString()
        };

        _telemetryClient.TrackEvent($"UserFlow_{operationName}", properties);
    }
}
```

### 2.2 Dependency Tracking

```csharp
// Manual dependency tracking
public async Task<string> CallExternalService(string url)
{
    using var activity = _telemetryClient.StartOperation<DependencyTelemetry>("HTTP GET", url);
    
    try
    {
        activity.Telemetry.Type = "HTTP";
        activity.Telemetry.Target = new Uri(url).Host;
        
        var response = await _httpClient.GetStringAsync(url);
        
        activity.Telemetry.Success = true;
        return response;
    }
    catch (Exception ex)
    {
        activity.Telemetry.Success = false;
        _telemetryClient.TrackException(ex);
        throw;
    }
}
```

## Step 3: Advanced Configuration

### 3.1 Telemetry Processors

```csharp
// Custom telemetry processor
public class FilteringTelemetryProcessor : ITelemetryProcessor
{
    private ITelemetryProcessor Next { get; set; }

    public FilteringTelemetryProcessor(ITelemetryProcessor next)
    {
        Next = next;
    }

    public void Process(ITelemetry item)
    {
        // Filter out health check requests
        if (item is RequestTelemetry request && 
            request.Url?.AbsolutePath?.Contains("/health") == true)
        {
            return; // Don't send to Application Insights
        }

        // Add custom properties
        if (item is ISupportProperties telemetryWithProperties)
        {
            telemetryWithProperties.Properties["Environment"] = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT");
        }

        Next.Process(item);
    }
}

// Register in Program.cs
builder.Services.AddApplicationInsightsTelemetryProcessor<FilteringTelemetryProcessor>();
```

### 3.2 Telemetry Initializers

```csharp
public class CustomTelemetryInitializer : ITelemetryInitializer
{
    public void Initialize(ITelemetry telemetry)
    {
        if (string.IsNullOrEmpty(telemetry.Context.Cloud.RoleName))
        {
            telemetry.Context.Cloud.RoleName = "MyWebApp";
        }

        // Add custom properties to all telemetry
        if (telemetry is ISupportProperties properties)
        {
            properties.Properties["ApplicationVersion"] = Assembly.GetExecutingAssembly().GetName().Version?.ToString();
        }
    }
}
```

## Step 4: Performance Monitoring

### 4.1 Live Metrics Configuration

```csharp
// Enable Live Metrics
builder.Services.Configure<TelemetryConfiguration>(config =>
{
    config.AddLiveMetricsCollector();
});
```

### 4.2 Custom Performance Counters

```javascript
// Node.js custom performance tracking
const performanceHooks = require('perf_hooks');

function trackOperationPerformance(operationName, operation) {
    const startTime = performanceHooks.performance.now();
    
    try {
        const result = operation();
        const duration = performanceHooks.performance.now() - startTime;
        
        client.trackMetric({
            name: `${operationName}_Duration`,
            value: duration
        });
        
        return result;
    } catch (error) {
        client.trackException({ exception: error });
        throw error;
    }
}
```

## Step 5: User Analytics

### 5.1 Page View Tracking

```javascript
// Client-side JavaScript
<script type="text/javascript">
    var appInsights = window.appInsights || function(a) {
        function b(a) { c[a] = function() { var b = arguments; c.queue.push(function() { c[a].apply(c, b) }) } }
        var c = { config: a }, d = document, e = window;
        setTimeout(function() {
            var b = d.createElement("script");
            b.src = a.url || "https://az416426.vo.msecnd.net/scripts/b/ai.2.min.js", d.getElementsByTagName("script")[0].parentNode.appendChild(b)
        });
        try { c.cookie = d.cookie } catch (a) { }
        c.queue = [], c.version = 2;
        for (var f = ["Event", "PageView", "Exception", "Trace", "DependencyData", "Metric", "PageViewPerformance"]; f.length;)
            b("track" + f.pop());
        b("startTrackPage"), b("stopTrackPage");
        var g = "Track" + f[0];
        if (b(g), c[g] = function(a, b) { c.queue.push([g, arguments]) }, !a.disableExceptionTracking) {
            f = "onerror", b("_" + f);
            var h = e[f];
            e[f] = function(a, b, d, e, g) { var i = h && h(a, b, d, e, g); return !0 !== i && c["_" + f]({ message: a, error: g }), i }
        }
        return c
    }({
        instrumentationKey: "your-instrumentation-key"
    });

    window.appInsights = appInsights, appInsights.queue && 0 === appInsights.queue.length && appInsights.trackPageView({});

    // Custom user tracking
    function trackUserAction(action, properties) {
        appInsights.trackEvent(action, properties);
    }

    // Track button clicks
    document.addEventListener('click', function(e) {
        if (e.target.tagName === 'BUTTON') {
            trackUserAction('ButtonClick', {
                buttonText: e.target.textContent,
                buttonId: e.target.id
            });
        }
    });
</script>
```

## Step 6: Monitoring Queries

### 6.1 Performance Analysis

```kql
// Application performance overview
requests
| where timestamp > ago(24h)
| summarize 
    RequestCount = count(),
    AvgDuration = avg(duration),
    P95Duration = percentile(duration, 95),
    FailureRate = countif(success == false) * 100.0 / count()
    by bin(timestamp, 1h)
| render timechart
```

### 6.2 Dependency Analysis

```kql
// Dependency failure analysis
dependencies
| where timestamp > ago(24h)
| where success == false
| summarize FailureCount = count() by target, type
| order by FailureCount desc
| take 10
```

### 6.3 User Behavior Analysis

```kql
// User session analysis
pageViews
| where timestamp > ago(7d)
| summarize 
    SessionCount = dcount(session_Id),
    PageViewCount = count(),
    UniqueUsers = dcount(user_Id)
    by bin(timestamp, 1d)
| render columnchart
```

## Step 7: Alerts and Monitoring

### 7.1 Application-Specific Alerts

```bash
# Create application performance alert
az monitor metrics alert create \
  --name "High Response Time" \
  --resource-group myResourceGroup \
  --scopes "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Insights/components/{app-insights-name}" \
  --condition "avg server/responseTime > 5000" \
  --description "Alert when average response time exceeds 5 seconds" \
  --evaluation-frequency 1m \
  --window-size 5m \
  --severity 2
```

### 7.2 Custom Log Alerts

```bash
# Create custom log alert
az monitor scheduled-query create \
  --name "High Error Rate" \
  --resource-group myResourceGroup \
  --scopes "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Insights/components/{app-insights-name}" \
  --condition-query "exceptions | where timestamp > ago(5m) | summarize count()" \
  --condition-threshold 10 \
  --condition-operator "GreaterThan" \
  --evaluation-frequency "PT1M" \
  --window-size "PT5M"
```

## Best Practices Demonstrated

1. **Comprehensive Coverage**: Monitoring all application layers
2. **Custom Telemetry**: Business-specific metrics and events
3. **Performance Optimization**: Sampling and filtering strategies
4. **User Experience**: Real user monitoring and analytics
5. **Proactive Monitoring**: Intelligent alerting and thresholds

## Troubleshooting Guide

### Common Issues
- **Missing Telemetry**: Check connection string and SDK configuration
- **High Costs**: Implement proper sampling and filtering
- **Performance Impact**: Optimize telemetry collection settings
- **Correlation Issues**: Ensure proper operation correlation setup

### Debugging Steps
1. Verify connection string configuration
2. Check telemetry in Live Metrics
3. Review sampling settings
4. Validate custom telemetry implementation

## Next Steps

1. Implement end-to-end transaction monitoring
2. Set up availability tests for critical user journeys
3. Create custom dashboards for business metrics
4. Integrate with DevOps pipelines for release monitoring

## Resources

- [Application Insights Documentation](https://docs.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- [Telemetry Data Model](https://docs.microsoft.com/azure/azure-monitor/app/data-model)
- [Performance Testing](https://docs.microsoft.com/azure/azure-monitor/app/monitor-performance-live-website-now)
