namespace Loader {

    // Is Loaded
    bool IsPBLoaded() {
        return IsPBLoaded_Clips();
    }
    bool IsPBLoaded_Clips() {
        auto mgr = GhostClipsMgr::Get(GetApp());
        if (mgr is null) return false;
        for (uint i = 0; i < mgr.Ghosts.Length; i++) {
            string gName = mgr.Ghosts[i].GhostModel.GhostNickname;
            if (gName.ToLower().Contains("personal best")) {
                return true;
            }
        }
        return false;
    }
    // This is unreliable... and clip gets both the ones loded through clips and the ones loaded through Replay_Add (or whatever it was called xdd)
    // bool IsPBLoaded_Local() {
    //     auto net = cast<CGameCtnNetwork>(GetApp().Network);
    //     if (net is null) return false;
    //     auto cmap = cast<CGameManiaAppPlayground>(net.ClientManiaAppPlayground);
    //     if (cmap is null) return false;
    //     auto dfm = cmap.DataFileMgr;
    //     if (dfm is null) return false;
        
    //     for (uint i = 0; i < dfm.Ghosts.Length; i++) {
    //         if (dfm.Ghosts[i].IdName.ToLower().Contains("personal best")) {
    //             return true;
    //         }
    //     }
    //     return false;
    // }
    bool IsFastestPBLoaded() {
        CControlFrame@ widget = GetRecordsList_RecordsWidgetUI();
        string playerName = GetApp().LocalPlayerInfo.Name;
        int widgetTime = GetPlayerPBFromWidget(widget, playerName);

        auto mgr = GhostClipsMgr::Get(GetApp());
        if (mgr is null) return false;

        array<uint> times = array<uint>();
        for (uint i = 0; i < mgr.Ghosts.Length; i++) {
            string gName = mgr.Ghosts[i].GhostModel.GhostNickname;
            if (gName.ToLower().Contains("personal best")) {
                auto time = mgr.Ghosts[i].GhostModel.RaceTime;
                times.InsertLast(time);
            }
        }

        if (times.Length == 0) return false;

        uint fastestTime = 2147483647;
        for (uint i = 0; i < times.Length; i++) {
            if (times[i] < fastestTime) {
                fastestTime = times[i];
            }
        }

        log("Widget time: " + widgetTime + " | Fastest time: " + fastestTime, LogLevel::Info, 60, "IsFastestPBLoaded");

        return widgetTime == int(fastestTime);
    }

    // Save
    array<CGameGhostScript@> tempLocalPBsForCurrentMap;
    void SaveLocalPBsUntillNextMapForEasyLoading() {
        CTrackMania@ app = cast<CTrackMania>(GetApp());
        if (app is null) return;
        CTrackManiaNetwork@ net = cast<CTrackManiaNetwork>(app.Network);
        if (net is null) return;
        CGameManiaAppPlayground@ cmap = cast<CGameManiaAppPlayground>(net.ClientManiaAppPlayground);
        if (cmap is null) return;
        CGameDataFileManagerScript@ dfm = cast<CGameDataFileManagerScript>(cmap.DataFileMgr);
        if (dfm is null) return;

        for (uint i = 0; i < dfm.Ghosts.Length; i++) {
            CGameGhostScript@ ghost = cast<CGameGhostScript>(dfm.Ghosts[i]);
            if (ghost.IdName.ToLower().Contains("personal best")) {
                log("Saving PB: " + ghost.Nickname, LogLevel::Info, 80, "SaveLocalPBsUntillNextMapForEasyLoading");
                tempLocalPBsForCurrentMap.InsertLast(ghost);
            }
        }
    }

    void RemoveLocalPBsUntillNextMapForEasyLoading() {
        tempLocalPBsForCurrentMap.RemoveRange(0, tempLocalPBsForCurrentMap.Length);
    }

    void LoadLocalPBsUntillNextMapForEasyLoading() {
        for (uint i = 0; i < tempLocalPBsForCurrentMap.Length; i++) {
            LoadGhost(tempLocalPBsForCurrentMap[i]);
        }
    }

    // Remove Slowest
    void RemoveSlowestPBGhost() {
        if (_Game::IsPlayingLocal()) {
            RemoveSlowestLocalPBGhost();
        } else if (_Game::IsPlayingOnServer()) {
            log("On a server ghosts can only be loaded through the Leaderboard widget, there isn't a 'slowest' pb ghost to remove, use 'RemoveServerPBGhost' for removing a server pb.", LogLevel::Warn, 101, "RemoveSlowestPBGhost");
        }
    }
    void RemoveSlowestLocalPBGhost() {
        auto dataFileMgr = GetApp().Network.ClientManiaAppPlayground.DataFileMgr;
        auto newGhosts = dataFileMgr.Ghosts;

        CGameGhostScript@ slowestGhost = null;
        for (uint i = 0; i < newGhosts.Length; i++) {
            CGameGhostScript@ ghost = cast<CGameGhostScript>(newGhosts[i]);
            if (ghost.IdName.ToLower().Contains("personal best")) {
                if (slowestGhost is null) {
                    @slowestGhost = ghost;
                } else {
                    if (ghost.Result.Time < slowestGhost.Result.Time) {
                        @slowestGhost = ghost;
                    }
                }
            }
        }

        if (slowestGhost is null) {
            log("No personal best ghosts found to remove.", LogLevel::Warn, 123, "RemoveSlowestLocalPBGhost");
            return;
        }

        if (GetApp().PlaygroundScript is null) return;

        auto gm = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript).GhostMgr;
        gm.Ghost_Remove(slowestGhost.Id);
        log("Record with the MwID of: " + slowestGhost.Id.GetName() + " removed.", LogLevel::Info, 131, "RemoveSlowestLocalPBGhost");
    }

    // Misc
    int TimeStringToMilliseconds(const string&in timeString) {
        string[] parts = timeString.Split(":");
        if (parts.Length != 2) return -1;

        string[] subParts = parts[1].Split(".");
        if (subParts.Length != 2) return -1;

        int minutes = Text::ParseInt(parts[0]);
        int seconds = Text::ParseInt(subParts[0]);
        int milliseconds = Text::ParseInt(subParts[1]);

        return (minutes * 60 * 1000) + (seconds * 1000) + milliseconds;
    }

    string MapUidToMapId(const string&in mapUid) {
        string mapId;
        string url = "https://prod.trackmania.core.nadeo.online/maps/?mapUidList=" + mapUid;
        auto req = NadeoServices::Get("NadeoServices", url);

        req.Start();

        while (!req.Finished()) { yield(); }

        if (req.ResponseCode() != 200) {
            log("Failed to fetch map ID, response code: " + req.ResponseCode(), LogLevel::Error, 159, "MapUidToMapId");
            mapId = "";
        } else {
            Json::Value data = Json::Parse(req.String());
            if (data.GetType() == Json::Type::Null) {
                log("Failed to parse response for map ID.", LogLevel::Error, 164, "MapUidToMapId");
                mapId = "";
            } else {
                if (data.GetType() != Json::Type::Array || data.Length == 0) {
                    log("Invalid map data in response.", LogLevel::Error, 168, "MapUidToMapId");
                    mapId = "";
                } else {
                    mapId = data[0]["mapId"];
                    log("Found map ID: " + mapId, LogLevel::Info, 172, "MapUidToMapId");
                }
            }
        }
        return mapId;
    }

}
