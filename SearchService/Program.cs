using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using SearchService.Data;
using Typesense;
using Typesense.Setup;
using Wolverine;
using Wolverine.RabbitMQ;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddOpenApi();
builder.AddServiceDefaults();

builder.Services.AddOpenTelemetry().WithTracing(providerBuilder =>
{
    providerBuilder
        .SetResourceBuilder(ResourceBuilder.CreateDefault()
            .AddService(builder.Environment.ApplicationName))
        .AddSource("Wolverine");
});

builder.Host.UseWolverine(ops =>
{
    ops.UseRabbitMqUsingNamedConnection("messaging").AutoProvision();
    ops.ListenToRabbitQueue("questions.search", cfg => { cfg.BindExchange("questions"); });
});

var typesenseUri = builder.Configuration["services:typesense:typesense:0"];

if (string.IsNullOrWhiteSpace(typesenseUri))
{
    throw new InvalidOperationException("typesense uri is missing");
}

var typesenseApiKey = builder.Configuration["typesense-api-key"];

if (string.IsNullOrWhiteSpace(typesenseApiKey))
{
    throw new InvalidOperationException("typesense api key is missing");
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

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseAuthorization();

app.MapControllers();
app.MapDefaultEndpoints();

using var scope = app.Services.CreateScope();
var typesenseClient = scope.ServiceProvider.GetRequiredService<ITypesenseClient>();
await SearchInitializer.EnsureIndexExists(typesenseClient);

app.Run();