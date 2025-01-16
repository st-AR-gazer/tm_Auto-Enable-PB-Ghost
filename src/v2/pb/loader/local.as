namespace Loader {

    void LoadPBFromDB() {
        string mapUid = get_CurrentMapUID();
        CControlFrame@ widget = GetRecordsList_RecordsWidgetUI();

        if (widget is null) {
            log("Could not find the records widget. Attempting to load record without important comparison data.", LogLevel::Warn);
            FallbackLoadPB(mapUid);
            return;
        }

        string playerName = GetApp().LocalPlayerInfo.Name;
        int playerPBTime = GetPlayerPBFromWidget(widget, playerName);

        if (playerPBTime >= 0) {
            log("Found PB in the widget. Attempting to match local record.", LogLevel::Info);
            LoadPersonalBestGhostFromTime(mapUid, playerPBTime);
        } else {
            log("Player PB not found in the widget. Falling back to fastest local record.", LogLevel::Warn);
            FallbackLoadPB(mapUid);
        }
    }

    void LoadPersonalBestGhostFromTime(const string&in mapUid, int playerPBTime) {
        auto replays = Index::GetReplaysFromDB(mapUid);

        if (replays.Length == 0) {
            log("No local PB ghost found for map UID: " + mapUid, LogLevel::Warn);
            ToggleLeaderboardPB();
            return;
        }

        for (uint i = 0; i < replays.Length; i++) {
            if (replays[i].BestTime == uint(playerPBTime)) {
                string fullPath = IO::FromUserGameFolder(replays[i].Path);
                LoadLocalGhost(fullPath);
                return;
            }
        }

        log("Could not find a matching local replay for time: " + playerPBTime + " ms.", LogLevel::Warn);
        FallbackLoadPB(mapUid);
    }

    void FallbackLoadPB(const string&in mapUid) {
        auto replays = Index::GetReplaysFromDB(mapUid);

        if (replays.Length == 0) {
            log("No local records found for map UID: " + mapUid + ". Using leaderboard toggle.", LogLevel::Warn);
            ToggleLeaderboardPB();
            return;
        }

        log("Loading fastest local record for map UID: " + mapUid, LogLevel::Info);
        auto bestReplay = FindBestReplay(replays);
        if (bestReplay !is null) {
            string fullPath = IO::FromUserGameFolder(bestReplay.Path);
            LoadLocalGhost(fullPath);
        }
    }

    void LoadLocalGhost(const string&in filePath) {
        if (!filePath.StartsWith(IO::FromUserGameFolder("Replays/"))) {
            log("File is not in the Replays folder. Moving File there temporarily, and set it for deletion after loading...", LogLevel::Warn);
            _IO::File::CopyFileTo(filePath, IO::FromUserGameFolder("Replays/" + Path::GetFileName(filePath)));
            return;
        }

        auto app = GetApp();
        if (app.Network.ClientManiaAppPlayground !is null) {
            app.Network.ClientManiaAppPlayground.DataFileMgr.Replay_Load(filePath);
            log("Loaded local ghost: " + filePath, LogLevel::Info);
        } else {
            log("Failed to load ghost: ClientManiaAppPlayground is null.", LogLevel::Error);
        }
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
