namespace Database {
    void AddRecordFromLocalFile(const string &in fullPath, uint timeMs, const string &in mapUid) {
        if (!IO::FileExists(fullPath)) { log("AddRecordFromLocalFile: file does not exist: " + fullPath, LogLevel::Error, 3, "AddRecordFromLocalFile", "", "\\$f80"); return; }

        string buf  = _IO::File::ReadFileToEnd(fullPath);
        string hash = Crypto::MD5(buf);

        {
            EnsureOpen();
            auto stmt = g_Db.Prepare(
                "SELECT 1 FROM replays WHERE ReplayHash = ? LIMIT 1;");
            stmt.Bind(1, hash);
            stmt.Execute();
            if (stmt.NextRow()) {
                log("Replay already present in DB (hash duplicate): " + hash, LogLevel::Info, 15, "AddRecordFromLocalFile", "", "\\$f80");
                return;
            }
        }

        ReplayRecord@ rec = ParseReplay(fullPath);
        if (rec is null) { log("Could not parse saved replay - record not added.", LogLevel::Error, 21, "AddRecordFromLocalFile", "", "\\$f80"); return; }

        rec.MapUid       = mapUid;
        rec.BestTime     = timeMs;
        rec.ReplayHash   = hash;
        rec.Path         = fullPath;
        rec.FoundThrough = "Local Save";

        InsertOne(rec);

        log("Added local PB replay to DB (" + mapUid + ", " + timeMs + " ms)", LogLevel::Info, 31, "AddRecordFromLocalFile", "", "\\$f80");
    }
}
