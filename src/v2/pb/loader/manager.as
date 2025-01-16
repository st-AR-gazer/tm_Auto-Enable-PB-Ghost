namespace Loader {
    NGameGhostClips_SMgr@ ghostClipMgr;

    void LoadPB() {
        if (!_Game::IsPlayingMap()) return;

        if (_Game::IsPlayingLocal()) {
            LoadPBFromDB();
            return;
        }
        if (_Game::IsPlayingOnServer()) {
            TogglePBFromMLHook();
            return;
        }
    }
}
