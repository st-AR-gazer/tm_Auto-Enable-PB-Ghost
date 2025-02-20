namespace Index {
    bool nodIsIndexing = false;
    bool nodPhaseGather = false;
    bool nodPhasePrepare = false;
    bool nodPhaseAdd = false;

    array<CGameCtnReplayRecordInfo@> nodPendingInfos;
    array<ReplayRecord> nodPendingRecords;

    int nodTotalCount = 0;
    int nodCurrentCount = 0;

    [Setting hidden]
    int NOD_GATHER_BATCH_SIZE = 1000;
    [Setting hidden]
    int NOD_PREPARE_BATCH_SIZE = 2;
    [Setting hidden]
    int NOD_ADD_BATCH_SIZE = 5;

    bool nodForceStop = false;

    string nodIndexingMessage = "";

    float PHASE_GATHER_END = 0.3f;
    float PHASE_PREPARE_END = 0.6f;


    void Stop_NodIndexing() {
        nodForceStop = true;
        nodIsIndexing = false;
        nodPhaseGather = false;
        nodPhasePrepare = false;
        nodPhaseAdd = false;
        nodPendingInfos.Resize(0);
        nodPendingRecords.Resize(0);
        nodIndexingMessage = "";
        nodTotalCount = 0;
        nodCurrentCount = 0;
    }

    void Start_IndexReplayRecords() {
        Stop_NodIndexing();
        nodForceStop = false;
        nodIsIndexing = true;
        nodIndexingMessage = "NOD indexing started.";

        nodPhaseGather = true;
        startnew(GatherNodReplays);
        while (nodPhaseGather && !nodForceStop) { yield(); }

        if (nodForceStop) { nodIsIndexing = false; return; }

        nodPhasePrepare = true;
        nodCurrentCount = 0;
        startnew(PrepareNodReplays);
        while (nodPhasePrepare && !nodForceStop) { yield(); }

        if (nodForceStop) { nodIsIndexing = false; return; }

        nodPhaseAdd = true;
        nodCurrentCount = 0;
        startnew(AddNodReplaysToDB);
        while (nodPhaseAdd && !nodForceStop) { yield(); }

        nodIsIndexing = false;
        nodIndexingMessage = "NOD indexing complete!";
        log(nodIndexingMessage, LogLevel::Info, 67, "Start_IndexReplayRecords");
        startnew(CoroutineFuncUserdataInt64(ClearNodIndexingMessageAfterDelay), 2000);
    }


    // Part 1: Gathering
    // ---------------------------------------------------------
    void GatherNodReplays() {
        nodPhaseGather = true;
        nodCurrentCount = 0;
        nodPendingInfos.Resize(0);

        auto app = GetApp();
        string currentPlayerLogin = app.LocalPlayerInfo.Login;
        const uint MAX_VALID_TIME = 2147480000;

        uint skippedCount = 0;
        uint localProcessed = 0;

        nodTotalCount = app.ReplayRecordInfos.Length;

        for (uint i = 0; i < app.ReplayRecordInfos.Length && !nodForceStop; i++) {
            auto info = app.ReplayRecordInfos[i];
            if (info is null) { skippedCount++; continue; }
            if (info.PlayerLogin != currentPlayerLogin) { skippedCount++; continue; }
            if (info.BestTime <= 0 || info.BestTime >= MAX_VALID_TIME) { skippedCount++; continue; }
            nodPendingInfos.InsertLast(info);

            localProcessed++;
            nodCurrentCount++;

            if (localProcessed % NOD_GATHER_BATCH_SIZE == 0) { yield(); }
        }

        nodIndexingMessage = "Gather: " + nodPendingInfos.Length + " valid replays, skipped " + skippedCount;
        nodPhaseGather = false;
    }

    // Part 2: Preparing
    // ---------------------------------------------------------
    void PrepareNodReplays() {
        nodPhasePrepare = true;
        nodPendingRecords.Resize(0);
        nodTotalCount = nodPendingInfos.Length;
        nodCurrentCount = 0;

        for (uint i = 0; i < nodPendingInfos.Length && !nodForceStop; i++) {
            auto info = nodPendingInfos[i];
            if (info is null) { yield(); continue; }
            BuildReplayRecord(info);
            nodCurrentCount++;

            if (i % NOD_PREPARE_BATCH_SIZE == 0) { yield(); }
        }

        nodIndexingMessage = "Prepared " + nodPendingRecords.Length + " replays for DB insertion.";
        nodPhasePrepare = false;
    }

    void BuildReplayRecord(CGameCtnReplayRecordInfo@ info) {
        string fullPath = IO::FromUserGameFolder("Replays/" + info.FileName);
        auto replay = ReplayRecord();
        replay.MapUid = info.MapUid;
        replay.PlayerLogin = info.PlayerLogin;
        replay.PlayerNickname = info.PlayerNickname;
        replay.FileName = info.FileName;
        replay.Path = fullPath;
        replay.BestTime = info.BestTime;
        replay.FoundThrough = "NOD indexing";
        replay.NodeType = Reflection::TypeOf(info).Name;
        replay.CalculateHash();
        nodPendingRecords.InsertLast(replay);
    }

    // Part 3: Add
    // ---------------------------------------------------------
    void AddNodReplaysToDB() {
        nodPhaseAdd = true;
        nodTotalCount = nodPendingRecords.Length;
        nodCurrentCount = 0;

        for (uint i = 0; i < nodPendingRecords.Length && !nodForceStop; i++) {
            auto replay = nodPendingRecords[i];
            InsertReplayIntoDatabase(replay);
            nodCurrentCount++;

            if (i % NOD_ADD_BATCH_SIZE == 0) { yield(); }
        }

        nodIndexingMessage = "Database insertion complete.";
        nodPhaseAdd = false;
    }

    void InsertReplayIntoDatabase(ReplayRecord@ replay) {
        string mapUid = replay.MapUid;
        if (!replayRecords.Exists(mapUid)) {
            array<ReplayRecord@> arr;
            replayRecords[mapUid] = arr;
        }
        auto arr = cast<array<ReplayRecord@>>(replayRecords[mapUid]);
        arr.InsertLast(replay);
        AddReplayToDatabase(replay);
    }

    float GetNodIndexProgressFraction() {
        if (nodPhaseGather) {
            if (nodTotalCount == 0) return 0.0f;
            return (float(nodCurrentCount) / float(nodTotalCount)) * 0.3f;
        }

        if (nodPhasePrepare) {
            if (nodTotalCount == 0) return 0.3f;
            float fraction = float(nodCurrentCount) / float(nodTotalCount);
            return 0.3f + fraction * 0.3f;
        }

        if (nodPhaseAdd) {
            if (nodTotalCount == 0) return 0.6f;
            float fraction = float(nodCurrentCount) / float(nodTotalCount);
            return 0.6f + fraction * 0.4f;
        }

        return 1.0f;
    }

    // ---------------------------------------------------------

    void ClearNodIndexingMessageAfterDelay(int64 delayMs) {
        sleep(delayMs);
        nodIndexingMessage = "";
    }
}
