using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc;
using SearchService.Models;
using Typesense;

namespace SearchService.Controllers;

[ApiController]
[Route("[controller]")]
public class SearchController(ITypesenseClient typesenseClient) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult> Get(string query)
    {
        string? tag = null;
        var tagMatch = Regex.Match(query, @"\[(.*?)\]");
        if (tagMatch.Success)
        {
            tag = tagMatch.Groups[1].Value;
            query = query.Replace(tagMatch.Value, "").Trim();
        }

        var searchParams = new SearchParameters(query, "title,content");

        if (!string.IsNullOrWhiteSpace(tag))
        {
            searchParams.FilterBy = $"tags:=[{tag}]";
        }

        try
        {
            var result = await typesenseClient.Search<SearchQuestion>("questions", searchParams);
            return Ok(result.Hits.Select(hit => hit.Document));
        }
        catch (Exception e)
        {
            return Problem("Typesense search failed", e.Message);
        }
    }

    [HttpGet("similar-titles")]
    public async Task<ActionResult> GetSimilarTitles(string query)
    {
        var searchParams = new SearchParameters(query, "title");

        try
        {
            var result = await typesenseClient.Search<SearchQuestion>("questions", searchParams);
            return Ok(result.Hits.Select(hit => hit.Document));
        }
        catch (Exception e)
        {
            return Problem("Typesense search failed", e.Message);
        }
    }
}