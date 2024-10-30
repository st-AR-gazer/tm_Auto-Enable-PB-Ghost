void Main() {
    PBVisibilityHook::InitializeHook();
    if (!IO::FileExists(autosaves_index)) {
        IndexAndSaveToFile();
    }
    MapTracker::MapMonitor();

    // Initialize PB Manager and visibility hook
    PBManager::Initialize(GetApp());
    PBManager::LoadPBFromIndex();
}

void OnDisabled() {
    PBVisibilityHook::UninitializeHook();
    PBManager::UnloadPB();
}

void OnDestroyed() {
    OnDisabled();
}