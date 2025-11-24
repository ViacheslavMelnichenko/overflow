using Projects;

var builder = DistributedApplication.CreateBuilder(args);

var keycloak = builder
    .AddKeycloak("keycloak", 6001)
    .WithDataVolume("keycloak-data");

var postgres = builder
    .AddPostgres("postgres", port: 5432)
    .WithDataVolume("postgres-data")
    .WithPgAdmin();

var typesenseApiKey = builder.AddParameter("typesense-api-key", secret: true);

var typesense = builder
    .AddContainer("typesense", "typesense/typesense", "29.0")
    .WithArgs("--data-dir", "/data", "--api-key", typesenseApiKey, "--enable-cors")
    .WithVolume("typesense-data", "/data")
    .WithHttpEndpoint(8108, 8108, name: "typesense");

var tysenseContainer = typesense.GetEndpoint("typesense");

var questionDb = postgres
    .AddDatabase("questionDb");

var rabbitMq = builder
    .AddRabbitMQ("messaging")
    .WithDataVolume("rabbitma-data")
    .WithManagementPlugin(port: 15672);

var questionService = builder
    .AddProject<QuestionService>("question-svc")
    .WithReference(keycloak)
    .WithReference(questionDb)
    .WithReference(rabbitMq)
    .WaitFor(keycloak)
    .WaitFor(questionDb)
    .WaitFor(rabbitMq);

var searchService = builder
    .AddProject<SearchService>("search-svc")
    .WithEnvironment("typesense-api-key", typesenseApiKey)
    .WithReference(tysenseContainer)
    .WithReference(rabbitMq)
    .WaitFor(typesense)
    .WaitFor(rabbitMq);

builder.Build().Run();