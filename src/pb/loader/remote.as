namespace Loader::Remote {
    array<string> g_askedMaps;

    bool AlreadyAskedLB(const string &in uid) { return g_askedMaps.Find(uid) >= 0; }

    void MarkAskedLB(const string &in uid) { if (!AlreadyAskedLB(uid)) g_askedMaps.InsertLast(uid); }

    void DownloadPBFromLeaderboard(const string &in mapUid) {
        startnew(CoroutineFuncUserdataString(_DownloadPBWorker), mapUid);
    }

    void _DownloadPBWorker(const string &in mapUid) {
        if (!_Game::HasPersonalBest(mapUid, true)) {
            log("No PB on Nadeo leaderboard for this map.", LogLevel::Warn, 20, "_DownloadPBWorker");
            return;
        }

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
            log("HTTP " + req.ResponseCode() + " when fetching PB record.", LogLevel::Error, 40, "_DownloadPBWorker");
            return;
        }

        Json::Value json = Json::Parse(req.String());
        if (json.GetType() != Json::Type::Array || json.Length == 0) {
            log("Unexpected JSON when fetching PB record.", LogLevel::Error, 46, "_DownloadPBWorker");
            return;
        }

        string fileUrl = json[0]["url"];
        if (fileUrl == "") {
            log("No replay URL in PB record JSON.", LogLevel::Error, 52, "_DownloadPBWorker");
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
            log("Could not resolve MapId. HTTP " + req.ResponseCode(), LogLevel::Error, 68, "_MapUidToMapId");
            return "";
        }

        Json::Value data = Json::Parse(req.String());
        if (data.GetType() != Json::Type::Array || data.Length == 0) {
            log("Malformed MapId response JSON.", LogLevel::Error, 74, "_MapUidToMapId");
            return "";
        }

        string mapId = data[0]["mapId"];
        log("Resolved MapUid " + uid + " --> MapId " + mapId, LogLevel::Info, 79, "_MapUidToMapId");
        return mapId;
    }
}
