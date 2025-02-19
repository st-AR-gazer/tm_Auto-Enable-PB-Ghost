namespace net {
    void ConvertGhostToReplay(const string &in url, const string &in mapRecordId) {
        CTrackMania@ app = cast<CTrackMania>(GetApp());
        if (app is null) return;
        CSmArenaRulesMode@ playgroundScript = cast<CSmArenaRulesMode>(app.PlaygroundScript);
        if (playgroundScript is null) return;
        CGameDataFileManagerScript@ dataFileMgr = cast<CGameDataFileManagerScript>(playgroundScript.DataFileMgr);
        if (dataFileMgr is null) { return; }

        if (url == "") { return; }

        log("ConvertGhostToReplay: Attempting to download ghost from URL: " + url, LogLevel::Info, 152, "ConvertGhostToReplay");
        CWebServicesTaskResult_GhostScript@ task = dataFileMgr.Ghost_Download("", url);

        while (task.IsProcessing && task.Ghost is null) { yield(); }

        CGameGhostScript@ ghost = cast<CGameGhostScript>(task.Ghost);
        if (ghost is null) { log("ConvertGhostToReplay: Download failed; ghost is null", LogLevel::Error, 158, "ConvertGhostToReplay"); return; }

        string replayName = Index::GetReplayFilename(ghost, app.RootMap);
        string replayPath_tmp = IO::FromUserGameFolder(Index::GetRelative_zzReplayPath() + "/tmp/" + replayName + ".Replay.Gbx");
        dataFileMgr.Replay_Save(replayPath_tmp, app.RootMap, ghost);

        string fileContent = _IO::File::ReadFileToEnd(replayPath_tmp);
        string hash = Crypto::MD5(fileContent);

        string replayPath = IO::FromUserGameFolder(Index::GetRelative_zzReplayPath() + "/dwn/" + hash + ".Replay.Gbx");
        dataFileMgr.Replay_Save(replayPath, app.RootMap, ghost);

        // FIXME: In a future update I need to add the ability to use Better Replay Folders so that the replay is saved to that folder instead (and not forced to be saved here...)
        log("ConvertGhostToReplay: Saving replay to " + replayPath, LogLevel::Info, 163, "ConvertGhostToReplay");

        Index::AddReplayToDatabse(replayPath, mapRecordId);

        startnew(CoroutineFuncUserdataString(Loader::LoadLocalGhost), replayPath);

        // I'm not sure if I should really be removing the ghost here...
        startnew(CoroutineFuncUserdataString(Index::DeleteFileWith200msDelay), replayPath_tmp);
    }
}