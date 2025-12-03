using SearchService.Data;
using Typesense;
using Typesense.Setup;

namespace SearchService.Extensions;

public static class TypesenseExtensions
{
    /// <summary>
    /// Configures Typesense client and registers it with dependency injection.
    /// </summary>
    /// <param name="builder">The host application builder.</param>
    /// <returns>The builder for chaining.</returns>
    public static IHostApplicationBuilder AddTypesense(this IHostApplicationBuilder builder)
    {
        var typesenseUri = builder.Configuration.GetConnectionString("typesense") 
                           ?? builder.Configuration["services:typesense:typesense:0"];
                           
        if (string.IsNullOrEmpty(typesenseUri))
        {
            throw new InvalidOperationException(
                "Typesense URI not found. Expected ConnectionStrings__typesense environment variable");
        }

        var typesenseApiKey = builder.Configuration["Typesense:ApiKey"] 
                              ?? builder.Configuration["typesense-api-key"];
                              
        if (string.IsNullOrEmpty(typesenseApiKey))
        {
            throw new InvalidOperationException(
                "Typesense API key not found. Expected Typesense__ApiKey environment variable");
        }

        var uri = new Uri(typesenseUri);
        builder.Services.AddTypesenseClient(config =>
        {
            config.ApiKey = typesenseApiKey;
            config.Nodes = new List<Node>
            {
                new(uri.Host, uri.Port.ToString(), uri.Scheme)
            };
        });

        // Store configuration for logging later
        builder.Services.AddSingleton(new TypesenseConfiguration
        {
            Uri = typesenseUri,
            Host = uri.Host,
            Port = uri.Port,
            Scheme = uri.Scheme
        });

        return builder;
    }

    /// <summary>
    /// Initializes the Typesense collection in the background with retry logic.
    /// This is non-blocking and allows the application to start even if Typesense is temporarily unavailable.
    /// </summary>
    /// <param name="app">The web application.</param>
    /// <param name="options">Configuration options for initialization.</param>
    /// <returns>The application for chaining.</returns>
    public static WebApplication InitializeTypesenseCollection(
        this WebApplication app,
        TypesenseInitializationOptions? options = null)
    {
        options ??= new TypesenseInitializationOptions();

        var logger = app.Services.GetRequiredService<ILogger<Program>>();
        var config = app.Services.GetService<TypesenseConfiguration>();
        
        if (config != null)
        {
            logger.LogInformation("🔍 Typesense configured: {TypesenseUri} ({Scheme}://{Host}:{Port})", 
                config.Uri, config.Scheme, config.Host, config.Port);
        }

        // Initialize collection in background
        _ = Task.Run(async () =>
        {
            await Task.Delay(options.StartupDelay);
            
            var appLogger = app.Services.GetRequiredService<ILogger<Program>>();
            appLogger.LogInformation("🔍 Initializing Typesense collection '{CollectionName}'...", options.CollectionName);
            
            for (int i = 0; i < options.MaxRetries; i++)
            {
                try
                {
                    using var scope = app.Services.CreateScope();
                    var client = scope.ServiceProvider.GetRequiredService<ITypesenseClient>();
                    
                    await SearchInitializer.EnsureIndexExists(client, appLogger);
                    
                    appLogger.LogInformation("✅ Typesense collection '{CollectionName}' initialized successfully", 
                        options.CollectionName);
                    break;
                }
                catch (Exception ex)
                {
                    appLogger.LogError(ex, 
                        "❌ Failed to initialize Typesense collection (attempt {Attempt}/{MaxRetries})", 
                        i + 1, options.MaxRetries);
                    
                    if (i < options.MaxRetries - 1)
                    {
                        appLogger.LogInformation("⏳ Retrying in {Delay} seconds...", 
                            options.RetryDelay.TotalSeconds);
                        await Task.Delay(options.RetryDelay);
                    }
                    else
                    {
                        appLogger.LogError(
                            "❌ Failed to initialize Typesense collection after {MaxRetries} attempts. " +
                            "The service will continue but search functionality may not work.", 
                            options.MaxRetries);
                    }
                }
            }
        });

        return app;
    }
}

/// <summary>
/// Configuration for Typesense connection (used for logging).
/// </summary>
public class TypesenseConfiguration
{
    public string Uri { get; set; } = string.Empty;
    public string Host { get; set; } = string.Empty;
    public int Port { get; set; }
    public string Scheme { get; set; } = string.Empty;
}

/// <summary>
/// Options for Typesense collection initialization.
/// </summary>
public class TypesenseInitializationOptions
{
    /// <summary>
    /// Collection name to initialize (for logging purposes).
    /// </summary>
    public string CollectionName { get; set; } = "questions";

    /// <summary>
    /// Delay before starting initialization to allow app to fully start.
    /// </summary>
    public TimeSpan StartupDelay { get; set; } = TimeSpan.FromSeconds(5);

    /// <summary>
    /// Maximum number of retry attempts.
    /// </summary>
    public int MaxRetries { get; set; } = 5;

    /// <summary>
    /// Delay between retry attempts.
    /// </summary>
    public TimeSpan RetryDelay { get; set; } = TimeSpan.FromSeconds(10);
}

