namespace Loader {
    bool isLeacerboardPBVisible = false;

    void TogglePBFromMLHook() {
        ToggleLeaderboardPB();
    }

    void ToggleLeaderboardPB() {
        if (!_Game::HasPersonalBest()) {
            log("No personal best found. Cannot toggle leaderboard PB ghost.", LogLevel::Warn, 10, "ToggleLeaderboardPB");
            return;
        }

        string pid = GetApp().LocalPlayerInfo.WebServicesUserId;
        if (pid == "") {
            log("pid is empty. Cannot toggle leaderboard PB ghost.", LogLevel::Error, 16, "ToggleLeaderboardPB");
            return;
        }

        MLHook::Queue_SH_SendCustomEvent("TMGame_Record_ToggleGhost", {pid});
        isLeacerboardPBVisible = !isLeacerboardPBVisible;
    }

    void DownloadPBFromLeaderboardAndLoadLocal(const string&in mapUid) {
        if (!_Game::HasPersonalBest()) { log("No personal best found. Cannot download leaderboard PB ghost.", LogLevel::Warn, 26, "DownloadPBFromLeaderboardAndLoadLocal"); return; }

        string pid = GetApp().LocalPlayerInfo.WebServicesUserId;
        string mapId = MapUidToMapId(mapUid);

        while (pid == "") { yield(); }
        while (mapId == "") { yield(); }

        string url = "https://prod.trackmania.core.nadeo.online/v2/mapRecords/?accountIdList=" + pid + "&mapId=" + mapId;
        auto req = NadeoServices::Get("NadeoServices", url);

        req.Start();

        while (!req.Finished()) { yield(); }

        if (req.ResponseCode() != 200) {
            log("Failed to fetch replay record, response code: " + req.ResponseCode(), LogLevel::Error, 44, "DownloadPBFromLeaderboardAndLoadLocal");
            ToggleLeaderboardPB();
            return;
        }

        Json::Value data = Json::Parse(req.String());
        if (data.GetType() == Json::Type::Null) {
            log("Failed to parse response for replay record.", LogLevel::Error, 51, "DownloadPBFromLeaderboardAndLoadLocal");
            ToggleLeaderboardPB();
            return;
        }

        if (data.GetType() != Json::Type::Array || data.Length == 0) {
            log("Invalid replay data in response.", LogLevel::Error, 57, "DownloadPBFromLeaderboardAndLoadLocal");
            ToggleLeaderboardPB();
            return;
        }

        string fileUrl = data[0]["url"];

        Index::AddReplayToDB(fileUrl); // this has to be done through a url in this case... Need to implement a way for it to be done though a local url for ghost files
                                       // too at some point, but idk how that would be done with how conversion between CGameCtnGhost and CGameGhostScript is done...
    }

    void SetPBVisibility(bool shouldShow) {
        isLeacerboardPBVisible = shouldShow;
        log("PB ghost visibility set to: " + (shouldShow ? "Visible" : "Hidden"), LogLevel::Info, 85, "SetPBVisibility");
    }

    int GetPlayerPBFromWidget(CControlFrame@ widget, const string&in playerName) {
        array<CControlFrame@> recordsWidget;

        for (uint i = 0; i < widget.Childs.Length; i++) {
            recordsWidget.InsertLast(cast<CControlFrame>(widget.Childs[i]));
        }

        dictionary records;
        for (uint i = 0; i < recordsWidget.Length; i++) {
            string name = cast<CControlLabel>(cast<CControlFrame>(cast<CControlFrame>(cast<CControlFrame>(recordsWidget[i].Childs[6]).Childs[0]).Childs[0]).Childs[1]).Label;
            string time = cast<CControlLabel>(recordsWidget[i].Childs[7]).Label;
            records[name] = time;
        }

        string localPlayerName = GetApp().LocalPlayerInfo.Name;
        if (records.Exists(localPlayerName)) {
            int time = TimeStringToMilliseconds(string(records[localPlayerName]));
            return time;
        }

        return -1;
    }

    CControlFrame@ GetRecordsList_RecordsWidgetUI() {
        int overlayIndex = FindValidWidgetChain_Overlay();
        if (overlayIndex == -1) {
            return CControlFrame();
        }
        
        CGameCtnApp@ app = GetApp();
        CDx11Viewport@ viewport = cast<CDx11Viewport>(app.Viewport);
        CHmsZoneOverlay@ overlay = cast<CHmsZoneOverlay>(viewport.Overlays[overlayIndex]);

        if (overlay.UserData is null) return null;
        CSceneSector@ userData = cast<CSceneSector>(overlay.UserData); // UserData
        if (userData.Scene is null) return null;
        CScene2d@ scene = cast<CScene2d>(userData.Scene); // Scene
        if (scene.Mobils.Length == 0) return null;
        CControlFrameStyled@ interfaceRoot = cast<CControlFrameStyled>(scene.Mobils[0]); // InterfaceRoot
        if (interfaceRoot.Childs.Length < 1 || interfaceRoot.Childs[0] is null) return null;
        CControlFrame@ frameSystemOverlay = cast<CControlFrame>(interfaceRoot.Childs[0]); // SystemOverlay
        if (frameSystemOverlay.Childs.Length < 3 || frameSystemOverlay.Childs[2] is null) return null;
        CControlFrame@ frameInGameBase = cast<CControlFrame>(frameSystemOverlay.Childs[2]); // InGameBase
        if (frameInGameBase.Childs.Length < 9 || frameInGameBase.Childs[8] is null) return null;
        CControlFrame@ frameInGame = cast<CControlFrame>(frameInGameBase.Childs[8]); // InGame
        if (frameInGame.Childs.Length < 13 || frameInGame.Childs[12] is null) return null;
        CControlFrame@ frameInGame2 = cast<CControlFrame>(frameInGame.Childs[12]); // InGame2
        if (frameInGame2.Childs.Length < 2 || frameInGame2.Childs[1] is null) return null;
        CControlFrame@ frameInGame3 = cast<CControlFrame>(frameInGame2.Childs[1]); // InGame3
        if (frameInGame3.Childs.Length < 3 || frameInGame3.Childs[2] is null) return null;
        CControlFrame@ frameInGame4 = cast<CControlFrame>(frameInGame3.Childs[2]); // InGame4
        if (frameInGame4.Childs.Length < 1 || frameInGame4.Childs[0] is null) return null;
        CControlFrame@ frameInGame5 = cast<CControlFrame>(frameInGame4.Childs[0]); // InGame5
        if (frameInGame5.Childs.Length < 1 || frameInGame5.Childs[0] is null) return null;
        CControlFrame@ frameInGame6 = cast<CControlFrame>(frameInGame5.Childs[0]); // InGame6
        if (frameInGame6.Childs.Length < 2 || frameInGame6.Childs[1] is null) return null;
        CControlFrame@ frameInGame7 = cast<CControlFrame>(frameInGame6.Childs[1]); // InGame7
        if (frameInGame7.Childs.Length < 8 || frameInGame7.Childs[7] is null) return null;
        CControlFrame@ frameInGame8 = cast<CControlFrame>(frameInGame7.Childs[7]); // InGame8
        if (frameInGame8.Childs.Length < 1 || frameInGame8.Childs[0] is null) return null;
        CControlFrame@ widget = cast<CControlFrame>(frameInGame8.Childs[0]); // Widget

        return widget;

        // i9 is the records widget to the left, specifically showing from 1st to 5th, and if applicable, the surround of the current player.
        // note that we can only use have to use i9.Childs[6] to get the pb record if the current player is not in the top 5...
        // We can use `GetApp().LocalPlayerInfo.Name;` to get the current displayname of the player, if this matches any player in the list,
        // we can then use the time and get the corrcet pb in relation to the current player, this is ofc, only if there are any pb's locally, 
        // if not we just load with the lb method...

        // Navigating the ui is (not) fun :mhm:
    }

    // Smadge why does it have to move around so much, I just want to get the widget :(
    int FindValidWidgetChain_Overlay() {
        if (GetApp() is null) return -1;
        CGameCtnApp@ app = GetApp();
        if (app.Viewport is null) return -1;
        CDx11Viewport@ viewport = cast<CDx11Viewport>(app.Viewport); // Viewport
        for (uint i = 0; i < viewport.Overlays.Length; i++) {
            CHmsZoneOverlay@ overlay = cast<CHmsZoneOverlay>(viewport.Overlays[i]); // Overlay
            if (overlay is null) continue;
            if (overlay.UserData is null) continue;
            CSceneSector@ userData = cast<CSceneSector>(overlay.UserData); // UserData
            if (userData is null) continue;
            if (userData.Scene is null) continue;
            CScene2d@ scene = cast<CScene2d>(userData.Scene); // Scene
            if (scene is null) continue;
            for (uint j = 0; j < scene.Mobils.Length; j++) {
                if (scene.Mobils[j] is null) continue;
                CControlFrameStyled@ interfaceRoot = cast<CControlFrameStyled>(scene.Mobils[j]); // InterfaceRoot
                if (interfaceRoot is null) continue;
                if (interfaceRoot.Childs.Length < 1) continue;
                if (interfaceRoot.Childs[0] is null) continue;
                CControlFrame@ frameSystemOverlay = cast<CControlFrame>(interfaceRoot.Childs[0]); // SystemOverlay
                if (frameSystemOverlay is null) continue;
                if (frameSystemOverlay.Childs.Length < 3) continue;
                if (frameSystemOverlay.Childs[2] is null) continue;
                CControlFrame@ frameInGameBase = cast<CControlFrame>(frameSystemOverlay.Childs[2]); // InGameBase
                if (frameInGameBase is null) continue;
                if (frameInGameBase.Childs.Length < 9) continue;
                if (frameInGameBase.Childs[8] is null) continue;
                CControlFrame@ frameInGame = cast<CControlFrame>(frameInGameBase.Childs[8]); // InGame
                if (frameInGame is null) continue;
                if (frameInGame.Childs.Length < 13) continue;
                if (frameInGame.Childs[12] is null) continue;
                CControlFrame@ frameInGame2 = cast<CControlFrame>(frameInGame.Childs[12]); // InGame2
                if (frameInGame2 is null) continue;
                if (frameInGame2.Childs.Length < 2) continue;
                if (frameInGame2.Childs[1] is null) continue;
                CControlFrame@ frameInGame3 = cast<CControlFrame>(frameInGame2.Childs[1]); // InGame3
                if (frameInGame3 is null) continue;
                if (frameInGame3.Childs.Length < 3) continue;
                if (frameInGame3.Childs[2] is null) continue;
                CControlFrame@ frameInGame4 = cast<CControlFrame>(frameInGame3.Childs[2]); // InGame4
                if (frameInGame4 is null) continue;
                if (frameInGame4.Childs.Length < 1) continue;
                if (frameInGame4.Childs[0] is null) continue;
                CControlFrame@ frameInGame5 = cast<CControlFrame>(frameInGame4.Childs[0]); // InGame5
                if (frameInGame5 is null) continue;
                if (frameInGame5.Childs.Length < 1) continue;
                if (frameInGame5.Childs[0] is null) continue;
                CControlFrame@ frameInGame6 = cast<CControlFrame>(frameInGame5.Childs[0]); // InGame6
                if (frameInGame6 is null) continue;
                if (frameInGame6.Childs.Length < 2) continue;
                if (frameInGame6.Childs[1] is null) continue;
                CControlFrame@ frameInGame7 = cast<CControlFrame>(frameInGame6.Childs[1]); // InGame7
                if (frameInGame7 is null) continue;
                if (frameInGame7.Childs.Length < 8) continue;
                if (frameInGame7.Childs[7] is null) continue;
                CControlFrame@ frameInGame8 = cast<CControlFrame>(frameInGame7.Childs[7]); // InGame8
                if (frameInGame8 is null) continue;
                if (frameInGame8.Childs.Length < 1) continue;
                if (frameInGame8.Childs[0] is null) continue;
                CControlFrame@ widget = cast<CControlFrame>(frameInGame8.Childs[0]); // Widget
                if (widget is null) continue;
                // Found a valid widget chain; return this overlay's index.
                return i;
            }
        }
        return -1;
    }

}
