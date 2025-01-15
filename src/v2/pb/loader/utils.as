namespace Loader {

    bool IsPBLoaded() {
        return IsClipPBLoaded() || IsLocalPBLoaded();
    }

    bool IsClipPBLoaded() {
        if (ghostMgr is null) return false;
        CGameCtnMediaClipPlayer@ pbClipPlayer = GhostClipsMgr::GetPBClipPlayer(ghostMgr);
        return pbClipPlayer !is null;
    }

    bool IsLocalPBLoaded() {
        auto net = cast<CGameCtnNetwork>(GetApp().Network);
        if (net is null) return false;
        auto cmap = cast<CGameManiaAppPlayground>(net.ClientManiaAppPlayground);
        if (cmap is null) return false;
        auto dfm = cmap.DataFileMgr;
        if (dfm is null) return false;
        
        for (uint i = 0; i < dfm.Ghosts.Length; i++) {
            if (dfm.Ghosts[i].IdName.ToLower().Contains("personal best")) {
                return true;
            }
        }
        return false;
    }
    
    void RemoveAllLoadedGhosts() {
        auto app = GetApp();
        if (app.Network.ClientManiaAppPlayground !is null) {
            app.Network.ClientManiaAppPlayground.DataFileMgr.Replay_();
            log("Loader::RemoveAllLoadedGhosts: Removed all loaded ghosts.", LogLevel::Info);
        } else {
            log("Loader::RemoveAllLoadedGhosts: Failed to remove ghosts: ClientManiaAppPlayground is null.", LogLevel::Error);
        }
    }

    void RemovePBGhosts() {
        log("Loader::RemovePBGhosts: Removed personal best ghosts.", LogLevel::Info);
    }

    void RemoveSlowestPBGhost() {
        log("Loader::RemoveSlowestPBGhost: Removed the slowest personal best ghost.", LogLevel::Info);
    }


}
