using System.Runtime.CompilerServices;
using System.Threading.Channels;

namespace Core;

public static class FileIndexer
{
    public static event Action? OnFileSeen;
    public static event Action<string>? OnFileDiscovered;
    public static event Action<string>? OnDirSkipped;

    public static async Task ProduceAsync(string root,
                                          ChannelWriter<string> wr,
                                          CancellationToken ct)
    {
        await foreach (var file in EnumerateGbxFilesSafe(root, ct: ct))
        {
            await wr.WriteAsync(file, ct);
            OnFileSeen?.Invoke();
            OnFileDiscovered?.Invoke(file);
        }
        wr.Complete();
    }

    private static async IAsyncEnumerable<string> EnumerateGbxFilesSafe(
        string root,
        [EnumeratorCancellation] CancellationToken ct,
        int yieldEvery = 4_096)
    {
        var opts = new EnumerationOptions
        {
            RecurseSubdirectories = false,
            IgnoreInaccessible = true,
            ReturnSpecialDirectories = false
        };

        var stack = new Stack<string>();
        stack.Push(root);
        int tick = 0;

        while (stack.Count > 0)
        {
            ct.ThrowIfCancellationRequested();
            var dir = stack.Pop();

            IEnumerable<string> entries;
            try { entries = Directory.EnumerateFileSystemEntries(dir, "*", opts); }
            catch (Exception ex)
            {
                OnDirSkipped?.Invoke($"{dir} - {ex.Message}");
                continue;
            }

            foreach (var path in entries)
            {
                if (ct.IsCancellationRequested) yield break;

                if (Directory.Exists(path))
                {
                    stack.Push(path);
                }
                else
                {
                    if (path.EndsWith(".ghost.gbx", StringComparison.OrdinalIgnoreCase) ||
                        path.EndsWith(".replay.gbx", StringComparison.OrdinalIgnoreCase))
                    {
                        yield return path;
                        if (++tick % yieldEvery == 0)
                            await Task.Yield();
                    }
                }
            }
        }
    }
}
