auto mapmonitor_initializer = startnew(MapTracker::MapMonitor);

bool allownessPassedForCurrentFlowCall = false;

namespace MapTracker {
    string oldMapUid = "";

    void MapMonitor() {
        while (true) {
            sleep(273);
            if (!S_enableGhosts) continue;

            if (!_Game::IsPlayingMap()) { oldMapUid = ""; continue; }

            if (oldMapUid != get_CurrentMapUID() && S_enableGhosts) {
                if (get_CurrentMapUID() == "") { oldMapUid = ""; continue; }
                while (!_Game::IsPlayingMap()) yield();
                log("Map changed to: " + get_CurrentMapUID(), LogLevel::Debug, 18, "MapMonitor", "", "\\$f80");
                
                // Permission check moved to the start of the PB loading flow

                Loader::StartPBFlow();
            }

            oldMapUid = get_CurrentMapUID();
        }
    }
}

string get_CurrentMapUID() {
    if (_Game::IsMapLoaded()) {
        CTrackMania@ app = cast<CTrackMania>(GetApp());
        if (app is null) return "";
        CGameCtnChallenge@ map = app.RootMap;
        if (map is null) return "";
        return map.MapInfo.MapUid;
    }
    return "";
}

string get_CurrentMapName() {
    if (_Game::IsMapLoaded()) {
        CTrackMania@ app = cast<CTrackMania>(GetApp());
        if (app is null) return "";
        CGameCtnChallenge@ map = app.RootMap;
        if (map is null) return "";
        return map.MapInfo.Name;
    }
    return "";
}

string get_CurrentGamemode() {
    if (_Game::IsMapLoaded()) {
        CTrackMania@ app = cast<CTrackMania>(GetApp());
        if (app is null) return "";
        CGameCtnNetwork@ net = cast<CGameCtnNetwork>(app.Network);
        if (net is null) return "";
        CTrackManiaNetworkServerInfo@ cnsi = cast<CTrackManiaNetworkServerInfo>(net.ServerInfo);
        if (cnsi is null) return "";
        return cnsi.CurGameModeStr;
    }
    return "";
}