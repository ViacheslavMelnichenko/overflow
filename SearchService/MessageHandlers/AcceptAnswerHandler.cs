using Microsoft.Extensions.Logging;
using Overflow.Contracts;
using Typesense;

namespace SearchService.MessageHandlers;

public class AcceptAnswerHandler
{
    private readonly ITypesenseClient _client;
    private readonly ILogger<AcceptAnswerHandler> _logger;

    public AcceptAnswerHandler(ITypesenseClient client, ILogger<AcceptAnswerHandler> logger)
    {
        _client = client;
        _logger = logger;
    }

    public async Task HandleAsync(AnswerAccepted message)
    {
        await _client.UpdateDocument("questions", message.QuestionId, 
            new {HasAcceptedAnswer = true});
        _logger.LogInformation("✅ Marked question {QuestionId} as having accepted answer", message.QuestionId);
    }
}