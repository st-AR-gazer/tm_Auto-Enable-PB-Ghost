namespace Index {
    dictionary replayRecords;

    string GetDatabasePath() {
        return IO::FromStorageFolder("ReplayRecords.db");
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
            FoundThrough TEXT
        );
        """;

        db.Execute(createTableQuery);
    }

    void SaveReplayToDB(const ReplayRecord@ replay) {
        const uint MAX_VALID_TIME = 2147480000;

        if (replay.BestTime <= 0 || replay.BestTime >= MAX_VALID_TIME) return;

        replay.CalculateHash();

        string dbPath = GetDatabasePath();
        SQLite::Database@ db = SQLite::Database(dbPath);

        string query = """
        INSERT INTO ReplayRecords (ReplayHash, MapUid, PlayerLogin, PlayerNickname, FileName, Path, BestTime, FoundThrough)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """;

        auto stmt = db.Prepare(query);
        stmt.Bind(1, replay.ReplayHash);
        stmt.Bind(2, replay.MapUid);
        stmt.Bind(3, replay.PlayerLogin);
        stmt.Bind(4, replay.PlayerNickname);
        stmt.Bind(5, replay.FileName);
        stmt.Bind(6, replay.Path);
        stmt.Bind(7, replay.BestTime);
        stmt.Bind(8, replay.FoundThrough);
        stmt.Execute();
    }

    array<ReplayRecord@>@ GetReplays(string mapUid) {
        if (replayRecords.Exists(mapUid)) {
            return cast<array<ReplayRecord@>>(replayRecords[mapUid]);
        }
        return array<ReplayRecord@>();
    }

    array<ReplayRecord@>@ GetReplaysFromDB(string mapUid) {
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
            replay.FoundThrough = stmt.GetColumnString("FoundThrough");
            results.InsertLast(replay);
        }

        return results;
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
    string FoundThrough;

    void CalculateHash() {
        string file = _IO::File::ReadFileToEnd(Path);
        ReplayHash = Crypto::MD5(file);
    }
}