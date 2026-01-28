namespace Loader::Remote {
    array<string> g_askedMaps;

    bool AlreadyAskedLB(const string &in uid) { return g_askedMaps.Find(uid) >= 0; }

    void MarkAskedLB(const string &in uid) { if (!AlreadyAskedLB(uid)) g_askedMaps.InsertLast(uid); }

    void DownloadPBFromLeaderboard(const string &in mapUid) {
        startnew(_DownloadPBWorker, mapUid);
    }

    bool HasPersonalBest(const string &in mapUid) {
        if (_Game::HasPersonalBest(mapUid)) { log("PB found for map: " + mapUid + ", " + _Game::CurrentPersonalBest(mapUid), LogLevel::Debug, 13, "HasPersonalBest", "", "\\$f80"); return true; }
        if (UINav::WidgetPlayerPB() >= 0) { log("Widget PB found for map: " + mapUid + ", " + UINav::WidgetPlayerPB(), LogLevel::Debug, 14, "HasPersonalBest", "", "\\$f80"); return true; }
        return false;
    }

    // _Game::HasPersonalBest does not always return true for servers, it does seems to always return for local play,
    // I've also noticed some issues not in local play, that I can't really explain, but does at least work for the most part :xdd:
    // but we should also check the widget, just in case...

    void _DownloadPBWorker(const string &in mapUid) {
        const int maxFrames = 6 * 60;
        int frameCount = 0;
        while (frameCount++ < maxFrames) {
            yield();
            if (HasPersonalBest(mapUid)) { break; }
        }
        if (!HasPersonalBest(mapUid)) { log("No PB on Nadeo leaderboard for this map within 360 frames given.", LogLevel::Warning, 29, "_DownloadPBWorker", "", "\\$f80"); return; }

        string playerId;
        while (playerId == "") {
            playerId = GetApp().LocalPlayerInfo.WebServicesUserId;
            yield();
        }

        string mapId = _MapUidToMapId(mapUid);
        if (mapId == "") return;

        string url = "https://prod.trackmania.core.nadeo.online/v2/mapRecords/"
                   + "?accountIdList=" + playerId
                   + "&mapId="         + mapId;

        auto req = NadeoServices::Get("NadeoServices", url);
        req.Start();
        while (!req.Finished()) { yield(); }

        if (req.ResponseCode() != 200) {
            log("HTTP " + req.ResponseCode() + " when fetching PB record.", LogLevel::Error, 49, "_DownloadPBWorker", "", "\\$f80");
            return;
        }

        Json::Value json = Json::Parse(req.String());
        if (json.GetType() != Json::Type::Array || json.Length == 0) {
            log("Unexpected JSON when fetching PB record.", LogLevel::Error, 55, "_DownloadPBWorker", "", "\\$f80");
            return;
        }

        string fileUrl = json[0]["url"];
        if (fileUrl == "") {
            log("No replay URL in PB record JSON.", LogLevel::Error, 61, "_DownloadPBWorker", "", "\\$f80");
            return;
        }

        Database::AddRecordFromUrl(fileUrl);
    }

    string _MapUidToMapId(const string &in uid) {
        string url = "https://prod.trackmania.core.nadeo.online/maps/?mapUidList=" + uid;
        auto req = NadeoServices::Get("NadeoServices", url);

        req.Start();
        while (!req.Finished()) { yield(); }

        if (req.ResponseCode() != 200) {
            log("Could not resolve MapId. HTTP " + req.ResponseCode(), LogLevel::Error, 76, "_MapUidToMapId", "", "\\$f80");
            return "";
        }

        Json::Value data = Json::Parse(req.String());
        if (data.GetType() != Json::Type::Array || data.Length == 0) {
            log("Malformed MapId response JSON.", LogLevel::Error, 82, "_MapUidToMapId", "", "\\$f80");
            return "";
        }

        string mapId = data[0]["mapId"];
        log("Resolved MapUid " + uid + " --> MapId " + mapId, LogLevel::Info, 87, "_MapUidToMapId", "", "\\$f80");
        return mapId;
    }
}
