using System.Diagnostics;
using System.Diagnostics.Metrics;
using Microsoft.EntityFrameworkCore;
using OpenTelemetry;
using OpenTelemetry.Logs;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using OrderService.Data;
using OrderService.Services;
using Serilog;

namespace OrderService;

public class Program
{
    public static void Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);

        // Configure Serilog for structured logging
        Log.Logger = new LoggerConfiguration()
            .ReadFrom.Configuration(builder.Configuration)
            .Enrich.FromLogContext()
            .WriteTo.Console()
            .WriteTo.OpenTelemetry(options =>
            {
                options.Endpoint = builder.Configuration["OpenTelemetry:Endpoint"] ?? "http://localhost:4317";
                options.Protocol = Serilog.Sinks.OpenTelemetry.OtlpProtocol.Grpc;
                options.IncludedData = Serilog.Sinks.OpenTelemetry.IncludedData.TraceIdField | 
                                     Serilog.Sinks.OpenTelemetry.IncludedData.SpanIdField;
            })
            .CreateLogger();

        builder.Host.UseSerilog();

        // Add services to the container
        builder.Services.AddControllers();
        builder.Services.AddEndpointsApiExplorer();
        builder.Services.AddSwaggerGen();

        // Add Entity Framework
        builder.Services.AddDbContext<OrderDbContext>(options =>
            options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

        // Add custom services
        builder.Services.AddScoped<IOrderService, Services.OrderService>();
        builder.Services.AddScoped<IPaymentService, PaymentService>();
        builder.Services.AddScoped<IInventoryService, InventoryService>();
        builder.Services.AddHttpClient<IPaymentService, PaymentService>(client =>
        {
            client.BaseAddress = new Uri(builder.Configuration["Services:PaymentService:BaseUrl"] ?? "http://localhost:5001");
        });

        // Configure OpenTelemetry
        var serviceName = "order-service";
        var serviceVersion = "1.0.0";
        var environment = builder.Environment.EnvironmentName;

        builder.Services.AddOpenTelemetry()
            .WithTracing(tracingBuilder =>
            {
                tracingBuilder
                    .SetResourceBuilder(ResourceBuilder.CreateDefault()
                        .AddService(serviceName, serviceVersion)
                        .AddAttributes(new Dictionary<string, object>
                        {
                            ["deployment.environment"] = environment,
                            ["service.version"] = serviceVersion,
                            ["host.name"] = Environment.MachineName,
                            ["service.instance.id"] = Environment.MachineName + "-" + Environment.ProcessId
                        }))
                    .AddAspNetCoreInstrumentation(options =>
                    {
                        options.RecordException = true;
                        options.Filter = (httpContext) => 
                            !httpContext.Request.Path.Value?.Contains("health", StringComparison.OrdinalIgnoreCase) == true;
                        options.EnrichWithHttpRequest = (activity, httpRequest) =>
                        {
                            activity.SetTag("http.request.body.size", httpRequest.ContentLength);
                            activity.SetTag("http.request.user_agent", httpRequest.Headers.UserAgent.ToString());
                        };
                        options.EnrichWithHttpResponse = (activity, httpResponse) =>
                        {
                            activity.SetTag("http.response.body.size", httpResponse.ContentLength);
                        };
                    })
                    .AddHttpClientInstrumentation(options =>
                    {
                        options.RecordException = true;
                        options.FilterHttpRequestMessage = (httpRequestMessage) =>
                            !httpRequestMessage.RequestUri?.AbsolutePath.Contains("health", StringComparison.OrdinalIgnoreCase) == true;
                    })
                    .AddEntityFrameworkCoreInstrumentation(options =>
                    {
                        options.SetDbStatementForText = true;
                        options.SetDbStatementForStoredProcedure = true;
                    })
                    .AddSource("OrderService")
                    .AddConsoleExporter()
                    .AddOtlpExporter(options =>
                    {
                        options.Endpoint = new Uri(builder.Configuration["OpenTelemetry:Endpoint"] ?? "http://localhost:4317");
                    });
            })
            .WithMetrics(metricsBuilder =>
            {
                metricsBuilder
                    .SetResourceBuilder(ResourceBuilder.CreateDefault()
                        .AddService(serviceName, serviceVersion))
                    .AddAspNetCoreInstrumentation()
                    .AddHttpClientInstrumentation()
                    .AddRuntimeInstrumentation()
                    .AddProcessInstrumentation()
                    .AddMeter("OrderService")
                    .AddConsoleExporter()
                    .AddOtlpExporter(options =>
                    {
                        options.Endpoint = new Uri(builder.Configuration["OpenTelemetry:Endpoint"] ?? "http://localhost:4317");
                    });
            });

        // Add logging with OpenTelemetry
        builder.Logging.ClearProviders();
        builder.Logging.AddOpenTelemetry(options =>
        {
            options.IncludeScopes = true;
            options.ParseStateValues = true;
            options.IncludeFormattedMessage = true;
            options.SetResourceBuilder(ResourceBuilder.CreateDefault()
                .AddService(serviceName, serviceVersion));
        });

        var app = builder.Build();

        // Configure the HTTP request pipeline
        if (app.Environment.IsDevelopment())
        {
            app.UseSwagger();
            app.UseSwaggerUI();
        }

        app.UseHttpsRedirection();
        app.UseAuthorization();
        app.MapControllers();

        // Health check endpoint
        app.MapGet("/health", () => Results.Ok(new { Status = "Healthy", Timestamp = DateTime.UtcNow }));

        // Initialize database
        using (var scope = app.Services.CreateScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<OrderDbContext>();
            context.Database.EnsureCreated();
        }

        app.Run();
    }
}

// Custom ActivitySource for manual instrumentation
public static class Telemetry
{
    public static readonly ActivitySource ActivitySource = new("OrderService");
    public static readonly Meter Meter = new("OrderService");
    
    // Custom metrics
    public static readonly Counter<long> OrdersProcessed = Meter.CreateCounter<long>(
        "orders_processed_total",
        "The total number of orders processed");
    
    public static readonly Histogram<double> OrderProcessingDuration = Meter.CreateHistogram<double>(
        "order_processing_duration_seconds",
        "The duration of order processing in seconds");
    
    public static readonly Counter<long> PaymentAttempts = Meter.CreateCounter<long>(
        "payment_attempts_total",
        "The total number of payment attempts");
    
    public static readonly Counter<long> PaymentFailures = Meter.CreateCounter<long>(
        "payment_failures_total",
        "The total number of payment failures");
    
    public static readonly Gauge<double> OrderValue = Meter.CreateGauge<double>(
        "order_value_dollars",
        "The value of orders in dollars");
    
    public static readonly Counter<long> InventoryChecks = Meter.CreateCounter<long>(
        "inventory_checks_total",
        "The total number of inventory checks");
}
