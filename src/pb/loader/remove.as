namespace Loader {

    bool _IsPB(const string &in name)          { return Loader::IsPB(name); }
    bool _IsPluginGhost(const string &in nick) { return Loader::IsPluginGhost(nick); }

    funcdef void PBGhostVisitor(PBGhost@ g);

    void _RemoveGhost(PBGhost@ g, const string &in why, uint msgId) {
        auto mode = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        if (mode !is null) mode.GhostMgr.Ghost_Remove(g.id);
        auto dfmC = _GetClientDFM(); if (dfmC !is null) dfmC.Ghost_Release(g.id);
        auto dfmA = cast<CGameDataFileManagerScript>(mode !is null ? mode.DataFileMgr : null);
        if (dfmA !is null) dfmA.Ghost_Release(g.id);
        log(why + " | src=" + SrcStr(g.src) + " | " + g.time + " ms | " + g.name, LogLevel::Debug, 14, "_RemoveGhost", "", "\\$f80");
    }

    void _DownloadPBForMap() {
        if (Loader::AlreadyAskedLB(CurrentMapUID)) return;
        Loader::MarkAskedLB(CurrentMapUID);

        startnew(CoroutineFunc(function() { Database::DownloadAndAddPBForCurrentMap(); }));
    }

    bool   _dlRequested = false;
    string _dlMapUid    = "";

    void ResetPBDownloadFlag() {
        _dlRequested = false;
        _dlMapUid    = CurrentMapUID;
    }

    void _ForEachPBGhost(PBGhostVisitor@ cb) {
        auto mgr  = GhostClipsMgr::Get(GetApp());
        auto dfmC = _GetClientDFM();
        auto mode = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        auto dfmA = cast<CGameDataFileManagerScript>(mode !is null ? mode.DataFileMgr : null);

        if (mgr !is null) {
            for (int i = int(mgr.Ghosts.Length) - 1; i >= 0; --i) {
                auto gg = mgr.Ghosts[i];
                if (!_IsPB(gg.GhostModel.GhostNickname)) continue;
                PBGhost@ g = PBGhost(PBGhostSource::Clips, gg.GhostModel.RaceTime, gg.GhostModel.GhostNickname,
                    MwId(GhostClipsMgr::GetInstanceIdAtIx(mgr, uint(i))), "", gg.GhostModel.GhostTrigram);
                cb(g);
            }
        }

        if (dfmC !is null) {
            for (int i = int(dfmC.Ghosts.Length) - 1; i >= 0; --i) {
                auto gg = cast<CGameGhostScript>(dfmC.Ghosts[i]);
                if (gg is null || !_IsPB(gg.IdName)) continue;
                PBGhost@ g = PBGhost(PBGhostSource::DfmClient, gg.Result.Time, gg.Nickname, gg.Id, "", gg.Trigram);
                cb(g);
            }
        }

        if (dfmA !is null) {
            for (int i = int(dfmA.Ghosts.Length) - 1; i >= 0; --i) {
                auto gg = cast<CGameGhostScript>(dfmA.Ghosts[i]);
                if (gg is null || !_IsPB(gg.IdName)) continue;
                PBGhost@ g = PBGhost(PBGhostSource::DfmArena, gg.Result.Time, gg.Nickname, gg.Id, "", gg.Trigram);
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
        array<uint>     times;
        array<PBGhost@> kept;
        uint            removed = 0;

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
                _RemoveGhost(prev, "Duplicate PB removed", 601);
                kept[idx] = g;
                removed++;
            } else {
                _RemoveGhost(g, "Duplicate PB removed", 602);
                removed++;
            }
        }
    }

    void CullPBsWithTheSameTime() {
        CDupResolver r;
        _ForEachPBGhost(PBGhostVisitor(@r.Visit));
        log("Duplicate-time cull done. Removed=" + r.removed, LogLevel::Debug, 107, "CullPBsWithTheSameTime", "", "\\$f80");
    }


    class CSlowerRemover {
        array<PBGhost@> all;
        void Visit(PBGhost@ g) { all.InsertLast(g); }

        void Execute() {
            if (all.Length <= 1) return;
            PBGhost@ fastest = all[0];
            PBGhost@ slowest = all[0];
            for (uint i = 1; i < all.Length; ++i) {
                if (all[i].time < fastest.time) @fastest = all[i];
                if (all[i].time > slowest.time) @slowest = all[i];
            }
            if (fastest.time == slowest.time) return;

            bool removedIsPlugin = slowest.IsPlugin();
            bool fastestIsPlugin = fastest.IsPlugin();
            if (removedIsPlugin && !fastestIsPlugin && slowest.time > fastest.time) {
                _RemoveGhost(slowest, "Slowest-time PB removed", 143);
                _DownloadPBForMap();
            } else if (slowest.time != fastest.time) {
                _RemoveGhost(slowest, "Slowest-time PB removed", 143);
            }
        }
    }

    void CullPBsSlowerThanFastest() {
        CSlowerRemover rm;
        _ForEachPBGhost(PBGhostVisitor(@rm.Visit));
        rm.Execute();
    }


    bool   _ensureTried = false;
    string _ensureMap   = "";

    void ResetEnsurePBFlag() {
        _ensureTried = false;
        _ensureMap   = CurrentMapUID;
    }

    class CCounter { uint count = 0; void Visit(PBGhost@ g) { count++; } }

    void EnsureOnePBPresent() {
        CCounter c;
        _ForEachPBGhost(PBGhostVisitor(@c.Visit));
        if (c.count > 0) return;

        if (_ensureTried && _ensureMap == CurrentMapUID) return;
        _ensureTried = true;
        _ensureMap   = CurrentMapUID;

        if      (_Game::IsPlayingLocal())    Local::EnsurePersonalBestLoaded();
        else if (_Game::IsPlayingOnServer()) Server::EnsurePersonalBestLoaded();
    }

    void CullPBs() {
        CullPBsSlowerThanFastest();
        CullPBsWithTheSameTime();
        EnsureOnePBPresent();
    }

    class CRemoveAll { void Visit(PBGhost@ g) { _RemoveGhost(g, "UnloadPBGhost", 168); } }

    void UnloadPBGhost() {
        CRemoveAll all;
        _ForEachPBGhost(PBGhostVisitor(@all.Visit));
        if (_Game::IsPlayingOnServer()) {
            if (Loader::Server::isLeaderboardPBVisible) Loader::Server::ToggleLeaderboardPB();
            else log("Attempted to remove leaderboard PB but it was already hidden.", LogLevel::Notice, 179, "UnloadPBGhost", "", "\\$f80");
        }
    }

    void UnloadPluginPBGhost() { }

}
