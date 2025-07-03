# OpenTelemetry Integration with Azure

## Overview

OpenTelemetry is an open-source observability framework that provides standardized APIs, libraries, and instrumentation for collecting telemetry data. This session covers integrating OpenTelemetry with Azure Monitor and Application Insights.

---

## What is OpenTelemetry?

OpenTelemetry (OTel) provides:
- **Standardized APIs** - Consistent telemetry collection across languages
- **Auto-instrumentation** - Automatic telemetry for popular libraries
- **Vendor Agnostic** - Send data to multiple observability backends
- **Rich Context** - Distributed tracing with correlation
- **Custom Instrumentation** - Application-specific telemetry

---

## OpenTelemetry Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Code                         │
│                                                             │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │
│ │    API      │ │    SDK      │ │    Auto-Instrumentation │ │
│ │             │ │             │ │                         │ │
│ │ • Tracing   │ │ • Resource  │ │ • HTTP clients         │ │
│ │ • Metrics   │ │ • Sampling  │ │ • Database drivers     │ │
│ │ • Logging   │ │ • Batching  │ │ • Message queues       │ │
│ └─────────────┘ └─────────────┘ └─────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              OpenTelemetry Collector                       │
│                                                             │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │
│ │ Receivers   │ │ Processors  │ │      Exporters         │ │
│ │             │ │             │ │                         │ │
│ │ • OTLP      │ │ • Filtering │ │ • Azure Monitor        │ │
│ │ • Jaeger    │ │ • Sampling  │ │ • Application Insights │ │
│ │ • Zipkin    │ │ • Batching  │ │ • Prometheus           │ │
│ │ • Prometheus│ │ • Transform │ │ • Custom backends      │ │
│ └─────────────┘ └─────────────┘ └─────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                 Observability Backends                     │
│                                                             │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │
│ │   Azure     │ │ Application │ │     Other Backends     │ │
│ │  Monitor    │ │  Insights   │ │                         │ │
│ │             │ │             │ │ • Jaeger               │ │
│ │ • Metrics   │ │ • Traces    │ │ • Prometheus           │ │
│ │ • Logs      │ │ • Metrics   │ │ • Grafana              │ │
│ │ • Alerts    │ │ • Events    │ │ • Custom systems       │ │
│ └─────────────┘ └─────────────┘ └─────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## .NET OpenTelemetry Implementation

### Basic Setup
```csharp
// Program.cs
using OpenTelemetry;
using OpenTelemetry.Trace;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;

var builder = WebApplication.CreateBuilder(args);

// Configure OpenTelemetry
builder.Services.AddOpenTelemetry()
    .ConfigureResource(resource => resource
        .AddService("MyWebApi", "1.0.0")
        .AddAttributes(new Dictionary<string, object>
        {
            ["environment"] = builder.Environment.EnvironmentName,
            ["team"] = "platform-team"
        }))
    .WithTracing(tracing => tracing
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddSqlClientInstrumentation()
        .AddAzureMonitorTraceExporter())
    .WithMetrics(metrics => metrics
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddRuntimeInstrumentation()
        .AddAzureMonitorMetricExporter());

var app = builder.Build();
```

### Custom Tracing
```csharp
using System.Diagnostics;
using OpenTelemetry.Trace;

public class OrderService
{
    private static readonly ActivitySource ActivitySource = new("MyCompany.OrderService");
    
    public async Task<Order> ProcessOrderAsync(string orderId)
    {
        using var activity = ActivitySource.StartActivity("ProcessOrder");
        activity?.SetTag("order.id", orderId);
        activity?.SetTag("operation.type", "order-processing");
        
        try
        {
            // Simulate order validation
            using var validationActivity = ActivitySource.StartActivity("ValidateOrder");
            validationActivity?.SetTag("validation.type", "business-rules");
            
            await ValidateOrderAsync(orderId);
            validationActivity?.SetStatus(ActivityStatusCode.Ok);
            
            // Simulate payment processing
            using var paymentActivity = ActivitySource.StartActivity("ProcessPayment");
            paymentActivity?.SetTag("payment.provider", "stripe");
            
            var paymentResult = await ProcessPaymentAsync(orderId);
            paymentActivity?.SetTag("payment.amount", paymentResult.Amount);
            paymentActivity?.SetStatus(ActivityStatusCode.Ok);
            
            activity?.SetStatus(ActivityStatusCode.Ok);
            activity?.SetTag("order.status", "completed");
            
            return new Order { Id = orderId, Status = "Completed" };
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.RecordException(ex);
            throw;
        }
    }
}

// Register the ActivitySource
builder.Services.AddOpenTelemetry()
    .WithTracing(tracing => tracing
        .AddSource("MyCompany.OrderService"));
```

### Custom Metrics
```csharp
using System.Diagnostics.Metrics;

public class OrderMetrics
{
    private static readonly Meter Meter = new("MyCompany.OrderService");
    
    private static readonly Counter<int> OrdersProcessed = 
        Meter.CreateCounter<int>("orders_processed_total", 
            description: "Total number of orders processed");
    
    private static readonly Histogram<double> OrderProcessingDuration = 
        Meter.CreateHistogram<double>("order_processing_duration_ms",
            description: "Time taken to process an order");
    
    private static readonly UpDownCounter<int> ActiveOrders = 
        Meter.CreateUpDownCounter<int>("active_orders",
            description: "Number of orders currently being processed");
    
    public void RecordOrderProcessed(string orderType, double durationMs)
    {
        OrdersProcessed.Add(1, new KeyValuePair<string, object?>("order_type", orderType));
        OrderProcessingDuration.Record(durationMs, 
            new KeyValuePair<string, object?>("order_type", orderType));
    }
    
    public void IncrementActiveOrders() => ActiveOrders.Add(1);
    public void DecrementActiveOrders() => ActiveOrders.Add(-1);
}

// Register the meter
builder.Services.AddOpenTelemetry()
    .WithMetrics(metrics => metrics
        .AddMeter("MyCompany.OrderService"));
```

---

## Node.js OpenTelemetry Implementation

### Basic Setup
```typescript
// instrumentation.ts
import { NodeSDK } from '@opentelemetry/sdk-node';
import { AzureMonitorTraceExporter } from '@azure/monitor-opentelemetry-exporter';
import { AzureMonitorMetricExporter } from '@azure/monitor-opentelemetry-exporter';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'my-node-api',
    [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
    [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: process.env.NODE_ENV,
  }),
  traceExporter: new AzureMonitorTraceExporter({
    connectionString: process.env.APPLICATIONINSIGHTS_CONNECTION_STRING,
  }),
  metricReader: new AzureMonitorMetricExporter({
    connectionString: process.env.APPLICATIONINSIGHTS_CONNECTION_STRING,
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();
```

### Custom Tracing
```typescript
import { trace, context, SpanStatusCode } from '@opentelemetry/api';

const tracer = trace.getTracer('my-service', '1.0.0');

export class UserService {
  async createUser(userData: UserData): Promise<User> {
    return tracer.startActiveSpan('UserService.createUser', async (span) => {
      span.setAttributes({
        'user.email': userData.email,
        'user.role': userData.role,
        'operation.type': 'user-creation'
      });
      
      try {
        // Validate user data
        const validationSpan = tracer.startSpan('ValidateUserData', {
          parent: span
        });
        
        await this.validateUserData(userData);
        validationSpan.setStatus({ code: SpanStatusCode.OK });
        validationSpan.end();
        
        // Create user in database
        const dbSpan = tracer.startSpan('Database.CreateUser', {
          parent: span,
          attributes: {
            'db.operation': 'INSERT',
            'db.table': 'users'
          }
        });
        
        const user = await this.userRepository.create(userData);
        
        dbSpan.setAttributes({
          'db.rows_affected': 1,
          'user.id': user.id
        });
        dbSpan.setStatus({ code: SpanStatusCode.OK });
        dbSpan.end();
        
        span.setAttributes({
          'user.id': user.id,
          'operation.result': 'success'
        });
        span.setStatus({ code: SpanStatusCode.OK });
        
        return user;
      } catch (error) {
        span.recordException(error as Error);
        span.setStatus({
          code: SpanStatusCode.ERROR,
          message: (error as Error).message
        });
        throw error;
      } finally {
        span.end();
      }
    });
  }
}
```

---

## Python OpenTelemetry Implementation

### Basic Setup
```python
# instrumentation.py
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.resources import Resource
from opentelemetry.exporter.azuremonitor import AzureMonitorTraceExporter, AzureMonitorMetricsExporter
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor

# Configure resource
resource = Resource.create({
    "service.name": "my-python-api",
    "service.version": "1.0.0",
    "deployment.environment": os.getenv("ENVIRONMENT", "development")
})

# Configure tracing
trace.set_tracer_provider(TracerProvider(resource=resource))
tracer_provider = trace.get_tracer_provider()

azure_monitor_exporter = AzureMonitorTraceExporter(
    connection_string=os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING")
)

tracer_provider.add_span_processor(
    BatchSpanProcessor(azure_monitor_exporter)
)

# Configure metrics
metrics.set_meter_provider(MeterProvider(resource=resource))
meter_provider = metrics.get_meter_provider()

metrics_exporter = AzureMonitorMetricsExporter(
    connection_string=os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING")
)

# Auto-instrumentation
RequestsInstrumentor().instrument()
FlaskInstrumentor().instrument()
SQLAlchemyInstrumentor().instrument()
```

### Custom Tracing
```python
from opentelemetry import trace
from opentelemetry.trace import Status, StatusCode

tracer = trace.get_tracer(__name__)

class OrderProcessor:
    def __init__(self):
        self.meter = metrics.get_meter(__name__)
        self.orders_processed = self.meter.create_counter(
            "orders_processed_total",
            description="Total number of orders processed"
        )
        self.processing_duration = self.meter.create_histogram(
            "order_processing_duration_seconds",
            description="Time taken to process orders"
        )
    
    async def process_order(self, order_id: str) -> Order:
        with tracer.start_as_current_span("process_order") as span:
            span.set_attributes({
                "order.id": order_id,
                "operation.type": "order_processing"
            })
            
            start_time = time.time()
            
            try:
                # Validate order
                with tracer.start_as_current_span("validate_order") as validate_span:
                    validate_span.set_attribute("validation.type", "business_rules")
                    order = await self.validate_order(order_id)
                    validate_span.set_status(Status(StatusCode.OK))
                
                # Process payment
                with tracer.start_as_current_span("process_payment") as payment_span:
                    payment_span.set_attributes({
                        "payment.provider": "stripe",
                        "payment.amount": order.amount
                    })
                    payment_result = await self.process_payment(order)
                    payment_span.set_status(Status(StatusCode.OK))
                
                # Record metrics
                duration = time.time() - start_time
                self.orders_processed.add(1, {"order_type": order.type})
                self.processing_duration.record(duration, {"order_type": order.type})
                
                span.set_attributes({
                    "order.status": "completed",
                    "processing.duration_seconds": duration
                })
                span.set_status(Status(StatusCode.OK))
                
                return order
                
            except Exception as e:
                span.record_exception(e)
                span.set_status(Status(StatusCode.ERROR, str(e)))
                raise
```

---

## OpenTelemetry Collector Configuration

### Basic Collector Config
```yaml
# otel-collector.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
  
  prometheus:
    config:
      scrape_configs:
        - job_name: 'app-metrics'
          static_configs:
            - targets: ['localhost:8080']

processors:
  batch:
    timeout: 1s
    send_batch_size: 1024
  
  resource:
    attributes:
      - key: environment
        value: production
        action: upsert
  
  memory_limiter:
    limit_mib: 512

exporters:
  azuremonitor:
    connection_string: "${APPLICATIONINSIGHTS_CONNECTION_STRING}"
  
  prometheus:
    endpoint: "0.0.0.0:8889"
  
  logging:
    loglevel: debug

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, resource, batch]
      exporters: [azuremonitor, logging]
    
    metrics:
      receivers: [otlp, prometheus]
      processors: [memory_limiter, resource, batch]
      exporters: [azuremonitor, prometheus]
  
  extensions: [health_check, pprof, zpages]
```

### Advanced Processing
```yaml
processors:
  # Sampling configuration
  probabilistic_sampler:
    sampling_percentage: 10.0
  
  # Attribute filtering
  attributes:
    actions:
      - key: credit_card_number
        action: delete
      - key: environment
        value: production
        action: upsert
  
  # Span filtering
  span:
    name:
      exclude:
        match_type: regexp
        regexp: '.*health.*'
  
  # Resource detection
  resourcedetection:
    detectors: [env, azure]
    timeout: 2s
```

---

## Distributed Tracing Patterns

### Correlation Across Services
```csharp
// Service A
public async Task<string> CallServiceB(string data)
{
    using var activity = ActivitySource.StartActivity("CallServiceB");
    activity?.SetTag("service.name", "service-b");
    activity?.SetTag("request.data", data);
    
    // OpenTelemetry automatically propagates trace context
    var response = await _httpClient.PostAsync("/api/process", 
        new StringContent(data));
    
    activity?.SetTag("response.status", (int)response.StatusCode);
    return await response.Content.ReadAsStringAsync();
}

// Service B
[HttpPost("/api/process")]
public async Task<IActionResult> ProcessData([FromBody] string data)
{
    // Trace context is automatically extracted
    using var activity = ActivitySource.StartActivity("ProcessData");
    activity?.SetTag("data.length", data.Length);
    
    // Process data...
    return Ok(result);
}
```

### Baggage for Cross-Cutting Concerns
```csharp
using OpenTelemetry.Context.Propagation;

// Set baggage at request entry point
Baggage.SetBaggage("user.id", userId);
Baggage.SetBaggage("tenant.id", tenantId);
Baggage.SetBaggage("correlation.id", correlationId);

// Access baggage in downstream services
public void ProcessOrder()
{
    var userId = Baggage.GetBaggage("user.id");
    var tenantId = Baggage.GetBaggage("tenant.id");
    
    using var activity = ActivitySource.StartActivity("ProcessOrder");
    activity?.SetTag("user.id", userId);
    activity?.SetTag("tenant.id", tenantId);
    
    // Process with context...
}
```

---

## Sampling Strategies

### Probabilistic Sampling
```csharp
// Fixed percentage sampling
builder.Services.AddOpenTelemetry()
    .WithTracing(tracing => tracing
        .SetSampler(new TraceIdRatioBasedSampler(0.1))); // 10% sampling
```

### Custom Sampling
```csharp
public class CustomSampler : Sampler
{
    public override SamplingResult ShouldSample(in SamplingParameters samplingParameters)
    {
        // Sample all errors
        if (samplingParameters.Tags.Any(tag => 
            tag.Key == "error" && tag.Value?.ToString() == "true"))
        {
            return SamplingResult.Create(SamplingDecision.RecordAndSample);
        }
        
        // Sample critical operations
        if (samplingParameters.Name.Contains("Critical"))
        {
            return SamplingResult.Create(SamplingDecision.RecordAndSample);
        }
        
        // Default low sampling for other operations
        return Random.Shared.NextDouble() < 0.05 
            ? SamplingResult.Create(SamplingDecision.RecordAndSample)
            : SamplingResult.Create(SamplingDecision.Drop);
    }
}
```

---

## Performance Considerations

### Instrumentation Overhead
```csharp
// Conditional instrumentation
public class ConditionalInstrumentation
{
    private static readonly bool IsTracingEnabled = 
        Environment.GetEnvironmentVariable("OTEL_TRACES_ENABLED") == "true";
    
    public void ProcessRequest(string requestId)
    {
        if (IsTracingEnabled)
        {
            using var activity = ActivitySource.StartActivity("ProcessRequest");
            activity?.SetTag("request.id", requestId);
            
            DoWork();
        }
        else
        {
            DoWork();
        }
    }
}

// Lazy attribute evaluation
activity?.SetTag("expensive.calculation", () => ExpensiveCalculation());
```

### Batching and Buffering
```csharp
builder.Services.AddOpenTelemetry()
    .WithTracing(tracing => tracing
        .AddProcessor(new BatchProcessor<Activity>(
            new AzureMonitorTraceExporter(),
            maxQueueSize: 2048,
            scheduledDelayMilliseconds: 5000,
            exporterTimeoutMilliseconds: 30000,
            maxExportBatchSize: 512)));
```

---

## Best Practices

### Instrumentation Guidelines
1. **Meaningful Span Names** - Use operation-focused names
2. **Appropriate Attributes** - Add business context
3. **Error Handling** - Record exceptions and error status
4. **Performance Impact** - Monitor instrumentation overhead

### Attribute Standards
```csharp
// Follow semantic conventions
activity?.SetTag("http.method", "POST");
activity?.SetTag("http.url", requestUrl);
activity?.SetTag("http.status_code", 200);
activity?.SetTag("db.operation", "SELECT");
activity?.SetTag("db.statement", query);
activity?.SetTag("messaging.system", "azure-servicebus");
```

### Security Considerations
```csharp
// Sanitize sensitive data
public class SensitiveDataProcessor : BaseProcessor<Activity>
{
    private readonly HashSet<string> _sensitiveKeys = new()
    {
        "password", "token", "key", "secret", "credit_card"
    };
    
    public override void OnStart(Activity activity)
    {
        // Remove sensitive attributes
        foreach (var tag in activity.Tags.ToList())
        {
            if (_sensitiveKeys.Any(key => tag.Key.Contains(key, StringComparison.OrdinalIgnoreCase)))
            {
                activity.SetTag(tag.Key, "[REDACTED]");
            }
        }
    }
}
```

---

## Integration with Azure Services

### Application Insights Integration
```csharp
// Dual exporting to maintain Application Insights features
builder.Services.AddOpenTelemetry()
    .WithTracing(tracing => tracing
        .AddAzureMonitorTraceExporter() // OpenTelemetry to Azure Monitor
        .AddApplicationInsights());      // Application Insights SDK features
```

### Azure Monitor Workbooks
```kql
// Query OpenTelemetry traces in Azure Monitor
AppTraces
| where OperationName contains "ProcessOrder"
| extend OrderId = tostring(Properties.["order.id"])
| extend Duration = todouble(Properties.["duration"])
| summarize avg(Duration) by bin(TimeGenerated, 5m), OrderId
| render timechart
```

---

## Troubleshooting

### Common Issues
1. **Missing Traces** - Check exporter configuration
2. **High Overhead** - Review sampling settings
3. **Context Loss** - Verify propagation headers
4. **Export Failures** - Monitor exporter health

### Diagnostic Tools
```csharp
// Enable OpenTelemetry diagnostics
using var tracerProvider = TracerProviderBuilder.Create()
    .SetSampler(new AlwaysOnSampler())
    .AddSource("MyApp")
    .AddConsoleExporter() // For debugging
    .AddAzureMonitorTraceExporter()
    .Build();

// Monitor export success
var processor = new BatchProcessor<Activity>(
    new AzureMonitorTraceExporter(),
    onExportProcessed: (exportResult) =>
    {
        Console.WriteLine($"Export result: {exportResult}");
    });
```

---

## Next Steps

1. **Choose Implementation** - Select language and framework
2. **Configure Exporters** - Set up Azure Monitor integration
3. **Add Instrumentation** - Implement custom telemetry
4. **Deploy Collector** - Set up centralized collection
5. **Monitor Performance** - Optimize sampling and processing
6. **Standardize Practices** - Establish team conventions
