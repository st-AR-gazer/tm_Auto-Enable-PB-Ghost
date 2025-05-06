namespace Loader {
    NGameGhostClips_SMgr@ ghostClipMgr;

    void LoadPB() {
        if (!_Game::IsPlayingMap()) return;

        uint startTime = Time::Now;
        while (_Game::CurrentPersonalBest(CurrentMapUID) == -1) {
            if (Time::Now - startTime > 8000) { break; }
            yield();
        }

        log("Attempting to load PB ghosts.", LogLevel::Debug, 13, "LoadPB");

        if (_Game::IsPlayingLocal()) {
            while (GetRecordsWidget_FullWidgetUI() is null) { yield(); }
            if (IsFastestPBLoaded()) { log("Fastest PB already loaded", LogLevel::Info, 17, "LoadPB"); CullPBs(); return; }
            
            LoadPBFromDB();
            CullPBs();
            return;
        }
        if (_Game::IsPlayingOnServer()) {
            while (GetRecordsWidget_FullWidgetUI() is null) { yield(); }

            TogglePBFromMLHook();
            return;
        }
    }

    void HidePB() {
        UnloadPBGhost();
    }

    void CullPBs() {
        auto mode = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        auto dfmA = cast<CGameDataFileManagerScript>(mode !is null ? mode.DataFileMgr : null);
        uint startTimeGhosts = Time::Now;
        while (dfmA.Ghosts.Length == 0 && Time::Now - startTimeGhosts < 1500) { yield(); }
        yield();
        CullPBsSlowerThanFastest();
        yield();
        CullPBsWithTheSameTime();
    }
}
