using GBX.NET;
using GBX.NET.Engines.Game;
using GBX.NET.Engines.MwFoundations;
using GBX.NET.LZO;
using Microsoft.Data.Sqlite;
using System.Security.Cryptography;
using System.Threading.Channels;
using TmEssentials;

namespace Core;

public static class ReplayParser
{
    public static event Action? OnParsedOk;
    public static event Action<string>? OnSkipped;

    private static string? _dbPath;
    public static void Init(string dbPath) => _dbPath = dbPath;

    public static async Task ConsumeAsync(
        ChannelReader<string> reader,
        ChannelWriter<ReplayRecord> writer,
        string? myLogin,
        CancellationToken ct)
    {
        if (_dbPath is null)
            throw new InvalidOperationException("ReplayParser.Init(dbPath) not called.");

        if (Gbx.LZO is null)
            Gbx.LZO = new Lzo();

        int degree = Environment.ProcessorCount;

        var workers = Enumerable.Range(0, degree).Select(_ => Task.Run(async () =>
        {
            using var con = new SqliteConnection($"Data Source={_dbPath};Mode=ReadOnly");
            con.Open();

            await foreach (var path in reader.ReadAllAsync(ct))
            {
                var rec = TryParseIfUnique(path, myLogin, con);
                if (rec is not null)
                {
                    await writer.WriteAsync(rec, ct);
                    OnParsedOk?.Invoke();
                }
            }
        }, ct)).ToArray();

        await Task.WhenAll(workers);
        writer.Complete();
    }

    private static ReplayRecord? TryParseIfUnique(
        string path,
        string? myLogin,
        SqliteConnection con)
    {
        byte[] buf;
        try { buf = File.ReadAllBytes(path); }
        catch { return Skip("IOReadError"); }

        var md5 = Convert.ToHexString(MD5.HashData(buf));

        using (var cmd = con.CreateCommand())
        {
            cmd.CommandText = "SELECT 1 FROM replays WHERE ReplayHash=$h LIMIT 1;";
            cmd.Parameters.AddWithValue("$h", md5);
            if (cmd.ExecuteScalar() is 1)
                return Skip("HashDup");
        }

        CMwNod? node;
        using var ms = new MemoryStream(buf, writable: false);
        try { node = Gbx.ParseNode(ms); }
        catch { return Skip("GbxParseError"); }

        var fi = new FileInfo(path);

        return node switch
        {
            CGameCtnGhost g => Handle(g, path, fi, md5, myLogin),
            CGameCtnReplayRecord r => Handle(r, path, fi, md5, myLogin),
            _ => Skip("UnknownType")
        };
    }

    private static ReplayRecord? Skip(string reason)
    {
        OnSkipped?.Invoke(reason);
        return null;
    }

    private static uint ToMs(TimeInt32? t) =>
        t.HasValue ? (uint)t.Value.TotalMilliseconds : 0xFFFFFFFFu;

    private static ReplayRecord? Handle(
        CGameCtnGhost g,
        string path,
        FileInfo fi,
        string md5,
        string? myLogin)
    {
        if (!g.RaceTime.HasValue || string.IsNullOrEmpty(g.Validate_ChallengeUid))
            return Skip("NoTimeOrUid");

        if (myLogin is not null && g.GhostLogin != myLogin)
            return Skip("LoginMismatch");

        return new ReplayRecord
        {
            ReplayHash = md5,
            MapUid = g.Validate_ChallengeUid,
            PlayerLogin = g.GhostLogin,
            PlayerNick = g.GhostNickname,
            FileName = fi.Name,
            Path = path,
            BestTime = ToMs(g.RaceTime),
            NodeType = nameof(CGameCtnGhost),
            FoundThrough = "Folder Indexing"
        };
    }

    private static ReplayRecord? Handle(
        CGameCtnReplayRecord r,
        string path,
        FileInfo fi,
        string md5,
        string? myLogin)
    {
        if (r.Ghosts.Count == 0)
            return Skip("NoGhosts");

        var g0 = r.Ghosts[0];

        if (!g0.RaceTime.HasValue || string.IsNullOrEmpty(r.Challenge?.MapUid))
            return Skip("NoTimeOrUid");

        if (myLogin is not null && g0.GhostLogin != myLogin)
            return Skip("LoginMismatch");

        return new ReplayRecord
        {
            ReplayHash = md5,
            MapUid = r.Challenge.MapUid,
            PlayerLogin = g0.GhostLogin,
            PlayerNick = g0.GhostNickname,
            FileName = fi.Name,
            Path = path,
            BestTime = ToMs(g0.RaceTime),
            NodeType = nameof(CGameCtnReplayRecord),
            FoundThrough = "Folder Indexing"
        };
    }
}
