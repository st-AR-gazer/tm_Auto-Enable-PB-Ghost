namespace Index {
    array<string> pendingFiles;
    bool isIndexingFolder = false;
    int totalFolderFileNumber = 0;
    int currentFolderFileNumber = 0;
    int FOLDER_INDEXING_PROCESS_LIMIT = 2;
    bool enqueueingFilesInProgress = false;

    void StartGameFolderFullIndexing() {
        string gameFolder = IO::FromUserGameFolder("");
        StartCustomFolderIndexing(gameFolder);
    }

    void StartCustomFolderIndexing(const string &in folderPath) {
        EnqueueFiles(folderPath);
        totalFolderFileNumber = pendingFiles.Length;
        currentFolderFileNumber = 0;
        isIndexingFolder = true;
        while (enqueueingFilesInProgress) { yield(); }
        ProcessFolderFiles();
    }
    
    void EnqueueFiles(const string &in path) {
        enqueueingFilesInProgress = true;
        string[]@ files = IO::IndexFolder(path, true);
        for (uint i = 0; i < files.Length; i++) {
            pendingFiles.InsertLast(files[i]);
        }
        enqueueingFilesInProgress = false;
    }

    void ProcessFolderFiles() {
        while (isIndexingFolder && pendingFiles.Length > 0) {
            int processedCount = 0;
            while (processedCount < FOLDER_INDEXING_PROCESS_LIMIT && pendingFiles.Length > 0) {
                string filePath = pendingFiles[0];
                pendingFiles.RemoveAt(0);
                ProcessFile(filePath);
                currentFolderFileNumber++;
                processedCount++;
            }
            yield();
        }

        if (pendingFiles.Length == 0) {
            isIndexingFolder = false;
            log("Folder indexing complete!", LogLevel::Info, 47, "ProcessFolderFiles");
        }
    }

    void ProcessFile(const string &in filePath) {
        if (!filePath.ToLower().EndsWith(".replay.gbx") && !filePath.ToLower().EndsWith(".ghost.gbx")) return;

        string relativePath = MoveFileToReplays(filePath);
        if (relativePath == "") return;

        CSystemFidFile@ fid = Fids::GetUser(relativePath);
        if (fid is null) { log("Failed to get fid for file: " + filePath, LogLevel::Error, 59, "ProcessFile"); return; }

        CMwNod@ nod = Fids::Preload(fid);
        if (nod is null) { log("Failed to preload nod for file: " + filePath, LogLevel::Error, 62, "ProcessFile"); return; }

        CGameCtnReplayRecord@ record = cast<CGameCtnReplayRecord>(nod);
        if (record is null) { log("Failed to cast nod for file: " + filePath, LogLevel::Error, 65, "ProcessFile"); return; }

        auto replay = ReplayRecord();
        replay.MapUid = record.Challenge.IdName;
        replay.PlayerLogin = record.Ghosts[0].GhostLogin;
        replay.PlayerNickname = record.Ghosts[0].GhostNickname;
        replay.FileName = Path::GetFileName(IO::FromUserGameFolder(relativePath));
        replay.Path = IO::FromUserGameFolder(relativePath);
        replay.BestTime = record.Ghosts[0].RaceTime;
        replay.FoundThrough = "Folder Indexing";
        replay.CalculateHash();

        SaveReplayToDB(replay);
    }

    string MoveFileToReplays(const string &in filePath) {
        string destinationFolder = IO::FromUserGameFolder("Replays/zzAutoEnablePBGhost/");
        if (!IO::FolderExists(destinationFolder)) {
            IO::CreateFolder(destinationFolder);
        }

        auto replay = ReplayRecord();
        replay.Path = filePath;
        replay.CalculateHash();

        string destinationPath = destinationFolder + "/" + replay.ReplayHash + ".Replay.gbx";

        if (IO::FileExists(destinationPath)) {
            log("File already exists: " + destinationPath + " | Overwriting", LogLevel::Warn, 93, "MoveFileToReplays");
            return "Replays/zzAutoEnablePBGhost/" + replay.ReplayHash + ".Replay.gbx";
        }

        IO::Move(filePath, destinationPath);
        if (!IO::FileExists(destinationPath)) {
            log("Failed to move file: " + filePath + " to: " + destinationPath, LogLevel::Error, 99, "MoveFileToReplays");
            return "";
        }

        return "Replays/zzAutoEnablePBGhost/" + replay.ReplayHash + ".Replay.gbx";
    }

    void DeleteMovedFiles() {
        string destinationFolder = IO::FromUserGameFolder("Replays/zzAutoEnablePBGhost");
        if (!IO::FolderExists(destinationFolder)) return;

        string[]@ files = IO::IndexFolder(destinationFolder, false);
        for (uint i = 0; i < files.Length; i++) {
            IO::Delete(files[i]);
        }
        log("All moved files have been deleted.", LogLevel::Notice, 114, "DeleteMovedFiles");
    }
}
