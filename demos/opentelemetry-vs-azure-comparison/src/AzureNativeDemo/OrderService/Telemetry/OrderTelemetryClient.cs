using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;

namespace OrderService.Telemetry;

public interface IOrderTelemetryClient
{
    void TrackOrderProcessed(string status, string customerId);
    void TrackOrderProcessingDuration(TimeSpan duration);
    void TrackOrderValue(decimal amount);
    void TrackPaymentAttempt(string customerId, decimal amount);
    void TrackPaymentFailure(string customerId, decimal amount, string? reason);
    void TrackInventoryCheck(string productId, int quantity, bool available);
}

public class OrderTelemetryClient : IOrderTelemetryClient
{
    private readonly TelemetryClient _telemetryClient;

    public OrderTelemetryClient(TelemetryClient telemetryClient)
    {
        _telemetryClient = telemetryClient;
    }

    public void TrackOrderProcessed(string status, string customerId)
    {
        _telemetryClient.TrackMetric("orders.processed", 1, new Dictionary<string, string>
        {
            ["status"] = status,
            ["customer_id"] = customerId
        });
    }

    public void TrackOrderProcessingDuration(TimeSpan duration)
    {
        _telemetryClient.TrackMetric("order.processing.duration", duration.TotalSeconds);
    }

    public void TrackOrderValue(decimal amount)
    {
        _telemetryClient.TrackMetric("order.value", (double)amount);
    }

    public void TrackPaymentAttempt(string customerId, decimal amount)
    {
        _telemetryClient.TrackMetric("payment.attempts", 1, new Dictionary<string, string>
        {
            ["customer_id"] = customerId,
            ["amount"] = amount.ToString()
        });
    }

    public void TrackPaymentFailure(string customerId, decimal amount, string? reason)
    {
        _telemetryClient.TrackMetric("payment.failures", 1, new Dictionary<string, string>
        {
            ["customer_id"] = customerId,
            ["amount"] = amount.ToString(),
            ["reason"] = reason ?? "Unknown"
        });
    }

    public void TrackInventoryCheck(string productId, int quantity, bool available)
    {
        _telemetryClient.TrackMetric("inventory.checks", 1, new Dictionary<string, string>
        {
            ["product_id"] = productId,
            ["quantity"] = quantity.ToString(),
            ["available"] = available.ToString()
        });
    }
}
