namespace Loader {
    void UnloadPBGhost_GhostClipsMgr() {
        auto mgr = GhostClipsMgr::Get(GetApp());
        if (mgr is null) return;

        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        if (ps is null) throw("null playground script");

        for (int i = int(mgr.Ghosts.Length) - 1; i >= 0; i--) {
            string gName = mgr.Ghosts[i].GhostModel.GhostNickname;
            if (gName.ToLower().Contains("personal best")) {
                auto id = GhostClipsMgr::GetInstanceIdAtIx(mgr, uint(i));
                ps.GhostMgr.Ghost_Remove(MwId(id));
                log("Removed ghost: " + gName, LogLevel::Info, 14, "UnloadPBGhost_GhostClipsMgr");
            }
        }
    }

    void CullPBsWithSameTime() {
        auto mgr = GhostClipsMgr::Get(GetApp());
        if (mgr is null) return;

        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        if (ps is null) return;

        array<uint> times;
        for (uint i = 0; i < mgr.Ghosts.Length; i++) {
            string gName = mgr.Ghosts[i].GhostModel.GhostNickname;
            if (gName.ToLower().Contains("personal best")) {
                auto time = mgr.Ghosts[i].GhostModel.RaceTime;
                if (times.Find(time) == -1) {
                    times.InsertLast(time);
                }
            }
        }

        for (uint i = 0; i < times.Length; i++) {
            array<uint> indexes;
            for (uint j = 0; j < mgr.Ghosts.Length; j++) {
                string gName = mgr.Ghosts[j].GhostModel.GhostNickname;
                if (gName.ToLower().Contains("personal best")) {
                    auto time = mgr.Ghosts[j].GhostModel.RaceTime;
                    if (time == times[i]) {
                        indexes.InsertLast(j);
                    }
                }
            }

            if (indexes.Length > 1) {
                for (uint j = 1; j < indexes.Length; j++) {
                    auto id = GhostClipsMgr::GetInstanceIdAtIx(mgr, indexes[j]);
                    ps.GhostMgr.Ghost_Remove(MwId(id));
                    log("Removed ghost: " + mgr.Ghosts[indexes[j]].GhostModel.GhostNickname, LogLevel::Info, 53, "CullPBsWithSameTime");
                }
            }
        }
    }

    void UnloadPBGhost() {
        UnloadPBGhost_GhostClipsMgr();

        if (_Game::IsPlayingLocal()) {
            UnloadPBGhost_LocalPBGhosts();
            return;
        }
        if (_Game::IsPlayingOnServer()) {
            UnloadPBGhost_ServerToggle();
            return;
        }
    }

    // Seems like 'clips' removes everything, so this doesn't really do much now :xdd:
    void UnloadPBGhost_LocalPBGhosts() {
        SaveLocalPBsUntillNextMapForEasyLoading();

        UnloadPBGhost_CGameDataFileManagerScript();
        UnloadPBGhost_CSmArenaRulesMode();
    }

    void UnloadPBGhost_CGameDataFileManagerScript() {
        CTrackMania@ app = cast<CTrackMania>(GetApp());
        if (app is null) return;
        CTrackManiaNetwork@ net = cast<CTrackManiaNetwork>(app.Network);
        if (net is null) return;
        CGameManiaAppPlayground@ cmap = cast<CGameManiaAppPlayground>(net.ClientManiaAppPlayground);
        if (cmap is null) return;
        CGameDataFileManagerScript@ dfm = cast<CGameDataFileManagerScript>(cmap.DataFileMgr);
        if (dfm is null) return;

        for (uint i = 0; i < dfm.Ghosts.Length; i++) {
            CGameGhostScript@ ghost = cast<CGameGhostScript>(dfm.Ghosts[i]);
            if (ghost.IdName.ToLower().Contains("personal best")) {
                dfm.Ghost_Release(ghost.Id);
            }
        }
    }

    void UnloadPBGhost_CSmArenaRulesMode() {
        CTrackMania@ app = cast<CTrackMania>(GetApp());
        if (app is null) return;
        CSmArenaRulesMode@ playgroundScript = cast<CSmArenaRulesMode>(app.PlaygroundScript);
        if (playgroundScript is null) return;
        CGameDataFileManagerScript@ dataFileMgr = cast<CGameDataFileManagerScript>(playgroundScript.DataFileMgr);
        if (dataFileMgr is null) return;

        if (GetApp().PlaygroundScript is null) return;

        auto gm = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript).GhostMgr;
        for (uint i = 0; i < dataFileMgr.Ghosts.Length; i++) {
            CGameGhostScript@ ghost = cast<CGameGhostScript>(dataFileMgr.Ghosts[i]);
            if (ghost.IdName.ToLower().Contains("personal best")) {
                gm.Ghost_Remove(ghost.Id);
            }
        }
    }


    void UnloadPBGhost_ServerToggle() {
        if (isLeacerboardPBVisible) { ToggleLeaderboardPB(); }
        else { log("Attempted to remove leaderboard PB but it was already hidden.", LogLevel::Notice, 120, "UnloadPBGhost_ServerToggle"); }
    }
}