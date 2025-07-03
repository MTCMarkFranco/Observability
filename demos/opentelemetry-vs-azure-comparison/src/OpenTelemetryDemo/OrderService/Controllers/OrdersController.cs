using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using OrderService.Models;
using OrderService.Services;

namespace OrderService.Controllers;

[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    private readonly IOrderService _orderService;
    private readonly IPaymentService _paymentService;
    private readonly IInventoryService _inventoryService;
    private readonly ILogger<OrdersController> _logger;

    public OrdersController(
        IOrderService orderService,
        IPaymentService paymentService,
        IInventoryService inventoryService,
        ILogger<OrdersController> logger)
    {
        _orderService = orderService;
        _paymentService = paymentService;
        _inventoryService = inventoryService;
        _logger = logger;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<Order>>> GetOrders()
    {
        using var activity = Telemetry.ActivitySource.StartActivity("GetOrders");
        
        try
        {
            _logger.LogInformation("Retrieving all orders");
            var orders = await _orderService.GetOrdersAsync();
            
            activity?.SetTag("orders.count", orders.Count());
            _logger.LogInformation("Retrieved {OrderCount} orders", orders.Count());
            
            return Ok(orders);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving orders");
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            return StatusCode(500, "Error retrieving orders");
        }
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<Order>> GetOrder(int id)
    {
        using var activity = Telemetry.ActivitySource.StartActivity("GetOrder");
        activity?.SetTag("order.id", id);
        
        try
        {
            _logger.LogInformation("Retrieving order {OrderId}", id);
            var order = await _orderService.GetOrderAsync(id);
            
            if (order == null)
            {
                _logger.LogWarning("Order {OrderId} not found", id);
                return NotFound();
            }
            
            activity?.SetTag("order.status", order.Status);
            activity?.SetTag("order.total", order.Total);
            
            return Ok(order);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving order {OrderId}", id);
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            return StatusCode(500, "Error retrieving order");
        }
    }

    [HttpPost]
    public async Task<ActionResult<Order>> CreateOrder(CreateOrderRequest request)
    {
        using var activity = Telemetry.ActivitySource.StartActivity("CreateOrder");
        var stopwatch = Stopwatch.StartNew();
        
        try
        {
            _logger.LogInformation("Creating order for customer {CustomerId} with {ItemCount} items", 
                request.CustomerId, request.Items.Count);
            
            activity?.SetTag("order.customer_id", request.CustomerId);
            activity?.SetTag("order.items.count", request.Items.Count);
            
            // Step 1: Check inventory
            using (var inventoryActivity = Telemetry.ActivitySource.StartActivity("CheckInventory"))
            {
                _logger.LogInformation("Checking inventory for {ItemCount} items", request.Items.Count);
                
                foreach (var item in request.Items)
                {
                    var available = await _inventoryService.CheckInventoryAsync(item.ProductId, item.Quantity);
                    if (!available)
                    {
                        _logger.LogWarning("Insufficient inventory for product {ProductId}", item.ProductId);
                        Telemetry.InventoryChecks.Add(1, new KeyValuePair<string, object?>("result", "insufficient"));
                        return BadRequest($"Insufficient inventory for product {item.ProductId}");
                    }
                }
                
                Telemetry.InventoryChecks.Add(request.Items.Count, new KeyValuePair<string, object?>("result", "available"));
                _logger.LogInformation("Inventory check passed for all items");
            }
            
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
            
            activity?.SetTag("order.total", order.Total);
            Telemetry.OrderValue.Record(order.Total);
            
            var createdOrder = await _orderService.CreateOrderAsync(order);
            
            // Step 3: Process payment
            using (var paymentActivity = Telemetry.ActivitySource.StartActivity("ProcessPayment"))
            {
                _logger.LogInformation("Processing payment for order {OrderId} amount {Amount}", 
                    createdOrder.Id, order.Total);
                
                paymentActivity?.SetTag("payment.amount", order.Total);
                paymentActivity?.SetTag("payment.customer_id", request.CustomerId);
                
                Telemetry.PaymentAttempts.Add(1, 
                    new KeyValuePair<string, object?>("customer_id", request.CustomerId),
                    new KeyValuePair<string, object?>("amount", order.Total));
                
                var paymentResult = await _paymentService.ProcessPaymentAsync(new PaymentRequest
                {
                    OrderId = createdOrder.Id,
                    Amount = order.Total,
                    CustomerId = request.CustomerId
                });
                
                if (paymentResult.Success)
                {
                    createdOrder.Status = "Paid";
                    paymentActivity?.SetTag("payment.status", "success");
                    _logger.LogInformation("Payment successful for order {OrderId}", createdOrder.Id);
                }
                else
                {
                    createdOrder.Status = "PaymentFailed";
                    paymentActivity?.SetTag("payment.status", "failed");
                    paymentActivity?.SetTag("payment.error", paymentResult.ErrorMessage);
                    
                    Telemetry.PaymentFailures.Add(1, 
                        new KeyValuePair<string, object?>("customer_id", request.CustomerId),
                        new KeyValuePair<string, object?>("reason", paymentResult.ErrorMessage));
                    
                    _logger.LogWarning("Payment failed for order {OrderId}: {Error}", 
                        createdOrder.Id, paymentResult.ErrorMessage);
                }
            }
            
            // Step 4: Update order status
            await _orderService.UpdateOrderAsync(createdOrder);
            
            stopwatch.Stop();
            Telemetry.OrderProcessingDuration.Record(stopwatch.Elapsed.TotalSeconds);
            Telemetry.OrdersProcessed.Add(1, 
                new KeyValuePair<string, object?>("status", createdOrder.Status),
                new KeyValuePair<string, object?>("customer_id", request.CustomerId));
            
            _logger.LogInformation("Order {OrderId} created successfully with status {Status} in {Duration}ms", 
                createdOrder.Id, createdOrder.Status, stopwatch.ElapsedMilliseconds);
            
            return CreatedAtAction(nameof(GetOrder), new { id = createdOrder.Id }, createdOrder);
        }
        catch (Exception ex)
        {
            stopwatch.Stop();
            _logger.LogError(ex, "Error creating order for customer {CustomerId}", request.CustomerId);
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            return StatusCode(500, "Error creating order");
        }
    }

    [HttpPut("{id}/status")]
    public async Task<IActionResult> UpdateOrderStatus(int id, [FromBody] string status)
    {
        using var activity = Telemetry.ActivitySource.StartActivity("UpdateOrderStatus");
        activity?.SetTag("order.id", id);
        activity?.SetTag("order.new_status", status);
        
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
            
            activity?.SetTag("order.previous_status", previousStatus);
            _logger.LogInformation("Order {OrderId} status updated from {PreviousStatus} to {NewStatus}", 
                id, previousStatus, status);
            
            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating order {OrderId} status", id);
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            return StatusCode(500, "Error updating order status");
        }
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteOrder(int id)
    {
        using var activity = Telemetry.ActivitySource.StartActivity("DeleteOrder");
        activity?.SetTag("order.id", id);
        
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
            
            _logger.LogInformation("Order {OrderId} deleted successfully", id);
            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting order {OrderId}", id);
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            return StatusCode(500, "Error deleting order");
        }
    }
}
