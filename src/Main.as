void Main() {
    if (!IO::FileExists(autosaves_index)) {
        IndexAndSaveToFile();
    }
    MapTracker::MapMonitor();
}

[Setting category="General" name="Re-index Autosaves folder manually"]
bool reindexAutosaves = false;

void Update(float dt) {
    if (reindexAutosaves) {
        IndexAndSaveToFile();
        reindexAutosaves = false;
    }
}

// void Render() {
//     if (UI::Begin("Main")) {
//         if (UI::Button("Is PB Loaded")) {
//             print(PBManager::IsPBLoaded());
//         }
//         if (UI::Button("Load Map")) {
//             PBManager::Initialize(GetApp());
//         }
//     }
//     UI::End();
// }