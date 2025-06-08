namespace Database {

    const string DB_DIR  = IO::FromStorageFolder("");
    const string DB_PATH = DB_DIR + "pbghost.sqlite";

    SQLite::Database@ g_Db = null;
    bool g_Ready = false;

    bool g_Adding  = false;
    uint g_AddTot  = 0;
    uint g_AddDone = 0;

    bool  IsAddingToDatabase() { return g_Adding; }
    uint  AddTotal()           { return g_AddTot; }
    uint  AddDone()            { return g_AddDone; }
    float AddFraction()        { return g_AddTot == 0 ? 0.f : float(g_AddDone) / g_AddTot; }

    array<ReplayRecord@>@ g_Pending = null;

    void EnsureOpen() {
        if (g_Ready) return;

        IO::CreateFolder(DB_DIR);
        @g_Db = SQLite::Database(DB_PATH);

        g_Db.Execute("PRAGMA journal_mode=WAL;");
        g_Db.Execute("PRAGMA synchronous=NORMAL;");

        g_Db.Execute(
            "CREATE TABLE IF NOT EXISTS replays ("
            "  Id            INTEGER PRIMARY KEY AUTOINCREMENT,"
            "  MapUid        TEXT NOT NULL,"
            "  PlayerLogin   TEXT,"
            "  PlayerNick    TEXT,"
            "  FileName      TEXT NOT NULL,"
            "  Path          TEXT NOT NULL,"
            "  BestTime      INTEGER NOT NULL,"
            "  ReplayHash    TEXT,"
            "  NodeType      TEXT,"
            "  FoundThrough  TEXT,"
            "  AddedAtUnix   INTEGER NOT NULL"
            ");"
        );

        g_Db.Execute("CREATE INDEX IF NOT EXISTS idx_mapuid ON replays(MapUid);");
        g_Db.Execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_hash ON replays(ReplayHash) WHERE ReplayHash IS NOT NULL;");

        g_Ready = true;
    }

    void EnsureReady() {
        if (g_Db is null) {
            const string DB_PATH = IO::FromStorageFolder("pbghost.sqlite");
            @g_Db = SQLite::Database(DB_PATH);
            g_Db.Execute(
                "CREATE TABLE IF NOT EXISTS replays ("
                "  Id           INTEGER PRIMARY KEY AUTOINCREMENT,"
                "  MapUid       TEXT NOT NULL,"
                "  PlayerLogin  TEXT,"
                "  PlayerNick   TEXT,"
                "  FileName     TEXT NOT NULL,"
                "  Path         TEXT NOT NULL,"
                "  BestTime     INTEGER NOT NULL,"
                "  ReplayHash   TEXT,"
                "  NodeType     TEXT,"
                "  FoundThrough TEXT,"
                "  AddedAtUnix  INTEGER NOT NULL)");
        }
    }

    void AddRecords(array<ReplayRecord@>@ recs) {
        if (recs is null || recs.Length == 0) return;
        EnsureOpen();

        if (g_Adding) { log("Database import already in progress | Ignoring duplicate call.", LogLevel::Warn, 75, "AddRecords"); return; }

        g_Adding   = true;
        g_AddTot   = recs.Length;
        g_AddDone  = 0;
        @g_Pending = recs;
        startnew(Coro_Add);
    }

    void Coro_Add() {
        const uint YIELD_EVERY = 256;

        auto stmt = g_Db.Prepare(
            "INSERT OR IGNORE INTO replays "
            "(MapUid,PlayerLogin,PlayerNick,FileName,Path,BestTime,"
            " ReplayHash,NodeType,FoundThrough,AddedAtUnix) "
            "VALUES (?,?,?,?,?,?,?,?,?,?);"
        );

        g_Db.Execute("BEGIN;");

        uint tick = 0;
        for (uint i = 0; i < g_Pending.Length; ++i) {
            ReplayRecord@ r = g_Pending[i];
            int col = 1;
            stmt.Bind(col++, r.MapUid);
            stmt.Bind(col++, r.PlayerLogin);
            stmt.Bind(col++, r.PlayerNickname);
            stmt.Bind(col++, r.FileName);
            stmt.Bind(col++, r.Path);
            stmt.Bind(col++, int64(r.BestTime));
            stmt.Bind(col++, r.ReplayHash);
            stmt.Bind(col++, r.NodeType);
            stmt.Bind(col++, r.FoundThrough);
            stmt.Bind(col++, int64(Time::Stamp));

            stmt.Execute();
            stmt.Reset();

            ++g_AddDone;
            if (++tick >= YIELD_EVERY) {
                tick = 0;
                g_Db.Execute("COMMIT; BEGIN;");
                yield();
            }
        }

        g_Db.Execute("COMMIT;");
        g_Adding = false;
        @g_Pending = null;
        log("Database: inserted " + g_AddDone + " row(s).", LogLevel::Info, 125, "Coro_Add");
    }

    void InsertOne(ReplayRecord@ rec) {
        EnsureOpen();
        
        auto stmt = g_Db.Prepare(
            "INSERT OR IGNORE INTO replays "
            "(MapUid,PlayerLogin,PlayerNick,FileName,Path,BestTime,"
            " ReplayHash,NodeType,FoundThrough,AddedAtUnix) "
            "VALUES (?,?,?,?,?,?,?,?,?,?);"
        );

        int col = 1;
        stmt.Bind(col++, rec.MapUid);
        stmt.Bind(col++, rec.PlayerLogin);
        stmt.Bind(col++, rec.PlayerNickname);
        stmt.Bind(col++, rec.FileName);
        stmt.Bind(col++, rec.Path);
        stmt.Bind(col++, int64(rec.BestTime));
        stmt.Bind(col++, rec.ReplayHash);
        stmt.Bind(col++, rec.NodeType);
        stmt.Bind(col++, rec.FoundThrough);
        stmt.Bind(col++, int64(Time::Stamp));
        stmt.Execute();
    }

    bool HashExists(const string &in hash) {
        EnsureReady();
        SQLite::Statement@ st = g_Db.Prepare(
            "SELECT 1 FROM replays WHERE ReplayHash = ?1 LIMIT 1");
        st.Bind(1, hash);
        bool present = st.NextRow();
        st.Reset();
        return present;
    }

    bool HashIsMine(const string &in hash) {
        EnsureReady();
        SQLite::Statement@ st = g_Db.Prepare(
            "SELECT PlayerLogin FROM replays WHERE ReplayHash = ?1 LIMIT 1");
        st.Bind(1, hash);
        if (!st.NextRow()) { st.Reset(); return false; }
        bool mine = st.GetColumnString("PlayerLogin") == _localLogin();
        st.Reset();
        return mine;
    }

    void StoreHash(const string &in hash, bool mine) {
        EnsureReady();
        if (HashExists(hash)) { return; }

        SQLite::Statement@ st = g_Db.Prepare(
            "INSERT INTO replays(ReplayHash, PlayerLogin, AddedAtUnix) "
            "VALUES (?1, ?2, ?3)");
        st.Bind(1, hash);
        st.Bind(2, mine ? _localLogin() : "");
        st.Bind(3, int64(Time::Stamp));
        st.Execute();
        st.Reset();
    }

    int HashStatus(const string &in md5) {
        EnsureReady();
        SQLite::Statement@ st = g_Db.Prepare(
            "SELECT PlayerLogin FROM replays WHERE ReplayHash = ?1 LIMIT 1");
        st.Bind(1, md5);

        if (!st.NextRow()) { st.Reset(); return -1; }

        bool mine = st.GetColumnString("PlayerLogin") == _localLogin();
        st.Reset();
        return mine ? 1 : 0;
    }

    string _localLogin() { return GetApp().LocalPlayerInfo.Login; }
    
    // -------------------------------------------------------------------------

    /* External API functions */
    array<ReplayRecord@>@ GetReplays(const string &in mapUid) {
        EnsureOpen();
        array<ReplayRecord@> result;

        auto stmt = g_Db.Prepare(
            "SELECT MapUid,PlayerLogin,PlayerNick,FileName,Path,BestTime,"
            "       ReplayHash,NodeType,FoundThrough "
            "FROM replays WHERE MapUid = ?;"
        );
        stmt.Bind(1, mapUid);
        stmt.Execute();

        while (stmt.NextRow()) {
            ReplayRecord r;
            r.MapUid         = stmt.GetColumnString("MapUid");
            r.PlayerLogin    = stmt.GetColumnString("PlayerLogin");
            r.PlayerNickname = stmt.GetColumnString("PlayerNick");
            r.FileName       = stmt.GetColumnString("FileName");
            r.Path           = stmt.GetColumnString("Path");
            r.BestTime       = uint(stmt.GetColumnInt("BestTime"));
            r.ReplayHash     = stmt.GetColumnString("ReplayHash");
            r.NodeType       = stmt.GetColumnString("NodeType");
            r.FoundThrough   = stmt.GetColumnString("FoundThrough");
            result.InsertLast(r);
        }
        return result;
    }

    uint GetReplayCount(const string &in mapUid) {
        EnsureOpen();

        auto stmt = g_Db.Prepare("SELECT COUNT(*) AS Cnt FROM replays WHERE MapUid = ?;");
        stmt.Bind(1, mapUid);
        stmt.Execute();

        uint cnt = 0;
        if (stmt.NextRow()) cnt = uint(stmt.GetColumnInt("Cnt"));

        return cnt;
    }

    void DeleteDatabase() {
        @g_Db  = null;
        g_Ready = false;


        string[]@ paths = IO::IndexFolder(DB_DIR, false);

        for (uint i = 0; i < paths.Length; ++i) {
            if (paths[i].StartsWith(DB_PATH)) {
                if (IO::FileExists(paths[i])) IO::Delete(paths[i]);
            }
        }
    }
}
