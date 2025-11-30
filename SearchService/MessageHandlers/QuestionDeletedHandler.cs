using Microsoft.Extensions.Logging;
using Overflow.Contracts;
using SearchService.Models;
using Typesense;

namespace SearchService.MessageHandlers;

public class QuestionDeletedHandler
{
    private readonly ITypesenseClient _client;
    private readonly ILogger<QuestionDeletedHandler> _logger;

    public QuestionDeletedHandler(ITypesenseClient client, ILogger<QuestionDeletedHandler> logger)
    {
        _client = client;
        _logger = logger;
    }

    public async Task HandleAsync(QuestionDeleted message)
    {
        await _client.DeleteDocument<SearchQuestion>("questions", message.QuestionId);
        _logger.LogInformation("✅ Deleted question {QuestionId} from search index", message.QuestionId);
    }
}