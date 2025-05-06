namespace Loader {

    bool _IsPB(const string &in name) { return name.ToLower().Contains("personal best"); }
    bool _IsPluginGhost(const string &in nickname) { return nickname.Contains("$g$h$o$s$t$"); }


    enum PBGhostSource { Clips, Dfm, Arena }

    string _SrcStr(PBGhostSource s) {
        switch (s) {
            case PBGhostSource::Clips:  return "Clips";
            case PBGhostSource::Dfm:    return "DFM";
            case PBGhostSource::Arena:  return "Arena";
        }
        return "?";
    }


    class PBGhost {
        PBGhostSource src;
        uint   time;
        string name;
        MwId   id;
        string trigram;

        bool IsPlugin() { return _IsPluginGhost(name); }

        void Remove(const string &in why, uint msgId) {
            auto mode = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
            if (mode !is null) mode.GhostMgr.Ghost_Remove(id);

            auto dfmC = _GetClientDFM(); if (dfmC !is null) dfmC.Ghost_Release(id);
            auto dfmA = cast<CGameDataFileManagerScript>(mode !is null ? mode.DataFileMgr : null);
            if (dfmA !is null) dfmA.Ghost_Release(id);

            log(why + " | src=" + _SrcStr(src) + " | " + time + " ms | " + name, LogLevel::Debug, 36, "Remove");
        }
    }

    funcdef void PBGhostVisitor(PBGhost@ g);

    void _ForEachPBGhost(PBGhostVisitor@ cb) {
        auto mgr  = GhostClipsMgr::Get(GetApp());
        auto dfmC = _GetClientDFM();
        auto mode = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        auto dfmA = cast<CGameDataFileManagerScript>(mode !is null ? mode.DataFileMgr : null);

        if (mgr !is null) {
            for (int i = int(mgr.Ghosts.Length) - 1; i >= 0; --i) {
                auto gg = mgr.Ghosts[i];
                if (!_IsPB(gg.GhostModel.GhostNickname)) continue;

                PBGhost g;
                g.src     = PBGhostSource::Clips;
                g.time    = gg.GhostModel.RaceTime;
                g.name    = gg.GhostModel.GhostNickname;
                g.trigram = gg.GhostModel.GhostTrigram;
                g.id      = MwId(GhostClipsMgr::GetInstanceIdAtIx(mgr, uint(i)));
                cb(g);
            }
        }

        if (dfmC !is null) {
            for (int i = int(dfmC.Ghosts.Length) - 1; i >= 0; --i) {
                auto gg = cast<CGameGhostScript>(dfmC.Ghosts[i]);
                if (gg is null || !_IsPB(gg.IdName)) continue;

                PBGhost g;
                g.src     = PBGhostSource::Dfm;
                g.time    = gg.Result.Time;
                g.name    = gg.Nickname;
                g.trigram = gg.Trigram;
                g.id      = gg.Id;
                cb(g);
            }
        }

        if (dfmA !is null) {
            for (int i = int(dfmA.Ghosts.Length) - 1; i >= 0; --i) {
                auto gg = cast<CGameGhostScript>(dfmA.Ghosts[i]);
                if (gg is null || !_IsPB(gg.IdName)) continue;

                PBGhost g;
                g.src     = PBGhostSource::Arena;
                g.time    = gg.Result.Time;
                g.name    = gg.Nickname;
                g.trigram = gg.Trigram;
                g.id      = gg.Id;
                cb(g);
            }
        }
    }

    CGameDataFileManagerScript@ _GetClientDFM() {
        auto app  = cast<CTrackMania>(GetApp());
        auto net  = cast<CTrackManiaNetwork>(app !is null ? app.Network : null);
        auto cmap = cast<CGameManiaAppPlayground>(net !is null ? net.ClientManiaAppPlayground : null);
        return cast<CGameDataFileManagerScript>(cmap !is null ? cmap.DataFileMgr : null);
    }


    class CDupResolver {
        array<uint> times;
        array<PBGhost@> kept;
        uint removed = 0;

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
                prev.Remove("Duplicate PB removed (replaced by preferred)", 601);
                kept[idx] = g;
                removed++;
            } else {
                g.Remove("Duplicate PB removed", 602);
                removed++;
            }
        }
    }

    void CullPBsWithTheSameTime() {
        CDupResolver r;
        _ForEachPBGhost(PBGhostVisitor(@r.Visit));
        log("Duplicate-time cull done. Removed=" + r.removed, LogLevel::Debug, 136, "CullPBsWithTheSameTime");
    }

    class CFastestFinder {
        uint fastest = uint(-1);
        uint total   = 0;
        void Visit(PBGhost@ g) { total++; if (g.time < fastest) fastest = g.time; }
    }

    class CSlowerRemover {
        uint limit; uint removed = 0;
        CSlowerRemover(uint l) { limit = l; }
        void Visit(PBGhost@ g) {
            if (g.time > limit) {
                g.Remove("Slower-than-fastest PB removed", 603);
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
        log("Slower-than-fastest cull done. Fastest=" + f.fastest + " ms, Removed=" + rm.removed, LogLevel::Debug, 163, "CullPBsSlowerThanFastest");
    }

    class CRemoveAll { void Visit(PBGhost@ g) { g.Remove("UnloadPBGhost", 605); } }

    void UnloadPBGhost() {
        CRemoveAll all;
        _ForEachPBGhost(PBGhostVisitor(@all.Visit));

        if (_Game::IsPlayingOnServer()) {
            if (isLeacerboardPBVisible) {
                ToggleLeaderboardPB();
            } else {
                log("Attempted to remove leaderboard PB but it was already hidden.", LogLevel::Notice, 176, "UnloadPBGhost");
            }
        }
    }

}
