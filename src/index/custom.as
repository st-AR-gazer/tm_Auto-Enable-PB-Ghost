namespace Index {
    string S_customFolderIndexingLocation = "";

    array<string> pendingFiles_FolderIndexing;
    array<string> pendingFiles_PrepareFiles;
    array<ReplayRecord> pendingFiles_AddToDatabase;

    bool isIndexing = false;
    bool f_isIndexing_FilePaths = false;
    bool p_isIndexing_PrepareFiles = false;
    bool d_isIndexing_AddToDatabase = false;

    int totalFileNumber = 0;
    int currentFileNumber = 0;

    string latestFile = "";
    string indexingMessage = "";
    string currentIndexingPath = "";

    bool forceStopIndexing = false;

    void Stop_RecursiveSearch() {
        forceStopIndexing = true;
        isIndexing = false; 
        totalFileNumber = 0;
        currentFileNumber = 0;
        latestFile = "";
        indexingMessage = "";
        currentIndexingPath = "";
    }

    void Start_RecursiveSearch(const string &in folderPath) {
        log("Starting recursive search in folder: " + folderPath, LogLevel::Info, 15, "Start_RecursiveSearch");
        isIndexing = true;
        
        f_isIndexing_FilePaths = true;
        log("Getting all file paths");
        startnew(CoroutineFuncUserdataString(IndexFoldersAndSubfolders), folderPath);
        while (f_isIndexing_FilePaths) { yield(); }
        
        p_isIndexing_PrepareFiles = true;
        log("Preparing files for addition to the database");
        startnew(PrepareFilesForAdditionToDatabase);
        while (p_isIndexing_PrepareFiles) { yield(); }
        
        d_isIndexing_AddToDatabase = true;
        log("Adding files to the database");
        startnew(AddFilesToDatabase);
        while (d_isIndexing_AddToDatabase) { yield(); }

        isIndexing = false;
        indexingMessage = "Full addition to the database complete!";
        startnew(CoroutineFuncUserdataInt64(SetIndexingMessageToEmptyStringAfterDelay), 1000);
        log("Finished recursive search in folder: " + folderPath, LogLevel::Info, 15, "Start_RecursiveSearch");
    }

    bool IsIndexingInProgress() {
        return isIndexing;
    }

    float idxProgress = 0.0f;
    float prepProgress = 0.0f;
    float addProgress = 0.0f;

    float GetIndexingProgressFraction() {
        if (!isIndexing) return 1.0;
        if (f_isIndexing_FilePaths) {
            return idxProgress / 3.0;
        } else if (p_isIndexing_PrepareFiles) {
            return (1.0 / 3.0) + (prepProgress / 3.0);
        } else if (d_isIndexing_AddToDatabase) {
            return (2.0 / 3.0) + (addProgress / 3.0);
        }
        return 1.0;
    }


    // =============================================================
    // Better IO::Index(string path, bool recursive = true)
    // =============================================================

    array<string> dirsToProcess;
    int RECURSIVE_SEARCH_BATCH_SIZE = 100;

    int totalTasks = 0;
    int totalFoldersProcessed = 0;

    void IndexFoldersAndSubfolders(const string&in folderPath) {

        // ----
        idxProgress = 0.0f;
        uint totalHandled = 0;
        uint totalPossible = 0;
        dirsToProcess.InsertLast(folderPath);
        totalFoldersProcessed = 0;

        uint totalDirCount = dirsToProcess.Length;
        uint processedDirCount = 0;
        while (f_isIndexing_FilePaths && dirsToProcess.Length > 0 && !forceStopIndexing) {
            string currentDir = dirsToProcess[dirsToProcess.Length - 1];
            dirsToProcess.RemoveAt(dirsToProcess.Length - 1);
            
            totalFoldersProcessed++;
            uint estimatedTotal = totalFoldersProcessed + dirsToProcess.Length;
            idxProgress = float(totalFoldersProcessed) / float(estimatedTotal);

            if (!IO::FolderExists(currentDir)) {
                log("Directory not found: " + currentDir, LogLevel::Warn, 44, "IndexFoldersAndSubfolders");
                yield();
                continue;
            }
            string[]@ topLevel = IO::IndexFolder(currentDir, false);
            array<string> subfolders, files;
            for (uint i = 0; i < topLevel.Length; i++) {
                if (_IO::Directory::IsDirectory(topLevel[i])) {
                    currentIndexingPath = topLevel[i];
                    subfolders.InsertLast(topLevel[i]);
                    if (i % RECURSIVE_SEARCH_BATCH_SIZE == 0) yield();
                } else {
                    currentIndexingPath = topLevel[i];
                    files.InsertLast(topLevel[i]);
                    if (i % RECURSIVE_SEARCH_BATCH_SIZE == 0) yield();
                }
            }
            for (uint s = 0; s < subfolders.Length; s++) {
                dirsToProcess.InsertLast(subfolders[s]);
            }
            totalDirCount += subfolders.Length;
            uint processedInThisDir = 0;
            for (uint f = 0; f < files.Length && !forceStopIndexing; f++) {
                pendingFiles_FolderIndexing.InsertLast(files[f]);
                processedInThisDir++;
                if (processedInThisDir % RECURSIVE_SEARCH_BATCH_SIZE == 0) {
                    processedInThisDir = 0;
                    yield();
                }
            }
            processedDirCount++;
            if (processedDirCount % RECURSIVE_SEARCH_BATCH_SIZE == 0) {
                processedDirCount = 0;
                yield();
            }
            indexingMessage = "Indexing files in: " + currentDir;
        }
        indexingMessage = "Finished indexing files in: " + folderPath;

        idxProgress = 1.0f;
        if (forceStopIndexing) {
            log("Indexing was forcibly stopped.", LogLevel::Info, 82, "IndexFoldersAndSubfolders");
            indexingMessage = "Indexing was forcibly stopped.";
        } else {
            log("Starting to prep files for addition to the database.", LogLevel::Info, 85, "IndexFoldersAndSubfolders");
        }

        // ----

        f_isIndexing_FilePaths = false;
    }


    // =============================================================
    // Adding the found files to the database
    // =============================================================

    int PREPARE_FILES_BATCH_SIZE = 1;

    void ProcessFileSafely(const string &in filePath) {
        indexingMessage = "Processing file: " + filePath;
        
        string parsePath = filePath;
        if (!parsePath.StartsWith(IO::FromUserGameFolder("Replays/"))) {
            log("File is not under 'Replays/', copying to tmp...", LogLevel::Info, 101, "ProcessFileSafely");
            string originalPath = filePath;
            string tempPath = IO::FromUserGameFolder(GetRelative_zzReplayPath() + "/tmp/") + Path::GetFileName(filePath);
            if (IO::FileExists(tempPath)) {
                log("File already exists in tmp, deleting...", LogLevel::Warn, 106, "ProcessFileSafely");
                IO::Delete(tempPath);
            }
            _IO::File::CopyFileTo(originalPath, tempPath);
            parsePath = tempPath;
            if (!IO::FileExists(parsePath)) {
                log("Failed to copy file: " + parsePath, LogLevel::Error, 113, "ProcessFileSafely");
                return;
            }
        }
        if (parsePath.StartsWith(IO::FromUserGameFolder(""))) {
            parsePath = parsePath.SubStr(IO::FromUserGameFolder("").Length, parsePath.Length - IO::FromUserGameFolder("").Length);
        }
        CSystemFidFile@ fid = Fids::GetUser(parsePath);
        if (fid is null) { 
            log("Failed to get fid for file: " + parsePath, LogLevel::Error, 125, "ProcessFileSafely"); 
            return; 
        }
        CMwNod@ nod = Fids::Preload(fid);
        if (nod is null) {
            log("Failed to preload nod for file: " + parsePath, LogLevel::Error, 128, "ProcessFileSafely");
            return;
        }
        CastFidToCorrectNod(nod, parsePath, filePath);
    }

    void PrepareFilesForAdditionToDatabase() {
        prepProgress = 0.0f;
        uint totalFiles = pendingFiles_FolderIndexing.Length;
        for (uint i = 0; i < totalFiles; i++) {
            string filePath = pendingFiles_FolderIndexing[i];
            if (!filePath.ToLower().EndsWith(".replay.gbx")) continue;
            startnew(CoroutineFuncUserdataString(ProcessFileSafely), filePath);
            startnew(CoroutineFuncUserdataString(DeleteFileWith1000msDelay), IO::FromUserGameFolder(GetRelative_zzReplayPath() + "/tmp/") + Path::GetFileName(filePath));
            if (i % PREPARE_FILES_BATCH_SIZE == 0) {
                yield();
            }
            prepProgress = float(i + 1) / float(totalFiles);
            print(prepProgress);
        }
        prepProgress = 1.0;
        p_isIndexing_PrepareFiles = false;
    }

    void CastFidToCorrectNod(CMwNod@ nod, const string &in parsePath, const string &in filePath) {
        CGameCtnReplayRecordInfo@ recordInfo = cast<CGameCtnReplayRecordInfo>(nod);
        if (recordInfo !is null) {
            ProcessFileWith_CGameCtnReplayRecordInfo(recordInfo);
            return;
        }

        CGameCtnReplayRecord@ record = cast<CGameCtnReplayRecord>(nod);
        if (record !is null) {
            ProcessFileWith_CGameCtnReplayRecord(record, parsePath, filePath);
            return;
        }

        CGameCtnGhost@ ghost = cast<CGameCtnGhost>(nod);
        if (ghost !is null) {
            ProcessFileWith_CGameCtnGhost(ghost, filePath);
            return;
        }
    }

    void ProcessFileWith_CGameCtnReplayRecord(CGameCtnReplayRecord@ record, const string &in parsePath, const string &in filePath) {
        if (record.Ghosts.Length == 0) { log("No ghosts found in file: " + parsePath, LogLevel::Warn, 141, "ProcessFileWithCGameCtnReplayRecord"); return; }
        if (record.Ghosts[0].RaceTime == 0xFFFFFFFF) { log("RaceTime is invalid", LogLevel::Warn, 141, "ProcessFileWithCGameCtnReplayRecord"); return; }
        if (record.Challenge.IdName.Length == 0) { log("MapUid is invalid", LogLevel::Warn, 141, "ProcessFileWithCGameCtnReplayRecord"); return; }

        auto replay = ReplayRecord();
        replay.MapUid = record.Challenge.IdName;
        replay.PlayerLogin = record.Ghosts[0].GhostLogin;
        replay.PlayerNickname = record.Ghosts[0].GhostNickname;
        replay.FileName = Path::GetFileName(filePath);
        replay.Path = filePath;
        replay.BestTime = record.Ghosts[0].RaceTime;
        replay.FoundThrough = "Folder Indexing";
        replay.NodeType = Reflection::TypeOf(record).Name;
        replay.CalculateHash();

        pendingFiles_AddToDatabase.InsertLast(replay);
    }

    void ProcessFileWith_CGameCtnGhost(CGameCtnGhost@ ghost, const string &in filePath) {
        if (ghost.RaceTime == 0xFFFFFFFF) { log("RaceTime is invalid", LogLevel::Warn, 141, "ProcessFileWithCGameCtnReplayRecordInfo"); return; }
        if (ghost.Validate_ChallengeUid.GetName().Length == 0) { log("MapUid is invalid", LogLevel::Warn, 141, "ProcessFileWithCGameCtnReplayRecordInfo"); return; }

        auto replay = ReplayRecord();
        replay.MapUid = ghost.Validate_ChallengeUid.GetName();
        replay.PlayerLogin = ghost.GhostLogin;
        replay.PlayerNickname = ghost.GhostNickname;
        replay.FileName = Path::GetFileName(filePath);
        replay.Path = filePath;
        replay.BestTime = ghost.RaceTime;
        replay.FoundThrough = "Folder Indexing";
        replay.NodeType = Reflection::TypeOf(ghost).Name;
        replay.CalculateHash();

        pendingFiles_AddToDatabase.InsertLast(replay);
    }

    void ProcessFileWith_CGameCtnReplayRecordInfo(CGameCtnReplayRecordInfo@ recordInfo) {
        if (recordInfo.BestTime == 0xFFFFFFFF) { log("BestTime is invalid", LogLevel::Warn, 141, "ProcessFileWithCGameCtnReplayRecordInfo"); return; }
        if (recordInfo.MapUid.Length == 0) { log("MapUid is invalid", LogLevel::Warn, 141, "ProcessFileWithCGameCtnReplayRecordInfo"); return; }

        auto replay = ReplayRecord();
        replay.MapUid = recordInfo.MapUid;
        replay.PlayerLogin = recordInfo.PlayerLogin;
        replay.PlayerNickname = recordInfo.PlayerNickname;
        replay.FileName = recordInfo.FileName;
        replay.Path = recordInfo.Path;
        replay.BestTime = recordInfo.BestTime;
        replay.FoundThrough = "Folder Indexing";
        replay.NodeType = Reflection::TypeOf(recordInfo).Name;
        replay.CalculateHash();

        pendingFiles_AddToDatabase.InsertLast(replay);
    }
    

    // =============================================================
    // Adding the found files to the database
    // =============================================================

    int ADD_FILES_TO_DATABASE_BATCH_SIZE = 100;

    void AddFilesToDatabase() {
        addProgress = 0.0f;
        totalFileNumber = pendingFiles_AddToDatabase.Length;
        for (uint i = 0; i < pendingFiles_AddToDatabase.Length; i++) {
            auto replay = pendingFiles_AddToDatabase[i];

            if (!replayRecords.Exists(replay.MapUid)) {
                array<ReplayRecord@> records;
                replayRecords[replay.MapUid] = records;
            }

            auto records = cast<array<ReplayRecord@>>(replayRecords[replay.MapUid]);
            records.InsertLast(replay);

            AddReplayToDatabse(replay);

            currentFileNumber++;
            addProgress = float(currentFileNumber) / float(totalFileNumber);

            if (i % ADD_FILES_TO_DATABASE_BATCH_SIZE == 0) {
                yield();
            }
        }

        d_isIndexing_AddToDatabase = false;
    }


    // =============================================================
    // Set the indexing message to an empty string after a delay
    // =============================================================

    void SetIndexingMessageToEmptyStringAfterDelay(int64 delay) {
        sleep(delay);
        indexingMessage = "";
    }
}