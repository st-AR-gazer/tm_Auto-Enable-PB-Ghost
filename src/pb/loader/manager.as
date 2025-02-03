namespace Loader {
    NGameGhostClips_SMgr@ ghostClipMgr;

    void LoadPB() {
        if (!_Game::IsPlayingMap()) return;

        if (_Game::IsPlayingLocal()) {
            if (IsPBLoaded()) { log("PB already loaded", LogLevel::Info, 0, "LoadPB"); return; }
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
