void Main() {
    Index::SetDatabasePath();

    IO::CreateFolder(IO::FromUserGameFolder("Replays/zzAutoEnablePBGhost"));
    IO::CreateFolder(IO::FromUserGameFolder("Replays/zzAutoEnablePBGhost/Ghosts"));
    
    startnew(MapTracker::MapMonitor);
    startnew(PBVisibilityHook::InitializeHook);

    if (!IO::FileExists(Index::GetDatabasePath())) {
        Index::InitializeDatabase();
    }
}