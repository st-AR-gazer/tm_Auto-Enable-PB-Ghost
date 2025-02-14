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
        auto replays = Index::GetReplaysFromDB(mapUid);

        if (replays.Length == 0) {
            log("No local PB ghost found for map UID: " + mapUid + " | attempting to download from leaderboard.", LogLevel::Warn, 22, "LoadPersonalBestGhostFromTime");
            DownloadPBFromLeaderboardAndLoadLocal(mapUid);
            return;
        }

        log("Loading local PB ghost for time: " + playerPBTime + " ms., total ghosts found: " + Index::GetTotalReplaysForMap(mapUid), LogLevel::Info, 27, "LoadPersonalBestGhostFromTime");

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
        auto replays = Index::GetReplaysFromDB(mapUid);

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
        if (!filePath.StartsWith(IO::FromUserGameFolder("Replays/"))) {
            log("File is not in the Replays folder. Moving File there temporarily, and set it for deletion after loading...", LogLevel::Warn, 72, "LoadLocalGhost");
            _IO::File::CopyFileTo(filePath, IO::FromUserGameFolder("Replays/" + Path::GetFileName(filePath)));
        }

        yield();

        if (!IO::FileExists(filePath)) { 
            log("Failed to load ghost: File does not exist.", LogLevel::Error, 79, "LoadLocalGhost"); 
            Index::DeleteEntryFromDatabaseBasedOnFilePath(filePath);
            if (_Game::HasPersonalBest(CurrentMapUID, true)) { LoadPB(); }
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
        print("aa");

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
