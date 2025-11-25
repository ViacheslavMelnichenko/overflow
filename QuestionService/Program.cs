using Microsoft.EntityFrameworkCore;
using Overflow.ServiceDefaults.Common;
using QuestionService.Data;
using QuestionService.Services;
using Wolverine.RabbitMQ;

var builder = WebApplication.CreateBuilder(args);

// Ensure all configuration is loaded from environment variables
builder.Configuration.AddEnvironmentVariables();

// Add services to the container.

builder.Services.AddControllers();
builder.Services.AddOpenApi();
builder.AddServiceDefaults();
builder.Services.AddMemoryCache();
builder.Services.AddScoped<TagService>();
builder.Services.AddKeyCloakAuthentication();

builder.AddNpgsqlDbContext<QuestionDbContext>("questionDb");

await builder.UseWolverineWithRabbitMqAsync(opts =>
{
    opts.PublishAllMessages().ToRabbitExchange("questions");
    opts.ApplicationAssembly = typeof(Program).Assembly;
});

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.MapControllers();

app.MapDefaultEndpoints();

using var scope = app.Services.CreateScope();
var services = scope.ServiceProvider;
try
{
    var context = services.GetRequiredService<QuestionDbContext>();
    await context.Database.MigrateAsync();
}
catch (Exception e)
{
    var logger = services.GetRequiredService<ILogger<Program>>();
    logger.LogError(e, "An error occurred while migrating or seeding the database.");
}

app.Run();