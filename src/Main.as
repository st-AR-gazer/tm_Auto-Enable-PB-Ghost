void Main() {
    Index::SetDatabasePath();

    if (S_markPluginLoadedPBs == "very secret id") { S_markPluginLoadedPBs = GetApp().LocalPlayerInfo.Trigram.SubStr(0, 1); }

    IO::CreateFolder(IO::FromUserGameFolder("Replays/zzAutoEnablePBGhost"));
    IO::CreateFolder(IO::FromUserGameFolder("Replays/zzAutoEnablePBGhost/Ghosts"));
    
    startnew(MapTracker::MapMonitor);
    startnew(PBVisibilityHook::InitializeHook);

    if (!IO::FileExists(Index::GetDatabasePath())) {
        Index::InitializeDatabase();
    }
}