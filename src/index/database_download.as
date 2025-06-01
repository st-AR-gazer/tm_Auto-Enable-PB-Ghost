namespace Database {
    
    const string DL_TMP_DIR   = IO::FromUserGameFolder("Replays/zzAutoEnablePBGhost/tmp/");
    const string DL_FINAL_DIR = IO::FromUserGameFolder("Replays_Offload/zzAutoEnablePBGhost/downloaded/");

    void AddRecordFromUrl(const string &in url) {
        if (url.Length == 0) { log("AddRecordFromUrl: empty URL", LogLevel::Warn, 7, "AddRecordFromUrl"); return; }
        IO::CreateFolder(DL_TMP_DIR);
        IO::CreateFolder(DL_FINAL_DIR);

        startnew(Coro_DownloadAndAdd, url);
    }

    void Coro_DownloadAndAdd(const string &in url) {
        CTrackMania@ app = cast<CTrackMania>(GetApp());
        if (app is null) { return; }

        CSmArenaRulesMode@ rules = cast<CSmArenaRulesMode>(app.PlaygroundScript);
        if (rules is null) {
            log("No Rules script (DataFileMgr unavailable) | download skipped", LogLevel::Error, 20, "Coro_DownloadAndAdd");
            return; // this will happen in servers as PlaygroundScript is always null there, gotta ask XertroV where the DataFileMgr is in that case so we can use that instead...
        }

        CGameDataFileManagerScript@ dfm = cast<CGameDataFileManagerScript>(rules.DataFileMgr);
        if (dfm is null) { log("DataFileMgr null | download skipped (cannot save locally without this)", LogLevel::Error, 25, "Coro_DownloadAndAdd"); return; }

        log("Downloading ghost: " + url, LogLevel::Info, 27, "Coro_DownloadAndAdd");
        CWebServicesTaskResult_GhostScript@ task = dfm.Ghost_Download("", url);

        while (task.IsProcessing) yield();

        CGameGhostScript@ ghost = cast<CGameGhostScript>(task.Ghost);
        if (ghost is null) { log("Download failed (ghost is null)", LogLevel::Error, 33, "Coro_DownloadAndAdd"); return; }

        if (app.RootMap is null) { log("RootMap unavailable | cannot convert save replay.", LogLevel::Error, 35, "Coro_DownloadAndAdd"); return; }

        string tmpName = "dl_" + tostring(Time::Stamp) + ".Replay.Gbx";
        string tmpPath = DL_TMP_DIR + tmpName;

        dfm.Replay_Save(tmpPath, app.RootMap, ghost);
        yield();

        if (!IO::FileExists(tmpPath)) { log("Replay_Save did not create a file", LogLevel::Error, 43, "Coro_DownloadAndAdd"); return; }

        string buf = _IO::File::ReadFileToEnd(tmpPath);
        string hash = Crypto::MD5(buf);
        string finalPath = DL_FINAL_DIR + hash + ".Replay.Gbx";

        if (IO::FileExists(finalPath)) {
            IO::Delete(tmpPath);
            log("Duplicate replay ignored (hash exists).", LogLevel::Info, 51, "Coro_DownloadAndAdd");
            return;
        }

        IO::Move(tmpPath, finalPath);

        ReplayRecord@ rec = ParseReplay(finalPath);
        if (rec is null) { IO::Delete(finalPath); log("Downloaded file could not be parsed and was therefore deleted.", LogLevel::Error, 58, "Coro_DownloadAndAdd"); return; }
        rec.ReplayHash   = hash;
        rec.FoundThrough = "URL Download";
        rec.Path         = finalPath;

        InsertOne(rec);
        log("Downloaded replay added (" + rec.MapUid + ", " + rec.BestTime + " ms).", LogLevel::Info, 64, "Coro_DownloadAndAdd");
    }

    ReplayRecord@ ParseReplay(const string &in fullPath) {
        const string DOC_ROOT = IO::FromUserGameFolder("");
        string rel = fullPath.StartsWith(DOC_ROOT) ? fullPath.SubStr(DOC_ROOT.Length) : fullPath;

        CSystemFidFile@ fid = Fids::GetUser(rel);
        if (fid is null) return null;

        CMwNod@ nod = Fids::Preload(fid);
        if (nod is null) return null;

        ReplayRecord r;
        r.FileName = Path::GetFileName(fullPath);
        r.Path = fullPath;


        // This isn't really nessary, but idk what Save_Replay actually saves the replay as, be that a ReplayRecord or a ReplayRecordInfo (or tbh could be something else entirely).
        // So this is just what I gotta do :xdd:
        CGameCtnReplayRecord@ rr = cast<CGameCtnReplayRecord>(nod);
        if (rr !is null && rr.Ghosts.Length > 0 && rr.Challenge !is null) {
            r.MapUid   = rr.Challenge.IdName;
            r.PlayerLogin    = rr.Ghosts[0].GhostLogin;
            r.PlayerNickname = rr.Ghosts[0].GhostNickname;
            r.BestTime = rr.Ghosts[0].RaceTime;
            r.NodeType = "CGameCtnReplayRecord";
            return r;
        }

        CGameCtnReplayRecordInfo@ info = cast<CGameCtnReplayRecordInfo>(nod);
        if (info !is null) {
            r.MapUid   = info.MapUid;
            r.PlayerLogin    = info.PlayerLogin;
            r.PlayerNickname = info.PlayerNickname;
            r.BestTime = info.BestTime;
            r.NodeType = "CGameCtnReplayRecordInfo";
            return r;
        }

        return null;
    }
}