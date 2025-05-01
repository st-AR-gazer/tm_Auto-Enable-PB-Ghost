namespace Index {
    dictionary replayRecords;
    string DATABASE_PATH = "";

    string GetDatabasePath() {
        return DATABASE_PATH;
    }

    void SetDatabasePath() {
        DATABASE_PATH = IO::FromStorageFolder("ReplayRecords.db");
    }

    void InitializeDatabase() {
        string dbPath = GetDatabasePath();
        SQLite::Database@ db = SQLite::Database(dbPath);

        string createTableQuery = """
        CREATE TABLE IF NOT EXISTS ReplayRecords (
            ReplayHash TEXT PRIMARY KEY,
            MapUid TEXT NOT NULL,
            PlayerLogin TEXT NOT NULL,
            PlayerNickname TEXT,
            FileName TEXT,
            Path TEXT,
            BestTime INTEGER,
            NodeType TEXT,
            FoundThrough TEXT
        );
        """;

        db.Execute(createTableQuery);
        log("Database initialized. Path: " + dbPath, LogLevel::Info, 32, "InitializeDatabase");
    }

    void AddReplayToDatabase(const string&in path) {
        if (path.StartsWith("http")) {
            startnew(CoroutineFuncUserdataString(net::ConvertGhostToReplay), path);
            return;
        }
        if (path.ToLower().EndsWith(".ghost.gbx")) {
            // Ghost::AddGhostToDatabase(path);
            log("Ghost files are not supported, file has been skipped: " + path, LogLevel::Warn, 42, "AddReplayToDatabase");
            return;
        }
        if (path.ToLower().EndsWith(".replay.gbx")) {
            AddFileToDatabase(path);
            return;
        }
    }

    void AddReplayToDatabase(ReplayRecord@ replay) {
        const uint MAX_VALID_TIME = 2147480000;

        if (replay.BestTime <= 0 || replay.BestTime >= MAX_VALID_TIME) {
            log("Replay skipped due to invalid BestTime: " + replay.BestTime + " | "+"isDir: "+_IO::Directory::IsDirectory(replay.Path)+" | "+replay.Path, LogLevel::Warn, 55, "AddReplayToDatabase");
            return;
        }

        replay.CalculateHash();

        string dbPath = GetDatabasePath();
        SQLite::Database@ db = SQLite::Database(dbPath);

        string query = """
        INSERT INTO ReplayRecords (ReplayHash, MapUid, PlayerLogin, PlayerNickname, FileName, Path, BestTime, NodeType, FoundThrough)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """;

        auto stmt = db.Prepare(query);
        stmt.Bind(1, replay.ReplayHash);
        stmt.Bind(2, replay.MapUid);
        stmt.Bind(3, replay.PlayerLogin);
        stmt.Bind(4, replay.PlayerNickname);
        stmt.Bind(5, replay.FileName);
        stmt.Bind(6, replay.Path);
        stmt.Bind(7, replay.BestTime);
        stmt.Bind(8, replay.NodeType);
        stmt.Bind(9, replay.FoundThrough);
        stmt.Execute();
    }

    array<ReplayRecord@>@ GetReplaysFromDatabase(const string&in mapUid) {
        array<ReplayRecord@> results;
        string dbPath = GetDatabasePath();
        SQLite::Database@ db = SQLite::Database(dbPath);

        string query = "SELECT * FROM ReplayRecords WHERE MapUid = ?";
        auto stmt = db.Prepare(query);
        stmt.Bind(1, mapUid);

        while (stmt.NextRow()) {
            auto replay = ReplayRecord();
            replay.ReplayHash = stmt.GetColumnString("ReplayHash");
            replay.MapUid = stmt.GetColumnString("MapUid");
            replay.PlayerLogin = stmt.GetColumnString("PlayerLogin");
            replay.PlayerNickname = stmt.GetColumnString("PlayerNickname");
            replay.FileName = stmt.GetColumnString("FileName");
            replay.Path = stmt.GetColumnString("Path");
            replay.BestTime = stmt.GetColumnInt("BestTime");
            replay.NodeType = stmt.GetColumnString("NodeType");
            replay.FoundThrough = stmt.GetColumnString("FoundThrough");
            results.InsertLast(replay);
        }

        return results;
    }

    void DeleteAndReInitialize() {
        string dbPath = GetDatabasePath();
        if (IO::FileExists(dbPath)) { IO::Delete(dbPath); }
        InitializeDatabase();
    }

    int GetTotalReplaysForMap(const string&in mapUid) {
        string dbPath = GetDatabasePath();
        SQLite::Database@ db = SQLite::Database(dbPath);

        string query = "SELECT COUNT(*) FROM ReplayRecords WHERE MapUid = ?";
        auto stmt = db.Prepare(query);
        stmt.Bind(1, mapUid);
        stmt.NextRow();
        return stmt.GetColumnInt("COUNT(*)");
    }

    void DeleteEntryFromDatabaseBasedOnFilePath(const string&in path) {
        string dbPath = GetDatabasePath();
        SQLite::Database@ db = SQLite::Database(dbPath);

        string query = "DELETE FROM ReplayRecords WHERE Path = ?";
        auto stmt = db.Prepare(query);
        stmt.Bind(1, path);
        stmt.Execute();
    }

    string GetReplayFilename(CGameGhostScript@ ghost, CGameCtnChallenge@ map) {
        if (ghost is null || map is null) { log("Error getting replay filename, ghost or map input is null", LogLevel::Info, 136, "GetReplayFilename"); return ""; }
        string safeMapName = Path::SanitizeFileName(map.MapName);
        string safeUserName = Path::SanitizeFileName(ghost.Nickname);
        string safeCurrentTime = Path::SanitizeFileName(Regex::Replace(GetApp().OSLocalDate, "[/ ]", "_"));
        string fmtGhostTime = Path::SanitizeFileName(Time::Format(ghost.Result.Time));
        return safeMapName + "_" + safeUserName + "_" + safeCurrentTime + "_(" + fmtGhostTime + ")";
    }

    void DeleteFileWith1000msDelay(const string &in path) {
        log("File scheduled for deletion: " + path, LogLevel::Debug, 145, "DeleteFileWith1000msDelay");
        sleep(1000);
        if (IO::FileExists(path)) {
            IO::Delete(path);
            indexingMessageDebug = "Deleted file: " + path;
            // log("Deleted file: " + path, LogLevel::Info, 150, "DeleteFileWith1000msDelay");
        }
    }

    string GetFull_zzReplayPath() { return IO::FromUserGameFolder("Replays/zzAutoEnablePBGhost/"); }
    string GetRelative_zzReplayPath() { return "Replays/zzAutoEnablePBGhost/"; }
}

class ReplayRecord {
    string ReplayHash;
    string MapUid;
    string PlayerLogin;
    string PlayerNickname;
    string FileName;
    string Path;
    uint BestTime;
    string NodeType;
    string FoundThrough;

    ReplayRecord() {
        ReplayHash = "";
        MapUid = "";
        PlayerLogin = "";
        PlayerNickname = "";
        FileName = "";
        Path = "";
        BestTime = 0;
        NodeType = "";
        FoundThrough = "";
    }

    void CalculateHash() {
        string fileContent = _IO::File::ReadFileToEnd(Path);
        ReplayHash = Crypto::MD5(fileContent);
    }
}
