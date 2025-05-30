namespace Loader::Server {

    bool isLeaderboardPBVisible = false;

    void EnsurePersonalBestLoaded() {
        if (TryLoadLocalPB()) return;
        if (!S_useLeaderboardWidgetAsAFallbackWhenAttemptingToLoadPBsOnAServer) { log("Server PB loading disabled in settings", LogLevel::Info, 7, "EnsurePersonalBestLoaded"); return; }
        startnew(CoroutineFunc(ToggleLeaderboardPB));
    }

    bool TryLoadLocalPB() {
        CGameGhostMgrScript@ gm = GhostMgrHelper::Get();
        if (gm is null) return false;

        log("Loading local PB into server GhostMgr", LogLevel::Info, 15, "TryLoadLocalPB");

        string mapUid = CurrentMapUID;
        int pb = _Game::CurrentPersonalBest(mapUid);
        if (pb <= 0) return false;

        auto replays = Database::GetReplays(mapUid);
        if (replays.Length == 0) return false;

        for (uint i = 0; i < replays.Length; ++i) {
            if (replays[i].BestTime == uint(pb)) {
                return LoadReplayIntoMgr(replays[i].Path, gm);
            }
        }

        ReplayRecord@ best = Loader::Local::FindBestReplay(replays);
        if (best is null || best.BestTime > uint(pb)) return false;

        return LoadReplayIntoMgr(best.Path, gm);
    }

    bool LoadReplayIntoMgr(const string &in path, CGameGhostMgrScript@ gm) {
        log("Loading PB into server GhostMgr: " + path, LogLevel::Info, 37, "LoadReplayIntoMgr");
        return GhostLoad::InjectReplay(path, gm);
    }

    /* ───────── fallback via ML-hook ───────── */
    void ToggleLeaderboardPB() {
        if (!_Game::HasPersonalBest(CurrentMapUID, true)) { log("No PB on this map to load from leaderboard", LogLevel::Warn, 43, "ToggleLeaderboardPB"); return; }
        const string pid = GetApp().LocalPlayerInfo.WebServicesUserId;
        if (pid == "") { log("Empty WebServices ID, cannot load LB PB", LogLevel::Error, 45, "ToggleLeaderboardPB"); return; }
        MLHook::Queue_SH_SendCustomEvent("TMGame_Record_ToggleGhost", {pid});
        log("Requested leaderboard PB ghost via ML hook", LogLevel::Info, 47, "ToggleLeaderboardPB");
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
            log("No PB for player on leaderboard; cannot download", LogLevel::Warn, 66, "DownloadPBFromLeaderboard");
            ToggleLeaderboardPB();
            return;
        }

        const string pid   = GetApp().LocalPlayerInfo.WebServicesUserId;
        const string mapId = Loader::Utils::MapUidToMapId(mapUid);

        while (pid == "") { yield(); }
        while (mapId == "") { yield(); }

        string url = "https://prod.trackmania.core.nadeo.online/v2/mapRecords/?accountIdList=" + pid + "&mapId=" + mapId;
        auto req   = NadeoServices::Get("NadeoServices", url);

        req.Start();
        while (!req.Finished()) { yield(); }

        if (req.ResponseCode() != 200) {
            log("HTTP error " + req.ResponseCode() + " fetching PB record", LogLevel::Error, 84, "DownloadPBFromLeaderboard");
            ToggleLeaderboardPB();
            return;
        }

        Json::Value json = Json::Parse(req.String());
        if (json.GetType() == Json::Type::Null || json.GetType() != Json::Type::Array || json.Length == 0) {
            log("Invalid JSON during PB record fetch", LogLevel::Error, 91, "DownloadPBFromLeaderboard");
            ToggleLeaderboardPB();
            return;
        }

        string fileUrl = json[0]["url"];
        if (fileUrl == "") {
            log("No URL in PB record JSON", LogLevel::Error, 98, "DownloadPBFromLeaderboard");
            ToggleLeaderboardPB();
            return;
        }

        Database::AddRecordFromUrl(fileUrl);
    }

    void SetPBVisibility(bool show) {
        isLeaderboardPBVisible = show;
        log("PB visibility set: " + (show ? "Visible" : "Hidden"), LogLevel::Info, 111, "SetPBVisibility");
    }
}
