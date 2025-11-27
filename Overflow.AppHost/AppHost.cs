using Microsoft.Extensions.Hosting;
using Overflow.AppHost.Extensions;

var builder = DistributedApplication.CreateBuilder(args);

// Keycloak setup
if (builder.Environment.IsDevelopment())
{
    // Local Keycloak container for development
    var keycloak = builder
        .AddKeycloak("keycloak", 6001)
        .WithDataVolume("keycloak-data");
    
    // Question Service configuration
    var questionService = builder.AddProject<Projects.QuestionService>("question-svc")
        .WithReference(keycloak)
        .WithKeycloakOptions(builder.Configuration)
        .WaitFor(keycloak);
}
else
{
    // External Keycloak for staging/production
    var keycloakUrl = builder.Configuration["KeycloakOptions:Url"] 
        ?? throw new InvalidOperationException("Keycloak URL is not configured.");
    var keycloak = builder.AddConnectionString("keycloak", keycloakUrl);
    
    // Question Service configuration
    var questionService = builder.AddProject<Projects.QuestionService>("question-svc")
        .WithReference(keycloak)
        .WithKeycloakOptions(builder.Configuration);
}


// var postgres = builder.AddPostgres("postgres", port: 5432)
//     .WithDataVolume("postgres-data")
//     .WithPgAdmin();
//
// var typesenseApiKey = builder.AddParameter("typesense-api-key", secret: true);
//
// var typesense = builder.AddContainer("typesense", "typesense/typesense", "29.0")
//     .WithArgs("--data-dir", "/data", "--api-key", typesenseApiKey, "--enable-cors")
//     .WithVolume("typesense-data", "/data")
//     .WithHttpEndpoint(8108, 8108, name: "typesense");
//
// var typesenseContainer = typesense.GetEndpoint("typesense");
//
// var questionDb = postgres.AddDatabase("questionDb");
//
// var rabbitmq = builder.AddRabbitMQ("messaging")
//     .WithDataVolume("rabbitmq-data")
//     .WithManagementPlugin(port: 15672);
//
// var questionService = builder.AddProject<Projects.QuestionService>("question-svc")
//     .WithEnvironment("KEYCLOAK_HTTP", keycloakHttp)
//     .WithEnvironment("KEYCLOAK_MANAGEMENT", keycloakMgmt)
//     .WithReference(questionDb)
//     .WithReference(rabbitmq)
//     .WaitFor(keycloak)
//     .WaitFor(questionDb)
//     .WaitFor(rabbitmq);
//
//
// var searchService = builder.AddProject<Projects.SearchService>("search-svc")
//     .WithEnvironment("typesense-api-key", typesenseApiKey)
//     .WithReference(typesenseContainer)
//     .WithReference(rabbitmq)
//     .WaitFor(typesense)
//     .WaitFor(rabbitmq);

builder.Build().Run();