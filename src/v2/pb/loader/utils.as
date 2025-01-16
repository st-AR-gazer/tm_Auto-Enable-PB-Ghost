namespace Loader {

    // Is Loaded
    bool IsPBLoaded() {
        return IsClipPBLoaded() || IsLocalPBLoaded();
    }
    bool IsClipPBLoaded() {
        if (ghostClipMgr is null) return false;
        CGameCtnMediaClipPlayer@ pbClipPlayer = GhostClipsMgr::GetPBClipPlayer(ghostClipMgr);
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

    // Remove
    void RemovePBGhosts() {
             if (_Game::IsPlayingLocal())    { RemoveLocalPBGhosts(); }
        else if (_Game::IsPlayingOnServer()) { RemoveServerPBGhost(); }
    }
    void RemoveServerPBGhost() {
        if (isLeacerboardPBVisible) { ToggleLeaderboardPB(); }
        else { log("Attempted to remove leaderboard PB but it was already hidden.", LogLevel::Notice); }
    }
    void RemoveLocalPBGhosts() {
        auto dataFileMgr = GetApp().Network.ClientManiaAppPlayground.DataFileMgr;
        auto newGhosts = dataFileMgr.Ghosts;

        for (uint i = 0; i < newGhosts.Length; i++) {
            CGameGhostScript@ ghost = cast<CGameGhostScript>(newGhosts[i]);
            if (ghost.IdName.ToLower().Contains("personal best")) {
                if (GetApp().PlaygroundScript is null) return;

                auto gm = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript).GhostMgr;
                gm.Ghost_Remove(ghost.Id);
                log("Record with the MwID of: " + ghost.Id.GetName() + " removed.", LogLevel::Info, 27, "RemoveInstanceRecord");
            }
        }
    }

    // Remove Slowest
    void RemoveSlowestPBGhost() {
        if (_Game::IsPlayingLocal()) {
            RemoveSlowestLocalPBGhost();
        } else if (_Game::IsPlayingOnServer()) {
            log("On a server ghosts can only be loaded through the Leaderboard widget, there isn't a 'slowest' pb ghost to remove, use 'RemoveServerPBGhost' for removing a server pb.", LogLevel::Warn);
        }
    }
    void RemoveSlowestLocalPBGhost() {
        auto dataFileMgr = GetApp().Network.ClientManiaAppPlayground.DataFileMgr;
        auto newGhosts = dataFileMgr.Ghosts;

        CGameGhostScript@ slowestGhost = null;
        for (uint i = 0; i < newGhosts.Length; i++) {
            CGameGhostScript@ ghost = cast<CGameGhostScript>(newGhosts[i]);
            if (ghost.IdName.ToLower().Contains("personal best")) {
                if (slowestGhost is null) {
                    @slowestGhost = ghost;
                } else {
                    if (ghost.Result.Time < slowestGhost.Result.Time) {
                        @slowestGhost = ghost;
                    }
                }
            }
        }

        if (slowestGhost is null) {
            log("No personal best ghosts found to remove.", LogLevel::Warn);
            return;
        }

        if (GetApp().PlaygroundScript is null) return;

        auto gm = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript).GhostMgr;
        gm.Ghost_Remove(slowestGhost.Id);
        log("Record with the MwID of: " + slowestGhost.Id.GetName() + " removed.", LogLevel::Info, 27, "RemoveInstanceRecord");
    }

    // Misc
    int TimeStringToMilliseconds(const string&in timeString) {
        string[] parts = timeString.Split(":");
        if (parts.Length != 2) return -1;

        string[] subParts = parts[1].Split(".");
        if (subParts.Length != 2) return -1;

        int minutes = Text::ParseInt(parts[0]);
        int seconds = Text::ParseInt(subParts[0]);
        int milliseconds = Text::ParseInt(subParts[1]);

        return (minutes * 60 * 1000) + (seconds * 1000) + milliseconds;
    }
}
