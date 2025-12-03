using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using QuestionService.Data;

namespace QuestionService.Health;

/// <summary>
/// Health check that verifies PostgreSQL database connectivity.
/// </summary>
public class DatabaseHealthCheck : IHealthCheck
{
    private readonly QuestionDbContext _context;
    private readonly ILogger<DatabaseHealthCheck> _logger;

    public DatabaseHealthCheck(QuestionDbContext context, ILogger<DatabaseHealthCheck> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            // Try to connect and execute a simple query
            var canConnect = await _context.Database.CanConnectAsync(cancellationToken);
            
            if (!canConnect)
            {
                return HealthCheckResult.Unhealthy(
                    "Cannot connect to database",
                    data: new Dictionary<string, object>
                    {
                        ["status"] = "connection_failed"
                    });
            }

            // Get connection info
            var connectionString = _context.Database.GetConnectionString();
            var dbName = "questions"; // Default
            
            if (!string.IsNullOrEmpty(connectionString))
            {
                try
                {
                    var builder = new Npgsql.NpgsqlConnectionStringBuilder(connectionString);
                    dbName = builder.Database ?? "questions";
                }
                catch
                {
                    // Ignore parsing errors
                }
            }

            var data = new Dictionary<string, object>
            {
                ["database"] = dbName,
                ["status"] = "connected"
            };

            _logger.LogDebug("Database health check passed for: {Database}", dbName);

            return HealthCheckResult.Healthy(
                $"Database is healthy. Connected to '{dbName}'",
                data);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database health check failed: {Message}", ex.Message);
            
            return HealthCheckResult.Unhealthy(
                $"Cannot connect to database: {ex.Message}",
                ex,
                new Dictionary<string, object>
                {
                    ["status"] = "connection_failed",
                    ["error"] = ex.Message
                });
        }
    }
}

