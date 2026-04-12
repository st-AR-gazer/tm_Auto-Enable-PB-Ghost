namespace Loader::GhostIO {

    const string HOST   = "127.0.0.1";
    const uint   PORT   = 4567;
    const string SRV_FS = IO::FromUserGameFolder("Replays_Offload/AutoEnablePBGhost/ghostsrv/");
    bool g_warnedUserPathMismatch = false;
    uint64 g_lastGhostMgrWarn = 0;
    bool g_warnedDbMissing = false;
    uint64 g_lastDbMissingNotify = 0;
    const uint kDbMissingNotifyCooldownMs = 15000;

    void _LogGhostMgrUnavailable(const string &in fnName, int line) {
        uint64 now = Time::Now;
        if (now - g_lastGhostMgrWarn < 2000) return;
        g_lastGhostMgrWarn = now;
        log("GhostMgr unavailable.", LogLevel::Warning, line, fnName, "", "\\$f80");
    }

    string _NormalizePath(const string &in path) {
        return path.Replace("\\", "/");
    }

    bool _PathStartsWith(const string &in path, const string &in root) {
        string p = _NormalizePath(path).ToLower();
        string r = _NormalizePath(root).ToLower();
        return p.StartsWith(r);
    }

    string _MakeTempReplayName(const string &in srcPath) {
        string ext = ".Replay.Gbx";
        string lower = srcPath.ToLower();
        if (lower.EndsWith(".ghost.gbx")) ext = ".Ghost.Gbx";
        return "tmp_" + tostring(Time::Now) + "_" + Math::Rand(0, 9999) + ext;
    }

    bool _CopyReplayToTmp(const string &in srcPath, const string &in tmpDir, string &out dstPath) {
        if (!IO::FileExists(srcPath)) {
            return false;
        }

        dstPath = tmpDir + _MakeTempReplayName(srcPath);
        IO::Copy(srcPath, dstPath);
        if (!IO::FileExists(dstPath)) {
            _IO::File::CopyFileTo(srcPath, dstPath);
        }

        if (!WaitUntilFileExists(dstPath, 5000)) {
            log("CopyToReplays failed: " + dstPath + " (src=" + srcPath + ")", LogLevel::Error, 33, "_CopyReplayToTmp", "", "\\$f80");
            return false;
        }
        return true;
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

    void _NotifyDbMissingOnce(const string &in filePath) {
        uint64 now = Time::Now;
        if (g_warnedDbMissing && now - g_lastDbMissingNotify < kDbMissingNotifyCooldownMs) return;
        g_warnedDbMissing = true;
        g_lastDbMissingNotify = now;

        string name = Path::GetFileName(filePath);
        string suffix = name.Length > 0 ? " (" + name + ")" : "";
        NotifyWarning("A replay file referenced in the PB Ghost database was not found" + suffix
            + ". Consider refreshing the database when convenient.");
    }

    void _RemoveStaleRecord(ReplayRecord@ rec, const string &in reason, const string &in pathForLog) {
        string path = pathForLog.Length > 0 ? pathForLog : rec.Path;
        log("DB replay invalid (" + reason + "): " + path, LogLevel::Warning, -1, "_RemoveStaleRecord", "", "\\$f80");

        if (rec.ReplayHash.Length > 0) {
            Database::DeleteByHash(rec.ReplayHash);
        } else if (rec.Path.Length > 0) {
            Database::DeleteByPath(rec.Path);
        }

        _NotifyDbMissingOnce(path);
    }

    bool _ValidateReplayRecord(ReplayRecord@ rec, string &out resolvedPath) {
        if (rec is null) return false;

        resolvedPath = rec.Path;
        if (resolvedPath.Length == 0) {
            _RemoveStaleRecord(rec, "empty path", resolvedPath);
            return false;
        }

        if (!IO::FileExists(resolvedPath)) {
            _TryResolveUserPathMismatch(rec, resolvedPath);
        }

        if (!IO::FileExists(resolvedPath)) {
            _RemoveStaleRecord(rec, "missing file", resolvedPath);
            return false;
        }

        if (rec.FileName.Length > 0) {
            string actualName = Path::GetFileName(resolvedPath);
            if (actualName.ToLower() != rec.FileName.ToLower()) {
                _RemoveStaleRecord(rec, "filename mismatch", resolvedPath);
                return false;
            }
        }

        if (rec.ReplayHash.Length > 0) {
            string hash = Crypto::MD5(_IO::File::ReadFileToEnd(resolvedPath));
            if (hash.ToLower() != rec.ReplayHash.ToLower()) {
                _RemoveStaleRecord(rec, "hash mismatch", resolvedPath);
                return false;
            }
        }

        return true;
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
        if (gm is null) { _LogGhostMgrUnavailable("Load", 82); return false; }

        if (!IO::FileExists(filePath)) {
            log("Source replay missing: " + filePath, LogLevel::Warning, 85, "Load", "", "\\$f80");
            return false;
        }

        string lower = filePath.ToLower();
        if (lower.EndsWith(".replay.gbx")) {
            return FromReplay(filePath, gm);
        } else if (lower.EndsWith(".ghost.gbx")) {
            return FromGhost(filePath, gm);
        } else {
            log("Unsupported file type: " + filePath, LogLevel::Error, 90, "Load", "", "\\$f80");
            return false;
        }
    }

    bool Load(ReplayRecord@ rec) {
        if (rec is null) return false;
        SourceFormat fmt = FromNodeType(rec.NodeType);

        CGameGhostMgrScript@ gm = GhostMgrHelper::Get();
        if (gm is null) { _LogGhostMgrUnavailable("Load", 100); return false; }

        string resolvedPath;
        if (!_ValidateReplayRecord(rec, resolvedPath)) return false;

        if (fmt == SourceFormat::ReplayFile) {
            return FromReplay(resolvedPath, gm);
        } else {
            return FromGhost(resolvedPath, gm);
        }
    }

    // .Replay.Gbx
    bool FromReplay(const string &in srcPath, CGameGhostMgrScript@ gm) {
        if (!IO::FileExists(srcPath)) {
            log("Source replay missing: " + srcPath, LogLevel::Warning, 121, "FromReplay", "", "\\$f80");
            return false;
        }

        string replayDir = IO::FromUserGameFolder("Replays/");
        string loadPath  = srcPath;

        if (!_PathStartsWith(srcPath, replayDir)) {
            string tmpDir = replayDir + "zzAutoEnablePBGhost/tmp/";
            IO::CreateFolder(tmpDir, true);

            string dstPath;
            if (!_CopyReplayToTmp(srcPath, tmpDir, dstPath)) {
                return false;
            }
            loadPath = dstPath;
            startnew(DeleteTempFileDelayed, loadPath);
        }

        CGameCtnNetwork@ net = cast<CGameCtnNetwork>(GetApp().Network);
        if (net is null) { log("CGameCtnNetwork is null", LogLevel::Error, 133, "FromReplay", "", "\\$f80"); return false; }
        CGameManiaAppPlayground@ cmap = cast<CGameManiaAppPlayground>(net.ClientManiaAppPlayground);
        if (cmap is null) { log("CGameManiaAppPlayground is null", LogLevel::Error, 135, "FromReplay", "", "\\$f80"); return false; }
        CGameDataFileManagerScript@ dfm = cast<CGameDataFileManagerScript>(cmap.DataFileMgr);
        if (dfm is null) { log("DataFileMgr null | download skipped (cannot save locally without this)", LogLevel::Error, 137, "FromReplay", "", "\\$f80"); return false; }

        auto task = dfm.Replay_Load(loadPath);
        while (task.IsProcessing) { yield(); }

        if (!task.HasSucceeded) {
            log("Replay_Load failed: " + task.ErrorCode, LogLevel::Error, 143, "FromReplay", "", "\\$f80");
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
        if (!IO::FileExists(path)) {
            log("Source ghost missing: " + path, LogLevel::Warning, 152, "FromGhost", "", "\\$f80");
            return false;
        }

        string fname = Path::GetFileName(path);
        _IO::File::CopyFileTo(path, SRV_FS + fname);

        string url = "http://" + HOST + ":" + PORT + "/get_ghost/" + fname;

        CGameCtnNetwork@ net = cast<CGameCtnNetwork>(GetApp().Network);
        if (net is null) { log("CGameCtnNetwork is null", LogLevel::Error, 166, "FromGhost", "", "\\$f80"); return false; }
        CGameManiaAppPlayground@ cmap = cast<CGameManiaAppPlayground>(net.ClientManiaAppPlayground);
        if (cmap is null) { log("CGameManiaAppPlayground is null", LogLevel::Error, 168, "FromGhost", "", "\\$f80"); return false; }
        CGameDataFileManagerScript@ dfm = cast<CGameDataFileManagerScript>(cmap.DataFileMgr);
        if (dfm is null) { log("DataFileMgr null | download skipped (cannot save locally without this)", LogLevel::Error, 170, "FromGhost", "", "\\$f80"); return false; }

        CWebServicesTaskResult_GhostScript@ task = dfm.Ghost_Download("", url);
        while (task.IsProcessing) { yield(); }

        if (!task.HasSucceeded) {
            log("Ghost_Download failed: " + task.ErrorDescription, LogLevel::Error, 176, "FromGhost", "", "\\$f80");
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
