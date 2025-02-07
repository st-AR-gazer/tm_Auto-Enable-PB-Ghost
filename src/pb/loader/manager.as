namespace Loader {
    NGameGhostClips_SMgr@ ghostClipMgr;

    void LoadPB() {
        if (!_Game::IsPlayingMap()) return;

        if (_Game::IsPlayingLocal()) {
            if (IsFastestPBLoaded()) { 
                log("Fastest PB already loaded", LogLevel::Info, 9, "LoadPB"); 
                return; 
            }
            HidePB();
            
            while (GetRecordsList_RecordsWidgetUI() is null) { yield(); }

            LoadPBFromDB();
            return;
        }
        if (_Game::IsPlayingOnServer()) {
            TogglePBFromMLHook();
            return;
        }
    }

    void HidePB() {
        UnloadPBGhost();
    }
}
