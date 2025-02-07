namespace Loader {

    void LoadPBFromDB() {
        uint startTime = Time::Now;
        while (_Game::CurrentPersonalBest(CurrentMapUID) == -1) {
            if (Time::Now - startTime > 8000) { break; }
            yield();
        }

        string mapUid = get_CurrentMapUID();

        string playerName = GetApp().LocalPlayerInfo.Name;
        int playerPBTime = _Game::CurrentPersonalBest(CurrentMapUID);

        if (playerPBTime >= 0) {
            log("Found PB in the widget. Attempting to match local record.", LogLevel::Info, 17, "LoadPBFromDB");
            LoadPersonalBestGhostFromTime(mapUid, playerPBTime);
        } else {
            log("Player PB not found in the widget. Falling back to fastest local record.", LogLevel::Warn, 20, "LoadPBFromDB");
            FallbackLoadPB(mapUid);
        }
    }

    void LoadPersonalBestGhostFromTime(const string&in mapUid, int playerPBTime) {
        auto replays = Index::GetReplaysFromDB(mapUid);

        if (replays.Length == 0) {
            log("No local PB ghost found for map UID: " + mapUid + " | attempting to download from leaderboard.", LogLevel::Warn, 29, "LoadPersonalBestGhostFromTime");
            DownloadPBFromLeaderboardAndLoadLocal(mapUid);
            return;
        }

        for (uint i = 0; i < replays.Length; i++) {
            if (replays[i].BestTime == uint(playerPBTime)) {
                string fullPath = replays[i].Path;
                LoadLocalGhost(fullPath);
                return;
            }
        }

        log("Could not find a matching local replay for time: " + playerPBTime + " ms.", LogLevel::Warn, 42, "LoadPersonalBestGhostFromTime");
        FallbackLoadPB(mapUid);
    }

    void FallbackLoadPB(const string&in mapUid) {
        auto replays = Index::GetReplaysFromDB(mapUid);

        if (replays.Length == 0) {
            log("No local records found for map UID: " + mapUid + " | attempting to download from leaderboard.", LogLevel::Warn, 50, "FallbackLoadPB");
            DownloadPBFromLeaderboardAndLoadLocal(mapUid);
            return;
        }

        log("Loading fastest local record for map UID: " + mapUid, LogLevel::Info, 55, "FallbackLoadPB");
        auto bestReplay = FindBestReplay(replays);
        CControlFrame@ widget = GetRecordsList_RecordsWidgetUI();

        if (bestReplay.BestTime > uint(GetPlayerPBFromWidget(widget, string(GetApp().LocalPlayerInfo.Name)))) {
            log("Local PB is slower than the widget PB("+ bestReplay.BestTime + " | " + GetPlayerPBFromWidget(widget, string(GetApp().LocalPlayerInfo.Name)) + "). Fetching from leaderboard.", LogLevel::Warn, 60, "FallbackLoadPB");
            DownloadPBFromLeaderboardAndLoadLocal(mapUid);
        } else if (bestReplay !is null) {
            string fullPath = bestReplay.Path;
            LoadLocalGhost(fullPath);
        }
    }

    void LoadLocalGhost(const string&in filePath) {
        if (!filePath.StartsWith(IO::FromUserGameFolder("Replays/"))) {
            log("File is not in the Replays folder. Moving File there temporarily, and set it for deletion after loading...", LogLevel::Warn, 70, "LoadLocalGhost");
            _IO::File::CopyFileTo(filePath, IO::FromUserGameFolder("Replays/" + Path::GetFileName(filePath)));
        }

        yield();

        if (!IO::FileExists(filePath)) { 
            log("Failed to load ghost: File does not exist.", LogLevel::Error, 77, "LoadLocalGhost"); 
            Index::DeleteEntryFromDatabaseBasedOnFilePath(filePath);
            if (_Game::HasPersonalBest(CurrentMapUID)) { LoadPB(); }
            return; 
        }

        auto task = GetApp().Network.ClientManiaAppPlayground.DataFileMgr.Replay_Load(filePath);
        while (task.IsProcessing) { yield(); }

        if (task.HasFailed || !task.HasSucceeded) { log("Failed to load ghost: " + filePath, LogLevel::Error, 86, "LoadLocalGhost"); return; }

        CGameGhostMgrScript@ gm = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript).GhostMgr;
        for (uint i = 0; i < task.Ghosts.Length; i++) {
            CGameGhostScript@ ghost = task.Ghosts[i];
            ghost.IdName = "Personal best";
            ghost.Nickname = "$5d8" + "Personal best";
            ghost.Trigram = "PB" + S_markPluginLoadedPBs;
            gm.Ghost_Add(ghost);
        }

        log("Loaded PB ghost from " + filePath, LogLevel::Info, 97, "LoadLocalGhost");



        // for (uint i = 0; i < GetApp().Network.ClientManiaAppPlayground.DataFileMgr.Ghosts.Length; i++) {
        //     print(GetApp().Network.ClientManiaAppPlayground.DataFileMgr.Ghosts[i].Nickname);
        // }
    }

    void LoadGhost(CGameGhostScript@ ghost) {
        if (ghost is null) { log("Ghost is null.", LogLevel::Error, 107, "LoadGhost"); return; }

        CGameGhostMgrScript@ gm = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript).GhostMgr;
        ghost.IdName = "Personal best";
        ghost.Nickname = "$5d8" + "Personal best";
        ghost.Trigram = "PB" + S_markPluginLoadedPBs;
        gm.Ghost_Add(ghost);
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
