using Microsoft.AspNetCore.Mvc;
using Microsoft.ApplicationInsights;
using SampleApp.Models;
using SampleApp.Services;

namespace SampleApp.Controllers;

[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    private readonly IOrderService _orderService;
    private readonly IInventoryService _inventoryService;
    private readonly INotificationService _notificationService;
    private readonly ILogger<OrdersController> _logger;
    private readonly TelemetryClient _telemetryClient;

    public OrdersController(
        IOrderService orderService,
        IInventoryService inventoryService,
        INotificationService notificationService,
        ILogger<OrdersController> logger,
        TelemetryClient telemetryClient)
    {
        _orderService = orderService;
        _inventoryService = inventoryService;
        _notificationService = notificationService;
        _logger = logger;
        _telemetryClient = telemetryClient;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<Order>>> GetOrders()
    {
        _logger.LogInformation("Fetching all orders");
        
        var stopwatch = System.Diagnostics.Stopwatch.StartNew();
        
        try
        {
            var orders = await _orderService.GetAllOrdersAsync();
            
            stopwatch.Stop();
            _telemetryClient.TrackMetric("OrdersRetrievalTime", stopwatch.ElapsedMilliseconds);
            _telemetryClient.TrackMetric("OrdersCount", orders.Count());
            
            _logger.LogInformation("Successfully fetched {Count} orders in {Duration}ms", 
                orders.Count(), stopwatch.ElapsedMilliseconds);
            
            return Ok(orders);
        }
        catch (Exception ex)
        {
            stopwatch.Stop();
            _logger.LogError(ex, "Failed to fetch orders");
            _telemetryClient.TrackException(ex);
            return StatusCode(500, "Failed to fetch orders");
        }
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<Order>> GetOrder(int id)
    {
        _logger.LogInformation("Fetching order {OrderId}", id);
        
        var stopwatch = System.Diagnostics.Stopwatch.StartNew();
        
        try
        {
            var order = await _orderService.GetOrderByIdAsync(id);
            
            stopwatch.Stop();
            _telemetryClient.TrackMetric("OrderRetrievalTime", stopwatch.ElapsedMilliseconds);
            
            if (order == null)
            {
                _logger.LogWarning("Order {OrderId} not found", id);
                _telemetryClient.TrackEvent("OrderNotFound", new Dictionary<string, string>
                {
                    ["OrderId"] = id.ToString()
                });
                return NotFound();
            }

            _logger.LogInformation("Successfully fetched order {OrderId} in {Duration}ms", 
                id, stopwatch.ElapsedMilliseconds);
            
            return Ok(order);
        }
        catch (Exception ex)
        {
            stopwatch.Stop();
            _logger.LogError(ex, "Failed to fetch order {OrderId}", id);
            _telemetryClient.TrackException(ex, new Dictionary<string, string>
            {
                ["OrderId"] = id.ToString()
            });
            return StatusCode(500, "Failed to fetch order");
        }
    }

    [HttpPost]
    public async Task<ActionResult<Order>> CreateOrder(CreateOrderRequest request)
    {
        _logger.LogInformation("Creating new order for customer {CustomerId}", request.CustomerId);
        
        var stopwatch = System.Diagnostics.Stopwatch.StartNew();
        
        try
        {
            // Check inventory
            var inventoryAvailable = await _inventoryService.CheckInventoryAsync(request.ProductId, request.Quantity);
            
            if (!inventoryAvailable)
            {
                _logger.LogWarning("Insufficient inventory for product {ProductId}, quantity {Quantity}", 
                    request.ProductId, request.Quantity);
                
                _telemetryClient.TrackEvent("InsufficientInventory", new Dictionary<string, string>
                {
                    ["ProductId"] = request.ProductId.ToString(),
                    ["RequestedQuantity"] = request.Quantity.ToString(),
                    ["CustomerId"] = request.CustomerId.ToString()
                });
                
                return BadRequest("Insufficient inventory");
            }

            // Reserve inventory
            await _inventoryService.ReserveInventoryAsync(request.ProductId, request.Quantity);
            
            // Create order
            var order = new Order
            {
                CustomerId = request.CustomerId,
                ProductId = request.ProductId,
                Quantity = request.Quantity,
                Status = OrderStatus.Pending,
                CreatedAt = DateTime.UtcNow
            };

            var createdOrder = await _orderService.CreateOrderAsync(order);
            
            // Send notification
            await _notificationService.SendOrderConfirmationAsync(createdOrder);
            
            stopwatch.Stop();
            
            _telemetryClient.TrackMetric("OrderCreationTime", stopwatch.ElapsedMilliseconds);
            _telemetryClient.TrackEvent("OrderCreated", new Dictionary<string, string>
            {
                ["OrderId"] = createdOrder.Id.ToString(),
                ["CustomerId"] = createdOrder.CustomerId.ToString(),
                ["ProductId"] = createdOrder.ProductId.ToString(),
                ["Quantity"] = createdOrder.Quantity.ToString()
            });
            
            _logger.LogInformation("Successfully created order {OrderId} for customer {CustomerId} in {Duration}ms", 
                createdOrder.Id, createdOrder.CustomerId, stopwatch.ElapsedMilliseconds);
            
            return CreatedAtAction(nameof(GetOrder), new { id = createdOrder.Id }, createdOrder);
        }
        catch (Exception ex)
        {
            stopwatch.Stop();
            _logger.LogError(ex, "Failed to create order for customer {CustomerId}", request.CustomerId);
            _telemetryClient.TrackException(ex, new Dictionary<string, string>
            {
                ["CustomerId"] = request.CustomerId.ToString(),
                ["ProductId"] = request.ProductId.ToString()
            });
            return StatusCode(500, "Failed to create order");
        }
    }

    [HttpPut("{id}/status")]
    public async Task<ActionResult> UpdateOrderStatus(int id, UpdateOrderStatusRequest request)
    {
        _logger.LogInformation("Updating order {OrderId} status to {Status}", id, request.Status);
        
        var stopwatch = System.Diagnostics.Stopwatch.StartNew();
        
        try
        {
            var order = await _orderService.GetOrderByIdAsync(id);
            
            if (order == null)
            {
                _logger.LogWarning("Order {OrderId} not found for status update", id);
                return NotFound();
            }

            var oldStatus = order.Status;
            await _orderService.UpdateOrderStatusAsync(id, request.Status);
            
            stopwatch.Stop();
            
            _telemetryClient.TrackMetric("OrderStatusUpdateTime", stopwatch.ElapsedMilliseconds);
            _telemetryClient.TrackEvent("OrderStatusUpdated", new Dictionary<string, string>
            {
                ["OrderId"] = id.ToString(),
                ["OldStatus"] = oldStatus.ToString(),
                ["NewStatus"] = request.Status.ToString()
            });
            
            _logger.LogInformation("Successfully updated order {OrderId} status from {OldStatus} to {NewStatus} in {Duration}ms", 
                id, oldStatus, request.Status, stopwatch.ElapsedMilliseconds);
            
            return Ok();
        }
        catch (Exception ex)
        {
            stopwatch.Stop();
            _logger.LogError(ex, "Failed to update order {OrderId} status", id);
            _telemetryClient.TrackException(ex, new Dictionary<string, string>
            {
                ["OrderId"] = id.ToString(),
                ["Status"] = request.Status.ToString()
            });
            return StatusCode(500, "Failed to update order status");
        }
    }

    [HttpDelete("{id}")]
    public async Task<ActionResult> DeleteOrder(int id)
    {
        _logger.LogInformation("Deleting order {OrderId}", id);
        
        var stopwatch = System.Diagnostics.Stopwatch.StartNew();
        
        try
        {
            var order = await _orderService.GetOrderByIdAsync(id);
            
            if (order == null)
            {
                _logger.LogWarning("Order {OrderId} not found for deletion", id);
                return NotFound();
            }

            // Release inventory if order is pending
            if (order.Status == OrderStatus.Pending)
            {
                await _inventoryService.ReleaseInventoryAsync(order.ProductId, order.Quantity);
            }

            await _orderService.DeleteOrderAsync(id);
            
            stopwatch.Stop();
            
            _telemetryClient.TrackMetric("OrderDeletionTime", stopwatch.ElapsedMilliseconds);
            _telemetryClient.TrackEvent("OrderDeleted", new Dictionary<string, string>
            {
                ["OrderId"] = id.ToString(),
                ["CustomerId"] = order.CustomerId.ToString(),
                ["ProductId"] = order.ProductId.ToString()
            });
            
            _logger.LogInformation("Successfully deleted order {OrderId} in {Duration}ms", 
                id, stopwatch.ElapsedMilliseconds);
            
            return Ok();
        }
        catch (Exception ex)
        {
            stopwatch.Stop();
            _logger.LogError(ex, "Failed to delete order {OrderId}", id);
            _telemetryClient.TrackException(ex, new Dictionary<string, string>
            {
                ["OrderId"] = id.ToString()
            });
            return StatusCode(500, "Failed to delete order");
        }
    }
}

public class CreateOrderRequest
{
    public int CustomerId { get; set; }
    public int ProductId { get; set; }
    public int Quantity { get; set; }
}

public class UpdateOrderStatusRequest
{
    public OrderStatus Status { get; set; }
}
