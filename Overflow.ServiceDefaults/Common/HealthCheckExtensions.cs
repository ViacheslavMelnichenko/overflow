using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using RabbitMQ.Client;
using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace Overflow.ServiceDefaults.Common;

public static class HealthCheckExtensions
{
    /// <summary>
    /// Adds RabbitMQ health check that verifies connectivity and virtual host accessibility.
    /// </summary>
    public static IHealthChecksBuilder AddRabbitMqHealthCheck(
        this IHealthChecksBuilder builder,
        string connectionStringName = "messaging")
    {
        builder.AddCheck<RabbitMqHealthCheck>(
            name: "rabbitmq",
            failureStatus: HealthStatus.Unhealthy,
            tags: new[] { "ready", "messaging", "rabbitmq" });

        return builder;
    }

    /// <summary>
    /// Adds Typesense health check that verifies connectivity and collection existence.
    /// Note: TypesenseHealthCheck must be registered in the service's Health folder.
    /// </summary>
    public static IHealthChecksBuilder AddTypesenseHealthCheck<THealthCheck>(
        this IHealthChecksBuilder builder)
        where THealthCheck : class, IHealthCheck
    {
        builder.AddCheck<THealthCheck>(
            name: "typesense",
            failureStatus: HealthStatus.Unhealthy,
            tags: new[] { "ready", "search", "typesense" });

        return builder;
    }

    /// <summary>
    /// Adds Database (PostgreSQL/SQL Server) health check that verifies connectivity.
    /// Note: DatabaseHealthCheck must be registered in the service's Health folder.
    /// </summary>
    public static IHealthChecksBuilder AddDatabaseHealthCheck<THealthCheck>(
        this IHealthChecksBuilder builder,
        string name = "database")
        where THealthCheck : class, IHealthCheck
    {
        builder.AddCheck<THealthCheck>(
            name: name,
            failureStatus: HealthStatus.Unhealthy,
            tags: new[] { "ready", "db", "database" });

        return builder;
    }

    /// <summary>
    /// Maps standard health check endpoints with detailed JSON responses.
    /// Includes /alive (liveness), /health/ready (readiness), and /health (full status).
    /// </summary>
    public static WebApplication MapStandardHealthCheckEndpoints(
        this WebApplication app,
        string serviceName)
    {
        var jsonOptions = new JsonSerializerOptions
        {
            WriteIndented = true,
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        };

        // Liveness endpoint - basic check that app is running
        app.MapHealthChecks("/alive", new HealthCheckOptions
        {
            Predicate = _ => false, // Don't run any checks, just return if app is alive
            ResponseWriter = async (context, _) =>
            {
                context.Response.ContentType = "application/json";
                var response = new
                {
                    status = "Alive",
                    timestamp = DateTime.UtcNow
                };
                await context.Response.WriteAsync(JsonSerializer.Serialize(response, jsonOptions));
            }
        });

        // Readiness endpoint - checks if all dependencies are available
        app.MapHealthChecks("/health/ready", new HealthCheckOptions
        {
            Predicate = check => check.Tags.Contains("ready"),
            ResponseWriter = async (context, report) =>
            {
                context.Response.ContentType = "application/json";

                var response = new
                {
                    status = report.Status.ToString(),
                    timestamp = DateTime.UtcNow,
                    duration = report.TotalDuration,
                    checks = report.Entries.Select(e => new
                    {
                        name = e.Key,
                        status = e.Value.Status.ToString(),
                        description = e.Value.Description,
                        duration = e.Value.Duration,
                        data = e.Value.Data,
                        exception = e.Value.Exception?.Message
                    })
                };

                await context.Response.WriteAsync(JsonSerializer.Serialize(response, jsonOptions));
            }
        });

        // Standard health endpoint - all checks with detailed info
        app.MapHealthChecks("/health", new HealthCheckOptions
        {
            ResponseWriter = async (context, report) =>
            {
                context.Response.ContentType = "application/json";

                var response = new
                {
                    status = report.Status.ToString(),
                    timestamp = DateTime.UtcNow,
                    duration = report.TotalDuration,
                    service = serviceName,
                    version = typeof(HealthCheckExtensions).Assembly.GetName().Version?.ToString(),
                    checks = report.Entries.Select(e => new
                    {
                        name = e.Key,
                        status = e.Value.Status.ToString(),
                        description = e.Value.Description,
                        duration = e.Value.Duration,
                        tags = e.Value.Tags,
                        data = e.Value.Data,
                        exception = e.Value.Exception?.Message
                    })
                };

                var statusCode = report.Status switch
                {
                    HealthStatus.Healthy => 200,
                    HealthStatus.Degraded => 200,
                    HealthStatus.Unhealthy => 503,
                    _ => 500
                };

                context.Response.StatusCode = statusCode;
                await context.Response.WriteAsync(JsonSerializer.Serialize(response, jsonOptions));
            }
        });

        return app;
    }

    /// <summary>
    /// Generic RabbitMQ health check implementation.
    /// </summary>
    private class RabbitMqHealthCheck : IHealthCheck
    {
        private readonly Microsoft.Extensions.Configuration.IConfiguration _configuration;
        private readonly Microsoft.Extensions.Logging.ILogger<RabbitMqHealthCheck> _logger;

        public RabbitMqHealthCheck(
            Microsoft.Extensions.Configuration.IConfiguration configuration,
            Microsoft.Extensions.Logging.ILogger<RabbitMqHealthCheck> logger)
        {
            _configuration = configuration;
            _logger = logger;
        }

        public async Task<HealthCheckResult> CheckHealthAsync(
            HealthCheckContext context,
            CancellationToken cancellationToken = default)
        {
            try
            {
                var connectionString = _configuration.GetConnectionString("messaging");

                if (string.IsNullOrEmpty(connectionString))
                {
                    return HealthCheckResult.Unhealthy(
                        "RabbitMQ connection string 'messaging' not configured",
                        data: new Dictionary<string, object>
                        {
                            ["status"] = "not_configured"
                        });
                }

                var connectionUri = new Uri(connectionString);
                var vhost = connectionUri.AbsolutePath.TrimStart('/');
                if (string.IsNullOrEmpty(vhost))
                {
                    vhost = "/";
                }

                var factory = new ConnectionFactory
                {
                    Uri = new Uri(connectionString)
                };

                // Test connection
                await using var connection = await factory.CreateConnectionAsync(cancellationToken);
                await using var channel = await connection.CreateChannelAsync(cancellationToken: cancellationToken);

                var data = new Dictionary<string, object>
                {
                    ["host"] = connectionUri.Host,
                    ["port"] = connectionUri.Port,
                    ["vhost"] = vhost,
                    ["status"] = "connected"
                };

                _logger.LogDebug("RabbitMQ health check passed: {Host}:{Port} vhost={VHost}",
                    connectionUri.Host, connectionUri.Port, vhost);

                return HealthCheckResult.Healthy(
                    $"RabbitMQ is healthy. Connected to {connectionUri.Host}:{connectionUri.Port} (vhost: {vhost})",
                    data);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "RabbitMQ health check failed: {Message}", ex.Message);

                return HealthCheckResult.Unhealthy(
                    $"Cannot connect to RabbitMQ: {ex.Message}",
                    ex,
                    new Dictionary<string, object>
                    {
                        ["status"] = "connection_failed",
                        ["error"] = ex.Message
                    });
            }
        }
    }
}

