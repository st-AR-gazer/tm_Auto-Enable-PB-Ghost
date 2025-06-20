namespace Loader::Local {

    void EnsurePersonalBestLoaded() {
        string mapUid = get_CurrentMapUID();
        int widgetTime = _Game::CurrentPersonalBest(mapUid);

        if (widgetTime < 0) { log("Widget PB unreadable | grabbing from leaderboard", LogLevel::Warn, 7, "EnsurePersonalBestLoaded", "", "\\$f80"); RequestFromLeaderboard(mapUid); return; }
        auto replays = Database::GetReplays(mapUid);
        if (replays.Length == 0) { log("No local replays | requesting PB from leaderboard", LogLevel::Info, 9, "EnsurePersonalBestLoaded", "", "\\$f80"); RequestFromLeaderboard(mapUid); return; }
        for (uint i = 0; i < replays.Length; ++i) { if (replays[i].BestTime == uint(widgetTime)) { LoadLocalGhost(replays[i].Path); return; } }

        ReplayRecord@ best = FindBestReplay(replays);
        if (best is null || best.BestTime > uint(widgetTime)) {
            log("Local fastest slower than widget | getting leaderboard PB", LogLevel::Info, 14, "EnsurePersonalBestLoaded", "", "\\$f80");
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

            if (!WaitUntilFileExists(dst, 2000)) { log("Copy failed | aborting ghost load (" + dst + ")", LogLevel::Error, 35, "_LoadLocalGhostImpl", "", "\\$f80"); return; }
            loadPath = dst;
            startnew(CoroutineFuncUserdataString(DeleteFileWith1000msDelay), dst);
        }

        auto gm = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript).GhostMgr;
        if (!GhostLoad::InjectReplay(loadPath, gm)) { log("Replay_Load failed for " + loadPath, LogLevel::Error, 41, "_LoadLocalGhostImpl", "", "\\$f80"); return; }
        log("Loaded PB ghost from " + loadPath, LogLevel::Info, 42, "_LoadLocalGhostImpl", "", "\\$f80");
    }

    void RequestFromLeaderboard(const string &in mapUid) {
        if (Loader::AlreadyAskedLB(mapUid)) return;
        Loader::MarkAskedLB(mapUid);

        Server::DownloadPBFromLeaderboard(mapUid);
    }

    ReplayRecord@ FindBestReplay(const array<ReplayRecord@>@ replays) {
        ReplayRecord@ best = null; uint bestTime = 0xFFFFFFFF;
        for (uint i = 0; i < replays.Length; ++i) {
            if (replays[i].BestTime < bestTime) { @best = replays[i]; bestTime = replays[i].BestTime; }
        }
        return best;
    }
}

void DeleteFileWith1000msDelay(const string &in path) {
    yield(1000);
    if (IO::FileExists(path)) {
        IO::Delete(path);
        log("Deleted temporary file: " + path, LogLevel::Debug, 65, "DeleteFileWith1000msDelay", "", "\\$f80");
    } else {
        log("Temporary file not found for deletion: " + path, LogLevel::Warn, 67, "DeleteFileWith1000msDelay", "", "\\$f80");
    }
}