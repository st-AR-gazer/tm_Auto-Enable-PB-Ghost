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

    void Stop() {
        forceStopIndexing = true;
        isIndexing = false; 
        totalFileNumber = 0;
        currentFileNumber = 0;
        latestFile = "";
        indexingMessage = "";
        currentIndexingPath = "";
    }

    void Start(const string &in folderPath) {
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


    // =============================================================
    // Better IO::Index(string path, bool recursive = true)
    // =============================================================

    array<string> dirsToProcess;
    int RECURSIVE_SEARCH_BATCH_SIZE = 100;

    int totalTasks = 0;

    void IndexFoldersAndSubfolders(const string&in folderPath) {
        dirsToProcess.InsertLast("");

        // ----



        // ----

        f_isIndexing_FilePaths = false;
    }


    // =============================================================
    // Adding the found files to the database
    // =============================================================

    void PrepareFilesForAdditionToDatabase() {
        for (uint i = 0; i < pendingFiles_FolderIndexing.Length; i++) {
            string filePath = pendingFiles_FolderIndexing[i];
            
            if (!filePath.ToLower().EndsWith(".replay.gbx")) continue;

            string parsePath = filePath;

            if (!parsePath.StartsWith(IO::FromUserGameFolder("Replays/"))) {
                log("File is not the the 'Replays' folder, copying over to temporary 'zzAutoEnablePBGhost/temp' folder...", LogLevel::Info, 101, "PrepareFilesForAdditionToDatabase");

                string originalPath = filePath;
                string tempPath = IO::FromUserGameFolder("Replays/zzAutoEnablePBGhost/temp/") + Path::GetFileName(filePath);

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

            startnew(CoroutineFuncUserdataString(DeleteFileWith200msDelay), IO::FromUserGameFolder("Replays/zzAutoEnablePBGhost/temp/") + Path::GetFileName(filePath));
        }

        p_isIndexing_PrepareFiles = false;
    }

    void CastFidToCorrectNod(CMwNod@ nod, const string &in parsePath, const string &in filePath) {
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

        CGameCtnReplayRecordInfo@ recordInfo = cast<CGameCtnReplayRecordInfo>(nod);
        if (recordInfo !is null) {
            ProcessFileWith_CGameCtnReplayRecordInfo(recordInfo, parsePath, filePath);
            return;
        }
    }

    void ProcessFileWith_CGameCtnReplayRecord(CGameCtnReplayRecord@ record, const string &in parsePath, const string &in filePath) {
        if (record.Ghosts.Length == 0) { log("No ghosts found in file: " + parsePath, LogLevel::Warn, 141, "ProcessFileWithCGameCtnReplayRecord"); return; }

        auto replay = ReplayRecord();
        replay.MapUid = record.Challenge.IdName;
        replay.PlayerLogin = record.Ghosts[0].GhostLogin;
        replay.PlayerNickname = record.Ghosts[0].GhostNickname;
        replay.FileName = Path::GetFileName(filePath);
        replay.Path = filePath;
        replay.BestTime = record.Ghosts[0].RaceTime;
        replay.FoundThrough = "Folder Indexing";
        replay.NodeType = "CGameCtnReplayRecord@";
        replay.CalculateHash();

        pendingFiles_AddToDatabase.InsertLast(replay);
    }

    void ProcessFileWith_CGameCtnGhost(CGameCtnGhost@ ghost, const string &in parsePath, const string &in filePath) {
        if (ghost.RaceTime == 0xFFFFFFFF) { log("RaceTime is invalid", LogLevel::Warn, 141, "ProcessFileWithCGameCtnReplayRecordInfo"); return; }

        auto replay = ReplayRecord();
        replay.MapUid = ghost.Validate_ChallengeUid.GetName();
        replay.PlayerLogin = ghost.GhostLogin;
        replay.PlayerNickname = ghost.GhostNickname;
        replay.FileName = Path::GetFileName(filePath);
        replay.Path = filePath;
        replay.BestTime = ghost.RaceTime;
        replay.FoundThrough = "Folder Indexing";
        replay.NodeType = "CGameCtnGhost@";
        replay.CalculateHash();

        pendingFiles_AddToDatabase.InsertLast(replay);
    }

    void ProcessFileWith_CGameCtnReplayRecordInfo(CGameCtnReplayRecordInfo@ recordInfo, const string &in parsePath, const string &in filePath) {
        if (recordInfo.BestTime == 0xFFFFFFFF) { log("BestTime is invalid", LogLevel::Warn, 141, "ProcessFileWithCGameCtnReplayRecordInfo"); return; }

        auto replay = ReplayRecord();
        replay.MapUid = recordInfo.MapUid;
        replay.PlayerLogin = recordInfo.PlayerLogin;
        replay.PlayerNickname = recordInfo.PlayerNickname;
        replay.FileName = recordInfo.FileName;
        replay.Path = recordInfo.Path;
        replay.BestTime = recordInfo.BestTime;
        replay.FoundThrough = "Folder Indexing";
        replay.NodeType = "CGameCtnReplayRecordInfo@";
        replay.CalculateHash();

        pendingFiles_AddToDatabase.InsertLast(replay);
    }


    void ProcessFile(const string &in filePath) {
        if (!filePath.ToLower().EndsWith(".replay.gbx")) return;

        string parsePath = filePath;
        if (parsePath.StartsWith(IO::FromUserGameFolder(""))) {
            parsePath = parsePath.SubStr(IO::FromUserGameFolder("").Length, parsePath.Length - IO::FromUserGameFolder("").Length);
        }

        if (!parsePath.StartsWith(IO::FromUserGameFolder("Replays/"))) {
            log("File is not in the 'Replays' folder, copying over to temporary 'zzAutoEnablePBGhost/temp' folder...", LogLevel::Info, 101, "ProcessFile");
            string tempPath = IO::FromUserGameFolder("Replays/zzAutoEnablePBGhost/temp/") + Path::GetFileName(filePath);

            if (IO::FileExists(tempPath)) {
                log("File already exists in temporary folder, deleting...", LogLevel::Info, 106, "ProcessFile");
                IO::Delete(tempPath);
            }
            
            _IO::File::CopyFileTo(filePath, tempPath);
            parsePath = tempPath;
            if (!IO::FileExists(parsePath)) { log("Failed to copy file to temporary folder: " + parsePath, LogLevel::Error, 113, "ProcessFile"); return; }
        }

        if (parsePath.StartsWith(IO::FromUserGameFolder(""))) {
            parsePath = parsePath.SubStr(IO::FromUserGameFolder("").Length, parsePath.Length - IO::FromUserGameFolder("").Length);
        }

        CSystemFidFile@ fid = Fids::GetUser(parsePath);
        if (fid is null) { log("Failed to get fid for file: " + parsePath, LogLevel::Error, 125, "ProcessFile"); return; }
    
        CMwNod@ nod = Fids::Preload(fid);
        if (nod is null) { log("Failed to preload nod for file: " + parsePath, LogLevel::Error, 128, "ProcessFile"); return; }
    
        CGameCtnReplayRecord@ record = cast<CGameCtnReplayRecord>(nod);
        if (record is null) {
            log("Failed to cast nod (CGameCtnReplayRecord) for file: " + parsePath, LogLevel::Warn, 132, "ProcessFile");
    
            // Not every file is a "CGameCtnReplayRecord", so try processing as CGameCtnGhost.
            ProcessFileWithCGameCtnGhost(nod, filePath);
            return;
        }
    
        if (record.Ghosts.Length == 0) { 
            log("No ghosts found in file: " + parsePath, LogLevel::Warn, 141, "ProcessFile"); 
            return; 
        }
    
        auto replay = ReplayRecord();
        replay.MapUid = record.Challenge.IdName;
        replay.PlayerLogin = record.Ghosts[0].GhostLogin;
        replay.PlayerNickname = record.Ghosts[0].GhostNickname;
        replay.FileName = Path::GetFileName(filePath);
        replay.Path = filePath;
        replay.BestTime = record.Ghosts[0].RaceTime;
        replay.FoundThrough = "Folder Indexing";
        replay.CalculateHash();
        SaveReplayToDB(replay);
        CleanupTemp(parsePath, filePath);
    }

    // =============================================================
    // Adding the found files to the database
    // =============================================================

    void AddFilesToDatabase() {
        for (uint i = 0; i < pendingFiles_AddToDatabase.Length; i++) {
            SaveReplayToDB(pendingFiles_AddToDatabase[i]);
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