namespace Index {
    void AddFileToDatabase(const string &in filePath) {
        if (!filePath.ToLower().EndsWith(".replay.gbx")) return;

        string parsePath = filePath;
        if (!parsePath.StartsWith(IO::FromUserGameFolder("Replays/"))) {
            log("File is not the the 'Replays' folder, copying over to temporary 'zzAutoEnablePBGhost/temp' folder...", LogLevel::Info, 7, "AddFileToDatabase");

            string originalPath = filePath;
            string tempPath = IO::FromUserGameFolder(GetRelative_zzReplayPath() + "/tmp/") + Path::GetFileName(filePath);

            if (IO::FileExists(tempPath)) {
                log("File already exists in temporary folder, deleting...", LogLevel::Warn, 13, "AddFileToDatabase");
                IO::Delete(tempPath);
            }

            _IO::File::CopyFileTo(originalPath, tempPath, true );

            parsePath = tempPath;
            
            if (!IO::FileExists(parsePath)) {
                log("Failed to copy file to temporary folder: " + parsePath, LogLevel::Error, 22, "AddFileToDatabase");
                return;
            }
        }

        log("Processing file: " + parsePath, LogLevel::Info, 27, "AddFileToDatabase");

        if (parsePath.StartsWith(IO::FromUserGameFolder(""))) {
            parsePath = parsePath.SubStr(IO::FromUserGameFolder("").Length, parsePath.Length - IO::FromUserGameFolder("").Length);
        }

        CSystemFidFile@ fid = Fids::GetUser(parsePath);
        if (fid is null) { log("Failed to get fid for file: " + parsePath, LogLevel::Error, 34, "AddFileToDatabase"); return; }

        CMwNod@ nod = Fids::Preload(fid);
        if (nod is null) { log("Failed to preload nod for file: " + parsePath, LogLevel::Error, 37, "AddFileToDatabase"); return; }

        CastFidToCorrectNod_AddDirect(nod, parsePath, filePath);

        startnew(CoroutineFuncUserdataString(DeleteFileWith1000msDelay), IO::FromUserGameFolder(GetRelative_zzReplayPath() + "/tmp/") + Path::GetFileName(filePath));

        log("Finished processing file: " + parsePath, LogLevel::Info, 43, "AddFileToDatabase");
    }

    void CastFidToCorrectNod_AddDirect(CMwNod@ nod, const string &in parsePath, const string &in filePath) {
        CGameCtnReplayRecordInfo@ recordInfo = cast<CGameCtnReplayRecordInfo>(nod);
        if (recordInfo !is null) { ProcessFileWith_CGameCtnReplayRecordInfo_AddDirect(recordInfo, parsePath, filePath); return; }

        CGameCtnReplayRecord@ record = cast<CGameCtnReplayRecord>(nod);
        if (record !is null) { ProcessFileWith_CGameCtnReplayRecord_AddDirect(record, parsePath, filePath); return; }

        CGameCtnGhost@ ghost = cast<CGameCtnGhost>(nod);
        if (ghost !is null) { ProcessFileWith_CGameCtnGhost_AddDirect(ghost, parsePath, filePath); return; }
    }

    void ProcessFileWith_CGameCtnReplayRecord_AddDirect(CGameCtnReplayRecord@ record, const string &in parsePath, const string &in filePath) {
        if (record.Ghosts.Length == 0) { log("No ghosts found in file: " + parsePath, LogLevel::Warn, 58, "ProcessFileWith_CGameCtnReplayRecord_AddDirect"); return; }
        if (record.Ghosts[0].RaceTime == 0xFFFFFFFF) { log("RaceTime is invalid", LogLevel::Warn, 59, "ProcessFileWith_CGameCtnReplayRecord_AddDirect"); return; }
        if (record.Challenge.IdName.Length == 0) { log("MapUid is invalid", LogLevel::Warn, 60, "ProcessFileWith_CGameCtnReplayRecord_AddDirect"); return; }

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

        AddReplayToDatabase(replay);
    }

    void ProcessFileWith_CGameCtnGhost_AddDirect(CGameCtnGhost@ ghost, const string &in parsePath, const string &in filePath) {
        if (ghost.RaceTime == 0xFFFFFFFF) { log("RaceTime is invalid", LogLevel::Warn, 77, "ProcessFileWith_CGameCtnGhost_AddDirect"); return; }
        if (ghost.Validate_ChallengeUid.GetName().Length == 0) { log("MapUid is invalid", LogLevel::Warn, 78, "ProcessFileWith_CGameCtnGhost_AddDirect"); return; }

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

        AddReplayToDatabase(replay);
    }

    void ProcessFileWith_CGameCtnReplayRecordInfo_AddDirect(CGameCtnReplayRecordInfo@ recordInfo, const string &in parsePath, const string &in filePath) {
        if (recordInfo.BestTime == 0xFFFFFFFF) { log("BestTime is invalid", LogLevel::Warn, 95, "ProcessFileWith_CGameCtnReplayRecordInfo_AddDirect"); return; }
        if (recordInfo.MapUid.Length == 0) { log("MapUid is invalid", LogLevel::Warn, 96, "ProcessFileWith_CGameCtnReplayRecordInfo_AddDirect"); return; }

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

        AddReplayToDatabase(replay);
    }
}