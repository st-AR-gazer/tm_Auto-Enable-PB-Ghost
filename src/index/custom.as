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
        isIndexing = true;
        
        f_isIndexing_FilePaths = true;
        startnew(CoroutineFuncUserdataString(IndexFoldersAndSubfolders), folderPath);
        while (f_isIndexing_FilePaths) { yield(); }
        
        p_isIndexing_PrepareFiles = true;
        startnew(PrepareFilesForAdditionToDatabase);
        while (p_isIndexing_PrepareFiles) { yield(); }
        
        d_isIndexing_AddToDatabase = true;
        startnew(AddFilesToDatabase);
        while (d_isIndexing_AddToDatabase) { yield(); }

        isIndexing = false;
        indexingMessage = "Full addition to the database complete!";
        startnew(CoroutineFuncUserdataInt64(SetIndexingMessageToEmptyStringAfterDelay), 1000);
    }

    bool IsIndexingInProgress() {
        return isIndexing;
    }

    float GetIndexingProgressFraction() {
        return progressFraction;
    }


    // =============================================================
    // Better IO::Index(string path, bool recursive = true)
    // =============================================================

    array<string> dirsToProcess;
    int RECURSIVE_SEARCH_BATCH_SIZE = 100;

    int totalTasks = 0;
    float progressFraction = 0.0f;

    void IndexFoldersAndSubfolders(const string&in folderPath) {

        // ----

        uint totalDirCount = dirsToProcess.Length;
        uint processedDirCount = 0;
        while (f_isIndexing_FilePaths && dirsToProcess > 0 && !forceStopIndexing) {
            string currentDir = dirsToProcess[dirsToProcess.Length - 1];
            dirsToProcess.RemoveAt(dirsToProcess.Length - 1);
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

        progressFraction = 1.0f;
        if (forceStopIndexing) {
            log("Indexing was forcibly stopped.", LogLevel::Info, 82, "IndexFoldersAndSubfolders");
            indexingMessage = "Indexing was forcibly stopped.";
        } else {
            log("Finished indexing files in: " + folderPath, LogLevel::Info, 85, "IndexFoldersAndSubfolders");
        }

        // ----

        f_isIndexing_FilePaths = false;
    }


    // =============================================================
    // Adding the found files to the database
    // =============================================================

    int PREPARE_FILES_BATCH_SIZE = 100;

    void PrepareFilesForAdditionToDatabase() {
        for (uint i = 0; i < pendingFiles_FolderIndexing.Length; i++) {
            string filePath = pendingFiles_FolderIndexing[i];
            
            if (!filePath.ToLower().EndsWith(".replay.gbx")) continue;

            string parsePath = filePath;

            if (!parsePath.StartsWith(IO::FromUserGameFolder("Replays/"))) {
                log("File is not the the 'Replays' folder, copying over to temporary 'zzAutoEnablePBGhost/tmp' folder...", LogLevel::Info, 101, "PrepareFilesForAdditionToDatabase");

                string originalPath = filePath;
                string tempPath = IO::FromUserGameFolder(GetRelative_zzReplayPath() + "/tmp/") + Path::GetFileName(filePath);

                if (IO::FileExists(tempPath)) {
                    log("File already exists in temporary folder, deleting...", LogLevel::Warn, 106, "PrepareFilesForAdditionToDatabase");
                    IO::Delete(tempPath);
                }

                _IO::File::CopyFileTo(originalPath, tempPath, true );

                parsePath = tempPath;
                
                if (!IO::FileExists(parsePath)) {
                    log("Failed to copy file to temporary folder: " + parsePath, LogLevel::Error, 113, "PrepareFilesForAdditionToDatabase");
                    continue;
                }
            }

            log("Processing file: " + parsePath, LogLevel::Info, 118, "PrepareFilesForAdditionToDatabase");

            if (parsePath.StartsWith(IO::FromUserGameFolder(""))) {
                parsePath = parsePath.SubStr(IO::FromUserGameFolder("").Length, parsePath.Length - IO::FromUserGameFolder("").Length);
            }

            CSystemFidFile@ fid = Fids::GetUser(parsePath);
            if (fid is null) { log("Failed to get fid for file: " + parsePath, LogLevel::Error, 125, "PrepareFilesForAdditionToDatabase"); continue; }

            CMwNod@ nod = Fids::Preload(fid);
            if (nod is null) { log("Failed to preload nod for file: " + parsePath, LogLevel::Error, 128, "PrepareFilesForAdditionToDatabase"); continue; }

            CastFidToCorrectNod(nod, parsePath, filePath);

            startnew(CoroutineFuncUserdataString(DeleteFileWith200msDelay), IO::FromUserGameFolder(GetRelative_zzReplayPath() + "/tmp/") + Path::GetFileName(filePath));

            if (i % PREPARE_FILES_BATCH_SIZE == 0) {
                yield();
            }
        }

        p_isIndexing_PrepareFiles = false;
    }

    void CastFidToCorrectNod(CMwNod@ nod, const string &in parsePath, const string &in filePath) {
        CGameCtnReplayRecordInfo@ recordInfo = cast<CGameCtnReplayRecordInfo>(nod);
        if (recordInfo !is null) {
            ProcessFileWith_CGameCtnReplayRecordInfo(recordInfo, parsePath, filePath);
            return;
        }

        CGameCtnReplayRecord@ record = cast<CGameCtnReplayRecord>(nod);
        if (record !is null) {
            ProcessFileWith_CGameCtnReplayRecord(record, parsePath, filePath);
            return;
        }

        CGameCtnGhost@ ghost = cast<CGameCtnGhost>(nod);
        if (ghost !is null) {
            ProcessFileWith_CGameCtnGhost(ghost, parsePath, filePath);
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

    void ProcessFileWith_CGameCtnGhost(CGameCtnGhost@ ghost, const string &in parsePath, const string &in filePath) {
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

    void ProcessFileWith_CGameCtnReplayRecordInfo(CGameCtnReplayRecordInfo@ recordInfo, const string &in parsePath, const string &in filePath) {
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
        for (uint i = 0; i < pendingFiles_AddToDatabase.Length; i++) {
            auto replay = pendingFiles_AddToDatabase[i];

            if (!replayRecords.Exists(replay.MapUid)) {
                array<ReplayRecord@> records;
                replayRecords[replay.MapUid] = records;
            }

            auto records = cast<array<ReplayRecord@>>(replayRecords[replay.MapUid]);
            records.InsertLast(replay);

            SaveReplayToDB(replay);

            currentFileNumber++;

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