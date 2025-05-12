namespace Loader::Local {
    void EnsurePersonalBestLoaded() {
        const string mapUid     = CurrentMapUID;
        const int    widgetTime = _Game::CurrentPersonalBest(mapUid);

        if (widgetTime < 0) { log("Widget PB unreadable | grabbing from leaderboard", LogLevel::Warn, 6, "EnsurePersonalBestLoaded"); RequestFromLeaderboard(mapUid); return; }
        auto replays = Index::GetReplaysFromDatabase(mapUid);
        if (replays.Length == 0) { log("No local replays | requesting PB from leaderboard", LogLevel::Info, 8, "EnsurePersonalBestLoaded"); RequestFromLeaderboard(mapUid); return; }
        for (uint i = 0; i < replays.Length; ++i) { if (replays[i].BestTime == uint(widgetTime)) { LoadLocalGhost(replays[i].Path); return; } }

        ReplayRecord@ best = FindBestReplay(replays);
        if (best is null || best.BestTime > uint(widgetTime)) {
            log("Local fastest slower than widget | getting leaderboard PB", LogLevel::Info, 13, "EnsurePersonalBestLoaded");
            RequestFromLeaderboard(mapUid);
        } else {
            LoadLocalGhost(best.Path);
        }
    }

    void LoadLocalGhost(const string &in path) {
        startnew(CoroutineFuncUserdataString(_LoadLocalGhostImpl), path);
    }

    void _LoadLocalGhostImpl(const string &in srcPath) {
        const string replayDir = IO::FromUserGameFolder("Replays/");
        string       loadPath  = srcPath;

        if (!srcPath.StartsWith(replayDir)) {
            const string tmp = replayDir + "zzAutoEnablePBGhost/tmp/";
            IO::CreateFolder(tmp);

            const string dst = tmp + Path::GetFileName(srcPath);
            _IO::File::CopyFileTo(srcPath, dst);

            if (!WaitUntilFileExists(dst, 2000)) { log("Copy failed | aborting ghost load (" + dst + ")", LogLevel::Error, 35, "_LoadLocalGhostImpl"); return; }

            loadPath = dst;
            startnew(CoroutineFuncUserdataString(Index::DeleteFileWith1000msDelay), dst);
        }

        auto dfm  = GetApp().Network.ClientManiaAppPlayground.DataFileMgr;
        auto task = dfm.Replay_Load(loadPath);
        while (task.IsProcessing) yield();

        if (!task.HasSucceeded) { log("Replay_Load failed for " + loadPath, LogLevel::Error, 45, "_LoadLocalGhostImpl"); return; }

        auto gm = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript).GhostMgr;
        for (uint i = 0; i < task.Ghosts.Length; ++i) {
            CGameGhostScript@ g = cast<CGameGhostScript>(task.Ghosts[i]);
            g.IdName   = "Personal best";
            /* "$fd8" <-- yellow-ish, used for testing */ 
            /* "$5d8" <-- green-ish, non default pb color */
            /* "$7fa" <-- green-ish, default pb color */
            g.Nickname = "$fd8"+"Personal Best"+"$g$h$o$s$t$" + Math::Rand(0, 999);
            g.Trigram  = "PB"+S_markPluginLoadedPBs;
            gm.Ghost_Add(g);
        }

        log("Loaded PB ghost from " + loadPath, LogLevel::Info, 59, "_LoadLocalGhostImpl");
    }

    void RequestFromLeaderboard(const string &in mapUid) {
        Leaderboard::DownloadPBFromLeaderboard(mapUid);
    }

    ReplayRecord@ FindBestReplay(const array<ReplayRecord@>@ replays) {
        ReplayRecord@ best     = null;
        uint          bestTime = 0xFFFFFFFF;

        for (uint i = 0; i < replays.Length; ++i) {
            if (replays[i].BestTime < bestTime) {
                @best     = replays[i];
                bestTime  = replays[i].BestTime;
            }
        }
        return best;
    }
}
