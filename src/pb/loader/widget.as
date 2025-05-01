namespace Loader {

    array<array<int>> g_candidateChains = {
        {0, 2, 8, 15, 1, 2, 0, 0, 1},
        {0, 2, 8, 13, 1, 2, 0, 0, 1},
        {0, 2, 8, 12, 1, 2, 0, 0, 1}
    };

    array<array<int>> g_recordsCandidateChains = {
        {7, 0}
    };

    CControlFrame@ TraverseWidgetChain(CControlFrame@ start, const array<int> indices) {
        CControlFrame@ current = start;
        for (uint i = 0; i < indices.Length; i++) {
            int idx = indices[i];
            if (current is null || int(current.Childs.Length) <= idx || current.Childs[idx] is null)
                return null;
            @current = cast<CControlFrame>(current.Childs[idx]);
        }
        return current;
    }

    bool HasValidWidgetChain(CHmsZoneOverlay@ overlay, const array<int> indices) {
        if (overlay is null || overlay.UserData is null) return false;
        CSceneSector@ userData = cast<CSceneSector>(overlay.UserData);
        if (userData is null || userData.Scene is null) return false;
        CScene2d@ scene = cast<CScene2d>(userData.Scene);
        if (scene.Mobils.Length == 0 || scene.Mobils[0] is null) return false;
        CControlFrameStyled@ interfaceRootStyled = cast<CControlFrameStyled>(scene.Mobils[0]);
        if (interfaceRootStyled is null || interfaceRootStyled.Childs.Length == 0 || interfaceRootStyled.Childs[0] is null) return false;
        CControlFrame@ interfaceRoot = cast<CControlFrame>(interfaceRootStyled);
        return (TraverseWidgetChain(interfaceRoot, indices) !is null);
    }

    int FindValidOverlay() {
        CGameCtnApp@ app = GetApp();
        if (app is null || app.Viewport is null) return -1;
        CDx11Viewport@ viewport = cast<CDx11Viewport>(app.Viewport);
        for (uint i = 0; i < viewport.Overlays.Length; i++) {
            CHmsZoneOverlay@ overlay = cast<CHmsZoneOverlay>(viewport.Overlays[i]);
            if (overlay is null || overlay.UserData is null) continue;
            CSceneSector@ userData = cast<CSceneSector>(overlay.UserData);
            if (userData is null || userData.Scene is null) continue;
            CScene2d@ scene = cast<CScene2d>(userData.Scene);
            if (scene.Mobils.Length == 0 || scene.Mobils[0] is null) continue;
            CControlFrameStyled@ interfaceRootStyled = cast<CControlFrameStyled>(scene.Mobils[0]);
            if (interfaceRootStyled is null || interfaceRootStyled.Childs.Length == 0 || interfaceRootStyled.Childs[0] is null) continue;
            return i;
        }
        return -1;
    }

    CControlFrame@ GetRecordsWidget_FullWidgetUI() {
        int overlayIndex = FindValidOverlay();
        if (overlayIndex == -1) return null;
        CGameCtnApp@ app = GetApp();
        CDx11Viewport@ viewport = cast<CDx11Viewport>(app.Viewport);
        CHmsZoneOverlay@ overlay = cast<CHmsZoneOverlay>(viewport.Overlays[overlayIndex]);
        if (overlay is null || overlay.UserData is null) return null;
        CSceneSector@ userData = cast<CSceneSector>(overlay.UserData);
        if (userData is null || userData.Scene is null) return null;
        CScene2d@ scene = cast<CScene2d>(userData.Scene);
        if (scene.Mobils.Length == 0 || scene.Mobils[0] is null) return null;
        CControlFrameStyled@ interfaceRootStyled = cast<CControlFrameStyled>(scene.Mobils[0]);
        if (interfaceRootStyled is null || interfaceRootStyled.Childs.Length == 0 || interfaceRootStyled.Childs[0] is null) return null;
        CControlFrame@ interfaceRoot = cast<CControlFrame>(interfaceRootStyled);
        if (interfaceRoot is null) return null;

        for (uint i = 0; i < g_candidateChains.Length; i++) {
            CControlFrame@ fullWidget = TraverseWidgetChain(interfaceRoot, g_candidateChains[i]);
            if (fullWidget !is null) return fullWidget;
            
            if (g_candidateChains[i].Length > 3) {
                int original = g_candidateChains[i][3];
                for (int delta = -3; delta <= 3; delta++) {
                    if (delta == 0) continue;
                    array<int> newChain = g_candidateChains[i];
                    newChain[3] = original + delta;
                    CControlFrame@ testWidget = TraverseWidgetChain(interfaceRoot, newChain);
                    if (testWidget !is null) return testWidget;
                }
            }
        }
        return null;
    }

    CControlFrame@ GetRecordsWidget_RecordsWidgetUI(CControlFrame@ fullWidget) {
        for (uint i = 0; i < g_recordsCandidateChains.Length; i++) {
            CControlFrame@ recordsWidget = TraverseWidgetChain(fullWidget, g_recordsCandidateChains[i]);
            if (recordsWidget !is null) return recordsWidget;
        }
        return null;
    }

    CControlFrame@ GetRecordsWidget_PlayerUI(CControlFrame@ fullWidget, string _playerName = "") {
        CControlFrame@ recordsWidget = GetRecordsWidget_RecordsWidgetUI(fullWidget);
        if (recordsWidget is null) { log("WARNING! recordsWidget retured null!", LogLevel::Critical, 98, "FindValidOverlay"); }
        if (recordsWidget is null) return CControlFrame();

        array<CControlFrame@> recordsWidgets;
        if (recordsWidgets is null) return CControlFrame();
        for (uint i = 0; i < recordsWidget.Childs.Length; i++) {
            if (recordsWidget.Childs[i] is null) continue;
            recordsWidgets.InsertLast(cast<CControlFrame>(recordsWidget.Childs[i]));
        }
        string targetName = _playerName;
        if (targetName == "") targetName = GetApp().LocalPlayerInfo.Name;

        for (uint i = 0; i < recordsWidgets.Length; i++) {
            if (recordsWidgets[i].Childs.Length < 7) continue;
            CControlFrame@ chain1 = cast<CControlFrame>(recordsWidgets[i].Childs[6]);
            if (chain1 is null || chain1.Childs.Length < 1) continue;
            CControlFrame@ chain2 = cast<CControlFrame>(chain1.Childs[0]);
            if (chain2 is null || chain2.Childs.Length < 1) continue;
            CControlFrame@ chain3 = cast<CControlFrame>(chain2.Childs[0]);
            if (chain3 is null || chain3.Childs.Length < 2) continue;
            CControlLabel@ nameLabel = cast<CControlLabel>(chain3.Childs[1]);
            if (nameLabel is null) continue;
            if (nameLabel.Label == targetName)
                return recordsWidgets[i];
        }
        return CControlFrame();
    }

    int GetRecordsWidget_PlayerUIPB(CControlFrame@ fullWidget = GetRecordsWidget_FullWidgetUI(), const string &in playerName = "") {
        CControlFrame@ playerWidget = GetRecordsWidget_PlayerUI(fullWidget, playerName);
        if (playerWidget is null) return -1;
        if (playerWidget.Childs.Length < 8) return -1;
        CControlLabel@ timeLabel = cast<CControlLabel>(playerWidget.Childs[7]);
        if (timeLabel is null) return -1;
        return TimeStringToMilliseconds(timeLabel.Label);
    }
}