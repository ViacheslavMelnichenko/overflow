using System.Text.RegularExpressions;
using Microsoft.Extensions.Logging;
using Overflow.Contracts;
using Typesense;

namespace SearchService.MessageHandlers;

public class QuestionUpdatedHandler
{
    private readonly ITypesenseClient _client;
    private readonly ILogger<QuestionUpdatedHandler> _logger;

    public QuestionUpdatedHandler(ITypesenseClient client, ILogger<QuestionUpdatedHandler> logger)
    {
        _client = client;
        _logger = logger;
    }

    public async Task HandleAsync(QuestionUpdated message)
    {
        await _client.UpdateDocument("questions", message.QuestionId, new
        {
            message.Title,
            Content = StripHtml(message.Content),
            Tags = message.Tags.ToArray(),
        });
        
        _logger.LogInformation("✅ Updated question {QuestionId} in search index", message.QuestionId);
    }
    
    private static string StripHtml(string content)
    {
        return Regex.Replace(content, "<.*?>", string.Empty);
    }
}