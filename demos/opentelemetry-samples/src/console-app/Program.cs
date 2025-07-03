using System.Diagnostics;
using System.Diagnostics.Metrics;
using Microsoft.Extensions.Logging;
using OpenTelemetry;
using OpenTelemetry.Logs;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

namespace ObservabilityDemo.OpenTelemetry;

public class Program
{
    private static readonly ActivitySource ActivitySource = new("ObservabilityDemo");
    private static readonly Meter Meter = new("ObservabilityDemo");
    private static readonly Counter<long> RequestCounter = Meter.CreateCounter<long>("requests_total");
    private static readonly Histogram<double> RequestDuration = Meter.CreateHistogram<double>("request_duration_seconds");

    public static async Task Main(string[] args)
    {
        // Configure OpenTelemetry
        using var tracerProvider = Sdk.CreateTracerProviderBuilder()
            .AddSource("ObservabilityDemo")
            .SetResourceBuilder(ResourceBuilder.CreateDefault()
                .AddService("observability-demo", "1.0.0")
                .AddAttributes(new Dictionary<string, object>
                {
                    ["deployment.environment"] = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "development",
                    ["service.version"] = "1.0.0"
                }))
            .AddConsoleExporter()
            .AddAzureMonitorTraceExporter(options =>
            {
                options.ConnectionString = Environment.GetEnvironmentVariable("APPLICATIONINSIGHTS_CONNECTION_STRING");
            })
            .Build();

        using var meterProvider = Sdk.CreateMeterProviderBuilder()
            .AddMeter("ObservabilityDemo")
            .SetResourceBuilder(ResourceBuilder.CreateDefault()
                .AddService("observability-demo", "1.0.0"))
            .AddConsoleExporter()
            .AddAzureMonitorMetricExporter(options =>
            {
                options.ConnectionString = Environment.GetEnvironmentVariable("APPLICATIONINSIGHTS_CONNECTION_STRING");
            })
            .Build();

        using var loggerFactory = LoggerFactory.Create(builder =>
            builder.AddOpenTelemetry(options =>
            {
                options.SetResourceBuilder(ResourceBuilder.CreateDefault()
                    .AddService("observability-demo", "1.0.0"));
                options.AddConsoleExporter();
                options.AddAzureMonitorLogExporter(options =>
                {
                    options.ConnectionString = Environment.GetEnvironmentVariable("APPLICATIONINSIGHTS_CONNECTION_STRING");
                });
            }));

        var logger = loggerFactory.CreateLogger<Program>();

        // Simulate application workflow
        logger.LogInformation("Application starting");

        for (int i = 0; i < 10; i++)
        {
            await ProcessOrderAsync(logger, i + 1);
            await Task.Delay(1000);
        }

        logger.LogInformation("Application completed");
    }

    private static async Task ProcessOrderAsync(ILogger logger, int orderId)
    {
        using var activity = ActivitySource.StartActivity("ProcessOrder");
        activity?.SetTag("order.id", orderId);
        activity?.SetTag("order.type", "standard");

        var stopwatch = Stopwatch.StartNew();

        try
        {
            logger.LogInformation("Processing order {OrderId}", orderId);

            // Increment request counter
            RequestCounter.Add(1, new KeyValuePair<string, object?>("operation", "process_order"));

            // Simulate order validation
            await ValidateOrderAsync(orderId);

            // Simulate payment processing
            await ProcessPaymentAsync(orderId);

            // Simulate inventory update
            await UpdateInventoryAsync(orderId);

            // Simulate order completion
            await CompleteOrderAsync(orderId);

            activity?.SetStatus(ActivityStatusCode.Ok);
            logger.LogInformation("Order {OrderId} processed successfully", orderId);
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.RecordException(ex);
            logger.LogError(ex, "Failed to process order {OrderId}", orderId);
            throw;
        }
        finally
        {
            stopwatch.Stop();
            RequestDuration.Record(stopwatch.Elapsed.TotalSeconds, 
                new KeyValuePair<string, object?>("operation", "process_order"));
        }
    }

    private static async Task ValidateOrderAsync(int orderId)
    {
        using var activity = ActivitySource.StartActivity("ValidateOrder");
        activity?.SetTag("order.id", orderId);

        // Simulate validation delay
        await Task.Delay(Random.Shared.Next(100, 500));

        // Simulate occasional validation failures
        if (Random.Shared.Next(1, 11) == 1)
        {
            throw new InvalidOperationException($"Order {orderId} validation failed");
        }

        activity?.SetTag("validation.result", "success");
    }

    private static async Task ProcessPaymentAsync(int orderId)
    {
        using var activity = ActivitySource.StartActivity("ProcessPayment");
        activity?.SetTag("order.id", orderId);
        activity?.SetTag("payment.method", "credit_card");

        // Simulate external payment service call
        await SimulateExternalServiceCallAsync("PaymentService", 200, 800);

        var amount = Random.Shared.Next(10, 1000);
        activity?.SetTag("payment.amount", amount);
        activity?.SetTag("payment.currency", "USD");
    }

    private static async Task UpdateInventoryAsync(int orderId)
    {
        using var activity = ActivitySource.StartActivity("UpdateInventory");
        activity?.SetTag("order.id", orderId);

        // Simulate database update
        await SimulateExternalServiceCallAsync("DatabaseUpdate", 50, 200);

        var itemsUpdated = Random.Shared.Next(1, 5);
        activity?.SetTag("inventory.items_updated", itemsUpdated);
    }

    private static async Task CompleteOrderAsync(int orderId)
    {
        using var activity = ActivitySource.StartActivity("CompleteOrder");
        activity?.SetTag("order.id", orderId);

        // Simulate notification sending
        await SimulateExternalServiceCallAsync("NotificationService", 100, 300);

        activity?.SetTag("notification.sent", true);
        activity?.SetTag("order.status", "completed");
    }

    private static async Task SimulateExternalServiceCallAsync(string serviceName, int minDelay, int maxDelay)
    {
        using var activity = ActivitySource.StartActivity($"Call {serviceName}");
        activity?.SetTag("service.name", serviceName);
        activity?.SetTag("span.kind", "client");

        var delay = Random.Shared.Next(minDelay, maxDelay);
        await Task.Delay(delay);

        // Simulate occasional service failures
        if (Random.Shared.Next(1, 21) == 1)
        {
            activity?.SetStatus(ActivityStatusCode.Error, $"{serviceName} temporarily unavailable");
            throw new HttpRequestException($"{serviceName} returned 503 Service Unavailable");
        }

        activity?.SetTag("http.status_code", 200);
        activity?.SetTag("http.response_size", Random.Shared.Next(100, 1000));
    }
}

// Custom telemetry extensions
public static class TelemetryExtensions
{
    public static void RecordException(this Activity? activity, Exception exception)
    {
        if (activity == null) return;

        activity.SetTag("exception.type", exception.GetType().Name);
        activity.SetTag("exception.message", exception.Message);
        activity.SetTag("exception.stacktrace", exception.StackTrace);
    }

    public static void AddBusinessMetrics(this Activity? activity, string operation, double value)
    {
        if (activity == null) return;

        activity.SetTag($"business.{operation}.value", value);
        activity.SetTag($"business.{operation}.timestamp", DateTimeOffset.UtcNow.ToUnixTimeSeconds());
    }
}
