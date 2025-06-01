namespace UI;

public sealed record CliOptions
{
    public string Root { get; init; } = "";
    public string DbPath { get; init; } = "";
    public string? Login { get; init; }
    public bool SkipHash { get; init; }
    public int? Threads { get; init; }
}