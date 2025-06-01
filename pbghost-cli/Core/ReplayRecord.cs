namespace Core;

public sealed record ReplayRecord
{
    public string MapUid { get; init; } = "";
    public string? PlayerLogin { get; init; }
    public string? PlayerNick { get; init; }
    public string FileName { get; init; } = "";
    public string Path { get; init; } = "";
    public uint BestTime { get; init; }
    public string? ReplayHash { get; set; }
    public string NodeType { get; init; } = "";
    public string FoundThrough { get; init; } = "Folder Indexing";
}
