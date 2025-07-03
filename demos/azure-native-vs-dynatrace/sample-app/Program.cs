using Microsoft.ApplicationInsights;
using Microsoft.EntityFrameworkCore;
using SampleApp.Data;
using SampleApp.Services;
using StackExchange.Redis;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Configure Application Insights (Azure Native)
builder.Services.AddApplicationInsightsTelemetry(options =>
{
    options.ConnectionString = builder.Configuration.GetConnectionString("ApplicationInsights");
    options.EnableDependencyTrackingTelemetryModule = true;
    options.EnablePerformanceCounterCollectionModule = true;
    options.EnableRequestTrackingTelemetryModule = true;
    options.EnableEventCounterCollectionModule = true;
});

// Configure Entity Framework
builder.Services.AddDbContext<SampleDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// Configure Redis
builder.Services.AddSingleton<IConnectionMultiplexer>(provider =>
{
    var connectionString = builder.Configuration.GetConnectionString("Redis");
    return ConnectionMultiplexer.Connect(connectionString);
});

// Add custom services
builder.Services.AddScoped<IOrderService, OrderService>();
builder.Services.AddScoped<IInventoryService, InventoryService>();
builder.Services.AddScoped<INotificationService, NotificationService>();

// Configure HTTP clients for external dependencies
builder.Services.AddHttpClient("PaymentService", client =>
{
    client.BaseAddress = new Uri(builder.Configuration["ExternalServices:PaymentService:BaseUrl"]!);
    client.Timeout = TimeSpan.FromSeconds(30);
});

builder.Services.AddHttpClient("ShippingService", client =>
{
    client.BaseAddress = new Uri(builder.Configuration["ExternalServices:ShippingService:BaseUrl"]!);
    client.Timeout = TimeSpan.FromSeconds(30);
});

// Add health checks
builder.Services.AddHealthChecks()
    .AddDbContext<SampleDbContext>()
    .AddCheck("redis", () =>
    {
        try
        {
            var redis = builder.Services.BuildServiceProvider().GetRequiredService<IConnectionMultiplexer>();
            redis.GetDatabase().Ping();
            return Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckResult.Healthy();
        }
        catch (Exception ex)
        {
            return Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckResult.Unhealthy(ex.Message);
        }
    })
    .AddCheck("external-payment", async () =>
    {
        try
        {
            var httpClient = builder.Services.BuildServiceProvider().GetRequiredService<IHttpClientFactory>().CreateClient("PaymentService");
            var response = await httpClient.GetAsync("/health");
            return response.IsSuccessStatusCode ? 
                Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckResult.Healthy() : 
                Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckResult.Unhealthy();
        }
        catch (Exception ex)
        {
            return Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckResult.Unhealthy(ex.Message);
        }
    });

// Configure logging
builder.Logging.AddApplicationInsights(
    configureTelemetryConfiguration: (config) =>
        config.ConnectionString = builder.Configuration.GetConnectionString("ApplicationInsights"),
    configureApplicationInsightsLoggerOptions: (options) => { }
);

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseAuthorization();

// Add custom middleware for request telemetry
app.UseMiddleware<RequestTelemetryMiddleware>();

// Map controllers
app.MapControllers();

// Map health checks
app.MapHealthChecks("/health");

// Add some sample endpoints for demonstration
app.MapGet("/api/demo/cpu-intensive", async (ILogger<Program> logger) =>
{
    logger.LogInformation("Starting CPU intensive operation");
    
    // Simulate CPU-intensive work
    var start = DateTime.UtcNow;
    var result = 0;
    for (int i = 0; i < 1000000; i++)
    {
        result += i;
    }
    
    var duration = DateTime.UtcNow - start;
    logger.LogInformation("CPU intensive operation completed in {Duration}ms", duration.TotalMilliseconds);
    
    return Results.Ok(new { result, duration = duration.TotalMilliseconds });
});

app.MapGet("/api/demo/memory-intensive", async (ILogger<Program> logger) =>
{
    logger.LogInformation("Starting memory intensive operation");
    
    // Simulate memory-intensive work
    var data = new List<byte[]>();
    for (int i = 0; i < 100; i++)
    {
        data.Add(new byte[1024 * 1024]); // 1MB each
    }
    
    logger.LogInformation("Memory intensive operation completed, allocated {Size}MB", data.Count);
    
    // Clean up
    data.Clear();
    GC.Collect();
    
    return Results.Ok(new { allocated = data.Count });
});

app.MapGet("/api/demo/simulate-error", async (ILogger<Program> logger) =>
{
    logger.LogError("Simulating an error for demo purposes");
    
    // Randomly throw different types of exceptions
    var random = new Random();
    var errorType = random.Next(1, 4);
    
    switch (errorType)
    {
        case 1:
            throw new InvalidOperationException("Simulated invalid operation");
        case 2:
            throw new ArgumentException("Simulated argument error");
        case 3:
            throw new TimeoutException("Simulated timeout error");
        default:
            throw new Exception("Generic simulated error");
    }
});

app.MapGet("/api/demo/external-dependency", async (IHttpClientFactory httpClientFactory, ILogger<Program> logger) =>
{
    logger.LogInformation("Calling external payment service");
    
    try
    {
        var client = httpClientFactory.CreateClient("PaymentService");
        var response = await client.GetAsync("/api/payment/status");
        
        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();
            logger.LogInformation("External service call successful");
            return Results.Ok(new { status = "success", response = content });
        }
        else
        {
            logger.LogWarning("External service call failed with status {StatusCode}", response.StatusCode);
            return Results.Problem("External service call failed");
        }
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "External service call failed with exception");
        return Results.Problem("External service call failed");
    }
});

// Initialize database
using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<SampleDbContext>();
    context.Database.EnsureCreated();
}

app.Run();

// Custom middleware for request telemetry
public class RequestTelemetryMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<RequestTelemetryMiddleware> _logger;
    private readonly TelemetryClient _telemetryClient;

    public RequestTelemetryMiddleware(RequestDelegate next, ILogger<RequestTelemetryMiddleware> logger, TelemetryClient telemetryClient)
    {
        _next = next;
        _logger = logger;
        _telemetryClient = telemetryClient;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var start = DateTime.UtcNow;
        
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Request failed: {Method} {Path}", context.Request.Method, context.Request.Path);
            
            // Track exception in Application Insights
            _telemetryClient.TrackException(ex, new Dictionary<string, string>
            {
                ["RequestMethod"] = context.Request.Method,
                ["RequestPath"] = context.Request.Path,
                ["UserAgent"] = context.Request.Headers["User-Agent"].ToString()
            });
            
            throw;
        }
        finally
        {
            var duration = DateTime.UtcNow - start;
            
            // Track custom metrics
            _telemetryClient.TrackMetric("RequestDuration", duration.TotalMilliseconds, new Dictionary<string, string>
            {
                ["RequestMethod"] = context.Request.Method,
                ["RequestPath"] = context.Request.Path,
                ["StatusCode"] = context.Response.StatusCode.ToString()
            });
            
            _logger.LogInformation("Request completed: {Method} {Path} - {StatusCode} ({Duration}ms)",
                context.Request.Method, context.Request.Path, context.Response.StatusCode, duration.TotalMilliseconds);
        }
    }
}
