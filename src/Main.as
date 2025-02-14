void Main() {
    Index::SetDatabasePath();
    Hotkeys::InitHotkeys();

    if (S_markPluginLoadedPBs == "very secret id") { S_markPluginLoadedPBs = GetApp().LocalPlayerInfo.Trigram.SubStr(0, 1); }

    IO::CreateFolder(IO::FromUserGameFolder("Replays/zzAutoEnablePBGhost"));
    
    startnew(MapTracker::MapMonitor);
    startnew(PBVisibilityHook::InitializeHook);

    if (!IO::FileExists(Index::GetDatabasePath())) {
        Index::InitializeDatabase();
    }
}