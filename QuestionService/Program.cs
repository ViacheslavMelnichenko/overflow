using Overflow.ServiceDefaults;
using Overflow.ServiceDefaults.Common;
using QuestionService.Data;
using QuestionService.Health;
using QuestionService.Services;
using Wolverine.RabbitMQ;
using ConfigurationExtensions = Overflow.ServiceDefaults.Common.ConfigurationExtensions;

// Use extension method to create builder without file watching (prevents inotify exhaustion in containers)
var builder = ConfigurationExtensions.CreateBuilderWithoutFileWatching(args);

builder.ConfigureKeycloakFromSettings();

// Add services to the container
builder.Services.AddControllers();
builder.Services.AddOpenApi();
builder.AddServiceDefaults();
builder.Services.AddMemoryCache();
builder.Services.AddScoped<TagService>();
builder.AddKeyCloakAuthentication();
builder.AddNpgsqlDbContext<QuestionDbContext>("questionDb");

// Add health checks
builder.Services.AddHealthChecks()
    .AddDatabaseHealthCheck<DatabaseHealthCheck>()
    .AddRabbitMqHealthCheck();

builder.ConfigureWolverineWithRabbit(opts =>
{
    opts.PublishAllMessages().ToRabbitExchange("questions");
    opts.ApplicationAssembly = typeof(Program).Assembly;
});

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsProduction())
{
    app.MapOpenApi();
}

app.MapStandardHealthCheckEndpoints("QuestionService");
app.MapControllers();

// Apply database migrations
await app.MigrateDatabaseAsync<QuestionDbContext>();

app.Run();