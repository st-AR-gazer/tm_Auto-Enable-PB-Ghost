namespace Loader::Utils {
    bool FastestPBIsLoaded() {
        int widgetTime = UINav::WidgetPlayerPB();
        if (widgetTime < 0) return false;

        auto mgr = GhostClipsMgr::Get(GetApp());
        if (mgr is null) return false;

        uint fastest = 0xFFFFFFFF;
        for (uint i = 0; i < mgr.Ghosts.Length; ++i) {
            string nick = mgr.Ghosts[i].GhostModel.GhostNickname;
            if (Loader::IsPB(nick)) fastest = Math::Min(fastest, mgr.Ghosts[i].GhostModel.RaceTime);
        }

        if (fastest == 0xFFFFFFFF) return false;

        log("Widget time: " + widgetTime + " | Fastest PB ghost: " + fastest, LogLevel::Info, 17, "FastestPBIsLoaded");

        return widgetTime == int(fastest);
    }

    int TimeStringToMilliseconds(const string &in timeString) {
        string[] parts = timeString.Split(":");
        if (parts.Length != 2) return -1;

        string[] subParts = parts[1].Split(".");
        if (subParts.Length != 2) return -1;

        int minutes      = Text::ParseInt(parts[0]);
        int seconds      = Text::ParseInt(subParts[0]);
        int milliseconds = Text::ParseInt(subParts[1]);

        return (minutes * 60 * 1000) + (seconds * 1000) + milliseconds;
    }

    string MapUidToMapId(const string &in mapUid) {
        string url = "https://prod.trackmania.core.nadeo.online/maps/?mapUidList=" + mapUid;
        auto req = NadeoServices::Get("NadeoServices", url);

        req.Start();
        while (!req.Finished()) { yield(); }

        if (req.ResponseCode() != 200) { log("Failed to fetch map ID, response code: " + req.ResponseCode(), LogLevel::Error, 43, "MapUidToMapId"); return ""; }

        Json::Value data = Json::Parse(req.String());
        if (data.GetType() == Json::Type::Null) { log("Failed to parse response for map ID.", LogLevel::Error, 46, "MapUidToMapId"); return ""; }
        if (data.GetType() != Json::Type::Array || data.Length == 0) { log("Invalid map data in response.", LogLevel::Error, 47, "MapUidToMapId"); return ""; }

        string mapId = data[0]["mapId"];
        log("Found map ID: " + mapId, LogLevel::Info, 50, "MapUidToMapId");
        return mapId;
    }
}
