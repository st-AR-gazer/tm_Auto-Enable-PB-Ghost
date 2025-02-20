namespace Loader {

    void LoadPBFromDB() {
        string mapUid = get_CurrentMapUID();

        string playerName = GetApp().LocalPlayerInfo.Name;
        int playerPBTime = _Game::CurrentPersonalBest(CurrentMapUID);

        if (playerPBTime >= 0) {
            log("Found PB in the widget. Attempting to match local record.", LogLevel::Info, 10, "LoadPBFromDB");
            LoadPersonalBestGhostFromTime(mapUid, playerPBTime);
        } else {
            log("Player PB not found in the widget. Falling back to fastest local record.", LogLevel::Warn, 13, "LoadPBFromDB");
            FallbackLoadPB(mapUid);
        }
    }

    void LoadPersonalBestGhostFromTime(const string&in mapUid, int playerPBTime) {
        auto replays = Index::GetReplaysFromDatabase(mapUid);

        if (replays.Length == 0) {
            log("No local PB ghost found for map UID: " + mapUid + " | attempting to download from leaderboard. | " + Index::GetTotalReplaysForMap(mapUid), LogLevel::Warn, 22, "LoadPersonalBestGhostFromTime");
            DownloadPBFromLeaderboardAndLoadLocal(mapUid);
            return;
        }

        log("Loading local PB ghost for time: " + playerPBTime + " ms., total ghosts found: " + Index::GetTotalReplaysForMap(mapUid) + " | " + mapUid, LogLevel::Info, 27, "LoadPersonalBestGhostFromTime");

        for (uint i = 0; i < replays.Length; i++) {
            if (replays[i].BestTime == uint(playerPBTime)) {
                string fullPath = replays[i].Path;
                startnew(CoroutineFuncUserdataString(LoadLocalGhost), fullPath);
                return;
            }
        }

        log("Could not find a matching local replay for time: " + playerPBTime + " ms.", LogLevel::Warn, 37, "LoadPersonalBestGhostFromTime");
        FallbackLoadPB(mapUid);
    }

    void FallbackLoadPB(const string&in mapUid) {
        auto replays = Index::GetReplaysFromDatabase(mapUid);

        if (replays.Length == 0) {
            log("No local records found for map UID: " + mapUid + " | attempting to download from leaderboard.", LogLevel::Warn, 45, "FallbackLoadPB");
            DownloadPBFromLeaderboardAndLoadLocal(mapUid);
            return;
        }

        for (uint i = 0; i < replays.Length; i++) {
            if (replays[i].BestTime > uint(_Game::GetPersonalBestTime()) && replays[i].BestTime <= 4294967295) {
                log("Local record (in database) is slower than the widget PB. Fetching from leaderboard.", LogLevel::Warn, 52, "FallbackLoadPB");
                DownloadPBFromLeaderboardAndLoadLocal(mapUid);
                return;
            }
        }

        log("Loading fastest local record for map UID: " + mapUid, LogLevel::Info, 58, "FallbackLoadPB");
        auto bestReplay = FindBestReplay(replays);
        
        if (bestReplay.BestTime > uint(GetRecordsWidget_PlayerUIPB(GetRecordsWidget_FullWidgetUI( ), string(GetApp().LocalPlayerInfo.Name)))) {
            log("Local PB is slower than the widget PB("+ bestReplay.BestTime + " | " + GetRecordsWidget_PlayerUIPB(GetRecordsWidget_FullWidgetUI(), string(GetApp().LocalPlayerInfo.Name)) + "). Fetching from leaderboard.", LogLevel::Warn, 62, "FallbackLoadPB");
            DownloadPBFromLeaderboardAndLoadLocal(mapUid);
        } else if (bestReplay !is null) {
            string fullPath = bestReplay.Path;
            startnew(CoroutineFuncUserdataString(LoadLocalGhost), fullPath);
        }
    }

    void LoadLocalGhost(const string&in filePath) {
        // only load from replay folder

        string replayPath = IO::FromUserGameFolder("Replays/");

        if (!filePath.StartsWith(replayPath)) {
            log("filePath is not in the Replays folder. Copying it to the Replays folder temporarily.", LogLevel::Warn, 78, "LoadLocalGhost");

            string destinationPath = replayPath + "zzAutoEnablePBGhost/tmp/" + Path::GetFileName(filePath);
            _IO::File::CopyFileTo(filePath, destinationPath);

            yield(2);

            print(filePath);

            if (!IO::FileExists(destinationPath)) { log("Failed to copy file to Replays folder: " + destinationPath + " | Aborting...", LogLevel::Error, 83, "LoadLocalGhost"); return; }

            startnew(CoroutineFuncUserdataString(LoadLocalGhost), destinationPath);
            startnew(CoroutineFuncUserdataString(Index::DeleteFileWith1000msDelay), destinationPath);

            return;
        }

        auto task = GetApp().Network.ClientManiaAppPlayground.DataFileMgr.Replay_Load(filePath);
        while (task.IsProcessing) { yield(); }

        if (task.HasFailed || !task.HasSucceeded) { log("Failed to load ghost: " + filePath, LogLevel::Error, 88, "LoadLocalGhost"); return; }

        CGameGhostMgrScript@ gm = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript).GhostMgr;
        for (uint i = 0; i < task.Ghosts.Length; i++) {
            CGameGhostScript@ ghost = task.Ghosts[i];
            ghost.IdName = "Personal best";
            ghost.Nickname = "$5d8" + "Personal best";
            ghost.Trigram = "PB" + S_markPluginLoadedPBs;
            gm.Ghost_Add(ghost);
        }

        SaveLocalPBsUntillNextMapForEasyLoading();

        log("Loaded PB ghost from " + filePath, LogLevel::Info, 101, "LoadLocalGhost");
    }

    void LoadGhost(CGameGhostScript@ ghost) {
        log("Ghost loding through 'loadGhost' is dissabled due to issues with saving ghosts.", LogLevel::Warn, 105, "LoadGhost");

        CGameGhostScript@ newGhost = ghost;
        if (newGhost is null) { log("Ghost is null.", LogLevel::Error, 108, "LoadGhost"); return; }

        CGameGhostMgrScript@ gm = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript).GhostMgr;
        newGhost.IdName = "Personal best";
        newGhost.Nickname = "$5d8" + "Personal best";
        newGhost.Trigram = "PB" + S_markPluginLoadedPBs;

        // Ghosts aren't saved properly... (I think)
        // gm.Ghost_Add(newGhost);
    }
    
    ReplayRecord@ FindBestReplay(const array<ReplayRecord@>@ replays) {
        ReplayRecord@ bestReplay = null;
        uint bestTime = 2147483647;

        for (uint i = 0; i < replays.Length; i++) {
            if (replays[i].BestTime < bestTime) {
                @bestReplay = replays[i];
                bestTime = replays[i].BestTime;
            }
        }

        return bestReplay;
    }
}
