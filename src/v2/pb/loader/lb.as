namespace Loader {
    bool isPBVisible = false;

    void TogglePBFromMLHook() {
        ToggleLeaderboardPB();
    }

    void ToggleLeaderboardPB() {
        string pid = GetApp().LocalPlayerInfo.WebServicesUserId;
        if (pid == "") {
            log("pid is empty. Cannot toggle leaderboard PB ghost.", LogLevel::Error);
            return;
        }

        MLHook::Queue_SH_SendCustomEvent("TMGame_Record_ToggleGhost", {pid});
        isPBVisible = !isPBVisible;
        log("Toggled PB ghost visibility to: " + (isPBVisible ? "Visible" : "Hidden"), LogLevel::Info);
    }

    void SetPBVisibility(bool shouldShow) {
        isPBVisible = shouldShow;
        log("PB ghost visibility set to: " + (shouldShow ? "Visible" : "Hidden"), LogLevel::Info);
    }

    int GetPlayerPBFromWidget(CControlFrame@ widget, const string&in playerName) {
        for (uint i = 0; i < widget.Childs.Length; i++) {
            CControlFrame@ i0 = widget.Childs[i];
            CControlFrame@ i1 = i0.Childs[6];
            CControlFrame@ i2 = i1.Childs[0];
            CControlFrame@ i3 = i2.Childs[0];
            CControlLabel@ i4 = i3.Childs[1];

            wstring recordDisplayName = i4.Label;

            if (recordDisplayName == playerName) {
                CControlLabel@ record = widget.Childs[i];
                wstring timeString = record.Label;
                return TimeStringToMilliseconds(timeString);
            }
        }
        return -1;
    }

    CControlFrame@ GetRecordsList_RecordsWidgetUI() {
        CGameCtnApp@ app = GetApp();
        if (app is null) { log("App is null", LogLevel::Error); return; }
        CDx11Viewport@ viewport = cast<CDx11Viewport>(app.Viewport);
        if (viewport is null) { log("Viewport is null", LogLevel::Error); return; }
        CHmsZoneOverlay@ widgetOverlay = viewport.Overlays[7];
        if (widgetOverlay is null) { log("Widget overlay is null", LogLevel::Error); return; }
        CSceneSector@ sector = widgetOverlay.UserData;
        CScene2d@ scene = sector.Scene;
        CControlFrame@ InterfaceRoot = scene.Mobils[1]; // 14738
        CControlFrame@ FrameInGameBase = InterfaceRoot.Childs[2]; // 5
        CControlFrame@ i1  = FrameInGameBase.Childs[8]; // 11
        CControlFrame@ i2  = i1.Childs[12]; // 27
        CControlFrame@ i3  = i2.Childs[1]; // 2
        CControlFrame@ i4  = i3.Childs[2]; // 3
        CControlFrame@ i5  = i4.Childs[0]; // 1
        CControlFrame@ i6  = i5.Childs[0]; // 2
        CControlFrame@ i7  = i6.Childs[1]; // 2
        CControlFrame@ i8  = i7.Childs[7]; // 11
        CControlFrame@ widget  = i8.Childs[0]; // 2

        // i9 is the records widget to the left, specifically showing from 1st to 5th, and if applicable, the surround of the current player.
        // note that we can only use have to use i9.Childs[6] to get the pb record if the current player is not in the top 5...
        // We can use `GetApp().LocalPlayerInfo.Name;` to get the current displayname of the player, if this matches any player in the list,
        // we can then use the time and get the corrcet pb in relation to the current player, this is ofc, only if there are any pb's locally, 
        // if not we just load with the lb method...

        // Navigating the ui is (not) fun :mhm:
    }
}
