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
            if (IsFastestPBLoaded()) {  log("Fastest PB already loaded", LogLevel::Info, 16, "LoadPB");  return;  }
            while (GetRecordsWidget_FullWidgetUI() is null) { yield(); }
            
            HidePB();
            LoadPBFromDB();
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
}
