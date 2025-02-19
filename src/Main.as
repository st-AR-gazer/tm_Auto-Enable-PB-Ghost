void Main() {
    Index::SetDatabasePath();
    Hotkeys::InitHotkeys();
    Ghost::SetMapNod();

    if (S_markPluginLoadedPBs == "very secret id") { S_markPluginLoadedPBs = GetApp().LocalPlayerInfo.Trigram.SubStr(0, 1); }

    IO::CreateFolder(IO::FromUserGameFolder(Index::GetRelative_zzReplayPath()));
    
    startnew(MapTracker::MapMonitor);
    startnew(PBVisibilityHook::InitializeHook);

    if (!IO::FileExists(Index::GetDatabasePath())) {
        Index::InitializeDatabase();
    }
}