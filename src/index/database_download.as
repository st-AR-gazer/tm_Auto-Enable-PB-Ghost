namespace Database {
    
    const string DL_TMP_DIR   = IO::FromUserGameFolder("Replays/zzAutoEnablePBGhost/tmp/");
    const string DL_FINAL_DIR = IO::FromUserGameFolder("Replays_Offload/zzAutoEnablePBGhost/downloaded/");

    void AddRecordFromUrl(const string &in url) {
        if (url.Length == 0) { log("AddRecordFromUrl: empty URL", LogLevel::Warn, 7, "AddRecordFromUrl", "", "\\$f80"); return; }
        IO::CreateFolder(DL_TMP_DIR);
        IO::CreateFolder(DL_FINAL_DIR);

        startnew(Coro_DownloadAndAdd, url);
    }

    void Coro_DownloadAndAdd(const string &in url) {
        CTrackMania@ app = cast<CTrackMania>(GetApp());
        if (app is null) { return; }

        CGameCtnNetwork@ net = cast<CGameCtnNetwork>(app.Network);
        if (net is null) { log("CGameCtnNetwork is null", LogLevel::Error, 19, "Coro_DownloadAndAdd", "", "\\$f80"); return; }

        CGameManiaAppPlayground@ cmap = cast<CGameManiaAppPlayground>(net.ClientManiaAppPlayground);
        if (cmap is null) { log("CGameManiaAppPlayground is null", LogLevel::Error, 22, "Coro_DownloadAndAdd", "", "\\$f80"); return; }

        CGameDataFileManagerScript@ dfm = cast<CGameDataFileManagerScript>(cmap.DataFileMgr);
        if (dfm is null) { log("DataFileMgr null | download skipped (cannot save locally without this)", LogLevel::Error, 25, "Coro_DownloadAndAdd", "", "\\$f80"); return; }

        log("Downloading ghost: " + url, LogLevel::Info, 27, "Coro_DownloadAndAdd", "", "\\$f80");
        CWebServicesTaskResult_GhostScript@ task = dfm.Ghost_Download("", url);

        while (task.IsProcessing) yield();

        CGameGhostScript@ ghost = cast<CGameGhostScript>(task.Ghost);
        if (ghost is null) { log("Download failed (ghost is null)", LogLevel::Error, 33, "Coro_DownloadAndAdd", "", "\\$f80"); return; }

        if (app.RootMap is null) { log("RootMap unavailable | cannot convert save replay.", LogLevel::Error, 35, "Coro_DownloadAndAdd", "", "\\$f80"); return; }

        string tmpName = "dl_" + tostring(Time::Stamp) + ".Replay.Gbx";
        string tmpPath = DL_TMP_DIR + tmpName;

        dfm.Replay_Save(tmpPath, app.RootMap, ghost);
        yield();

        if (!IO::FileExists(tmpPath)) { log("Replay_Save did not create a file", LogLevel::Error, 43, "Coro_DownloadAndAdd", "", "\\$f80"); return; }

        string buf = _IO::File::ReadFileToEnd(tmpPath);
        string hash = Crypto::MD5(buf);
        string finalPath = DL_FINAL_DIR + hash + ".Replay.Gbx";

        if (IO::FileExists(finalPath) && Database::HashExists(hash)) {
            IO::Delete(tmpPath);
            Loader::StartPBFlow();            
            return;
        }

        IO::Move(tmpPath, finalPath);

        ReplayRecord@ rec = ParseReplay(finalPath);
        if (rec is null) { IO::Delete(finalPath); log("Downloaded file could not be parsed and was therefore deleted.", LogLevel::Error, 58, "Coro_DownloadAndAdd", "", "\\$f80"); return; }
        rec.ReplayHash   = hash;
        rec.FoundThrough = "URL Download";
        rec.Path         = finalPath;

        InsertOne(rec);
        log("Downloaded replay added to db (" + rec.MapUid + ", " + rec.BestTime + " ms).", LogLevel::Info, 64, "Coro_DownloadAndAdd", "", "\\$f80");
        log("Replay saved to: " + finalPath + "from URL: " + url + " with tmp path: " + tmpPath, LogLevel::Debug, 65, "Coro_DownloadAndAdd", "", "\\$f80");
        yield(5);
        
        Loader::StartPBFlow();
    }
}