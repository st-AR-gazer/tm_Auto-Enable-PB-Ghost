namespace Loader {
    bool isLeacerboardPBVisible = false;

    void TogglePBFromMLHook() {
        startnew(ToggleLeaderboardPB);
    }

    void ToggleLeaderboardPB() {
        if (!_Game::HasPersonalBest(CurrentMapUID, true)) { log("No personal best found. Cannot toggle leaderboard PB ghost.", LogLevel::Warn, 9, "ToggleLeaderboardPB"); return; }

        string pid = GetApp().LocalPlayerInfo.WebServicesUserId;
        if (pid == "") { log("pid is empty. Cannot toggle leaderboard PB ghost.", LogLevel::Error, 12, "ToggleLeaderboardPB"); return; }

        // if (HasServerPB()) { log("Server PB is already loaded. Not toggling PB.", LogLevel::Info, 14, "ToggleLeaderboardPB"); return; }

        MLHook::Queue_SH_SendCustomEvent("TMGame_Record_ToggleGhost", {pid});

        HidePBIcon();

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
        if (widget is null) { log("Failed to get widget. Cannot hide PB icon.", LogLevel::Error, 42, "HidePBIcon"); return; }

        CControlFrame@ pbWidget = GetRecordsWidget_PlayerUI(widget, GetApp().LocalPlayerInfo.Name);
        if (pbWidget is null) { log("Failed to get PB widget. Cannot hide PB icon.", LogLevel::Error, 45, "HidePBIcon"); return; }


        

    }

    void DownloadPBFromLeaderboardAndLoadLocal(const string&in mapUid) {
        if (!_Game::HasPersonalBest(CurrentMapUID, true)) { log("No personal best found. Cannot download leaderboard PB ghost.", LogLevel::Warn, 53, "DownloadPBFromLeaderboardAndLoadLocal"); return; }

        string pid = GetApp().LocalPlayerInfo.WebServicesUserId;
        string mapId = MapUidToMapId(mapUid);

        while (pid == "") { yield(); }
        while (mapId == "") { yield(); }

        string url = "https://prod.trackmania.core.nadeo.online/v2/mapRecords/?accountIdList=" + pid + "&mapId=" + mapId;
        auto req = NadeoServices::Get("NadeoServices", url);

        req.Start();

        while (!req.Finished()) { yield(); }

        if (req.ResponseCode() != 200) {
            log("Failed to fetch replay record, response code: " + req.ResponseCode(), LogLevel::Error, 69, "DownloadPBFromLeaderboardAndLoadLocal");
            ToggleLeaderboardPB();
            return;
        }

        Json::Value data = Json::Parse(req.String());
        if (data.GetType() == Json::Type::Null) {
            log("Failed to parse response for replay record.", LogLevel::Error, 76, "DownloadPBFromLeaderboardAndLoadLocal");
            ToggleLeaderboardPB();
            return;
        }

        if (data.GetType() != Json::Type::Array || data.Length == 0) {
            log("Invalid replay data in response.", LogLevel::Error, 82, "DownloadPBFromLeaderboardAndLoadLocal");
            ToggleLeaderboardPB();
            return;
        }

        string fileUrl = data[0]["url"];
        string mapRecordId = data[0]["mapRecordId"];

        Index::AddReplayToDB(fileUrl, mapRecordId); // this has to be done through a url in this case... Need to implement a way for it to be done though a local url for ghost files
                                                    // too at some point, but idk how that would be done with how conversion between CGameCtnGhost and CGameGhostScript is done...
    }

    void SetPBVisibility(bool shouldShow) {
        isLeacerboardPBVisible = shouldShow;
        log("PB ghost visibility set to: " + (shouldShow ? "Visible" : "Hidden"), LogLevel::Info, 96, "SetPBVisibility");
    }
    
}
