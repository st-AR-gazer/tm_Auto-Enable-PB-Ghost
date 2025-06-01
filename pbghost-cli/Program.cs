using System.CommandLine;
using System.Collections.Concurrent;
using System.Threading;
using System.Threading.Channels;
using Microsoft.Data.Sqlite;
using Core;
using Spectre.Console;
using UI;

namespace PbGhostCli;

internal static class Program
{
    public static async Task Main(string[] args)
    {
        var rootOpt = new Option<DirectoryInfo?>("--root", "Root folder to scan");
        var dbOpt = new Option<FileInfo?>("--db", "Custom sqlite path");
        var loginOpt = new Option<string?>("--login", "Trackmania login or * for all");
        var threadsOpt = new Option<int?>("--threads", "Max parser threads");
        var guiOpt = new Option<bool>(new[] { "--gui", "--no-gui" }, () => !Console.IsOutputRedirected, "Show progress UI");
        var verboseOpt = new Option<bool>("--verbose", "Verbose FILE / SKIP / INSERT");
        var debugOpt = new Option<bool>("--debug", "Show first 50 dir errors");

        var cmd = new RootCommand("PB-ghost bulk indexer")
        {
            rootOpt, dbOpt, loginOpt, threadsOpt, guiOpt, verboseOpt, debugOpt
        };

        cmd.SetHandler(async (DirectoryInfo? root,
                              FileInfo? db,
                              string? login,
                              int? threads,
                              bool gui,
                              bool verbose,
                              bool debug) =>
        {
            var opts = ResolveOptions(root, db, login, threads);
            if (opts is not null)
                await RunAsync(opts, gui, verbose, debug);
        },
        rootOpt, dbOpt, loginOpt, threadsOpt, guiOpt, verboseOpt, debugOpt);

        await cmd.InvokeAsync(args);
    }

    private static CliOptions? ResolveOptions(
        DirectoryInfo? cliRoot,
        FileInfo? cliDb,
        string? cliLogin,
        int? threads)
    {
        string? root = cliRoot?.FullName;
        while (string.IsNullOrWhiteSpace(root) || !Directory.Exists(root))
        {
            root = AnsiConsole.Ask<string>("Enter [yellow]root folder[/] (blank = quit):");
            if (string.IsNullOrWhiteSpace(root)) return null;
            if (!Directory.Exists(root)) AnsiConsole.MarkupLine("[red]Folder not found.[/]");
        }

        string? login = cliLogin;
        while (string.IsNullOrWhiteSpace(login))
        {
            login = AnsiConsole.Ask<string>(
                "Enter your [yellow]Trackmania login-identifier[/] or [green]*[/] for all replays\n" +
                "[grey](find it on your trackmania.io profile, labelled “login”, e.g. 0QzczTHnSR-VBNcu46cN5g)[/]\n" +
                "(blank = quit):");
            if (string.IsNullOrWhiteSpace(login)) return null;
        }
        if (login == "*") login = null;

        var dbPath = cliDb?.FullName ?? DefaultDbPath();
        Directory.CreateDirectory(Path.GetDirectoryName(dbPath)!);

        return new CliOptions
        {
            Root = root,
            DbPath = dbPath,
            Login = login,
            Threads = threads
        };
    }

    private static string DefaultDbPath()
    {
        var user = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        var dev = Path.Combine(user, "OpenplanetNext", "PluginStorage", "tm_Auto-Enable-PB-Ghost");
        var prod = Path.Combine(user, "OpenplanetNext", "PluginStorage", "AutoEnablePBGhost");
        return Directory.Exists(dev) ? Path.Combine(dev, "pbghost.sqlite")
                                     : Path.Combine(prod, "pbghost.sqlite");
    }

    private static void EnsureSchema(string dbPath)
    {
        using var con = new SqliteConnection($"Data Source={dbPath}");
        con.Open();
        using var cmd = con.CreateCommand();
        cmd.CommandText =
            @"PRAGMA journal_mode=WAL;
              PRAGMA synchronous=NORMAL;
              CREATE TABLE IF NOT EXISTS replays(
                 Id INTEGER PRIMARY KEY AUTOINCREMENT,
                 MapUid       TEXT NOT NULL,
                 PlayerLogin  TEXT,
                 PlayerNick   TEXT,
                 FileName     TEXT NOT NULL,
                 Path         TEXT NOT NULL,
                 BestTime     INTEGER NOT NULL,
                 ReplayHash   TEXT,
                 NodeType     TEXT,
                 FoundThrough TEXT,
                 AddedAtUnix  INTEGER NOT NULL);
              CREATE INDEX IF NOT EXISTS idx_mapuid ON replays(MapUid);
              CREATE UNIQUE INDEX IF NOT EXISTS idx_hash ON replays(ReplayHash) WHERE ReplayHash IS NOT NULL;";
        cmd.ExecuteNonQuery();
    }

    private static async Task RunAsync(
        CliOptions o, bool showGui, bool verbose, bool debug)
    {
        if (o.Threads is int n && n > 0) ThreadPool.SetMaxThreads(n, n);

        EnsureSchema(o.DbPath);
        ReplayParser.Init(o.DbPath);

        var fileCh = Channel.CreateBounded<string>(1024);
        var recCh = Channel.CreateUnbounded<ReplayRecord>();
        var cts = new CancellationTokenSource();

        long idx = 0, par = 0, ins = 0, skip = 0;
        var skipBreak = new ConcurrentDictionary<string, long>();

        FileIndexer.OnFileSeen += () => Interlocked.Increment(ref idx);
        FileIndexer.OnFileDiscovered += p => { if (verbose) Console.WriteLine($"FILE   {p}"); };

        int dirShown = 0;
        FileIndexer.OnDirSkipped += m =>
        {
            skipBreak.AddOrUpdate("DirError", 1, (_, v) => v + 1);
            Interlocked.Increment(ref skip);
            if (debug && dirShown < 50) { Console.WriteLine($"[DirSkip] {m}"); dirShown++; }
        };

        ReplayParser.OnParsedOk += () =>
        {
            Interlocked.Increment(ref par);
            if (verbose) Console.WriteLine("OK     parsed");
        };
        ReplayParser.OnSkipped += r =>
        {
            skipBreak.AddOrUpdate(r, 1, (_, v) => v + 1);
            Interlocked.Increment(ref skip);
            if (verbose) Console.WriteLine($"SKIP   {r}");
        };

        var tIdx = FileIndexer.ProduceAsync(o.Root, fileCh.Writer, cts.Token);
        var tPar = ReplayParser.ConsumeAsync(fileCh.Reader, recCh.Writer, o.Login, cts.Token);
        var tSql = SqlInserter(recCh.Reader, o.DbPath,
                     () =>
                     {
                         Interlocked.Increment(ref ins);
                         if (verbose) Console.WriteLine("INSERT row");
                     },
                     cts.Token);

        if (showGui)
            await RunGui(tIdx, tPar, tSql,
                         () => idx, () => par, () => ins, () => skip);
        else
            await Task.WhenAll(tIdx, tPar, tSql);

        Console.WriteLine();
        Console.WriteLine($"Files indexed : {idx:N0}");
        Console.WriteLine($"Parsed OK     : {par:N0}");
        Console.WriteLine($"Rows inserted : {ins:N0}");
        Console.WriteLine($"Skipped total : {skip:N0}");
        if (skipBreak.Count > 0)
            foreach (var kv in skipBreak.OrderBy(k => k.Key))
                Console.WriteLine($"{kv.Key,-15} {kv.Value:N0}");
    }

    private static async Task SqlInserter(
        ChannelReader<ReplayRecord> reader,
        string dbPath,
        Action onInsert,
        CancellationToken ct)
    {
        using var con = new SqliteConnection($"Data Source={dbPath}");
        con.Open();
        using (var c = con.CreateCommand())
        {
            c.CommandText = "PRAGMA journal_mode=WAL;"; c.ExecuteNonQuery();
            c.CommandText = "PRAGMA synchronous=NORMAL;"; c.ExecuteNonQuery();
        }

        var cmd = con.CreateCommand();
        cmd.CommandText =
            @"INSERT OR IGNORE INTO replays
              (MapUid,PlayerLogin,PlayerNick,FileName,Path,BestTime,
               ReplayHash,NodeType,FoundThrough,AddedAtUnix)
              VALUES ($u,$l,$n,$fn,$p,$t,$h,$nt,$ft,$ts);";

        var pu = cmd.CreateParameter(); pu.ParameterName = "$u"; cmd.Parameters.Add(pu);
        var pl = cmd.CreateParameter(); pl.ParameterName = "$l"; cmd.Parameters.Add(pl);
        var pn = cmd.CreateParameter(); pn.ParameterName = "$n"; cmd.Parameters.Add(pn);
        var pfn = cmd.CreateParameter(); pfn.ParameterName = "$fn"; cmd.Parameters.Add(pfn);
        var pp = cmd.CreateParameter(); pp.ParameterName = "$p"; cmd.Parameters.Add(pp);
        var pt = cmd.CreateParameter(); pt.ParameterName = "$t"; cmd.Parameters.Add(pt);
        var ph = cmd.CreateParameter(); ph.ParameterName = "$h"; cmd.Parameters.Add(ph);
        var pnt = cmd.CreateParameter(); pnt.ParameterName = "$nt"; cmd.Parameters.Add(pnt);
        var pft = cmd.CreateParameter(); pft.ParameterName = "$ft"; cmd.Parameters.Add(pft);
        var pts = cmd.CreateParameter(); pts.ParameterName = "$ts"; cmd.Parameters.Add(pts);

        SqliteTransaction txn = con.BeginTransaction();
        cmd.Transaction = txn;
        int inTxn = 0;

        await foreach (var r in reader.ReadAllAsync(ct))
        {
            pu.Value = r.MapUid; pl.Value = r.PlayerLogin; pn.Value = r.PlayerNick;
            pfn.Value = r.FileName; pp.Value = r.Path; pt.Value = (long)r.BestTime;
            ph.Value = r.ReplayHash ?? (object)DBNull.Value;
            pnt.Value = r.NodeType; pft.Value = r.FoundThrough;
            pts.Value = DateTimeOffset.UtcNow.ToUnixTimeSeconds();

            try { cmd.ExecuteNonQuery(); } catch { }
            onInsert();

            if (++inTxn >= 1000)
            {
                txn.Commit(); txn.Dispose();
                txn = con.BeginTransaction(); cmd.Transaction = txn; inTxn = 0;
            }
        }
        txn.Commit();
    }

    private static async Task RunGui(
        Task idxT, Task parT, Task sqlT,
        Func<long> getIdx, Func<long> getPar, Func<long> getIns, Func<long> getSkip)
    {
        const int IdleSeconds = 10;

        await AnsiConsole.Progress()
            .AutoRefresh(true).AutoClear(false)
            .Columns(new ProgressColumn[]{
                new TaskDescriptionColumn(), new ProgressBarColumn(),
                new SpinnerColumn(),         new ElapsedTimeColumn()
            })
            .StartAsync(async ctx =>
        {
            var tIdx = ctx.AddTask("Indexing  (0)"); tIdx.IsIndeterminate = true;
            var tPar = ctx.AddTask("Parsing   (0)"); tPar.IsIndeterminate = true;
            var tSql = ctx.AddTask("SQLite    (0)"); tSql.IsIndeterminate = true;
            var tSkp = ctx.AddTask("Skipped   (0)"); tSkp.IsIndeterminate = true;

            var lastIdx = 0L; var lastPar = 0L; var lastIns = 0L;
            var idle = System.Diagnostics.Stopwatch.StartNew();
            var timer = new PeriodicTimer(TimeSpan.FromMilliseconds(250));

            while (await timer.WaitForNextTickAsync())
            {
                tIdx.Description = $"Indexing  ({getIdx():N0})";
                tPar.Description = $"Parsing   ({getPar():N0})";
                tSql.Description = $"SQLite    ({getIns():N0})";
                tSkp.Description = $"Skipped   ({getSkip():N0})";

                if (idxT.IsCompleted && parT.IsCompleted && sqlT.IsCompleted)
                {
                    timer.Dispose(); break;
                }

                if (getIdx() == lastIdx && getPar() == lastPar && getIns() == lastIns)
                {
                    if (idle.Elapsed >= TimeSpan.FromSeconds(IdleSeconds))
                    {
                        AnsiConsole.MarkupLine("\n[yellow]Warning: Very large library detected (>50k files). " +
                                               "All workers appear idle but UI cannot confirm this automatically. " +
                                               "If the counters no longer change you can safely close the window.[/]");
                        AnsiConsole.MarkupLine("\n[gray]This is just me saying 'fuck it' I don't want to spend more time figuring out why it dosn't work xpp[/]");
                        timer.Dispose(); break;
                    }
                }
                else
                {
                    idle.Restart();
                    lastIdx = getIdx(); lastPar = getPar(); lastIns = getIns();
                }
            }

            await Task.WhenAll(idxT, parT, sqlT);
            tIdx.StopTask(); tPar.StopTask(); tSql.StopTask(); tSkp.StopTask();
            ctx.Refresh();
            AnsiConsole.MarkupLine("\n[green]✓ Completed.[/]");
        });
    }
}
