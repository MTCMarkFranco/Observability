using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DependencyCollector;
using Microsoft.ApplicationInsights.Extensibility;
using Microsoft.ApplicationInsights.Extensibility.EventCounterCollector;
using Microsoft.ApplicationInsights.Extensibility.PerfCounterCollector;
using Microsoft.EntityFrameworkCore;
using OrderService.Data;
using OrderService.Services;
using OrderService.Telemetry;

namespace OrderService;

public class Program
{
    public static void Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);

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

        // Configure Application Insights
        builder.Services.AddApplicationInsightsTelemetry(options =>
        {
            options.ConnectionString = builder.Configuration.GetConnectionString("ApplicationInsights");
            options.EnableAdaptiveSampling = true;
            options.EnableQuickPulseMetricStream = true;
            options.EnableDependencyTrackingTelemetryModule = true;
            options.EnableRequestTrackingTelemetryModule = true;
            options.EnableEventCounterCollectionModule = true;
            options.EnablePerformanceCounterCollectionModule = true;
            options.EnableHeartbeat = true;
            options.EnableAuthenticationTrackingJavaScript = false;
        });

        // Configure telemetry processors
        builder.Services.AddApplicationInsightsTelemetryProcessor<FilterHealthCheckTelemetryProcessor>();
        builder.Services.AddApplicationInsightsTelemetryProcessor<EnrichmentTelemetryProcessor>();

        // Configure telemetry modules
        builder.Services.ConfigureTelemetryModule<DependencyTrackingTelemetryModule>((module, o) =>
        {
            module.EnableSqlCommandTextInstrumentation = true;
            module.EnableLegacyCorrelationHeadersInjection = true;
        });

        builder.Services.ConfigureTelemetryModule<RequestTrackingTelemetryModule>((module, o) =>
        {
            module.CollectionOptions.TrackExceptions = true;
            module.CollectionOptions.InjectResponseHeaders = true;
        });

        builder.Services.ConfigureTelemetryModule<EventCounterCollectionModule>((module, o) =>
        {
            module.Counters.Add(new EventCounterCollectionRequest("System.Runtime", "cpu-usage"));
            module.Counters.Add(new EventCounterCollectionRequest("System.Runtime", "working-set"));
            module.Counters.Add(new EventCounterCollectionRequest("System.Runtime", "gc-heap-size"));
            module.Counters.Add(new EventCounterCollectionRequest("Microsoft.AspNetCore.Hosting", "requests-per-second"));
            module.Counters.Add(new EventCounterCollectionRequest("Microsoft.AspNetCore.Hosting", "total-requests"));
            module.Counters.Add(new EventCounterCollectionRequest("Microsoft.AspNetCore.Hosting", "current-requests"));
            module.Counters.Add(new EventCounterCollectionRequest("Microsoft.AspNetCore.Hosting", "failed-requests"));
        });

        // Configure telemetry initializers
        builder.Services.AddSingleton<ITelemetryInitializer, CustomTelemetryInitializer>();

        // Configure advanced telemetry features
        builder.Services.Configure<TelemetryConfiguration>(config =>
        {
            config.DefaultTelemetrySink.TelemetryProcessorChainBuilder
                .UseAdaptiveSampling(maxTelemetryItemsPerSecond: 5, excludedTypes: "Event")
                .Build();
        });

        // Add custom telemetry client for business metrics
        builder.Services.AddSingleton<IOrderTelemetryClient, OrderTelemetryClient>();

        // Configure logging to send to Application Insights
        builder.Logging.AddApplicationInsights(
            configureTelemetryConfiguration: (config) =>
            {
                config.ConnectionString = builder.Configuration.GetConnectionString("ApplicationInsights");
            },
            configureApplicationInsightsLoggerOptions: (options) =>
            {
                options.IncludeScopes = true;
                options.TrackExceptionsAsExceptionTelemetry = true;
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
