namespace Loader::GhostIO {

    const string HOST   = "127.0.0.1";
    const uint   PORT   = 4567;
    const string SRV_FS = IO::FromDataFolder("ghostsrv/");

    bool Load(const string &in filePath) {
        CGameGhostMgrScript@ gm = GhostMgrHelper::Get();
        if (gm is null) { log("GhostMgr unavailable.", LogLevel::Error, 9, "Load", "", "\\$f80"); return false; }

        string lower = filePath.ToLower();
        if (lower.EndsWith(".replay.gbx")) {
            return FromReplay(filePath, gm);
        } else if (lower.EndsWith(".ghost.gbx")) {
            return FromGhost(filePath, gm);
        } else {
            log("Unsupported file type: " + filePath, LogLevel::Error, 17, "Load", "", "\\$f80");
            return false;
        }
    }

    bool Load(const ReplayRecord@ rec) {
        SourceFormat fmt = FromNodeType(rec.NodeType);

        CGameGhostMgrScript@ gm = GhostMgrHelper::Get();
        if (gm is null) { log("GhostMgr unavailable.", LogLevel::Error, 26, "Load", "", "\\$f80"); return false; }

        if (fmt == SourceFormat::ReplayFile) {
            return FromReplay(rec.Path, gm);
        } else {
            return FromGhost(rec.Path, gm);
        }
    }

    // .Replay.Gbx
    bool FromReplay(const string &in srcPath, CGameGhostMgrScript@ gm) {
        string replayDir = IO::FromUserGameFolder("Replays/");
        string loadPath  = srcPath;

        if (!srcPath.StartsWith(replayDir)) {
            string tmpDir = replayDir + "zzAutoEnablePBGhost/tmp/";
            IO::CreateFolder(tmpDir);

            string dstPath = tmpDir + Path::GetFileName(srcPath);
            _IO::File::CopyFileTo(srcPath, dstPath);

            if (!WaitUntilFileExists(dstPath, 2000)) {
                log("CopyToReplays failed: " + dstPath, LogLevel::Error, 48, "FromReplay", "", "\\$f80");
                return false;
            }
            loadPath = dstPath;
            startnew(CoroutineFuncUserdataString(DeleteTempFileDelayed), loadPath);
        }

        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        if (ps is null) { log("PlaygroundScript null (Replay)", LogLevel::Error, 56, "FromReplay", "", "\\$f80"); return false; }
        CGameDataFileManagerScript@ dfm = ps.DataFileMgr;

        auto task = dfm.Replay_Load(loadPath);
        while (task.IsProcessing) { yield(); }

        if (!task.HasSucceeded) {
            log("Replay_Load failed: " + task.ErrorCode, LogLevel::Error, 63, "FromReplay", "", "\\$f80");
            return false;
        }

        for (uint i = 0; i < task.Ghosts.Length; ++i) {
            CGameGhostScript@ g = cast<CGameGhostScript>(task.Ghosts[i]);
            DecoratePB(g);
            MwId id = gm.Ghost_Add(g);

            Loader::GhostRegistry::Track(
                PBGhost(g, id, srcPath, SourceFormat::ReplayFile));
        }
        return true;
    }

    // .Ghost.Gbx
    bool FromGhost(const string &in path, CGameGhostMgrScript@ gm) {
        string fname = Path::GetFileName(path);
        _IO::File::CopyFileTo(path, SRV_FS + fname);

        string url = "http://" + HOST + ":" + PORT + "/get_ghost/" + fname;

        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        if (ps is null) { log("PlaygroundScript null (Ghost)", LogLevel::Error, 86, "FromGhost", "", "\\$f80"); return false; }
        CGameDataFileManagerScript@ dfm = ps.DataFileMgr;

        CWebServicesTaskResult_GhostScript@ task = dfm.Ghost_Download("", url);
        while (task.IsProcessing) { yield(); }

        if (!task.HasSucceeded) {
            log("Ghost_Download failed: " + task.ErrorDescription, LogLevel::Error, 93, "FromGhost", "", "\\$f80");
            return false;
        }

        MwId id = gm.Ghost_Add(task.Ghost);
        Loader::GhostRegistry::Track(
            PBGhost(task.Ghost, id, path, SourceFormat::GhostFile));

        dfm.TaskResult_Release(task.Id);
        return true;
    }

    void DecoratePB(CGameGhostScript@ g) {
        g.IdName = "Personal best";
                  /* "$fd8" <-- yellow‑ish, used for testing
                     "$5d8" <-- green‑ish,  non‑default PB colour
                     "$7fa" <-- green‑ish,  default PB colour                                   */
        g.Nickname = "$fd8" + "Personal Best" + "$g$h$o$s$t$" + Math::Rand(0, 999);
        g.Trigram  = "PB" + S_markPluginLoadedPBs;
    }

    CGameGhostScript@ DecoratePB(const CGameGhostScript@ g) {
        g.IdName   = "Personal best";
        g.Nickname = "$fd8" + "Personal Best" + "$g$h$o$s$t$" + Math::Rand(0, 999);
        g.Trigram  = "PB" + S_markPluginLoadedPBs;
        return g;
    }

    bool WaitUntilFileExists(const string &in path, uint timeoutMs) {
        uint64 start = Time::Now;
        while (!IO::FileExists(path) && (Time::Now - start) < timeoutMs) { yield(); }
        return IO::FileExists(path);
    }

    void DeleteTempFileDelayed(const string &in path) {
        yield(1000);
        if (IO::FileExists(path)) { IO::Delete(path); }
    }
}
