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

    void RemovePBs() {
        if (_Game::IsPlayingLocal()) {
            RemoveLocalPBGhosts();
            return;
        }
        if (_Game::IsPlayingOnServer()) {
            RemoveServerPBGhost();
            return;
        }
    }
}
