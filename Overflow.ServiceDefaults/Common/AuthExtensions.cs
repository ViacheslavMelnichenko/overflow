using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using Overflow.ServiceDefaults.Options;

namespace Overflow.ServiceDefaults.Common;

public static class AuthExtensions
{
    public static WebApplicationBuilder AddKeyCloakAuthentication(this WebApplicationBuilder builder)
    {
        builder.Services
            .AddOptions<KeycloakOptions>()
            .BindConfiguration(nameof(KeycloakOptions))
            .ValidateDataAnnotations()
            .ValidateOnStart();

        var keycloakOptions = builder
            .Services
            .BuildServiceProvider()
            .GetRequiredService<Microsoft.Extensions.Options.IOptions<KeycloakOptions>>().Value;

        builder.Services
            .AddAuthentication()
            .AddKeycloakJwtBearer(
                keycloakOptions.ServiceName,
                keycloakOptions.Realm,
                options =>
                {
                    options.RequireHttpsMetadata = false;
                    options.Audience = keycloakOptions.Audience;
                    options.TokenValidationParameters = new TokenValidationParameters
                    {
                        ValidIssuers = keycloakOptions.ValidIssuers
                    };
                });

        return builder;
    }
}