namespace Loader {
    bool _IsPB(const string &in name)          { return Loader::IsPB(name); }
    bool _IsPluginGhost(const string &in nick) { return Loader::IsPluginGhost(nick); }

    funcdef void PBGhostVisitor(PBGhost@ g);

    void _ForEachPBGhost(PBGhostVisitor@ cb) {
        auto mgr  = GhostClipsMgr::Get(GetApp());
        auto dfmC = _GetClientDFM();
        auto mode = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        auto dfmA = cast<CGameDataFileManagerScript>(mode !is null ? mode.DataFileMgr : null);

        // -------------- Clips --------------
        if (mgr !is null) {
            for (int i = int(mgr.Ghosts.Length) - 1; i >= 0; --i) {
                auto gg = mgr.Ghosts[i];
                if (!_IsPB(gg.GhostModel.GhostNickname)) continue;

                PBGhost@ g = PBGhost(
                    PBGhostSource::Clips,
                    gg.GhostModel.RaceTime,
                    gg.GhostModel.GhostNickname,
                    MwId(GhostClipsMgr::GetInstanceIdAtIx(mgr, uint(i))),
                    "",
                    gg.GhostModel.GhostTrigram
                );
                cb(g);
            }
        }

        // -------------- DFM (client) --------------
        if (dfmC !is null) {
            for (int i = int(dfmC.Ghosts.Length) - 1; i >= 0; --i) {
                auto gg = cast<CGameGhostScript>(dfmC.Ghosts[i]);
                if (gg is null || !_IsPB(gg.IdName)) continue;

                PBGhost@ g = PBGhost(
                    PBGhostSource::DfmClient,
                    gg.Result.Time,
                    gg.Nickname,
                    gg.Id,
                    "",
                    gg.Trigram
                );
                cb(g);
            }
        }

        // -------------- DFM (arena) --------------
        if (dfmA !is null) {
            for (int i = int(dfmA.Ghosts.Length) - 1; i >= 0; --i) {
                auto gg = cast<CGameGhostScript>(dfmA.Ghosts[i]);
                if (gg is null || !_IsPB(gg.IdName)) continue;

                PBGhost@ g = PBGhost(
                    PBGhostSource::DfmArena,
                    gg.Result.Time,
                    gg.Nickname,
                    gg.Id,
                    "",
                    gg.Trigram
                );
                cb(g);
            }
        }
    }

    CGameDataFileManagerScript@ _GetClientDFM() {
        auto app  = cast<CTrackMania>(GetApp());
        auto net  = cast<CTrackManiaNetwork>(app !is null ? app.Network : null);
        auto cmap = cast<CGameManiaAppPlayground>( net !is null ? net.ClientManiaAppPlayground : null);
        return cast<CGameDataFileManagerScript>( cmap !is null ? cmap.DataFileMgr : null);
    }

    class CDupResolver {
        array<uint>      times;
        array<PBGhost@>  kept;
        uint             removed = 0;

        bool _PreferSecond(PBGhost@ a, PBGhost@ b) {
            if (!b.IsPlugin() && a.IsPlugin()) return true;
            if (!a.IsPlugin() && b.IsPlugin()) return false;
            return false;
        }

        void Visit(PBGhost@ g) {
            int idx = times.Find(g.time);
            if (idx == -1) {
                times.InsertLast(g.time);
                kept.InsertLast(g);
                return;
            }

            PBGhost@ prev = kept[idx];
            if (_PreferSecond(prev, g)) {
                _Remove(prev, "Duplicate PB removed", 601);
                kept[idx] = g;
                removed++;
            } else {
                _Remove(g, "Duplicate PB removed", 602);
                removed++;
            }
        }

        void _Remove(PBGhost@ g, const string &in why, uint msgId) {
            auto mode = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
            if (mode !is null) mode.GhostMgr.Ghost_Remove(g.id);

            auto dfmC = _GetClientDFM(); if (dfmC !is null) dfmC.Ghost_Release(g.id);
            auto dfmA = cast<CGameDataFileManagerScript>(mode !is null ? mode.DataFileMgr : null);
            if (dfmA !is null) dfmA.Ghost_Release(g.id);

            log(why + " | src=" + SrcStr(g.src) + " | " + g.time + " ms | " + g.name, LogLevel::Debug, 113, "_Remove");
        }
    }

    void CullPBsWithTheSameTime() {
        CDupResolver r;
        _ForEachPBGhost(PBGhostVisitor(@r.Visit));
        log("Duplicate-time cull done. Removed=" + r.removed, LogLevel::Debug, 120, "CullPBsWithTheSameTime");
    }

    class CFastestFinder {
        uint fastest = uint(-1);
        uint total   = 0;
        void Visit(PBGhost@ g) { total++; if (g.time < fastest) fastest = g.time; }
    }

    class CSlowerRemover {
        uint limit;
        uint removed = 0;
        CSlowerRemover(uint l) { limit = l; }

        void Visit(PBGhost@ g) {
            if (g.time > limit) {
                auto mode = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
                if (mode !is null) mode.GhostMgr.Ghost_Remove(g.id);

                auto dfmC = _GetClientDFM(); if (dfmC !is null) dfmC.Ghost_Release(g.id);
                auto dfmA = cast<CGameDataFileManagerScript>(mode !is null ? mode.DataFileMgr : null);
                if (dfmA !is null) dfmA.Ghost_Release(g.id);

                log("Slower-than-fastest PB removed | " + g.time + " ms | " + g.name, LogLevel::Debug, 143, "Visit");
                removed++;
            }
        }
    }

    void CullPBsSlowerThanFastest() {
        CFastestFinder f;
        _ForEachPBGhost(PBGhostVisitor(@f.Visit));
        if (f.total <= 1) return;

        CSlowerRemover rm(f.fastest);
        _ForEachPBGhost(PBGhostVisitor(@rm.Visit));
        log("Slower-than-fastest cull done. Fastest=" + f.fastest + " ms, Removed=" + rm.removed, LogLevel::Debug, 156, "CullPBsSlowerThanFastest");
    }

    class CRemoveAll {
        void Visit(PBGhost@ g) {
            auto mode = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
            if (mode !is null) mode.GhostMgr.Ghost_Remove(g.id);

            auto dfmC = _GetClientDFM(); if (dfmC !is null) dfmC.Ghost_Release(g.id);
            auto dfmA = cast<CGameDataFileManagerScript>(mode !is null ? mode.DataFileMgr : null);
            if (dfmA !is null) dfmA.Ghost_Release(g.id);

            log("UnloadPBGhost | src=" + SrcStr(g.src) + " | " + g.time + " ms | " + g.name, LogLevel::Debug, 168, "Visit");
        }
    }

    void UnloadPBGhost() {
        CRemoveAll all;
        _ForEachPBGhost(PBGhostVisitor(@all.Visit));

        if (_Game::IsPlayingOnServer()) {
            if (Loader::Leaderboard::isLeaderboardPBVisible) {
                Loader::Leaderboard::ToggleLeaderboardPB();
            } else {
                log("Attempted to remove leaderboard PB but it was already hidden.", LogLevel::Notice, 180, "UnloadPBGhost");
            }
        }
    }

    void UnloadPluginPBGhost() {
        
    }
}
