using System.ComponentModel.DataAnnotations;

namespace QuestionService.DTOs;

public record CreateQuestionDto(
    [Required] string Title,
    [Required] string Content,
    [Required] List<string> Tags);