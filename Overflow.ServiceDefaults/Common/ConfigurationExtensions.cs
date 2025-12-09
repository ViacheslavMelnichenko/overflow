using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.Configuration;

namespace Overflow.ServiceDefaults.Common;

/// <summary>
/// Extension methods for configuring application configuration sources.
/// </summary>
public static class ConfigurationExtensions
{
    /// <summary>
    /// Creates a WebApplicationBuilder with configuration file watching disabled.
    /// This prevents inotify instance exhaustion in containerized environments where
    /// configuration files are static and don't change at runtime.
    /// </summary>
    /// <param name="args">Command line arguments</param>
    /// <param name="configureOptions">Optional action to configure WebApplicationOptions</param>
    /// <returns>A WebApplicationBuilder with optimized configuration for containers</returns>
    public static WebApplicationBuilder CreateBuilderWithoutFileWatching(
        string[] args,
        Action<WebApplicationOptions>? configureOptions = null)
    {
        var options = new WebApplicationOptions
        {
            Args = args
        };
        
        configureOptions?.Invoke(options);
        
        var builder = WebApplication.CreateBuilder(options);
        
        // Clear default configuration sources and rebuild without file watching
        builder.Configuration.Sources.Clear();
        builder.Configuration
            .AddJsonFile("appsettings.json", optional: true, reloadOnChange: false)
            .AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.json", optional: true, reloadOnChange: false)
            .AddEnvironmentVariables()
            .AddCommandLine(args);
        
        return builder;
    }
    
    /// <summary>
    /// Disables file watching on an existing configuration builder.
    /// This method rebuilds the configuration sources with reloadOnChange set to false.
    /// Use this to prevent inotify instance exhaustion in containerized environments.
    /// </summary>
    /// <param name="builder">The WebApplicationBuilder to configure</param>
    /// <returns>The same builder for method chaining</returns>
    public static WebApplicationBuilder DisableConfigurationFileWatching(
        this WebApplicationBuilder builder)
    {
        // Get the current environment name before clearing sources
        var environmentName = builder.Environment.EnvironmentName;
        var args = builder.Configuration.GetValue<string[]>("CommandLineArgs") ?? Array.Empty<string>();
        
        // Clear and rebuild configuration sources without file watching
        builder.Configuration.Sources.Clear();
        builder.Configuration
            .AddJsonFile("appsettings.json", optional: true, reloadOnChange: false)
            .AddJsonFile($"appsettings.{environmentName}.json", optional: true, reloadOnChange: false)
            .AddEnvironmentVariables()
            .AddCommandLine(args);
        
        return builder;
    }
}

