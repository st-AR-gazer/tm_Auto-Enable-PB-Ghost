namespace Index {
    array<string> pendingFiles;
    int filesPerFrame = 50;
    bool isIndexing = false;

    void StartFolderIndexing() {
        string userGameFolder = IO::FromUserGameFolder("");

        string[]@ pathParts = userGameFolder.Split("/");
        string finalPart = pathParts[pathParts.Length - 1];

        string documentsFolder = IO::FromUserGameFolder("../");
        if (finalPart == "Trackmania2020") {
            EnqueueFiles(documentsFolder + "Trackmania");
        } else if (finalPart == "Trackmania") {
            EnqueueFiles(documentsFolder + "Trackmania2020");
        }

        EnqueueFiles(documentsFolder);
        isIndexing = true;
    }

    void StartCustomFolderIndexing(const string&in folderPath) {
        EnqueueFiles(folderPath);
        isIndexing = true;
    }

    void EnqueueFiles(const string&in path) {
        string[]@ files = IO::IndexFolder(path, true);
        for (uint i = 0; i < files.Length; i++) {
            pendingFiles.InsertLast(files[i]);
        }
    }

    void ProcessFolderFiles() {
        if (!isIndexing || pendingFiles.Length == 0) return;

        int processedCount = 0;
        while (processedCount < filesPerFrame && pendingFiles.Length > 0) {
            string filePath = pendingFiles[0];
            pendingFiles.RemoveAt(0);

            ProcessFile(filePath);
            processedCount++;
        }

        if (pendingFiles.Length == 0) {
            isIndexing = false;
            log("Folder indexing complete!", LogLevel::Info, 44, "ProcessFolderFiles");
        }
    }

    void ProcessFile(const string&in filePath) {
        if (!filePath.ToLower().EndsWith(".replay.gbx") && !filePath.ToLower().EndsWith(".ghost.gbx")) return;

        string relativePath = MoveFileToReplays(filePath);
        if (relativePath == "") return;

        CSystemFidFile@ fid = Fids::GetUser(relativePath);
        if (fid is null) { log("Failed to get fid for file: " + filePath, LogLevel::Error, 55, "ProcessFile"); return; }

        CMwNod@ nod = Fids::Preload(fid);
        if (nod is null) { log("Failed to preload nod for file: " + filePath, LogLevel::Error, 58, "ProcessFile"); return; }

        CGameCtnReplayRecordInfo@ record = cast<CGameCtnReplayRecordInfo>(nod);
        if (record is null) { log("Failed to cast nod to CGameCtnReplayRecordInfo for file: " + filePath, LogLevel::Error, 61, "ProcessFile"); return; }

        auto replay = ReplayRecord();
        replay.MapUid = record.MapUid;
        replay.PlayerLogin = record.PlayerLogin;
        replay.PlayerNickname = record.PlayerNickname;
        replay.FileName = record.FileName;
        replay.Path = filePath;
        replay.BestTime = record.BestTime;
        replay.FoundThrough = "Folder Indexing";
        replay.CalculateHash();

        SaveReplayToDB(replay);
    }

    string MoveFileToReplays(const string&in filePath) {
        string destinationFolder = IO::FromUserGameFolder("Replays/zzAutoLoadPBGhost");
        if (!IO::FolderExists(destinationFolder)) {
            IO::CreateFolder(destinationFolder);
        }

        auto replay = ReplayRecord();
        replay.Path = filePath;
        replay.CalculateHash();

        string destinationPath = destinationFolder + "/" + replay.ReplayHash + ".Replay.gbx";

        if (IO::FileExists(destinationPath)) {
            log("File already exists: " + destinationPath, LogLevel::Warn, 89, "MoveFileToReplays");
            return "Replays/zzAutoLoadPBGhost/" + replay.ReplayHash + ".Replay.gbx";
        }

        IO::Move(filePath, destinationPath);
        if (!IO::FileExists(destinationPath)) {
            log("Failed to move file: " + filePath + " to: " + destinationPath, LogLevel::Error, 96, "MoveFileToReplays");
            return "";
        }

        return "Replays/zzAutoLoadPBGhost/" + replay.ReplayHash + ".Replay.gbx";
    }

    bool IsIndexing() {
        return isIndexing;
    }

    void DeleteMovedFiles() {
        string destinationFolder = IO::FromUserGameFolder("Replays/zzAutoLoadPBGhost");
        if (!IO::FolderExists(destinationFolder)) return;

        string[]@ files = IO::IndexFolder(destinationFolder, false);
        for (uint i = 0; i < files.Length; i++) {
            IO::Delete(files[i]);
        }
        log("All moved files have been deleted.", LogLevel::Notice, 113, "DeleteMovedFiles");
    }

    
}
