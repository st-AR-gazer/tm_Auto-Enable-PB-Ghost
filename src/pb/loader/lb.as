namespace Loader::Server {
    bool isLeaderboardPBVisible = false;

    void EnsurePersonalBestLoaded() {
        if (HasServerPB()) { log("Server PB already loaded", LogLevel::Info, 5, "EnsurePersonalBestLoaded"); return; }

        if (!S_allowLoadingPBsOnServers) { log("Server PB loading disabled by settings", LogLevel::Info, 7, "EnsurePersonalBestLoaded"); return; }

        startnew(CoroutineFunc(ToggleLeaderboardPB));
    }

    void ToggleLeaderboardPB() {
        if (!_Game::HasPersonalBest(CurrentMapUID, true)) { log("No PB on this map to load from leaderboard", LogLevel::Warn, 13, "ToggleLeaderboardPB"); return; }

        const string pid = GetApp().LocalPlayerInfo.WebServicesUserId;
        if (pid == "") { log("Empty WebServices ID, cannot load LB PB", LogLevel::Error, 16, "ToggleLeaderboardPB"); return; }

        MLHook::Queue_SH_SendCustomEvent("TMGame_Record_ToggleGhost", {pid});
        log("Requested leaderboard PB ghost via ML hook", LogLevel::Info, 19, "ToggleLeaderboardPB");
    }

    bool HasServerPB() {
        CTrackManiaNetwork@ net = cast<CTrackManiaNetwork>(GetApp().Network);
        if (net.ClientManiaAppPlayground is null) return false;

        CGameDataFileManagerScript@ dfm = net.ClientManiaAppPlayground.DataFileMgr;
        if (dfm is null) return false;

        for (uint i = 0; i < dfm.Ghosts.Length; ++i) { 
            CGameGhostScript@ g = cast<CGameGhostScript>(dfm.Ghosts[i]); 
            if (Loader::IsPB(g.IdName)) return true; 
        }
        return false;
    }

    void DownloadPBFromLeaderboard(const string &in mapUid) {
        if (!_Game::HasPersonalBest(CurrentMapUID, true)) {
            log("No PB for player on leaderboard; cannot download", LogLevel::Warn, 38, "DownloadPBFromLeaderboard");
            ToggleLeaderboardPB();
            return;
        }

        const string pid   = GetApp().LocalPlayerInfo.WebServicesUserId;
        const string mapId = Loader::Utils::MapUidToMapId(mapUid);

        while (pid   == "") { yield(); }
        while (mapId == "") { yield(); }

        string url = "https://prod.trackmania.core.nadeo.online/v2/mapRecords/?accountIdList=" + pid + "&mapId=" + mapId;
        auto   req = NadeoServices::Get("NadeoServices", url);

        req.Start();
        while (!req.Finished()) { yield(); }

        if (req.ResponseCode() != 200) {
            log("HTTP error " + req.ResponseCode() + " fetching PB record", LogLevel::Error, 56, "DownloadPBFromLeaderboard");
            ToggleLeaderboardPB();
            return;
        }

        Json::Value json = Json::Parse(req.String());
        if (
            json.GetType() == Json::Type::Null ||
            json.GetType() != Json::Type::Array ||
            json.Length == 0
        ) {
            log("Invalid JSON during PB record fetch", LogLevel::Error, 67, "DownloadPBFromLeaderboard");
            ToggleLeaderboardPB();
            return;
        }

        string fileUrl = json[0]["url"];
        if (fileUrl == "") {
            log("No URL in PB record JSON", LogLevel::Error, 74, "DownloadPBFromLeaderboard");
            ToggleLeaderboardPB();
            return;
        }

        Index::AddReplayToDatabase(fileUrl);
    }

    void SetPBVisibility(bool shouldShow) {
        isLeaderboardPBVisible = shouldShow;
        log("PB visibility set to: " + (shouldShow ? "Visible" : "Hidden"), LogLevel::Info, 84, "SetPBVisibility");
    }
}
