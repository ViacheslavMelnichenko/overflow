using Overflow.ServiceDefaults;
using Overflow.ServiceDefaults.Common;
using SearchService.Extensions;
using SearchService.Health;
using Wolverine.RabbitMQ;
using ConfigurationExtensions = Overflow.ServiceDefaults.Common.ConfigurationExtensions;

// Use extension method to create builder without file watching (prevents inotify exhaustion in containers)
var builder = ConfigurationExtensions.CreateBuilderWithoutFileWatching(args);

builder.ConfigureKeycloakFromSettings();

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddOpenApi();
builder.AddServiceDefaults();

// Add health checks
builder.Services.AddHealthChecks()
    .AddTypesenseHealthCheck<TypesenseHealthCheck>()
    .AddRabbitMqHealthCheck();

// Configure Wolverine with RabbitMQ
builder.ConfigureWolverineWithRabbit(opts =>
{
    opts.ListenToRabbitQueue("questions.search", cfg =>
    {
        cfg.BindExchange("questions");
    });
    opts.ApplicationAssembly = typeof(Program).Assembly;
});

// Configure Typesense
builder.AddTypesense();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsProduction())
{
    app.MapOpenApi();
}

app.MapStandardHealthCheckEndpoints("SearchService");
app.MapControllers();
app.InitializeTypesenseCollection();
app.Run();