using Microsoft.Data.Sqlite;

namespace Core;

public sealed class Database : IDisposable
{
    private readonly SqliteConnection _conn;
    private readonly SqliteCommand _insert;

    public Database(string dbPath)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(dbPath)!);
        _conn = new SqliteConnection($"Data Source={dbPath}");
        _conn.Open();

        using var pragma = _conn.CreateCommand();
        pragma.CommandText = "PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;";
        pragma.ExecuteNonQuery();

        _conn.Execute("""
            CREATE TABLE IF NOT EXISTS replays(
                Id            INTEGER PRIMARY KEY AUTOINCREMENT,
                MapUid        TEXT NOT NULL,
                PlayerLogin   TEXT,
                PlayerNick    TEXT,
                FileName      TEXT NOT NULL,
                Path          TEXT NOT NULL,
                BestTime      INTEGER NOT NULL,
                ReplayHash    TEXT,
                NodeType      TEXT,
                FoundThrough  TEXT,
                AddedAtUnix   INTEGER NOT NULL
            );
            CREATE INDEX  IF NOT EXISTS idx_mapuid ON replays(MapUid);
            CREATE UNIQUE INDEX IF NOT EXISTS idx_hash
                ON replays(ReplayHash) WHERE ReplayHash IS NOT NULL;
        """);

        _insert = _conn.CreateCommand();
        _insert.CommandText = """
            INSERT OR IGNORE INTO replays
            (MapUid,PlayerLogin,PlayerNick,FileName,Path,BestTime,
             ReplayHash,NodeType,FoundThrough,AddedAtUnix)
            VALUES ($map,$login,$nick,$file,$path,$time,
                    $hash,$node,$through,$ts);
        """;
        foreach (var p in new[]
        {
            "$map","$login","$nick","$file","$path","$time",
            "$hash","$node","$through","$ts"
        }) _insert.Parameters.Add(new(p, null));
    }

    public async Task BulkInsertAsync(IAsyncEnumerable<ReplayRecord> items,
                                      Action tick,
                                      CancellationToken ct)
    {
        using var tx = _conn.BeginTransaction();

        await foreach (var r in items.WithCancellation(ct))
        {
            _insert.Parameters["$map"].Value = r.MapUid;
            _insert.Parameters["$login"].Value = r.PlayerLogin;
            _insert.Parameters["$nick"].Value = r.PlayerNick;
            _insert.Parameters["$file"].Value = r.FileName;
            _insert.Parameters["$path"].Value = r.Path;
            _insert.Parameters["$time"].Value = (long)r.BestTime;
            _insert.Parameters["$hash"].Value = r.ReplayHash;
            _insert.Parameters["$node"].Value = r.NodeType;
            _insert.Parameters["$through"].Value = r.FoundThrough;
            _insert.Parameters["$ts"].Value = DateTimeOffset.UtcNow.ToUnixTimeSeconds();

            _insert.ExecuteNonQuery();
            tick();
        }

        tx.Commit();
    }

    public void Dispose() => _conn.Dispose();
}

file static class SqliteExt
{
    public static void Execute(this SqliteConnection c, string sql)
    {
        using var cmd = c.CreateCommand();
        cmd.CommandText = sql;
        cmd.ExecuteNonQuery();
    }
}
