namespace Loader {
    bool isLeacerboardPBVisible = false;

    void TogglePBFromMLHook() {
        if (!S_useLeaderBoardAsLastResort) { log("Loading PB as a last resort from the leaderboard is disabled. Cannot toggle leaderboard PB ghost.", LogLevel::Warn, 5, "TogglePBFromMLHook"); return; }
        startnew(ToggleLeaderboardPB);
    }

    void ToggleLeaderboardPB() {
        if (!S_allowLoadingPBsOnServers) { log("Loading PB ghosts on servers is disabled. Cannot toggle leaderboard PB ghost.", LogLevel::Warn, 10, "ToggleLeaderboardPB"); return; }
        if (!_Game::HasPersonalBest(CurrentMapUID, true)) { log("No personal best found. Cannot toggle leaderboard PB ghost.", LogLevel::Warn, 11, "ToggleLeaderboardPB"); return; }

        string pid = GetApp().LocalPlayerInfo.WebServicesUserId;
        if (pid == "") { log("pid is empty. Cannot toggle leaderboard PB ghost.", LogLevel::Error, 14, "ToggleLeaderboardPB"); return; }

        if (HasServerPB()) { log("Server PB is already loaded. Not toggling PB.", LogLevel::Info, 16, "ToggleLeaderboardPB"); return; }

        MLHook::Queue_SH_SendCustomEvent("TMGame_Record_ToggleGhost", {pid});

        yield(30);

        HidePBIcon();
        ChangePBName();
        log("Toggled leaderboard PB ghost.", LogLevel::Info, 24, "ToggleLeaderboardPB");

        isLeacerboardPBVisible = !isLeacerboardPBVisible;
    }

    bool HasServerPB() {
        CTrackManiaNetwork@ network = cast<CTrackManiaNetwork>(GetApp().Network);
        if (network.ClientManiaAppPlayground is null) return false;

        CGameDataFileManagerScript@ dfm = network.ClientManiaAppPlayground.DataFileMgr;
        if (dfm is null) return false;

        for (uint i = 0; i < dfm.Ghosts.Length; i++) {
            CGameGhostScript@ ghost = cast<CGameGhostScript>(dfm.Ghosts[i]);
            if (string(ghost.Nickname).ToLower().Contains("personal best")) {
                return true;
            }
        }

        return false;
    }

    void HidePBIcon() {
        CControlFrame@ widget = GetRecordsWidget_FullWidgetUI();
        if (widget is null) { log("Failed to get widget. Cannot hide PB icon.", LogLevel::Error, 48, "HidePBIcon"); return; }

        CControlFrame@ pbWidget;
        while (pbWidget is null) { yield(); @pbWidget = GetRecordsWidget_PlayerUI(widget, GetApp().LocalPlayerInfo.Name); }
        
        CControlQuad@ pbIcon = cast<CControlQuad>(pbWidget.Childs[8]);
        if (pbIcon is null) { log("Failed to get PB icon. Cannot hide PB icon.", LogLevel::Error, 54, "HidePBIcon"); return; }

        pbIcon.IsHiddenExternal = true;
        log("Hid PB icon.", LogLevel::Info, 57, "HidePBIcon");
    }

    void ChangePBName() {
        CTrackManiaNetwork@ network = cast<CTrackManiaNetwork>(GetApp().Network);
        if (network.ClientManiaAppPlayground is null) { log("Failed to get playground. Cannot change PB name.", LogLevel::Error, 62, "ChangePBName"); return; }

        CGameDataFileManagerScript@ dfm = network.ClientManiaAppPlayground.DataFileMgr;
        if (dfm is null) { log("Failed to get data file manager. Cannot change PB name.", LogLevel::Error, 65, "ChangePBName"); return; }

        for (uint i = 0; i < dfm.Ghosts.Length; i++) {
            CGameGhostScript@ ghost = cast<CGameGhostScript>(dfm.Ghosts[i]);
            if (string(ghost.Nickname).Contains(GetApp().LocalPlayerInfo.Name)) {
                ghost.Nickname = "$5d8"+"Personal Best";
                
                log("Changed PB name to Personal best", LogLevel::Info, 72, "ChangePBName");
                return;
            }
        }
    }

    void DownloadPBFromLeaderboardAndLoadLocal(const string&in mapUid) {
        if (!_Game::HasPersonalBest(CurrentMapUID, true)) { log("No personal best found. Cannot download leaderboard PB ghost.", LogLevel::Warn, 79, "DownloadPBFromLeaderboardAndLoadLocal"); return; }

        string pid = GetApp().LocalPlayerInfo.WebServicesUserId;
        string mapId = MapUidToMapId(mapUid);

        while (pid == "") { yield(); }
        while (mapId == "") { yield(); }

        string url = "https://prod.trackmania.core.nadeo.online/v2/mapRecords/?accountIdList=" + pid + "&mapId=" + mapId;
        auto req = NadeoServices::Get("NadeoServices", url);

        req.Start();

        while (!req.Finished()) { yield(); }

        if (req.ResponseCode() != 200) {
            log("Failed to fetch replay record, response code: " + req.ResponseCode(), LogLevel::Error, 95, "DownloadPBFromLeaderboardAndLoadLocal");
            ToggleLeaderboardPB();
            return;
        }

        Json::Value data = Json::Parse(req.String());
        if (data.GetType() == Json::Type::Null) {
            log("Failed to parse response for replay record.", LogLevel::Error, 102, "DownloadPBFromLeaderboardAndLoadLocal");
            ToggleLeaderboardPB();
            return;
        }

        if (data.GetType() != Json::Type::Array || data.Length == 0) {
            log("Invalid replay data in response.", LogLevel::Error, 108, "DownloadPBFromLeaderboardAndLoadLocal");
            ToggleLeaderboardPB();
            return;
        }

        string fileUrl = data[0]["url"];
        string mapRecordId = data[0]["mapRecordId"];

        Index::AddReplayToDatabase(fileUrl, mapRecordId); // this has to be done through a url in this case... Need to implement a way for it to be done though a local url for ghost files
                                                             // too at some point, but idk how that would be done with how conversion between CGameCtnGhost and CGameGhostScript is done...
    }

    void SetPBVisibility(bool shouldShow) {
        isLeacerboardPBVisible = shouldShow;
        log("PB ghost visibility set to: " + (shouldShow ? "Visible" : "Hidden"), LogLevel::Info, 122, "SetPBVisibility");
    }
    
}
