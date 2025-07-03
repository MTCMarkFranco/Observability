# OpenTelemetry Sample Application Demo

This demo demonstrates how to implement OpenTelemetry in a .NET application and send telemetry data to Azure Monitor and Log Analytics.

## Demo Overview

This sample includes:
- **ASP.NET Core Web API** with OpenTelemetry instrumentation
- **Background Service** for generating sample telemetry
- **Custom Metrics and Traces** for business operations
- **Integration with Azure Monitor** and Application Insights
- **Console Applications** for testing various scenarios

## Prerequisites

- .NET 8 SDK
- Azure subscription with Log Analytics workspace
- Application Insights resource
- Visual Studio Code or Visual Studio 2022

## Project Structure

```
opentelemetry-samples/
├── src/
│   ├── WebApi/                    # Main Web API application
│   ├── BackgroundService/         # Worker service for background tasks
│   ├── ConsoleApp/               # Console app for testing
│   └── Shared/                   # Shared libraries and utilities
├── docker/
│   ├── Dockerfile
│   └── docker-compose.yml
├── k8s/                          # Kubernetes manifests
└── docs/                         # Additional documentation
```

## Step 1: Create the Solution

```powershell
# Create solution structure
mkdir opentelemetry-samples
cd opentelemetry-samples

# Create solution file
dotnet new sln -n OpenTelemetrySamples

# Create projects
dotnet new webapi -n WebApi -o src/WebApi
dotnet new worker -n BackgroundService -o src/BackgroundService  
dotnet new console -n ConsoleApp -o src/ConsoleApp
dotnet new classlib -n Shared -o src/Shared

# Add projects to solution
dotnet sln add src/WebApi/WebApi.csproj
dotnet sln add src/BackgroundService/BackgroundService.csproj
dotnet sln add src/ConsoleApp/ConsoleApp.csproj
dotnet sln add src/Shared/Shared.csproj

# Add project references
dotnet add src/WebApi/WebApi.csproj reference src/Shared/Shared.csproj
dotnet add src/BackgroundService/BackgroundService.csproj reference src/Shared/Shared.csproj
dotnet add src/ConsoleApp/ConsoleApp.csproj reference src/Shared/Shared.csproj
```

## Step 2: Configure Shared Observability Library

### Package References for Shared Project

```xml
<!-- src/Shared/Shared.csproj -->
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="OpenTelemetry" Version="1.7.0" />
    <PackageReference Include="OpenTelemetry.Extensions.Hosting" Version="1.7.0" />
    <PackageReference Include="OpenTelemetry.Instrumentation.AspNetCore" Version="1.7.1" />
    <PackageReference Include="OpenTelemetry.Instrumentation.Http" Version="1.7.1" />
    <PackageReference Include="OpenTelemetry.Instrumentation.SqlClient" Version="1.7.0-beta.1" />
    <PackageReference Include="OpenTelemetry.Instrumentation.Runtime" Version="1.7.0" />
    <PackageReference Include="OpenTelemetry.Instrumentation.Process" Version="0.5.0-beta.4" />
    <PackageReference Include="Azure.Monitor.OpenTelemetry.Exporter" Version="1.2.0" />
    <PackageReference Include="Microsoft.ApplicationInsights.AspNetCore" Version="2.21.0" />
    <PackageReference Include="Microsoft.Extensions.Hosting" Version="8.0.0" />
    <PackageReference Include="Microsoft.Extensions.Logging" Version="8.0.0" />
    <PackageReference Include="Microsoft.Extensions.Configuration" Version="8.0.0" />
  </ItemGroup>

</Project>
```

### Observability Configuration Extensions

```csharp
// src/Shared/ObservabilityExtensions.cs
using System.Diagnostics;
using System.Diagnostics.Metrics;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using OpenTelemetry;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

namespace Shared;

public static class ObservabilityExtensions
{
    public static IServiceCollection AddObservability(
        this IServiceCollection services,
        IConfiguration configuration,
        string serviceName,
        string serviceVersion = "1.0.0")
    {
        var connectionString = configuration.GetConnectionString("ApplicationInsights");
        var environment = configuration["Environment"] ?? "Development";
        var teamName = configuration["TeamName"] ?? "Platform";

        // Add Application Insights (for backward compatibility and additional features)
        services.AddApplicationInsightsTelemetry(options =>
        {
            options.ConnectionString = connectionString;
        });

        // Configure OpenTelemetry
        services.AddOpenTelemetry()
            .ConfigureResource(resource => resource
                .AddService(serviceName, serviceVersion)
                .AddAttributes(new Dictionary<string, object>
                {
                    ["deployment.environment"] = environment,
                    ["service.team"] = teamName,
                    ["service.language"] = "dotnet",
                    ["telemetry.sdk.name"] = "opentelemetry",
                    ["telemetry.sdk.language"] = "dotnet",
                    ["telemetry.sdk.version"] = "1.7.0"
                }))
            .WithTracing(tracing => tracing
                .AddAspNetCoreInstrumentation(options =>
                {
                    options.RecordException = true;
                    options.EnableGrpcAspNetCoreSupport = true;
                    options.Filter = (httpContext) =>
                    {
                        // Don't trace health checks and metrics endpoints
                        var path = httpContext.Request.Path.Value;
                        return !path?.Contains("/health") == true && 
                               !path?.Contains("/metrics") == true;
                    };
                    options.Enrich = (activity, eventName, rawObject) =>
                    {
                        if (eventName == "OnStartActivity" && rawObject is HttpRequest request)
                        {
                            activity.SetTag("http.client_ip", 
                                request.Headers["X-Forwarded-For"].FirstOrDefault() ?? 
                                request.HttpContext.Connection.RemoteIpAddress?.ToString());
                            
                            if (request.Headers.ContainsKey("User-Agent"))
                            {
                                activity.SetTag("http.user_agent", request.Headers["User-Agent"].ToString());
                            }
                        }
                    };
                })
                .AddHttpClientInstrumentation(options =>
                {
                    options.RecordException = true;
                    options.FilterHttpRequestMessage = (request) =>
                    {
                        // Don't trace calls to telemetry endpoints
                        return !request.RequestUri?.Host.Contains("dc.services.visualstudio.com") == true;
                    };
                    options.EnrichWithHttpRequestMessage = (activity, request) =>
                    {
                        activity.SetTag("http.request.method", request.Method.ToString());
                        activity.SetTag("http.url", request.RequestUri?.ToString());
                    };
                })
                .AddSqlClientInstrumentation(options =>
                {
                    options.SetDbStatementForText = true;
                    options.RecordException = true;
                    options.EnableConnectionLevelAttributes = true;
                })
                .AddSource(BusinessMetrics.ActivitySourceName)
                .AddSource("MyCompany.*") // Add all company activity sources
                .AddConsoleExporter() // For development
                .AddAzureMonitorTraceExporter())
            .WithMetrics(metrics => metrics
                .AddAspNetCoreInstrumentation()
                .AddHttpClientInstrumentation()
                .AddRuntimeInstrumentation()
                .AddProcessInstrumentation()
                .AddMeter(BusinessMetrics.MeterName)
                .AddMeter("MyCompany.*") // Add all company meters
                .AddConsoleExporter() // For development
                .AddAzureMonitorMetricExporter());

        // Register custom telemetry services
        services.AddSingleton<BusinessMetrics>();
        services.AddSingleton<TelemetryEnricher>();
        
        return services;
    }
}

// Custom business metrics
public class BusinessMetrics
{
    public const string ActivitySourceName = "MyCompany.BusinessOperations";
    public const string MeterName = "MyCompany.BusinessMetrics";
    
    private static readonly ActivitySource ActivitySource = new(ActivitySourceName);
    private static readonly Meter Meter = new(MeterName);
    
    // Counters
    private static readonly Counter<int> OrdersProcessed = 
        Meter.CreateCounter<int>("orders_processed_total", 
            description: "Total number of orders processed");
    
    private static readonly Counter<int> PaymentsProcessed = 
        Meter.CreateCounter<int>("payments_processed_total",
            description: "Total number of payments processed");
    
    // Histograms
    private static readonly Histogram<double> OrderProcessingDuration = 
        Meter.CreateHistogram<double>("order_processing_duration_ms",
            description: "Time taken to process an order in milliseconds");
    
    private static readonly Histogram<double> OrderValue = 
        Meter.CreateHistogram<double>("order_value_usd",
            description: "Value of processed orders in USD");
    
    // Up/Down Counters
    private static readonly UpDownCounter<int> ActiveSessions = 
        Meter.CreateUpDownCounter<int>("active_user_sessions",
            description: "Number of active user sessions");
    
    // Gauges (using callbacks)
    private static readonly ObservableGauge<int> QueueDepth = 
        Meter.CreateObservableGauge<int>("message_queue_depth",
            description: "Current depth of the message queue");
    
    public BusinessMetrics()
    {
        // Register gauge callback
        Meter.CreateObservableGauge<double>("memory_usage_percentage", 
            () => GC.GetTotalMemory(false) / (1024.0 * 1024.0),
            description: "Current memory usage in MB");
    }
    
    public Activity? StartOrderProcessing(string orderId, string orderType)
    {
        var activity = ActivitySource.StartActivity("ProcessOrder");
        activity?.SetTag("order.id", orderId);
        activity?.SetTag("order.type", orderType);
        activity?.SetTag("operation.type", "order-processing");
        return activity;
    }
    
    public void RecordOrderProcessed(string orderType, double durationMs, double orderValue)
    {
        var tags = new KeyValuePair<string, object?>[]
        {
            new("order.type", orderType)
        };
        
        OrdersProcessed.Add(1, tags);
        OrderProcessingDuration.Record(durationMs, tags);
        OrderValue.Record(orderValue, tags);
    }
    
    public void RecordPaymentProcessed(string paymentMethod, bool success)
    {
        var tags = new KeyValuePair<string, object?>[]
        {
            new("payment.method", paymentMethod),
            new("payment.success", success.ToString())
        };
        
        PaymentsProcessed.Add(1, tags);
    }
    
    public void IncrementActiveSessions() => ActiveSessions.Add(1);
    public void DecrementActiveSessions() => ActiveSessions.Add(-1);
}

// Telemetry enricher for adding contextual information
public class TelemetryEnricher
{
    private readonly ILogger<TelemetryEnricher> _logger;
    
    public TelemetryEnricher(ILogger<TelemetryEnricher> logger)
    {
        _logger = logger;
    }
    
    public void EnrichWithUserContext(Activity? activity, string? userId, string? tenantId = null)
    {
        if (activity == null) return;
        
        if (!string.IsNullOrEmpty(userId))
        {
            activity.SetTag("user.id", userId);
            activity.SetBaggage("user.id", userId);
        }
        
        if (!string.IsNullOrEmpty(tenantId))
        {
            activity.SetTag("tenant.id", tenantId);
            activity.SetBaggage("tenant.id", tenantId);
        }
    }
    
    public void EnrichWithBusinessContext(Activity? activity, Dictionary<string, object> context)
    {
        if (activity == null) return;
        
        foreach (var kvp in context)
        {
            activity.SetTag($"business.{kvp.Key}", kvp.Value?.ToString());
        }
    }
}
```

## Step 3: Web API Implementation

### Web API Project Configuration

```xml
<!-- src/WebApi/WebApi.csproj -->
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.OpenApi" Version="8.0.0" />
    <PackageReference Include="Swashbuckle.AspNetCore" Version="6.4.0" />
    <PackageReference Include="Microsoft.EntityFrameworkCore.InMemory" Version="8.0.0" />
    <PackageReference Include="Microsoft.AspNetCore.Diagnostics.HealthChecks" Version="2.2.0" />
    <PackageReference Include="AspNetCore.HealthChecks.UI.Client" Version="8.0.1" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="../Shared/Shared.csproj" />
  </ItemGroup>

</Project>
```

### Program.cs

```csharp
// src/WebApi/Program.cs
using Shared;
using WebApi.Models;
using WebApi.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using HealthChecks.UI.Client;
using System.Diagnostics;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Add Entity Framework with In-Memory database for demo
builder.Services.AddDbContext<OrderContext>(options =>
    options.UseInMemoryDatabase("OrdersDb"));

// Add business services
builder.Services.AddScoped<OrderService>();
builder.Services.AddScoped<PaymentService>();
builder.Services.AddHttpClient<ExternalApiService>();

// Add health checks
builder.Services.AddHealthChecks()
    .AddCheck("self", () => Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckResult.Healthy())
    .AddDbContextCheck<OrderContext>();

// Add observability
builder.Services.AddObservability(
    builder.Configuration,
    "OrderManagement.WebApi",
    "1.0.0");

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseAuthorization();

// Health checks endpoint
app.MapHealthChecks("/health", new HealthCheckOptions
{
    ResponseWriter = UIResponseWriter.WriteHealthCheckUIResponse
});

app.MapControllers();

// Add some sample data
using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<OrderContext>();
    SeedData.Initialize(context);
}

app.Run();
```

### Sample Controller with OpenTelemetry

```csharp
// src/WebApi/Controllers/OrdersController.cs
using Microsoft.AspNetCore.Mvc;
using WebApi.Models;
using WebApi.Services;
using Shared;
using System.Diagnostics;

namespace WebApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    private readonly OrderService _orderService;
    private readonly PaymentService _paymentService;
    private readonly BusinessMetrics _businessMetrics;
    private readonly TelemetryEnricher _telemetryEnricher;
    private readonly ILogger<OrdersController> _logger;

    public OrdersController(
        OrderService orderService,
        PaymentService paymentService,
        BusinessMetrics businessMetrics,
        TelemetryEnricher telemetryEnricher,
        ILogger<OrdersController> logger)
    {
        _orderService = orderService;
        _paymentService = paymentService;
        _businessMetrics = businessMetrics;
        _telemetryEnricher = telemetryEnricher;
        _logger = logger;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<Order>>> GetOrders()
    {
        using var activity = _businessMetrics.StartOrderProcessing("list-orders", "query");
        var stopwatch = Stopwatch.StartNew();
        
        try
        {
            _logger.LogInformation("Retrieving all orders");
            
            var orders = await _orderService.GetOrdersAsync();
            
            activity?.SetTag("orders.count", orders.Count());
            activity?.SetStatus(ActivityStatusCode.Ok);
            
            _logger.LogInformation("Retrieved {OrderCount} orders", orders.Count());
            
            return Ok(orders);
        }
        catch (Exception ex)
        {
            activity?.RecordException(ex);
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            
            _logger.LogError(ex, "Failed to retrieve orders");
            return StatusCode(500, "Failed to retrieve orders");
        }
        finally
        {
            stopwatch.Stop();
            _businessMetrics.RecordOrderProcessed("query", stopwatch.ElapsedMilliseconds, 0);
        }
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<Order>> GetOrder(int id)
    {
        using var activity = _businessMetrics.StartOrderProcessing(id.ToString(), "lookup");
        var stopwatch = Stopwatch.StartNew();
        
        try
        {
            activity?.SetTag("order.id", id);
            _telemetryEnricher.EnrichWithBusinessContext(activity, new Dictionary<string, object>
            {
                ["operation.category"] = "order-lookup",
                ["request.source"] = "api"
            });
            
            _logger.LogInformation("Retrieving order {OrderId}", id);
            
            var order = await _orderService.GetOrderAsync(id);
            
            if (order == null)
            {
                activity?.SetTag("order.found", false);
                activity?.SetStatus(ActivityStatusCode.Ok, "Order not found");
                
                _logger.LogWarning("Order {OrderId} not found", id);
                return NotFound();
            }
            
            activity?.SetTag("order.found", true);
            activity?.SetTag("order.value", order.Total);
            activity?.SetTag("order.status", order.Status);
            activity?.SetStatus(ActivityStatusCode.Ok);
            
            _logger.LogInformation("Retrieved order {OrderId} with status {OrderStatus}", 
                id, order.Status);
            
            return Ok(order);
        }
        catch (Exception ex)
        {
            activity?.RecordException(ex);
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            
            _logger.LogError(ex, "Failed to retrieve order {OrderId}", id);
            return StatusCode(500, "Failed to retrieve order");
        }
        finally
        {
            stopwatch.Stop();
            _businessMetrics.RecordOrderProcessed("lookup", stopwatch.ElapsedMilliseconds, 0);
        }
    }

    [HttpPost]
    public async Task<ActionResult<Order>> CreateOrder(CreateOrderRequest request)
    {
        using var activity = _businessMetrics.StartOrderProcessing("new-order", request.OrderType);
        var stopwatch = Stopwatch.StartNew();
        
        try
        {
            activity?.SetTag("order.type", request.OrderType);
            activity?.SetTag("order.initial_value", request.Total);
            activity?.SetTag("customer.id", request.CustomerId);
            
            // Simulate user context (in real app, this would come from authentication)
            _telemetryEnricher.EnrichWithUserContext(activity, request.CustomerId, "tenant-123");
            
            _logger.LogInformation("Creating new order for customer {CustomerId}", request.CustomerId);
            
            // Validate request
            if (request.Total <= 0)
            {
                activity?.SetTag("validation.error", "invalid_total");
                activity?.SetStatus(ActivityStatusCode.Error, "Invalid order total");
                
                _logger.LogWarning("Invalid order total {Total} for customer {CustomerId}", 
                    request.Total, request.CustomerId);
                return BadRequest("Order total must be greater than 0");
            }
            
            // Create order
            var order = await _orderService.CreateOrderAsync(request);
            
            activity?.SetTag("order.id", order.Id);
            activity?.SetTag("order.created", true);
            
            // Process payment if required
            if (request.ProcessPayment)
            {
                using var paymentActivity = _businessMetrics.StartOrderProcessing(
                    order.Id.ToString(), "payment");
                
                paymentActivity?.SetTag("payment.method", request.PaymentMethod ?? "default");
                paymentActivity?.SetTag("payment.amount", request.Total);
                
                try
                {
                    var paymentResult = await _paymentService.ProcessPaymentAsync(
                        order.Id, request.Total, request.PaymentMethod ?? "credit_card");
                    
                    if (paymentResult.Success)
                    {
                        order.Status = "Paid";
                        await _orderService.UpdateOrderAsync(order);
                        
                        paymentActivity?.SetTag("payment.success", true);
                        paymentActivity?.SetStatus(ActivityStatusCode.Ok);
                        
                        _businessMetrics.RecordPaymentProcessed(
                            request.PaymentMethod ?? "credit_card", true);
                    }
                    else
                    {
                        paymentActivity?.SetTag("payment.success", false);
                        paymentActivity?.SetTag("payment.error", paymentResult.ErrorMessage);
                        paymentActivity?.SetStatus(ActivityStatusCode.Error, paymentResult.ErrorMessage);
                        
                        _businessMetrics.RecordPaymentProcessed(
                            request.PaymentMethod ?? "credit_card", false);
                        
                        order.Status = "Payment Failed";
                        await _orderService.UpdateOrderAsync(order);
                    }
                }
                catch (Exception paymentEx)
                {
                    paymentActivity?.RecordException(paymentEx);
                    paymentActivity?.SetStatus(ActivityStatusCode.Error, paymentEx.Message);
                    
                    _businessMetrics.RecordPaymentProcessed(
                        request.PaymentMethod ?? "credit_card", false);
                    throw;
                }
            }
            
            activity?.SetStatus(ActivityStatusCode.Ok);
            
            _logger.LogInformation("Created order {OrderId} for customer {CustomerId} with status {OrderStatus}", 
                order.Id, request.CustomerId, order.Status);
            
            return CreatedAtAction(nameof(GetOrder), new { id = order.Id }, order);
        }
        catch (Exception ex)
        {
            activity?.RecordException(ex);
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            
            _logger.LogError(ex, "Failed to create order for customer {CustomerId}", request.CustomerId);
            return StatusCode(500, "Failed to create order");
        }
        finally
        {
            stopwatch.Stop();
            _businessMetrics.RecordOrderProcessed(request.OrderType, 
                stopwatch.ElapsedMilliseconds, request.Total);
        }
    }

    [HttpPost("{id}/process")]
    public async Task<ActionResult> ProcessOrder(int id)
    {
        using var activity = _businessMetrics.StartOrderProcessing(id.ToString(), "processing");
        var stopwatch = Stopwatch.StartNew();
        
        try
        {
            activity?.SetTag("order.id", id);
            activity?.SetTag("operation.type", "order-processing");
            
            _logger.LogInformation("Processing order {OrderId}", id);
            
            var order = await _orderService.GetOrderAsync(id);
            if (order == null)
            {
                activity?.SetTag("order.found", false);
                activity?.SetStatus(ActivityStatusCode.Error, "Order not found");
                return NotFound();
            }
            
            activity?.SetTag("order.current_status", order.Status);
            
            // Simulate processing steps
            await SimulateOrderValidation(id);
            await SimulateInventoryCheck(id);
            await SimulateShippingArrangement(id);
            
            order.Status = "Processed";
            await _orderService.UpdateOrderAsync(order);
            
            activity?.SetTag("order.final_status", order.Status);
            activity?.SetStatus(ActivityStatusCode.Ok);
            
            _logger.LogInformation("Successfully processed order {OrderId}", id);
            
            return Ok(new { message = "Order processed successfully", orderId = id });
        }
        catch (Exception ex)
        {
            activity?.RecordException(ex);
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            
            _logger.LogError(ex, "Failed to process order {OrderId}", id);
            return StatusCode(500, "Failed to process order");
        }
        finally
        {
            stopwatch.Stop();
            _businessMetrics.RecordOrderProcessed("processing", stopwatch.ElapsedMilliseconds, 0);
        }
    }
    
    private async Task SimulateOrderValidation(int orderId)
    {
        using var activity = Activity.Current?.Source.StartActivity("ValidateOrder");
        activity?.SetTag("order.id", orderId);
        activity?.SetTag("validation.type", "business-rules");
        
        // Simulate validation work
        await Task.Delay(Random.Shared.Next(100, 500));
        
        // Simulate occasional validation failures
        if (Random.Shared.NextDouble() < 0.05) // 5% failure rate
        {
            var error = "Business rule validation failed";
            activity?.SetStatus(ActivityStatusCode.Error, error);
            throw new InvalidOperationException(error);
        }
        
        activity?.SetStatus(ActivityStatusCode.Ok);
    }
    
    private async Task SimulateInventoryCheck(int orderId)
    {
        using var activity = Activity.Current?.Source.StartActivity("CheckInventory");
        activity?.SetTag("order.id", orderId);
        activity?.SetTag("check.type", "inventory-availability");
        
        // Simulate inventory check
        await Task.Delay(Random.Shared.Next(200, 800));
        
        var itemsAvailable = Random.Shared.Next(1, 100);
        activity?.SetTag("inventory.items_available", itemsAvailable);
        
        if (itemsAvailable < 5)
        {
            var warning = "Low inventory detected";
            activity?.SetStatus(ActivityStatusCode.Ok, warning);
            _logger.LogWarning("Low inventory for order {OrderId}: {ItemsAvailable} items", 
                orderId, itemsAvailable);
        }
        else
        {
            activity?.SetStatus(ActivityStatusCode.Ok);
        }
    }
    
    private async Task SimulateShippingArrangement(int orderId)
    {
        using var activity = Activity.Current?.Source.StartActivity("ArrangeShipping");
        activity?.SetTag("order.id", orderId);
        activity?.SetTag("shipping.type", "standard");
        
        // Simulate shipping arrangement
        await Task.Delay(Random.Shared.Next(300, 1000));
        
        var trackingNumber = $"TRK{Random.Shared.Next(100000, 999999)}";
        activity?.SetTag("shipping.tracking_number", trackingNumber);
        activity?.SetTag("shipping.carrier", "DemoShipping");
        activity?.SetStatus(ActivityStatusCode.Ok);
        
        _logger.LogInformation("Arranged shipping for order {OrderId} with tracking {TrackingNumber}", 
            orderId, trackingNumber);
    }
}
```

Run this demo to see comprehensive OpenTelemetry telemetry flowing to Azure Monitor!

## Next Steps

1. **Run the Application** - Start the Web API and generate sample traffic
2. **View in Azure Monitor** - Check Application Insights for traces and metrics
3. **Create Dashboards** - Build workbooks using the custom telemetry
4. **Add More Instruments** - Extend with additional business metrics
5. **Test Error Scenarios** - Trigger exceptions to see error tracking
