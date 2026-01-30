namespace Loader::GhostIO {

    const string HOST   = "127.0.0.1";
    const uint   PORT   = 4567;
    const string SRV_FS = IO::FromUserGameFolder("Replays_Offload/AutoEnablePBGhost/ghostsrv/");
    bool g_warnedUserPathMismatch = false;

    string _NormalizePath(const string &in path) {
        return path.Replace("\\", "/");
    }

    string _GetUserFromPath(const string &in path) {
        string norm = _NormalizePath(path);
        string lower = norm.ToLower();
        int idx = lower.IndexOf("/users/");
        if (idx < 0) return "";
        int start = idx + 7;
        if (start >= norm.Length) return "";
        int relEnd = norm.SubStr(start).IndexOf("/");
        int end = relEnd < 0 ? norm.Length : start + relEnd;
        return norm.SubStr(start, end - start);
    }

    string _ReplaceUserInPath(const string &in path, const string &in newUser) {
        string norm = _NormalizePath(path);
        string lower = norm.ToLower();
        int idx = lower.IndexOf("/users/");
        if (idx < 0) return path;
        int start = idx + 7;
        int relEnd = norm.SubStr(start).IndexOf("/");
        int end = relEnd < 0 ? norm.Length : start + relEnd;
        string replaced = norm.SubStr(0, start) + newUser + norm.SubStr(end);
        if (path.IndexOf("\\") >= 0) {
            replaced = replaced.Replace("/", "\\");
        }
        return replaced;
    }

    void _WarnUserPathMismatchOnce(const string &in pathUser, const string &in curUser) {
        if (g_warnedUserPathMismatch) return;
        g_warnedUserPathMismatch = true;
        NotifyWarning("Replay file appears to be under user '" + pathUser
            + "', but current user is '" + curUser
            + "'. The replay may fail to load unless you update paths or reindex.");
    }

    bool _TryResolveUserPathMismatch(ReplayRecord@ rec, string &out resolvedPath) {
        resolvedPath = rec.Path;
        string curUser  = _GetUserFromPath(IO::FromUserGameFolder(""));
        string pathUser = _GetUserFromPath(rec.Path);
        string curUserLower = curUser.ToLower();
        string pathUserLower = pathUser.ToLower();
        if (curUserLower == "" || pathUserLower == "" || curUserLower == pathUserLower) return false;

        string candidate = _ReplaceUserInPath(rec.Path, curUser);
        if (candidate == rec.Path) return false;
        if (!IO::FileExists(candidate)) {
            _WarnUserPathMismatchOnce(pathUser, curUser);
            return false;
        }
        if (rec.ReplayHash == "") {
            _WarnUserPathMismatchOnce(pathUser, curUser);
            return false;
        }

        string buf = _IO::File::ReadFileToEnd(candidate);
        string hash = Crypto::MD5(buf);
        if (hash == rec.ReplayHash) {
            Database::UpdatePathByHash(rec.ReplayHash, candidate);
            rec.Path = candidate;
            rec.FileName = Path::GetFileName(candidate);
            resolvedPath = candidate;
            return true;
        }

        _WarnUserPathMismatchOnce(pathUser, curUser);
        return false;
    }

    bool Load(const string &in filePath) {
        CGameGhostMgrScript@ gm = GhostMgrHelper::Get();
        if (gm is null) { log("GhostMgr unavailable.", LogLevel::Warning, 9, "Load", "", "\\$f80"); return false; }

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

    bool Load(ReplayRecord@ rec) {
        if (rec is null) return false;
        SourceFormat fmt = FromNodeType(rec.NodeType);

        CGameGhostMgrScript@ gm = GhostMgrHelper::Get();
        if (gm is null) { log("GhostMgr unavailable.", LogLevel::Warning, 26, "Load", "", "\\$f80"); return false; }

        string resolvedPath = rec.Path;
        _TryResolveUserPathMismatch(rec, resolvedPath);

        if (fmt == SourceFormat::ReplayFile) {
            return FromReplay(resolvedPath, gm);
        } else {
            return FromGhost(resolvedPath, gm);
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
            startnew(DeleteTempFileDelayed, loadPath);
        }

        CGameCtnNetwork@ net = cast<CGameCtnNetwork>(GetApp().Network);
        if (net is null) { log("CGameCtnNetwork is null", LogLevel::Error, 56, "FromReplay", "", "\\$f80"); return false; }
        CGameManiaAppPlayground@ cmap = cast<CGameManiaAppPlayground>(net.ClientManiaAppPlayground);
        if (cmap is null) { log("CGameManiaAppPlayground is null", LogLevel::Error, 58, "FromReplay", "", "\\$f80"); return false; }
        CGameDataFileManagerScript@ dfm = cast<CGameDataFileManagerScript>(cmap.DataFileMgr);
        if (dfm is null) { log("DataFileMgr null | download skipped (cannot save locally without this)", LogLevel::Error, 60, "FromReplay", "", "\\$f80"); return false; }

        auto task = dfm.Replay_Load(loadPath);
        while (task.IsProcessing) { yield(); }

        if (!task.HasSucceeded) {
            log("Replay_Load failed: " + task.ErrorCode, LogLevel::Error, 66, "FromReplay", "", "\\$f80");
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

        CGameCtnNetwork@ net = cast<CGameCtnNetwork>(GetApp().Network);
        if (net is null) { log("CGameCtnNetwork is null", LogLevel::Error, 89, "FromGhost", "", "\\$f80"); return false; }
        CGameManiaAppPlayground@ cmap = cast<CGameManiaAppPlayground>(net.ClientManiaAppPlayground);
        if (cmap is null) { log("CGameManiaAppPlayground is null", LogLevel::Error, 91, "FromGhost", "", "\\$f80"); return false; }
        CGameDataFileManagerScript@ dfm = cast<CGameDataFileManagerScript>(cmap.DataFileMgr);
        if (dfm is null) { log("DataFileMgr null | download skipped (cannot save locally without this)", LogLevel::Error, 93, "FromGhost", "", "\\$f80"); return false; }

        CWebServicesTaskResult_GhostScript@ task = dfm.Ghost_Download("", url);
        while (task.IsProcessing) { yield(); }

        if (!task.HasSucceeded) {
            log("Ghost_Download failed: " + task.ErrorDescription, LogLevel::Error, 99, "FromGhost", "", "\\$f80");
            return false;
        }

        MwId id = gm.Ghost_Add(task.Ghost);
        Loader::GhostRegistry::Track(
            PBGhost(task.Ghost, id, path, SourceFormat::GhostFile));

        dfm.TaskResult_Release(task.Id);
        return true;
    }

    CGameGhostScript@ DecoratePB(CGameGhostScript@ g) {
        g.IdName = "Personal best";
                  /* "$fd8" <-- yellow‑ish, used for testing
                     "$5d8" <-- green‑ish,  non‑default PB colour
                     "$7fa" <-- green‑ish,  default PB colour                                   */
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
