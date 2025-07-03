using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;
using Microsoft.AspNetCore.Mvc;
using OrderService.Models;
using OrderService.Services;
using OrderService.Telemetry;

namespace OrderService.Controllers;

[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    private readonly IOrderService _orderService;
    private readonly IPaymentService _paymentService;
    private readonly IInventoryService _inventoryService;
    private readonly ILogger<OrdersController> _logger;
    private readonly TelemetryClient _telemetryClient;
    private readonly IOrderTelemetryClient _orderTelemetryClient;

    public OrdersController(
        IOrderService orderService,
        IPaymentService paymentService,
        IInventoryService inventoryService,
        ILogger<OrdersController> logger,
        TelemetryClient telemetryClient,
        IOrderTelemetryClient orderTelemetryClient)
    {
        _orderService = orderService;
        _paymentService = paymentService;
        _inventoryService = inventoryService;
        _logger = logger;
        _telemetryClient = telemetryClient;
        _orderTelemetryClient = orderTelemetryClient;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<Order>>> GetOrders()
    {
        using var operation = _telemetryClient.StartOperation<RequestTelemetry>("GetOrders");
        
        try
        {
            _logger.LogInformation("Retrieving all orders");
            var orders = await _orderService.GetOrdersAsync();
            
            operation.Telemetry.Properties["orders.count"] = orders.Count().ToString();
            _telemetryClient.TrackMetric("orders.retrieved", orders.Count());
            
            _logger.LogInformation("Retrieved {OrderCount} orders", orders.Count());
            
            return Ok(orders);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving orders");
            operation.Telemetry.Success = false;
            _telemetryClient.TrackException(ex);
            return StatusCode(500, "Error retrieving orders");
        }
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<Order>> GetOrder(int id)
    {
        using var operation = _telemetryClient.StartOperation<RequestTelemetry>("GetOrder");
        operation.Telemetry.Properties["order.id"] = id.ToString();
        
        try
        {
            _logger.LogInformation("Retrieving order {OrderId}", id);
            var order = await _orderService.GetOrderAsync(id);
            
            if (order == null)
            {
                _logger.LogWarning("Order {OrderId} not found", id);
                return NotFound();
            }
            
            operation.Telemetry.Properties["order.status"] = order.Status;
            operation.Telemetry.Properties["order.total"] = order.Total.ToString();
            
            return Ok(order);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving order {OrderId}", id);
            operation.Telemetry.Success = false;
            _telemetryClient.TrackException(ex, new Dictionary<string, string> { ["order.id"] = id.ToString() });
            return StatusCode(500, "Error retrieving order");
        }
    }

    [HttpPost]
    public async Task<ActionResult<Order>> CreateOrder(CreateOrderRequest request)
    {
        using var operation = _telemetryClient.StartOperation<RequestTelemetry>("CreateOrder");
        var stopwatch = System.Diagnostics.Stopwatch.StartNew();
        
        try
        {
            _logger.LogInformation("Creating order for customer {CustomerId} with {ItemCount} items", 
                request.CustomerId, request.Items.Count);
            
            operation.Telemetry.Properties["order.customer_id"] = request.CustomerId;
            operation.Telemetry.Properties["order.items.count"] = request.Items.Count.ToString();
            
            // Step 1: Check inventory
            using var inventoryOperation = _telemetryClient.StartOperation<DependencyTelemetry>("CheckInventory");
            inventoryOperation.Telemetry.Type = "Internal";
            inventoryOperation.Telemetry.Target = "InventoryService";
            
            _logger.LogInformation("Checking inventory for {ItemCount} items", request.Items.Count);
            
            foreach (var item in request.Items)
            {
                var available = await _inventoryService.CheckInventoryAsync(item.ProductId, item.Quantity);
                if (!available)
                {
                    _logger.LogWarning("Insufficient inventory for product {ProductId}", item.ProductId);
                    _orderTelemetryClient.TrackInventoryCheck(item.ProductId, item.Quantity, false);
                    
                    _telemetryClient.TrackEvent("InventoryCheckFailed", new Dictionary<string, string>
                    {
                        ["product.id"] = item.ProductId,
                        ["quantity"] = item.Quantity.ToString(),
                        ["customer.id"] = request.CustomerId
                    });
                    
                    return BadRequest($"Insufficient inventory for product {item.ProductId}");
                }
                
                _orderTelemetryClient.TrackInventoryCheck(item.ProductId, item.Quantity, true);
            }
            
            inventoryOperation.Telemetry.Success = true;
            _logger.LogInformation("Inventory check passed for all items");
            
            // Step 2: Create order
            var order = new Order
            {
                CustomerId = request.CustomerId,
                OrderDate = DateTime.UtcNow,
                Status = "Pending",
                Items = request.Items.Select(i => new OrderItem
                {
                    ProductId = i.ProductId,
                    Quantity = i.Quantity,
                    Price = i.Price
                }).ToList()
            };
            
            order.Total = order.Items.Sum(i => i.Price * i.Quantity);
            
            operation.Telemetry.Properties["order.total"] = order.Total.ToString();
            _orderTelemetryClient.TrackOrderValue(order.Total);
            
            var createdOrder = await _orderService.CreateOrderAsync(order);
            
            // Step 3: Process payment
            using var paymentOperation = _telemetryClient.StartOperation<DependencyTelemetry>("ProcessPayment");
            paymentOperation.Telemetry.Type = "HTTP";
            paymentOperation.Telemetry.Target = "PaymentService";
            
            _logger.LogInformation("Processing payment for order {OrderId} amount {Amount}", 
                createdOrder.Id, order.Total);
            
            paymentOperation.Telemetry.Properties["payment.amount"] = order.Total.ToString();
            paymentOperation.Telemetry.Properties["payment.customer_id"] = request.CustomerId;
            
            _orderTelemetryClient.TrackPaymentAttempt(request.CustomerId, order.Total);
            
            var paymentResult = await _paymentService.ProcessPaymentAsync(new PaymentRequest
            {
                OrderId = createdOrder.Id,
                Amount = order.Total,
                CustomerId = request.CustomerId
            });
            
            if (paymentResult.Success)
            {
                createdOrder.Status = "Paid";
                paymentOperation.Telemetry.Success = true;
                paymentOperation.Telemetry.Properties["payment.status"] = "success";
                
                _telemetryClient.TrackEvent("PaymentSuccess", new Dictionary<string, string>
                {
                    ["order.id"] = createdOrder.Id.ToString(),
                    ["customer.id"] = request.CustomerId,
                    ["amount"] = order.Total.ToString()
                });
                
                _logger.LogInformation("Payment successful for order {OrderId}", createdOrder.Id);
            }
            else
            {
                createdOrder.Status = "PaymentFailed";
                paymentOperation.Telemetry.Success = false;
                paymentOperation.Telemetry.Properties["payment.status"] = "failed";
                paymentOperation.Telemetry.Properties["payment.error"] = paymentResult.ErrorMessage;
                
                _orderTelemetryClient.TrackPaymentFailure(request.CustomerId, order.Total, paymentResult.ErrorMessage);
                
                _telemetryClient.TrackEvent("PaymentFailed", new Dictionary<string, string>
                {
                    ["order.id"] = createdOrder.Id.ToString(),
                    ["customer.id"] = request.CustomerId,
                    ["amount"] = order.Total.ToString(),
                    ["error"] = paymentResult.ErrorMessage ?? "Unknown error"
                });
                
                _logger.LogWarning("Payment failed for order {OrderId}: {Error}", 
                    createdOrder.Id, paymentResult.ErrorMessage);
            }
            
            // Step 4: Update order status
            await _orderService.UpdateOrderAsync(createdOrder);
            
            stopwatch.Stop();
            _orderTelemetryClient.TrackOrderProcessingDuration(stopwatch.Elapsed);
            _orderTelemetryClient.TrackOrderProcessed(createdOrder.Status, request.CustomerId);
            
            operation.Telemetry.Properties["order.final_status"] = createdOrder.Status;
            operation.Telemetry.Metrics["order.processing_duration_ms"] = stopwatch.ElapsedMilliseconds;
            
            _telemetryClient.TrackEvent("OrderCreated", new Dictionary<string, string>
            {
                ["order.id"] = createdOrder.Id.ToString(),
                ["customer.id"] = request.CustomerId,
                ["status"] = createdOrder.Status,
                ["total"] = order.Total.ToString()
            }, new Dictionary<string, double>
            {
                ["processing_duration_ms"] = stopwatch.ElapsedMilliseconds,
                ["order_total"] = order.Total,
                ["item_count"] = request.Items.Count
            });
            
            _logger.LogInformation("Order {OrderId} created successfully with status {Status} in {Duration}ms", 
                createdOrder.Id, createdOrder.Status, stopwatch.ElapsedMilliseconds);
            
            return CreatedAtAction(nameof(GetOrder), new { id = createdOrder.Id }, createdOrder);
        }
        catch (Exception ex)
        {
            stopwatch.Stop();
            _logger.LogError(ex, "Error creating order for customer {CustomerId}", request.CustomerId);
            operation.Telemetry.Success = false;
            
            _telemetryClient.TrackException(ex, new Dictionary<string, string>
            {
                ["customer.id"] = request.CustomerId,
                ["item.count"] = request.Items.Count.ToString()
            });
            
            return StatusCode(500, "Error creating order");
        }
    }

    [HttpPut("{id}/status")]
    public async Task<IActionResult> UpdateOrderStatus(int id, [FromBody] string status)
    {
        using var operation = _telemetryClient.StartOperation<RequestTelemetry>("UpdateOrderStatus");
        operation.Telemetry.Properties["order.id"] = id.ToString();
        operation.Telemetry.Properties["order.new_status"] = status;
        
        try
        {
            _logger.LogInformation("Updating order {OrderId} status to {Status}", id, status);
            
            var order = await _orderService.GetOrderAsync(id);
            if (order == null)
            {
                _logger.LogWarning("Order {OrderId} not found for status update", id);
                return NotFound();
            }
            
            var previousStatus = order.Status;
            order.Status = status;
            await _orderService.UpdateOrderAsync(order);
            
            operation.Telemetry.Properties["order.previous_status"] = previousStatus;
            
            _telemetryClient.TrackEvent("OrderStatusUpdated", new Dictionary<string, string>
            {
                ["order.id"] = id.ToString(),
                ["previous_status"] = previousStatus,
                ["new_status"] = status
            });
            
            _logger.LogInformation("Order {OrderId} status updated from {PreviousStatus} to {NewStatus}", 
                id, previousStatus, status);
            
            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating order {OrderId} status", id);
            operation.Telemetry.Success = false;
            _telemetryClient.TrackException(ex, new Dictionary<string, string> { ["order.id"] = id.ToString() });
            return StatusCode(500, "Error updating order status");
        }
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteOrder(int id)
    {
        using var operation = _telemetryClient.StartOperation<RequestTelemetry>("DeleteOrder");
        operation.Telemetry.Properties["order.id"] = id.ToString();
        
        try
        {
            _logger.LogInformation("Deleting order {OrderId}", id);
            
            var order = await _orderService.GetOrderAsync(id);
            if (order == null)
            {
                _logger.LogWarning("Order {OrderId} not found for deletion", id);
                return NotFound();
            }
            
            await _orderService.DeleteOrderAsync(id);
            
            _telemetryClient.TrackEvent("OrderDeleted", new Dictionary<string, string>
            {
                ["order.id"] = id.ToString(),
                ["customer.id"] = order.CustomerId
            });
            
            _logger.LogInformation("Order {OrderId} deleted successfully", id);
            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting order {OrderId}", id);
            operation.Telemetry.Success = false;
            _telemetryClient.TrackException(ex, new Dictionary<string, string> { ["order.id"] = id.ToString() });
            return StatusCode(500, "Error deleting order");
        }
    }
}
