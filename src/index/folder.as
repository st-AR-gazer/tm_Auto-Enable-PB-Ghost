namespace Index {
    array<string> pendingFiles;
    bool isIndexingFolder = false;
    int totalFolderFileNumber = 0;
    int currentFolderFileNumber = 0;
    int FOLDER_INDEXING_PROCESS_LIMIT = 1;
    bool enqueueingFilesInProgress = false;
    int totalFilesToEnqueue = 0;
    int filesEnqueued = 0;
    string lastFileIndexed = "";

    float lastCheckTime = 0.0f;
    uint lastFileCount = 0;
    uint speedCount = 0;
    float updateIntervalSec = 1.0f;

    // FIXME: This currently doesn't work, see issue in SettingsUI.as
    void UpdateIndexingSpeed() {
        float now = Time::Now;
        float dt = now - lastCheckTime;
        if (dt >= updateIntervalSec) {
            uint processedSinceLast = currentFolderFileNumber - lastFileCount;
            speedCount = uint(float(processedSinceLast) / dt);
            lastFileCount = currentFolderFileNumber;
            lastCheckTime = now;
        }
    }

    void StartGameFolderFullIndexing() {
        ManualIndex::Stop();
        ManualIndex::StartRecursiveSearch(IO::FromUserGameFolder(""));
        startnew(CoroutineFuncUserdata(PostManualIndexCoroutine), null);
    }

    void StartCustomFolderIndexing(const string &in folderPath) {
        ManualIndex::Stop();
        ManualIndex::StartRecursiveSearch(folderPath);
        startnew(CoroutineFuncUserdata(PostManualIndexCoroutine), null);
    }

    void PostManualIndexCoroutine(ref@ _) {
        while (ManualIndex::indexingInProgress) { yield(); }
        array<string>@ results = ManualIndex::GetFoundFiles();
        print(results[0] + "    | aaaaaaaaaaaaaaaaaaaaaaa");
        enqueueingFilesInProgress = true;
        totalFilesToEnqueue = results.Length;
        filesEnqueued = 0;
        for (uint i = 0; i < results.Length; i++) {
            pendingFiles.InsertLast(results[i]);
            filesEnqueued++;
            lastFileIndexed = results[i];
            if (i % 739 == 0) yield();
        }
        enqueueingFilesInProgress = false;
        totalFolderFileNumber = pendingFiles.Length;
        currentFolderFileNumber = 0;
        isIndexingFolder = true;
        lastCheckTime = Time::Now;
        lastFileCount = 0;
        speedCount = 0;
        ProcessFolderFiles();
    }

    void StopEnqueueing() {
        enqueueingFilesInProgress = false;
        pendingFiles.Resize(0);
        totalFilesToEnqueue = 0;
        filesEnqueued = 0;
        lastFileIndexed = "";
    }

    void ProcessFolderFiles() {
        while (isIndexingFolder && pendingFiles.Length > 0) {
            int processedCount = 0;
            while (processedCount < FOLDER_INDEXING_PROCESS_LIMIT && pendingFiles.Length > 0) {
                string filePath = pendingFiles[0];
                pendingFiles.RemoveAt(0);
                startnew(CoroutineFuncUserdataString(ProcessFile), filePath);
                currentFolderFileNumber++;
                processedCount++;
                UpdateIndexingSpeed();
            }
            yield();
        }
        if (pendingFiles.Length == 0) {
            isIndexingFolder = false;
            log("Folder indexing complete!", LogLevel::Info, 86, "ProcessFolderFiles");
        }
    }

    void StopIndexingFolder() {
        isIndexingFolder = false;
        pendingFiles.Resize(0);
        totalFolderFileNumber = 0;
        currentFolderFileNumber = 0;
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

    void ProcessFileWithCGameCtnGhost(CMwNod@ nod, const string &in filePath) {
        CGameCtnGhost@ ghost = cast<CGameCtnGhost>(nod);
        if (ghost is null) { log("Failed to cast nod (CGameCtnGhost) for file: " + filePath, LogLevel::Error, 158, "ProcessFileWithCGameCtnGhost"); return; }
        log("Casting to CGameCtnGhost successful for file: " + filePath, LogLevel::Info, 159, "ProcessFileWithCGameCtnGhost");

        auto replay = ReplayRecord();
        replay.MapUid = ghost.Validate_ChallengeUid.GetName();
        replay.PlayerLogin = ghost.GhostLogin;
        replay.PlayerNickname = ghost.GhostNickname;
        replay.FileName = Path::GetFileName(filePath);
        replay.Path = filePath;
        replay.BestTime = ghost.RaceTime;
        replay.FoundThrough = "Folder Indexing";
        replay.CalculateHash();
        SaveReplayToDB(replay);
        CleanupTemp(filePath, filePath);
    }

    void CleanupTemp(const string &in parsePath, const string &in originalPath) {
        string properParsePath = IO::FromUserGameFolder(parsePath);
        if (properParsePath != originalPath && IO::FileExists(properParsePath)) {
            IO::Delete(properParsePath);
        }
    }

    void DeleteMovedFiles() {
        log("No permanent moves. Nothing to delete here.", LogLevel::Notice, 179, "DeleteMovedFiles");
    }
}
