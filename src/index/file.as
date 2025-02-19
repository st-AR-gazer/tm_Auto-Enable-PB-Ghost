namespace Index {
    void AddFileToDatabase(const string &in filePath) {
        if (!filePath.ToLower().EndsWith(".replay.gbx")) return;

        string parsePath = filePath;
        if (!parsePath.StartsWith(IO::FromUserGameFolder("Replays/"))) {
            log("File is not the the 'Replays' folder, copying over to temporary 'zzAutoEnablePBGhost/temp' folder...", LogLevel::Info, 101, "PrepareFilesForAdditionToDatabase");

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

        log("Finished processing file: " + parsePath, LogLevel::Info, 137, "PrepareFilesForAdditionToDatabase");
    }

    void CastFidToCorrectNod(CMwNod@ nod, const string &in parsePath, const string &in filePath) {
        CGameCtnReplayRecordInfo@ recordInfo = cast<CGameCtnReplayRecordInfo>(nod);
        if (recordInfo !is null) { ProcessFileWith_CGameCtnReplayRecordInfo(recordInfo, parsePath, filePath); return; }

        CGameCtnReplayRecord@ record = cast<CGameCtnReplayRecord>(nod);
        if (record !is null) { ProcessFileWith_CGameCtnReplayRecord(record, parsePath, filePath); return; }

        CGameCtnGhost@ ghost = cast<CGameCtnGhost>(nod);
        if (ghost !is null) { ProcessFileWith_CGameCtnGhost(ghost, parsePath, filePath); return; }
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

        AddReplayToDB(replay);
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

        AddReplayToDB(replay);
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

        AddReplayToDB(replay);
    }
}