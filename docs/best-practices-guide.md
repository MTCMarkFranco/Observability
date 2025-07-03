# Azure Observability Best Practices Guide

## Log Analytics Best Practices

### Workspace Design

#### Single Workspace Strategy
```yaml
Environment: Production
Strategy: Single workspace per environment
Benefits:
  - Centralized logging and correlation
  - Simplified access control
  - Cost optimization through unified billing
  - Cross-service analytics capabilities

Workspace Naming: law-{org}-{env}-{region}
Example: law-contoso-prod-eastus
```

#### Data Retention Strategy
```kql
// Configure table-specific retention
// High-value data: 2 years
SecurityEvent, AuditLogs, SigninLogs: 730 days

// Operational data: 6 months  
AzureActivity, AzureMetrics: 180 days

// Performance data: 90 days
Perf, Event, Syslog: 90 days

// Debug data: 30 days
Traces, Dependencies: 30 days
```

### Query Optimization

#### Efficient KQL Patterns
```kql
// ✅ GOOD: Filter early and use indexed columns
SecurityEvent
| where TimeGenerated > ago(1h)    // Use time filter first
| where EventID == 4625             // Filter on indexed columns
| where Computer startswith "WEB"   // Use startswith for string filtering
| summarize count() by Account, bin(TimeGenerated, 5m)
| order by TimeGenerated desc

// ❌ BAD: Late filtering and inefficient operations
SecurityEvent
| summarize count() by Account, EventID, bin(TimeGenerated, 5m)
| where EventID == 4625
| where TimeGenerated > ago(1h)
| where Account contains "admin"    // Avoid contains when possible
```

#### Performance Best Practices
```kql
// Use summarize instead of distinct for counting
// ✅ GOOD
requests | summarize dcount(user_Id)

// ❌ BAD  
requests | distinct user_Id | count

// Use materialized views for frequently accessed data
.create materialized-view DailyUserActivity on table(PageViews) {
    PageViews
    | summarize Users = dcount(user_Id), Views = count() 
      by bin(timestamp, 1d), application_Version
}

// Use query hints for large datasets
SecurityEvent
| where TimeGenerated > ago(7d)
| summarize count() by Computer
| hint.shufflekey = Computer  // Distribute processing
```

### Cost Management

#### Data Volume Control
```json
{
  "dataRetentionStrategy": {
    "criticalData": {
      "types": ["SecurityEvent", "AuditLogs", "SigninLogs"],
      "retention": "730 days",
      "archiveAfter": "90 days"
    },
    "operationalData": {
      "types": ["AzureActivity", "AzureMetrics", "Heartbeat"],
      "retention": "180 days",
      "sampling": "None"
    },
    "debugData": {
      "types": ["Traces", "Dependencies", "CustomLogs"],
      "retention": "30 days",
      "sampling": "10%"
    }
  },
  "costOptimization": {
    "dailyQuota": "Set based on budget constraints",
    "alertThreshold": "80% of quota",
    "dataExport": "Configure for long-term archival"
  }
}
```

#### Sampling Strategy
```kql
// Application Insights sampling configuration
{
  "sampling": {
    "percentage": 10.0,  // 10% sampling
    "excludedTypes": ["Request", "Exception"],  // Never sample these
    "includedTypes": ["Trace", "Event"],       // Always sample these
    "maxTelemetryItemsPerSecond": 5
  }
}

// Dynamic sampling based on volume
let HighVolumeThreshold = 1000000;  // 1M records/hour
let CurrentVolume = (
    AppTraces 
    | where timestamp > ago(1h) 
    | count
);
let SamplingRate = iff(CurrentVolume > HighVolumeThreshold, 0.1, 1.0);
AppTraces
| where rand() <= SamplingRate
```

---

## Azure Monitor Best Practices

### Metrics Strategy

#### Platform vs Custom Metrics
```yaml
Platform Metrics:
  Collection: Automatic
  Cost: Included in resource cost
  Retention: 93 days
  Examples: CPU, Memory, Network, Storage

Custom Metrics:
  Collection: Manual instrumentation
  Cost: $0.10 per metric time series
  Retention: 93 days
  Examples: Business KPIs, Application counters
```

#### Metric Naming Convention
```csharp
// Follow OpenTelemetry semantic conventions
public static class MetricNames
{
    // Infrastructure metrics
    public const string CpuUtilization = "system.cpu.utilization";
    public const string MemoryUtilization = "system.memory.utilization";
    public const string DiskIoOperations = "system.disk.operations";
    
    // Application metrics  
    public const string HttpRequestDuration = "http.request.duration";
    public const string DatabaseConnectionPool = "db.connection_pool.usage";
    public const string MessageQueueDepth = "messaging.queue.depth";
    
    // Business metrics
    public const string OrdersProcessed = "business.orders.processed";
    public const string RevenueGenerated = "business.revenue.total";
    public const string UserSessions = "business.user.sessions.active";
}
```

### Alert Design

#### Alert Hierarchy
```yaml
Severity 0 (Critical):
  Description: Service is completely down
  Response Time: Immediate (< 5 minutes)
  Examples:
    - Application 100% failure rate
    - Database completely unavailable
    - Critical security breach detected
  
Severity 1 (Error):
  Description: Service significantly degraded
  Response Time: < 15 minutes
  Examples:
    - Error rate > 10%
    - Response time > 10 seconds
    - Disk space < 5%

Severity 2 (Warning):
  Description: Potential issues detected
  Response Time: < 1 hour
  Examples:
    - CPU usage > 80%
    - Memory usage > 85%
    - Unusual traffic patterns

Severity 3 (Informational):
  Description: Awareness notifications
  Response Time: Next business day
  Examples:
    - Deployment completed
    - Certificate expiring in 30 days
    - Performance recommendation
```

#### Dynamic Thresholds
```kql
// Use machine learning for adaptive thresholds
requests
| where timestamp > ago(30d)
| make-series RequestCount = count() default = 0 
  on timestamp step 5m
| extend (anomalies, score, baseline) = 
  series_decompose_anomalies(RequestCount, 1.5, 7, 'linefit', 1, 'ctukey', 0.01)
| mv-expand timestamp, RequestCount, anomalies, score, baseline
| where anomalies != 0
| project timestamp, RequestCount, baseline, score
```

### Action Groups

#### Multi-Channel Notifications
```json
{
  "actionGroups": {
    "critical": {
      "channels": [
        {
          "type": "sms",
          "recipients": ["on-call-engineer"],
          "enabled": "production-only"
        },
        {
          "type": "email", 
          "recipients": ["soc-team", "platform-team"],
          "useCommonSchema": true
        },
        {
          "type": "webhook",
          "endpoint": "https://teams.webhook.url",
          "customPayload": {
            "severity": "[alertContext.Severity]",
            "resource": "[alertContext.AffectedConfigurationItems]"
          }
        },
        {
          "type": "azureFunction",
          "functionApp": "alert-processor",
          "function": "ProcessCriticalAlert"
        }
      ]
    }
  }
}
```

---

## Application Insights Best Practices

### SDK Configuration

#### .NET Application Setup
```csharp
// Program.cs - Production-ready configuration
public static void Main(string[] args)
{
    var builder = WebApplication.CreateBuilder(args);
    
    // Application Insights with custom configuration
    builder.Services.AddApplicationInsightsTelemetry(options =>
    {
        options.ConnectionString = builder.Configuration.GetConnectionString("ApplicationInsights");
        options.DeveloperMode = builder.Environment.IsDevelopment();
        options.EnableAdaptiveSampling = true;
        options.EnableQuickPulseMetricStream = true;
        options.EnableAuthenticationTrackingJavaScript = true;
    });
    
    // Custom telemetry processors
    builder.Services.Configure<TelemetryConfiguration>(config =>
    {
        // Add custom processors
        config.DefaultTelemetrySink.TelemetryProcessorChainBuilder
            .Use((next) => new SensitiveDataTelemetryProcessor(next))
            .Use((next) => new PerformanceFilterTelemetryProcessor(next))
            .Use((next) => new UserIdentificationTelemetryProcessor(next))
            .UseAdaptiveSampling(maxTelemetryItemsPerSecond: 5, excludedTypes: "Request;Exception")
            .Build();
    });
    
    var app = builder.Build();
    
    // Custom middleware for enhanced telemetry
    app.UseMiddleware<CorrelationMiddleware>();
    app.UseMiddleware<UserContextMiddleware>();
}
```

#### Custom Telemetry Processors
```csharp
// Filter sensitive data from telemetry
public class SensitiveDataTelemetryProcessor : ITelemetryProcessor
{
    private readonly ITelemetryProcessor _next;
    private readonly HashSet<string> _sensitiveKeys = new(StringComparer.OrdinalIgnoreCase)
    {
        "password", "secret", "key", "token", "authorization", "ssn", "creditcard"
    };
    
    public void Process(ITelemetry item)
    {
        switch (item)
        {
            case RequestTelemetry request:
                SanitizeUrl(request);
                break;
            case TraceTelemetry trace:
                SanitizeMessage(trace);
                break;
            case ExceptionTelemetry exception:
                SanitizeException(exception);
                break;
        }
        
        _next.Process(item);
    }
    
    private void SanitizeUrl(RequestTelemetry request)
    {
        if (request.Url == null) return;
        
        var query = HttpUtility.ParseQueryString(request.Url.Query);
        bool modified = false;
        
        foreach (string key in query.AllKeys)
        {
            if (_sensitiveKeys.Any(sensitive => key.Contains(sensitive)))
            {
                query[key] = "[REDACTED]";
                modified = true;
            }
        }
        
        if (modified)
        {
            var builder = new UriBuilder(request.Url) { Query = query.ToString() };
            request.Url = builder.Uri;
        }
    }
}

// Add user context to all telemetry
public class UserContextTelemetryProcessor : ITelemetryProcessor
{
    private readonly ITelemetryProcessor _next;
    private readonly IHttpContextAccessor _httpContextAccessor;
    
    public void Process(ITelemetry item)
    {
        var httpContext = _httpContextAccessor.HttpContext;
        if (httpContext?.User?.Identity?.IsAuthenticated == true)
        {
            var userId = httpContext.User.FindFirst("sub")?.Value ?? 
                        httpContext.User.Identity.Name;
            var tenantId = httpContext.User.FindFirst("tid")?.Value;
            
            if (item is ISupportProperties telemetryWithProperties)
            {
                if (!string.IsNullOrEmpty(userId))
                    telemetryWithProperties.Properties["UserId"] = userId;
                if (!string.IsNullOrEmpty(tenantId))  
                    telemetryWithProperties.Properties["TenantId"] = tenantId;
            }
        }
        
        _next.Process(item);
    }
}
```

### Performance Monitoring

#### Custom Performance Counters
```csharp
public class BusinessMetrics
{
    private readonly TelemetryClient _telemetryClient;
    private readonly Timer _metricsTimer;
    
    public BusinessMetrics(TelemetryClient telemetryClient)
    {
        _telemetryClient = telemetryClient;
        
        // Collect business metrics every minute
        _metricsTimer = new Timer(CollectMetrics, null, TimeSpan.Zero, TimeSpan.FromMinutes(1));
    }
    
    private void CollectMetrics(object state)
    {
        // Active user sessions
        var activeSessions = GetActiveUserSessions();
        _telemetryClient.TrackMetric("Business.ActiveSessions", activeSessions);
        
        // Queue depths
        var orderQueueDepth = GetOrderQueueDepth();
        _telemetryClient.TrackMetric("Business.OrderQueue.Depth", orderQueueDepth);
        
        // Revenue metrics
        var revenueToday = GetTodaysRevenue();
        _telemetryClient.TrackMetric("Business.Revenue.Daily", revenueToday);
        
        // System health
        var memoryUsage = GC.GetTotalMemory(false) / (1024 * 1024); // MB
        _telemetryClient.TrackMetric("System.Memory.Usage", memoryUsage);
    }
}

// Track business events with rich context
public class OrderService
{
    private readonly TelemetryClient _telemetryClient;
    
    public async Task<Order> ProcessOrderAsync(OrderRequest request)
    {
        using var operation = _telemetryClient.StartOperation<RequestTelemetry>("ProcessOrder");
        operation.Telemetry.Properties["OrderType"] = request.OrderType;
        operation.Telemetry.Properties["CustomerId"] = request.CustomerId;
        operation.Telemetry.Properties["OrderValue"] = request.Total.ToString();
        
        var stopwatch = Stopwatch.StartNew();
        
        try
        {
            // Validate order
            await ValidateOrderAsync(request);
            
            // Process payment
            var paymentResult = await ProcessPaymentAsync(request);
            operation.Telemetry.Properties["PaymentMethod"] = paymentResult.Method;
            operation.Telemetry.Properties["PaymentSuccess"] = paymentResult.Success.ToString();
            
            // Create order
            var order = await CreateOrderAsync(request);
            
            operation.Telemetry.Success = true;
            
            // Track business event
            _telemetryClient.TrackEvent("OrderCompleted", new Dictionary<string, string>
            {
                ["OrderId"] = order.Id.ToString(),
                ["OrderType"] = request.OrderType,
                ["CustomerId"] = request.CustomerId,
                ["PaymentMethod"] = paymentResult.Method,
                ["ProcessingTime"] = stopwatch.ElapsedMilliseconds.ToString()
            }, new Dictionary<string, double>
            {
                ["OrderValue"] = request.Total,
                ["ProcessingDuration"] = stopwatch.ElapsedMilliseconds
            });
            
            return order;
        }
        catch (Exception ex)
        {
            operation.Telemetry.Success = false;
            _telemetryClient.TrackException(ex, new Dictionary<string, string>
            {
                ["OrderType"] = request.OrderType,
                ["CustomerId"] = request.CustomerId,
                ["ProcessingStage"] = GetCurrentProcessingStage()
            });
            throw;
        }
    }
}
```

### Dependency Tracking

#### Custom Dependency Tracking
```csharp
public class ExternalServiceClient
{
    private readonly HttpClient _httpClient;
    private readonly TelemetryClient _telemetryClient;
    
    public async Task<T> CallExternalServiceAsync<T>(string endpoint, object request)
    {
        var dependencyName = "ExternalAPI";
        var dependencyType = "HTTP";
        var target = _httpClient.BaseAddress?.Host ?? "unknown";
        
        using var operation = _telemetryClient.StartOperation<DependencyTelemetry>(
            dependencyName, $"{dependencyType} {endpoint}");
        
        operation.Telemetry.Type = dependencyType;
        operation.Telemetry.Target = target;
        operation.Telemetry.Data = endpoint;
        
        var stopwatch = Stopwatch.StartNew();
        
        try
        {
            var jsonRequest = JsonSerializer.Serialize(request);
            var content = new StringContent(jsonRequest, Encoding.UTF8, "application/json");
            
            var response = await _httpClient.PostAsync(endpoint, content);
            var responseContent = await response.Content.ReadAsStringAsync();
            
            operation.Telemetry.Success = response.IsSuccessStatusCode;
            operation.Telemetry.ResultCode = ((int)response.StatusCode).ToString();
            operation.Telemetry.Properties["RequestSize"] = content.Headers.ContentLength?.ToString() ?? "0";
            operation.Telemetry.Properties["ResponseSize"] = responseContent.Length.ToString();
            
            if (response.IsSuccessStatusCode)
            {
                return JsonSerializer.Deserialize<T>(responseContent);
            }
            else
            {
                throw new HttpRequestException($"External service returned {response.StatusCode}");
            }
        }
        catch (Exception ex)
        {
            operation.Telemetry.Success = false;
            _telemetryClient.TrackException(ex);
            throw;
        }
        finally
        {
            stopwatch.Stop();
            operation.Telemetry.Duration = stopwatch.Elapsed;
        }
    }
}
```

---

## Security Monitoring Best Practices

### Microsoft Sentinel Configuration

#### Data Connectors Priority
```yaml
High Priority Connectors:
  - Azure Active Directory (Sign-ins, Audit, Identity Protection)
  - Azure Activity Logs
  - Azure Security Center
  - Office 365 (if applicable)
  - Windows Security Events (Domain Controllers)

Medium Priority:
  - Network Security Groups (NSG) Flow Logs  
  - Azure Key Vault
  - Azure Storage
  - DNS Logs
  - Threat Intelligence Feeds

Low Priority:
  - Application logs
  - Performance counters
  - Custom security tools
```

#### Analytics Rules

##### Failed Authentication Detection
```kql
// Multiple failed sign-ins followed by success
let FailureThreshold = 5;
let TimeWindow = 10m;
let LookbackPeriod = 1h;

SigninLogs
| where TimeGenerated > ago(LookbackPeriod)
| where ResultType != "0"  // Failed sign-ins
| summarize FailureCount = count(), 
            FailureTimes = make_list(TimeGenerated),
            FirstFailure = min(TimeGenerated),
            LastFailure = max(TimeGenerated)
  by UserPrincipalName, IPAddress, AppDisplayName
| where FailureCount >= FailureThreshold
| where LastFailure > ago(TimeWindow)
| join kind=inner (
    SigninLogs
    | where TimeGenerated > ago(LookbackPeriod)
    | where ResultType == "0"  // Successful sign-ins
    | where TimeGenerated > ago(TimeWindow)
) on UserPrincipalName, IPAddress
| where TimeGenerated > LastFailure
| project-away TimeGenerated1, ResultType1
| extend Alert = "Suspicious authentication pattern detected"
```

##### Privilege Escalation Detection  
```kql
// Detect unusual role assignments
let BaselinePeriod = 30d;
let AlertPeriod = 1h;

// Get baseline of normal role assignment patterns
let Baseline = AuditLogs
| where TimeGenerated between(ago(BaselinePeriod)..ago(AlertPeriod))
| where OperationName has "Add member to role"
| extend Role = tostring(TargetResources[0].displayName)
| extend Assignee = tostring(TargetResources[1].userPrincipalName) 
| extend Assigner = tostring(InitiatedBy.user.userPrincipalName)
| summarize BaselineCount = count() by Role, Assigner, bin(TimeGenerated, 1d)
| summarize AvgDaily = avg(BaselineCount), MaxDaily = max(BaselineCount) by Role, Assigner;

// Check recent activity against baseline
AuditLogs
| where TimeGenerated > ago(AlertPeriod)
| where OperationName has "Add member to role"
| extend Role = tostring(TargetResources[0].displayName)
| extend Assignee = tostring(TargetResources[1].userPrincipalName)
| extend Assigner = tostring(InitiatedBy.user.userPrincipalName)
| summarize RecentCount = count() by Role, Assigner
| join kind=leftanti Baseline on Role, Assigner
| where RecentCount > 0
| extend Alert = "Unusual role assignment activity detected"
```

### Security Automation

#### Automated Response Playbooks
```json
{
  "playbooks": {
    "compromisedAccount": {
      "trigger": "High-risk sign-in detected",
      "actions": [
        {
          "action": "DisableUser",
          "api": "Microsoft Graph",
          "endpoint": "/users/{userId}/accountEnabled",
          "method": "PATCH",
          "body": {"accountEnabled": false}
        },
        {
          "action": "RevokeTokens", 
          "api": "Microsoft Graph",
          "endpoint": "/users/{userId}/revokeSignInSessions",
          "method": "POST"
        },
        {
          "action": "NotifySecurityTeam",
          "type": "email",
          "recipients": ["soc@company.com"],
          "template": "compromised-account-alert"
        },
        {
          "action": "CreateIncident",
          "system": "ServiceNow",
          "priority": "High",
          "category": "Security"
        }
      ]
    },
    "malwareDetection": {
      "trigger": "Malware detected on endpoint",
      "actions": [
        {
          "action": "IsolateDevice",
          "api": "Microsoft Defender",
          "endpoint": "/machines/{machineId}/isolate",
          "method": "POST"
        },
        {
          "action": "CollectForensics",
          "type": "investigation-package",
          "retention": "90 days"
        }
      ]
    }
  }
}
```

This comprehensive best practices guide covers all major aspects of Azure observability implementation, from basic setup to advanced security monitoring and automation.
