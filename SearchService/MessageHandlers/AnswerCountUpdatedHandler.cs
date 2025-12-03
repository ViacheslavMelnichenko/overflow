using Microsoft.Extensions.Logging;
using Overflow.Contracts;
using Typesense;

namespace SearchService.MessageHandlers;

public class AnswerCountUpdatedHandler
{
    private readonly ITypesenseClient _client;
    private readonly ILogger<AnswerCountUpdatedHandler> _logger;

    public AnswerCountUpdatedHandler(ITypesenseClient client, ILogger<AnswerCountUpdatedHandler> logger)
    {
        _client = client;
        _logger = logger;
    }

    public async Task HandleAsync(AnswerCountUpdated message)
    {
        await _client.UpdateDocument("questions", message.QuestionId,
            new { message.AnswerCount }
        );
        _logger.LogInformation("✅ Updated answer count for question {QuestionId}: {AnswerCount}", 
            message.QuestionId, message.AnswerCount);
    }
}