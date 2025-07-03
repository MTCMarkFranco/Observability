using Microsoft.EntityFrameworkCore;
using SampleApp.Data;
using SampleApp.Models;

namespace SampleApp.Services;

public interface IOrderService
{
    Task<IEnumerable<Order>> GetAllOrdersAsync();
    Task<Order?> GetOrderByIdAsync(int id);
    Task<Order> CreateOrderAsync(Order order);
    Task UpdateOrderStatusAsync(int id, OrderStatus status);
    Task DeleteOrderAsync(int id);
}

public class OrderService : IOrderService
{
    private readonly SampleDbContext _context;
    private readonly ILogger<OrderService> _logger;

    public OrderService(SampleDbContext context, ILogger<OrderService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<IEnumerable<Order>> GetAllOrdersAsync()
    {
        _logger.LogInformation("Retrieving all orders from database");
        return await _context.Orders.ToListAsync();
    }

    public async Task<Order?> GetOrderByIdAsync(int id)
    {
        _logger.LogInformation("Retrieving order {OrderId} from database", id);
        return await _context.Orders.FindAsync(id);
    }

    public async Task<Order> CreateOrderAsync(Order order)
    {
        _logger.LogInformation("Creating new order in database");
        
        _context.Orders.Add(order);
        await _context.SaveChangesAsync();
        
        _logger.LogInformation("Created order {OrderId} in database", order.Id);
        return order;
    }

    public async Task UpdateOrderStatusAsync(int id, OrderStatus status)
    {
        _logger.LogInformation("Updating order {OrderId} status to {Status}", id, status);
        
        var order = await _context.Orders.FindAsync(id);
        if (order != null)
        {
            order.Status = status;
            order.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
            
            _logger.LogInformation("Updated order {OrderId} status to {Status}", id, status);
        }
    }

    public async Task DeleteOrderAsync(int id)
    {
        _logger.LogInformation("Deleting order {OrderId} from database", id);
        
        var order = await _context.Orders.FindAsync(id);
        if (order != null)
        {
            _context.Orders.Remove(order);
            await _context.SaveChangesAsync();
            
            _logger.LogInformation("Deleted order {OrderId} from database", id);
        }
    }
}

public interface IInventoryService
{
    Task<bool> CheckInventoryAsync(int productId, int quantity);
    Task ReserveInventoryAsync(int productId, int quantity);
    Task ReleaseInventoryAsync(int productId, int quantity);
}

public class InventoryService : IInventoryService
{
    private readonly SampleDbContext _context;
    private readonly ILogger<InventoryService> _logger;

    public InventoryService(SampleDbContext context, ILogger<InventoryService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<bool> CheckInventoryAsync(int productId, int quantity)
    {
        _logger.LogInformation("Checking inventory for product {ProductId}, quantity {Quantity}", productId, quantity);
        
        var product = await _context.Products.FindAsync(productId);
        var available = product?.InventoryCount >= quantity;
        
        _logger.LogInformation("Inventory check for product {ProductId}: {Available} (requested: {Quantity}, available: {InventoryCount})", 
            productId, available, quantity, product?.InventoryCount ?? 0);
        
        return available;
    }

    public async Task ReserveInventoryAsync(int productId, int quantity)
    {
        _logger.LogInformation("Reserving inventory for product {ProductId}, quantity {Quantity}", productId, quantity);
        
        var product = await _context.Products.FindAsync(productId);
        if (product != null && product.InventoryCount >= quantity)
        {
            product.InventoryCount -= quantity;
            await _context.SaveChangesAsync();
            
            _logger.LogInformation("Reserved {Quantity} units of product {ProductId}, remaining: {RemainingInventory}", 
                quantity, productId, product.InventoryCount);
        }
        else
        {
            _logger.LogWarning("Failed to reserve inventory for product {ProductId}, insufficient stock", productId);
            throw new InvalidOperationException($"Insufficient inventory for product {productId}");
        }
    }

    public async Task ReleaseInventoryAsync(int productId, int quantity)
    {
        _logger.LogInformation("Releasing inventory for product {ProductId}, quantity {Quantity}", productId, quantity);
        
        var product = await _context.Products.FindAsync(productId);
        if (product != null)
        {
            product.InventoryCount += quantity;
            await _context.SaveChangesAsync();
            
            _logger.LogInformation("Released {Quantity} units of product {ProductId}, total: {TotalInventory}", 
                quantity, productId, product.InventoryCount);
        }
    }
}

public interface INotificationService
{
    Task SendOrderConfirmationAsync(Order order);
    Task SendOrderStatusUpdateAsync(Order order);
}

public class NotificationService : INotificationService
{
    private readonly ILogger<NotificationService> _logger;
    private readonly IHttpClientFactory _httpClientFactory;

    public NotificationService(ILogger<NotificationService> logger, IHttpClientFactory httpClientFactory)
    {
        _logger = logger;
        _httpClientFactory = httpClientFactory;
    }

    public async Task SendOrderConfirmationAsync(Order order)
    {
        _logger.LogInformation("Sending order confirmation for order {OrderId}", order.Id);
        
        // Simulate sending email notification
        await Task.Delay(100); // Simulate network delay
        
        _logger.LogInformation("Order confirmation sent for order {OrderId}", order.Id);
    }

    public async Task SendOrderStatusUpdateAsync(Order order)
    {
        _logger.LogInformation("Sending order status update for order {OrderId}, status: {Status}", order.Id, order.Status);
        
        // Simulate sending SMS notification
        await Task.Delay(150); // Simulate network delay
        
        _logger.LogInformation("Order status update sent for order {OrderId}", order.Id);
    }
}
