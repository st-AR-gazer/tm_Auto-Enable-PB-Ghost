namespace Index {
    void IndexReplays() {
        auto app = GetApp();
        string currentPlayerLogin = app.LocalPlayerInfo.Login;
        const uint MAX_VALID_TIME = 2147480000;

        uint indexedCount = 0;
        uint skippedCount = 0;
        uint processedThisFrame = 0;
        const uint PROCESS_LIMIT = 2;

        for (uint i = 0; i < app.ReplayRecordInfos.Length; i++) {
            auto record = app.ReplayRecordInfos[i];

            if (record.PlayerLogin != currentPlayerLogin) {
                skippedCount++;
                continue;
            }

            if (record.BestTime <= 0 || record.BestTime >= MAX_VALID_TIME) {
                skippedCount++;
                continue;
            }

            string key = record.MapUid;

            string ProperPath = IO::FromUserGameFolder("Replays/" + record.FileName);
            string ProperFoundThrough = record.FileName;
            ProperFoundThrough = ProperFoundThrough.SubStr(0, ProperFoundThrough.LastIndexOf("\\"));

            auto replay = ReplayRecord();
            replay.MapUid = record.MapUid;
            replay.PlayerLogin = record.PlayerLogin;
            replay.PlayerNickname = record.PlayerNickname;
            replay.FileName = record.FileName;
            replay.Path = ProperPath;
            replay.BestTime = record.BestTime;
            replay.FoundThrough = ProperFoundThrough;
            replay.CalculateHash();

            if (!replayRecords.Exists(key)) {
                array<ReplayRecord@> records;
                replayRecords[key] = records;
            }

            auto records = cast<array<ReplayRecord@>>(replayRecords[key]);
            records.InsertLast(replay);

            SaveReplayToDB(replay);

            indexedCount++;
            processedThisFrame++;

            if (processedThisFrame >= PROCESS_LIMIT) {
                processedThisFrame = 0;
                yield();
            }
        }

        log("Indexed " + indexedCount + " replays. Skipped " + skippedCount + " invalid or non-relevant replays.", LogLevel::Info, 60, "IndexReplays");
    }
}