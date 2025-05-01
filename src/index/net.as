namespace net {
    void ConvertGhostToReplay(const string &in url) {
        CTrackMania@ app = cast<CTrackMania>(GetApp());
        if (app is null) return;
        CSmArenaRulesMode@ playgroundScript = cast<CSmArenaRulesMode>(app.PlaygroundScript);
        if (playgroundScript is null) return;
        CGameDataFileManagerScript@ dataFileMgr = cast<CGameDataFileManagerScript>(playgroundScript.DataFileMgr);
        if (dataFileMgr is null) { return; }

        if (url == "") { return; }

        log("ConvertGhostToReplay: Attempting to download ghost from URL: " + url, LogLevel::Info, 12, "ConvertGhostToReplay");
        CWebServicesTaskResult_GhostScript@ task = dataFileMgr.Ghost_Download("", url);

        while (task.IsProcessing && task.Ghost is null) { yield(); }

        CGameGhostScript@ ghost = cast<CGameGhostScript>(task.Ghost);
        if (ghost is null) { log("ConvertGhostToReplay: Download failed; ghost is null", LogLevel::Error, 18, "ConvertGhostToReplay"); return; }
        yield();

        string replayName = Index::GetReplayFilename(ghost, app.RootMap);
        string replayPath_tmp = IO::FromUserGameFolder(Index::GetRelative_zzReplayPath() + "/tmp/" + replayName + ".Replay.Gbx");
        dataFileMgr.Replay_Save(replayPath_tmp, app.RootMap, ghost);
        yield();

        string fileContent = _IO::File::ReadFileToEnd(replayPath_tmp);
        yield();
        string hash = Crypto::MD5(fileContent);
        yield();

        string replayPath = IO::FromUserGameFolder(Index::GetRelative_zzReplayPath() + "/dwn/" + hash + ".Replay.Gbx");
        dataFileMgr.Replay_Save(replayPath, app.RootMap, ghost);
        yield();

        // FIXME: In a future update I need to add the ability to use Better Replay Folders so that the replay is saved to that folder instead (and not forced to be saved here...)
        log("ConvertGhostToReplay: Saving replay to " + replayPath, LogLevel::Info, 36, "ConvertGhostToReplay");

        Index::AddReplayToDatabase(replayPath);
        yield();

        startnew(CoroutineFuncUserdataString(Loader::LoadLocalGhost), replayPath);

        // I'm not sure if I should really be removing the ghost here...
        startnew(CoroutineFuncUserdataString(Index::DeleteFileWith1000msDelay), replayPath_tmp);
    }
}

// [   ScriptRuntime] [  LOG] [17:47:28] [_Auto-Enable-PB-Ghost]  \$0ff[DEBUG]  \$z\$0cc 15   : MapMonitor      : \$zMap changed to: 6wm_j9UZGtiXk40hcMEINR8Py39
// [   ScriptRuntime] [  LOG] [17:47:28] [_Auto-Enable-PB-Ghost]  \$0ff[DEBUG]  \$z\$0cc 13   : LoadPB          : \$zAttempting to load PB ghosts.
// [   ScriptRuntime] [  LOG] [17:47:28] [_Auto-Enable-PB-Ghost]  \$0f0[INFO]   \$z\$0c0 58   : IsFastestPBLoad : \$zWidget time: -1 | Fastest time: 43538
// [   ScriptRuntime] [  LOG] [17:47:28] [_Auto-Enable-PB-Ghost]  \$0f0[INFO]   \$z\$0c0 14   : UnloadPBGhost_G : \$zRemoved ghost: Personal best
// [   ScriptRuntime] [  LOG] [17:47:28] [_Auto-Enable-PB-Ghost]  \$0f0[INFO]   \$z\$0c0 14   : UnloadPBGhost_G : \$zRemoved ghost: Personal best
// [   ScriptRuntime] [  LOG] [17:47:28] [_Auto-Enable-PB-Ghost]  \$0f0[INFO]   \$z\$0c0 10   : LoadPBFromDB    : \$zFound PB in the widget. Attempting to match local record.
// [   ScriptRuntime] [  LOG] [17:47:28] [_Auto-Enable-PB-Ghost]  \$ff0[WARN]   \$z\$cc0 22   : LoadPersonalBes : \$zNo local PB ghost found for map UID: 6wm_j9UZGtiXk40hcMEINR8Py39 | attempting to download from leaderboard. | 0
// [   ScriptRuntime] [  LOG] [17:47:28] [_Auto-Enable-PB-Ghost]  \$0ff[DEBUG]  \$z\$0cc 265  : HasPersonalBest : \$z6wm_j9UZGtiXk40hcMEINR8Py39 | 43538
// [   ScriptRuntime] [ TRAC] [17:47:28] [MLHook]  MLHook preparing 9 outbound messages to ML
// [   ScriptRuntime] [  LOG] [17:47:29] [_Auto-Enable-PB-Ghost]  \$0f0[INFO]   \$z\$0c0 176  : MapUidToMapId   : \$zFound map ID: 689fa270-7763-4677-a1e9-8a9165960c50
// [   ScriptRuntime] [  LOG] [17:47:29] [_Auto-Enable-PB-Ghost]  \$0f0[INFO]   \$z\$0c0 12   : ConvertGhostToR : \$zConvertGhostToReplay: Attempting to download ghost from URL: https://core.trackmania.nadeo.live/mapRecords/408d28da-394a-4906-a57b-4f91d446d734/replay
// [   ScriptRuntime] [ERROR] [17:47:30] [_Auto-Enable-PB-Ghost]  Script execution timeout exceeded! (1000 milliseconds)
// [   ScriptRuntime] [ERROR] [17:47:30] [_Auto-Enable-PB-Ghost]      #0  void net::ConvertGhostToReplay(const string&in url, const string&in mapRecordId) (C:/Users/ar/OpenplanetNext/Plugins/_Auto-Enable-PB-Ghost/src/index/net.as line 31)
// [   ScriptRuntime] [ERROR] [17:47:30] [_Auto-Enable-PB-Ghost]      #1  void Index::AddReplayToDatabase(const string&in path, const string&in mapRecordId = "") (C:/Users/ar/OpenplanetNext/Plugins/_Auto-Enable-PB-Ghost/src/index/manager.as line 37)
// [   ScriptRuntime] [ERROR] [17:47:30] [_Auto-Enable-PB-Ghost]      #2  void Loader::DownloadPBFromLeaderboardAndLoadLocal(const string&in mapUid) (C:/Users/ar/OpenplanetNext/Plugins/_Auto-Enable-PB-Ghost/src/pb/loader/lb.as line 129)
// [   ScriptRuntime] [ERROR] [17:47:30] [_Auto-Enable-PB-Ghost]      #3  void Loader::LoadPersonalBestGhostFromTime(const string&in mapUid, int playerPBTime) (C:/Users/ar/OpenplanetNext/Plugins/_Auto-Enable-PB-Ghost/src/pb/loader/local.as line 23)
// [   ScriptRuntime] [ERROR] [17:47:30] [_Auto-Enable-PB-Ghost]      #4  void Loader::LoadPBFromDB() (C:/Users/ar/OpenplanetNext/Plugins/_Auto-Enable-PB-Ghost/src/pb/loader/local.as line 11)
// [   ScriptRuntime] [ERROR] [17:47:30] [_Auto-Enable-PB-Ghost]      #5  void Loader::LoadPB() (C:/Users/ar/OpenplanetNext/Plugins/_Auto-Enable-PB-Ghost/src/pb/loader/manager.as line 20)
// [   ScriptRuntime] [ERROR] [17:47:30] [_Auto-Enable-PB-Ghost]      #6  void MapTracker::MapMonitor() (C:/Users/ar/OpenplanetNext/Plugins/_Auto-Enable-PB-Ghost/src/map/monitor.as line 28)