using Typesense;

namespace SearchService.Data;

public static class SearchInitializer
{
    public static async Task EnsureIndexExists(ITypesenseClient client, ILogger logger)
    {
        const string schemaName = "questions";
        
        try
        {
            await client.RetrieveCollection(schemaName);
            logger.LogInformation("✅ Collection '{SchemaName}' already exists", schemaName);
            return;
        }
        catch (TypesenseApiNotFoundException)
        {
            logger.LogInformation("📝 Collection '{SchemaName}' not found, creating it now...", schemaName);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "⚠️ Error checking collection '{SchemaName}': {Message}", schemaName, ex.Message);
            throw;
        }

        var schema = new Schema(schemaName, new List<Field>
        {
            new("id", FieldType.String),
            new("title", FieldType.String),
            new("content", FieldType.String),
            new("tags", FieldType.StringArray),
            new("createdAt", FieldType.Int64),
            new("answerCount", FieldType.Int32),
            new("hasAcceptedAnswer", FieldType.Bool),
        })
        {
            DefaultSortingField = "createdAt"
        };
        
        try
        {
            await client.CreateCollection(schema);
            logger.LogInformation("✅ Collection '{SchemaName}' created successfully", schemaName);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "❌ Failed to create collection '{SchemaName}': {Message}", schemaName, ex.Message);
            throw;
        }
    }
}