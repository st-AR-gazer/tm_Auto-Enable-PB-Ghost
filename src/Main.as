void Main() {
    DeleteIndexFile();

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

    PBManager::Update(dt);
}

void DeleteIndexFile() {
    string versionFilePath = IO::FromStorageFolder("version");
    if (!IO::FileExists(versionFilePath)) {
        _IO::File::WriteFile(versionFilePath, tostring(1));
        if (IO::FileExists(autosaves_index)) {
            IO::Delete(autosaves_index);
        }
    } else {
        string versionContent = _IO::File::ReadFileToEnd(versionFilePath);
        int version = Text::ParseInt(versionContent);
        if (version < 1) {
            if (IO::FileExists(autosaves_index)) {
                IO::Delete(autosaves_index);
            }
        }
    }
}