namespace Loader::Local {

    void EnsurePersonalBestLoaded() {
        string mapUid = get_CurrentMapUID();
        int widgetTime = _Game::CurrentPersonalBest(mapUid);

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
        string loadPath = srcPath;

        if (!srcPath.StartsWith(replayDir)) {
            const string tmp = replayDir + "zzAutoEnablePBGhost/tmp/";
            IO::CreateFolder(tmp);
            const string dst = tmp + Path::GetFileName(srcPath);
            _IO::File::CopyFileTo(srcPath, dst);

            if (!WaitUntilFileExists(dst, 2000)) { log("Copy failed | aborting ghost load (" + dst + ")", LogLevel::Error, 35, "_LoadLocalGhostImpl"); return; }
            loadPath = dst;
            startnew(CoroutineFuncUserdataString(Index::DeleteFileWith1000msDelay), dst);
        }

        auto gm = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript).GhostMgr;
        if (!GhostLoad::InjectReplay(loadPath, gm)) { log("Replay_Load failed for " + loadPath, LogLevel::Error, 48, "_LoadLocalGhostImpl"); return; }
        log("Loaded PB ghost from " + loadPath, LogLevel::Info, 50, "_LoadLocalGhostImpl");
    }

    void RequestFromLeaderboard(const string &in mapUid) { Server::DownloadPBFromLeaderboard(mapUid); }

    ReplayRecord@ FindBestReplay(const array<ReplayRecord@>@ replays) {
        ReplayRecord@ best = null; uint bestTime = 0xFFFFFFFF;
        for (uint i = 0; i < replays.Length; ++i) {
            if (replays[i].BestTime < bestTime) { @best = replays[i]; bestTime = replays[i].BestTime; }
        }
        return best;
    }
}