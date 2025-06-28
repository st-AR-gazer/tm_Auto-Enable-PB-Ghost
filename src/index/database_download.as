namespace Database {
    
    const string DL_TMP_DIR   = IO::FromUserGameFolder("Replays/zzAutoEnablePBGhost/tmp/");
    const string DL_FINAL_DIR = IO::FromUserGameFolder("Replays_Offload/zzAutoEnablePBGhost/downloaded/");

    void DownloadAndAddPBForCurrentMap() {
        log("DownloadAndAddPBForCurrentMap called, but since I'm lazy I haven't implemented it yet, :Shirley: at some point right", LogLevel::Info, 7, "DownloadAndAddPBForCurrentMap", "", "\\$f80");

        // This func is mean to be called if a game PB is faster than the local one, so that the newest can be downloaded and added to the database
        // There is already a check, but that only checks the if the widget contains a valid PB, and if we do not have a PB for the current map stored locally.
        // 
    }

    void AddRecordFromUrl(const string &in url) {
        if (url.Length == 0) { log("AddRecordFromUrl: empty URL", LogLevel::Warn, 15, "AddRecordFromUrl", "", "\\$f80"); return; }
        IO::CreateFolder(DL_TMP_DIR);
        IO::CreateFolder(DL_FINAL_DIR);

        startnew(Coro_DownloadAndAdd, url);
    }

    void Coro_DownloadAndAdd(const string &in url) {
        CTrackMania@ app = cast<CTrackMania>(GetApp());
        if (app is null) { return; }

        CSmArenaRulesMode@ rules = cast<CSmArenaRulesMode>(app.PlaygroundScript);
        if (rules is null) {
            log("No Rules script (DataFileMgr unavailable) | download skipped", LogLevel::Error, 28, "Coro_DownloadAndAdd", "", "\\$f80");
            return; // this will happen in servers as PlaygroundScript is always null there, gotta ask XertroV where the DataFileMgr is in that case so we can use that instead...
        }

        CGameDataFileManagerScript@ dfm = cast<CGameDataFileManagerScript>(rules.DataFileMgr);
        if (dfm is null) { log("DataFileMgr null | download skipped (cannot save locally without this)", LogLevel::Error, 33, "Coro_DownloadAndAdd", "", "\\$f80"); return; }

        log("Downloading ghost: " + url, LogLevel::Info, 35, "Coro_DownloadAndAdd", "", "\\$f80");
        CWebServicesTaskResult_GhostScript@ task = dfm.Ghost_Download("", url);

        while (task.IsProcessing) yield();

        CGameGhostScript@ ghost = cast<CGameGhostScript>(task.Ghost);
        if (ghost is null) { log("Download failed (ghost is null)", LogLevel::Error, 41, "Coro_DownloadAndAdd", "", "\\$f80"); return; }

        if (app.RootMap is null) { log("RootMap unavailable | cannot convert save replay.", LogLevel::Error, 43, "Coro_DownloadAndAdd", "", "\\$f80"); return; }

        string tmpName = "dl_" + tostring(Time::Stamp) + ".Replay.Gbx";
        string tmpPath = DL_TMP_DIR + tmpName;

        dfm.Replay_Save(tmpPath, app.RootMap, ghost);
        yield();

        if (!IO::FileExists(tmpPath)) { log("Replay_Save did not create a file", LogLevel::Error, 51, "Coro_DownloadAndAdd", "", "\\$f80"); return; }

        string buf = _IO::File::ReadFileToEnd(tmpPath);
        string hash = Crypto::MD5(buf);
        string finalPath = DL_FINAL_DIR + hash + ".Replay.Gbx";

        if (IO::FileExists(finalPath)) {
            IO::Delete(tmpPath);
            log("Duplicate replay ignored (hash exists).", LogLevel::Info, 59, "Coro_DownloadAndAdd", "", "\\$f80");
            return;
        }

        IO::Move(tmpPath, finalPath);

        ReplayRecord@ rec = ParseReplay(finalPath);
        if (rec is null) { IO::Delete(finalPath); log("Downloaded file could not be parsed and was therefore deleted.", LogLevel::Error, 66, "Coro_DownloadAndAdd", "", "\\$f80"); return; }
        rec.ReplayHash   = hash;
        rec.FoundThrough = "URL Download";
        rec.Path         = finalPath;

        InsertOne(rec);
        log("Downloaded replay added to db (" + rec.MapUid + ", " + rec.BestTime + " ms).", LogLevel::Info, 72, "Coro_DownloadAndAdd", "", "\\$f80");
        log("Replay saved to: " + finalPath + "from URL: " + url + " with tmp path: " + tmpPath, LogLevel::Debug, 73, "Coro_DownloadAndAdd", "", "\\$f80");
        yield(5);
        
        Loader::StartLoadProcess();
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