namespace SearchService.DTOs;

/// <summary>
/// Response for search queries containing matching questions
/// </summary>
public class SearchResponse
{
    public List<Models.SearchQuestion> Results { get; set; } = new();
    public long TotalFound { get; set; }
    public int Page { get; set; }
    public int PerPage { get; set; }
    public string Query { get; set; } = string.Empty;
    public string? Tag { get; set; }
}

/// <summary>
/// Response for similar titles search
/// </summary>
public class SimilarTitlesResponse
{
    public List<SimilarTitle> Results { get; set; } = new();
    public long TotalFound { get; set; }
    public string Query { get; set; } = string.Empty;
}

/// <summary>
/// Represents a question with a similar title
/// </summary>
public class SimilarTitle
{
    public string Id { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public List<string> Tags { get; set; } = new();
    public long CreatedAt { get; set; }
    public long Score { get; set; }
}

