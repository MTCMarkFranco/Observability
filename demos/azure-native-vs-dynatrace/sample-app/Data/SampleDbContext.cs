using Microsoft.EntityFrameworkCore;
using SampleApp.Models;

namespace SampleApp.Data;

public class SampleDbContext : DbContext
{
    public SampleDbContext(DbContextOptions<SampleDbContext> options) : base(options)
    {
    }

    public DbSet<Order> Orders { get; set; }
    public DbSet<Product> Products { get; set; }
    public DbSet<Customer> Customers { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Configure Order entity
        modelBuilder.Entity<Order>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).ValueGeneratedOnAdd();
            entity.Property(e => e.CustomerId).IsRequired();
            entity.Property(e => e.ProductId).IsRequired();
            entity.Property(e => e.Quantity).IsRequired();
            entity.Property(e => e.Status).HasConversion<string>().IsRequired();
            entity.Property(e => e.CreatedAt).IsRequired();
            entity.Property(e => e.UpdatedAt).IsRequired(false);
        });

        // Configure Product entity
        modelBuilder.Entity<Product>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).ValueGeneratedOnAdd();
            entity.Property(e => e.Name).IsRequired().HasMaxLength(100);
            entity.Property(e => e.Price).HasPrecision(10, 2).IsRequired();
            entity.Property(e => e.InventoryCount).IsRequired();
        });

        // Configure Customer entity
        modelBuilder.Entity<Customer>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).ValueGeneratedOnAdd();
            entity.Property(e => e.Name).IsRequired().HasMaxLength(100);
            entity.Property(e => e.Email).IsRequired().HasMaxLength(200);
        });

        // Seed data
        modelBuilder.Entity<Product>().HasData(
            new Product { Id = 1, Name = "Laptop", Price = 999.99m, InventoryCount = 50 },
            new Product { Id = 2, Name = "Mouse", Price = 29.99m, InventoryCount = 200 },
            new Product { Id = 3, Name = "Keyboard", Price = 79.99m, InventoryCount = 150 },
            new Product { Id = 4, Name = "Monitor", Price = 299.99m, InventoryCount = 75 },
            new Product { Id = 5, Name = "Headphones", Price = 129.99m, InventoryCount = 100 }
        );

        modelBuilder.Entity<Customer>().HasData(
            new Customer { Id = 1, Name = "John Doe", Email = "john.doe@example.com" },
            new Customer { Id = 2, Name = "Jane Smith", Email = "jane.smith@example.com" },
            new Customer { Id = 3, Name = "Bob Johnson", Email = "bob.johnson@example.com" },
            new Customer { Id = 4, Name = "Alice Brown", Email = "alice.brown@example.com" },
            new Customer { Id = 5, Name = "Charlie Davis", Email = "charlie.davis@example.com" }
        );
    }
}
