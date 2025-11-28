﻿using System.ComponentModel.DataAnnotations;

namespace Overflow.Common.Options;

public class KeycloakOptions
{
    public string? Url { get; set; }

    [Required]
    public required string ServiceName { get; set; }

    [Required]
    public required string Realm { get; set; }

    [Required]
    public required string Audience { get; set; }

    [Required]
    public required List<string> ValidIssuers { get; set; }
    
    // Optional: Client credentials for OAuth flows
    public string? ClientId { get; set; }
    
    public string? ClientSecret { get; set; }
}