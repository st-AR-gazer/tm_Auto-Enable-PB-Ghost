void Main() {
    PBVisibilityHook::InitializeHook();
    if (!IO::FileExists(autosaves_index)) {
        IndexAndSaveToFile();
    }
    startnew(MapTracker::MapMonitor);

    PBManager::Initialize(GetApp());
    // PBManager::LoadPB();
}

void OnDisabled() {
    PBVisibilityHook::UninitializeHook();
    PBManager::UnloadAllPBs();
}

void OnDestroyed() {
    OnDisabled();
}

void Update(float dt) {
    if (reindexAutosaves) {
        reindexAutosaves = false;
        IndexAndSaveToFile();
    }
}