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
        log("Database initialized. Path: " + dbPath, LogLevel::Info, 31, "InitializeDatabase");
    }

    void AddReplayToDB(const string&in path, const string&in mapRecordId = "") {
        if (path.StartsWith("http")) {
            ConvertGhostToReplay(path, mapRecordId);
            return;
        }
        if (path.ToLower().EndsWith(".ghost.gbx")) {
            log("Adding a .ghost.gbx file currently doesn't work, as they are stored as CGameCtnGhost..." + path, LogLevel::Error, 40, "AddReplayToDB");
            return;
        }
        if (path.ToLower().EndsWith(".replay.gbx")) {
            ProcessFile(path);
            return;
        }
    }

    void SaveReplayToDB(ReplayRecord@ replay) {
        const uint MAX_VALID_TIME = 2147480000;

        if (replay.BestTime <= 0 || replay.BestTime >= MAX_VALID_TIME) {
            log("Replay skipped due to invalid BestTime: " + replay.BestTime + " | "+"isDir: "+_IO::Directory::IsDirectory(replay.Path)+" | "+replay.Path, LogLevel::Warn, 53, "SaveReplayToDB");
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

        // log("Replay saved to DB: " + replay.ReplayHash, LogLevel::Info, 78, "SaveReplayToDB");
    }

    array<ReplayRecord@>@ GetReplaysFromDB(const string&in mapUid) {
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
        if (ghost is null || map is null) { log("Error getting replay filename, ghost or map input is null", LogLevel::Info, 134, "GetReplayFilename"); return ""; }
        string safeMapName = Path::SanitizeFileName(map.MapName);
        string safeUserName = Path::SanitizeFileName(ghost.Nickname);
        string safeCurrentTime = Path::SanitizeFileName(Regex::Replace(GetApp().OSLocalDate, "[/ ]", "_"));
        string fmtGhostTime = Path::SanitizeFileName(Time::Format(ghost.Result.Time));
        return safeMapName + "_" + safeUserName + "_" + safeCurrentTime + "_(" + fmtGhostTime + ")";
    }

    void ConvertGhostToReplay(const string &in url, const string &in mapRecordId) {
        CTrackMania@ app = cast<CTrackMania>(GetApp());
        if (app is null) return;
        CSmArenaRulesMode@ playgroundScript = cast<CSmArenaRulesMode>(app.PlaygroundScript);
        if (playgroundScript is null) return;
        CGameDataFileManagerScript@ dataFileMgr = cast<CGameDataFileManagerScript>(playgroundScript.DataFileMgr);
        if (dataFileMgr is null) { return; }

        if (url == "") { return; }

        log("ConvertGhostToReplay: Attempting to download ghost from URL: " + url, LogLevel::Info, 152, "ConvertGhostToReplay");
        CWebServicesTaskResult_GhostScript@ task = dataFileMgr.Ghost_Download("", url);

        while (task.IsProcessing && task.Ghost is null) { yield(); }

        CGameGhostScript@ ghost = cast<CGameGhostScript>(task.Ghost);
        if (ghost is null) { log("ConvertGhostToReplay: Download failed; ghost is null", LogLevel::Error, 158, "ConvertGhostToReplay"); return; }

        string replayName = GetReplayFilename(ghost, app.RootMap);
        string replayPath_tmp = IO::FromUserGameFolder("Replays/zzAutoEnablePBGhost/temp/" + replayName + ".Replay.Gbx");
        dataFileMgr.Replay_Save(replayPath_tmp, app.RootMap, ghost);

        string fileContent = _IO::File::ReadFileToEnd(replayPath_tmp);
        string hash = Crypto::MD5(fileContent);

        string replayPath = IO::FromUserGameFolder("Replays/zzAutoEnablePBGhost/dwn/" + hash + ".Replay.Gbx");
        dataFileMgr.Replay_Save(replayPath, app.RootMap, ghost);

        // FIXME: In a future update I need to add the ability to use Better Replay Folders so that the replay is saved to that folder instead (and not forced to be saved here...)
        log("ConvertGhostToReplay: Saving replay to " + replayPath, LogLevel::Info, 163, "ConvertGhostToReplay");

        AddReplayToDB(replayPath, mapRecordId);

        startnew(CoroutineFuncUserdataString(Loader::LoadLocalGhost), replayPath);

        // I'm not sure if I should really be removing the ghost here...
        startnew(CoroutineFuncUserdataString(DeleteFileWith200msDelay), replayPath_tmp);
    }

    void DeleteFileWith200msDelay(const string &in path) {
        sleep(200);
        if (IO::FileExists(path)) {
            IO::Delete(path);
            log("Deleted file: " + path, LogLevel::Info, 179, "DeleteFileWith200msDelay");
        }
    }
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

    void CalculateHash() {
        string fileContent = _IO::File::ReadFileToEnd(Path);
        ReplayHash = Crypto::MD5(fileContent);
    }
}
