namespace Loader::PBMonitor {

    bool   g_running   = false;
    string g_mapUid    = "";
    uint64 g_lastCheck = 0;

    void Start() {
        if (!g_running) {
            g_running = true;
            startnew(MainLoop);
        }
    }

    void Stop() {
        g_running = false;
    }

    void MainLoop() {
        while (g_running) {
            if (Time::Now - g_lastCheck >= 500) {
                g_lastCheck = Time::Now;
                _Tick();
            }
            yield();
        }
    }

    void _Tick() {
        CGameCtnApp@ app = GetApp();
        if (app.RootMap is null) return;

        _DeduplicatePluginGhosts();

        string curUid = app.RootMap.MapInfo.MapUid;
        if (curUid != g_mapUid) { g_mapUid = curUid; return; }


        uint storedFastest = _FastestStoredTime();    // from DB
        uint gameFastest   = _BestGameTime();         // loaded by Nadeo
        uint loadedPlugin  = _BestLoadedPluginTime(); // in‑memory plugin ghost

        if (storedFastest < 0xFFFFFFFF
         && (loadedPlugin == 0xFFFFFFFF || storedFastest < loadedPlugin)
         && (gameFastest  == 0xFFFFFFFF || storedFastest < gameFastest)) {
            _EnsurePluginGhostLoaded(storedFastest);
            return;
        }

        if (gameFastest == 0xFFFFFFFF && loadedPlugin == 0xFFFFFFFF) {
            int hinted = _HintedPB();
            if (hinted > 0 && !Loader::Remote::AlreadyAskedLB(g_mapUid)) {
                Loader::Remote::MarkAskedLB(g_mapUid);
                Loader::Remote::DownloadPBFromLeaderboard(g_mapUid);
            }
            return;
        }

        if (loadedPlugin < gameFastest) {
            if (HideSlowerGamePB) { _RemoveSlowerGameGhosts(loadedPlugin); }
            return;
        }

        if (loadedPlugin == gameFastest) { UnloadPluginGhosts(); return; }

        if (gameFastest < storedFastest) {
            UnloadPluginGhosts();
            _CacheGamePB(gameFastest);
            return;
        }
    }

    void _CacheGamePB(uint targetTime) {
        CGameCtnApp@ app = GetApp(); // if (app.Editor !is null) return; // debating whether or not to cache PBs in editor mode xdd
        CGameCtnNetwork@ net = cast<CGameCtnNetwork>(app.Network); if (net is null) return;
        CGameManiaAppPlayground@ cmap = cast<CGameManiaAppPlayground>(net.ClientManiaAppPlayground); if (cmap is null) return;
        CGameDataFileManagerScript@ dfm = cast<CGameDataFileManagerScript>(cmap.DataFileMgr); if (dfm is null) return;

        CGameGhostScript@ ghost = null;
        for (uint i = 0; i < dfm.Ghosts.Length; ++i) {
            CGameGhostScript@ g = cast<CGameGhostScript>(dfm.Ghosts[i]);
            if (g is null) continue;

            if (g.Nickname != GetApp().LocalPlayerInfo.Name) continue;
            if (g.Result.Time != targetTime) continue;

            @ghost = g;
            break;
        }
        if (ghost is null) return;

        log("Caching PB ghost for " + g_mapUid + " with time " + targetTime + " ms | nickname: " + ghost.Nickname + " | trigram: " + ghost.Trigram + " | id: " + ghost.IdName + ")", LogLevel::Info, 91, "_CacheGamePB", "", "\\$f80");

        string baseDir = IO::FromUserGameFolder("Replays_Offload/zzAutoEnablePBGhost/improvements/");
        IO::CreateFolder(baseDir);

        string fileName = g_mapUid + "_" + targetTime + ".Replay.Gbx";
        string fullPath = baseDir + fileName;

        string  origIdName   = ghost.IdName;
        string  origNick     = ghost.Nickname;
        string  origTrigram  = ghost.Trigram;

        Loader::GhostIO::DecoratePB(ghost);

        dfm.Replay_Save(fullPath, app.RootMap, ghost);
        yield();

        ghost.IdName   = origIdName;
        ghost.Nickname = origNick;
        ghost.Trigram  = origTrigram;

        Database::AddRecordFromLocalFile(fullPath, targetTime, g_mapUid);

        log("Cached new PB replay to " + fullPath, LogLevel::Info, 114, "_CacheGamePB", "", "\\$f80");
    }

    void _DeduplicatePluginGhosts() {
        NGameGhostClips_SMgr@ mgr = GhostClipsMgr::Get(GetApp());
        if (mgr is null) return;

        CGameGhostMgrScript@ gm = GhostMgrHelper::Get();
        if (gm is null) return;

        uint fastestTime   = 0xFFFFFFFF;
        uint fastestInstId = uint(-1);
        array<uint> pluginInstIds;

        for (uint i = 0; i < mgr.Ghosts.Length; ++i) {
            auto clip = mgr.Ghosts[i]; if (clip is null) continue;
            CGameCtnGhost@ model = clip.GhostModel; if (model is null) continue;

            if (!_IsPluginGhost(model.GhostNickname)) continue;

            uint instId = GhostClipsMgr::GetInstanceIdAtIx(mgr, i);
            pluginInstIds.InsertLast(instId);

            if (model.RaceTime < fastestTime) {
                fastestTime   = model.RaceTime;
                fastestInstId = instId;
            }
        }

        for (uint j = 0; j < pluginInstIds.Length; ++j) {
            if (pluginInstIds[j] != fastestInstId) {
                gm.Ghost_Remove(MwId(pluginInstIds[j]));
            }
        }
    }

    uint _FastestStoredTime() {
        auto reps = Database::GetReplays(g_mapUid);
        uint best = 0xFFFFFFFF;

        for (uint i = 0; i < reps.Length; ++i) {
            if (reps[i].BestTime < best) best = reps[i].BestTime;
        }
        return best;
    }

        uint _BestLoadedPluginTime() {
            auto list = Loader::GhostRegistry::All();
            uint best = 0xFFFFFFFF;

            for (uint i = 0; i < list.Length; ++i) {
                if (list[i].durationMs < best) best = list[i].durationMs;
            }
            if (best < 0xFFFFFFFF) return best;

            NGameGhostClips_SMgr@ mgr = GhostClipsMgr::Get(GetApp());
            if (mgr is null) return 0xFFFFFFFF;

            for (uint i = 0; i < mgr.Ghosts.Length; ++i) {
                auto clip = mgr.Ghosts[i]; if (clip is null) continue;
                CGameCtnGhost@ model = clip.GhostModel; if (model is null) continue;

                if (!_IsPluginGhost(model.GhostNickname)) continue;
                if (model.RaceTime < best) best = model.RaceTime;
            }
            return best;
        }


    uint _BestGameTime() {
        NGameGhostClips_SMgr@ mgr = GhostClipsMgr::Get(GetApp());
        if (mgr is null) return 0xFFFFFFFF;

        uint best = 0xFFFFFFFF;

        for (uint i = 0; i < mgr.Ghosts.Length; ++i) {
            auto clip = mgr.Ghosts[i]; if (clip is null) continue;

            CGameCtnGhost@ model = clip.GhostModel; if (model is null) continue;

            if (_IsPluginGhost(model.GhostNickname)) continue;
            if (!_IsGameGhost(model.GhostNickname))  continue;

            if (model.RaceTime < best) best = model.RaceTime;
        }
        return best;
    }

    bool _IsPluginGhost(const string &in nick) { return nick.Contains("$g$h$o$s$t$"); }
    bool _IsGameGhost(const string &in nick) { return nick.StartsWith("") || nick.StartsWith("$7FA"); }

    int _HintedPB() {
        int v1 = _Game::CurrentPersonalBest(g_mapUid);
        int v2 = UINav::WidgetPlayerPB();
        if (v1 > 0 && v2 > 0) return Math::Min(v1, v2);
        if (v1 > 0) return v1;
        if (v2 > 0) return v2;
        return -1;
    }

    void _EnsurePluginGhostLoaded(uint timeMs) {
        auto list = Loader::GhostRegistry::All();
        for (uint i = 0; i < list.Length; ++i) {
            if (list[i].durationMs == timeMs) return;
        }

        auto reps = Database::GetReplays(g_mapUid);
        for (uint i = 0; i < reps.Length; ++i) {
            if (reps[i].BestTime == timeMs) {
                GhostIO::Load(reps[i]);
                return;
            }
        }
    }

    void UnloadPluginGhosts() {
        Loader::Unloader::RemoveAll();

        NGameGhostClips_SMgr@ mgr = GhostClipsMgr::Get(GetApp());
        if (mgr is null) return;

        CGameGhostMgrScript@ gm = GhostMgrHelper::Get();
        if (gm is null) return;

        for (uint i = 0; i < mgr.Ghosts.Length; ++i) {
            auto clip = mgr.Ghosts[i]; if (clip is null) continue;
            CGameCtnGhost@ model = clip.GhostModel; if (model is null) continue;

            if (!_IsPluginGhost(model.GhostNickname)) continue;

            uint instId = GhostClipsMgr::GetInstanceIdAtIx(mgr, i);
            gm.Ghost_Remove(MwId(instId));
        }
    }


    void _RemoveSlowerGameGhosts(uint fastestAllowed) {
        NGameGhostClips_SMgr@ mgr = GhostClipsMgr::Get(GetApp());
        if (mgr is null) return;

        CGameGhostMgrScript@ gm = GhostMgrHelper::Get();
        if (gm is null) return;

        for (uint i = 0; i < mgr.Ghosts.Length; ++i) {
            auto clip = mgr.Ghosts[i]; if (clip is null) continue;

            CGameCtnGhost@ model = clip.GhostModel; if (model is null) continue;
            if (_IsPluginGhost(model.GhostNickname)) continue;
            if (!_IsGameGhost(model.GhostNickname))  continue;

            if (model.RaceTime > fastestAllowed) {
                uint instId = GhostClipsMgr::GetInstanceIdAtIx(mgr, i);
                gm.Ghost_Remove(MwId(instId));
            }
        }
    }

    const bool HideSlowerGamePB = true;
}
