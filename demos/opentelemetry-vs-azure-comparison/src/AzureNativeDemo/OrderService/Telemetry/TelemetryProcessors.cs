using Microsoft.ApplicationInsights.Channel;
using Microsoft.ApplicationInsights.DataContracts;
using Microsoft.ApplicationInsights.Extensibility;

namespace OrderService.Telemetry;

/// <summary>
/// Filters out health check telemetry to reduce noise
/// </summary>
public class FilterHealthCheckTelemetryProcessor : ITelemetryProcessor
{
    private readonly ITelemetryProcessor _next;

    public FilterHealthCheckTelemetryProcessor(ITelemetryProcessor next)
    {
        _next = next;
    }

    public void Process(ITelemetry item)
    {
        if (item is RequestTelemetry request)
        {
            if (request.Url?.AbsolutePath?.Contains("/health", StringComparison.OrdinalIgnoreCase) == true)
            {
                // Skip health check requests
                return;
            }
        }

        if (item is DependencyTelemetry dependency)
        {
            if (dependency.Target?.Contains("health", StringComparison.OrdinalIgnoreCase) == true)
            {
                // Skip health check dependencies
                return;
            }
        }

        _next.Process(item);
    }
}

/// <summary>
/// Adds custom enrichment to telemetry
/// </summary>
public class EnrichmentTelemetryProcessor : ITelemetryProcessor
{
    private readonly ITelemetryProcessor _next;

    public EnrichmentTelemetryProcessor(ITelemetryProcessor next)
    {
        _next = next;
    }

    public void Process(ITelemetry item)
    {
        // Add custom properties to all telemetry
        if (item is ISupportProperties telemetryWithProperties)
        {
            if (!telemetryWithProperties.Properties.ContainsKey("service.name"))
            {
                telemetryWithProperties.Properties["service.name"] = "order-service";
            }
            
            if (!telemetryWithProperties.Properties.ContainsKey("service.version"))
            {
                telemetryWithProperties.Properties["service.version"] = "1.0.0";
            }
        }

        // Add custom metrics for specific operations
        if (item is RequestTelemetry request)
        {
            // Add response time categories
            if (request.Duration.TotalMilliseconds > 5000)
            {
                request.Properties["performance.category"] = "slow";
            }
            else if (request.Duration.TotalMilliseconds > 1000)
            {
                request.Properties["performance.category"] = "medium";
            }
            else
            {
                request.Properties["performance.category"] = "fast";
            }
        }

        _next.Process(item);
    }
}

/// <summary>
/// Initializes telemetry with environment information
/// </summary>
public class CustomTelemetryInitializer : ITelemetryInitializer
{
    public void Initialize(ITelemetry telemetry)
    {
        if (telemetry is ISupportProperties telemetryWithProperties)
        {
            // Add environment information
            telemetryWithProperties.Properties["deployment.environment"] = 
                Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Unknown";
            
            telemetryWithProperties.Properties["host.name"] = Environment.MachineName;
            
            telemetryWithProperties.Properties["service.instance.id"] = 
                Environment.MachineName + "-" + Environment.ProcessId;
        }

        // Set cloud role name for Application Map
        if (telemetry.Context.Cloud.RoleName == null)
        {
            telemetry.Context.Cloud.RoleName = "order-service";
        }

        // Set cloud role instance
        if (telemetry.Context.Cloud.RoleInstance == null)
        {
            telemetry.Context.Cloud.RoleInstance = Environment.MachineName;
        }
    }
}
