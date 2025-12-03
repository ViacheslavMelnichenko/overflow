using Microsoft.Extensions.Diagnostics.HealthChecks;
using Typesense;

namespace SearchService.Health;

/// <summary>
/// Health check that verifies Typesense connectivity and collection existence.
/// </summary>
public class TypesenseHealthCheck(ITypesenseClient client, ILogger<TypesenseHealthCheck> logger)
    : IHealthCheck
{
    private const string CollectionName = "questions";

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            // Check if we can reach Typesense and retrieve the collection
            var collection = await client.RetrieveCollection(CollectionName, cancellationToken);
            
            var data = new Dictionary<string, object>
            {
                ["collection"] = CollectionName,
                ["collectionName"] = collection.Name ?? CollectionName,
                ["status"] = "connected"
            };

            logger.LogDebug("Typesense health check passed for collection: {CollectionName}", CollectionName);

            return HealthCheckResult.Healthy(
                $"Typesense is healthy. Collection '{CollectionName}' exists and is accessible.",
                data);
        }
        catch (TypesenseApiNotFoundException)
        {
            logger.LogWarning("Typesense collection '{CollectionName}' not found", CollectionName);
            
            return HealthCheckResult.Degraded(
                $"Typesense collection '{CollectionName}' does not exist yet. It will be created on first use.",
                data: new Dictionary<string, object>
                {
                    ["collection"] = CollectionName,
                    ["status"] = "collection_not_found"
                });
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Typesense health check failed: {Message}", ex.Message);
            
            return HealthCheckResult.Unhealthy(
                $"Cannot connect to Typesense: {ex.Message}",
                ex,
                new Dictionary<string, object>
                {
                    ["collection"] = CollectionName,
                    ["status"] = "connection_failed",
                    ["error"] = ex.Message
                });
        }
    }
}
