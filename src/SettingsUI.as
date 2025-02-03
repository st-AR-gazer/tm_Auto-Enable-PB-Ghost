[SettingsTab name="General" icon="" order="1"]
void RT_Settings() {
    FILE_EXPLORER_BASE_RENDERER();

    if (UI::BeginChild("General Settings", vec2(0, 0), true)) {
        UI::Text("General Options");
        UI::Separator();

        UI::Text("Ghosts");

        S_loadPBs = UI::Checkbox("Load Ghost on Map Enter", S_loadPBs);
        S_markPluginLoadedPBs = UI::InputText("Special Ghost Plugin Indicator", S_markPluginLoadedPBs);
        S_onlyUseLocalPBs = UI::Checkbox("Use leaderboard as a last resort for loading a pb", S_onlyUseLocalPBs);
        S_onlyLoadFastestPB = UI::Checkbox("Only Load One PB Ghost If Multiple Are Found", S_onlyLoadFastestPB);
        S_enableGhosts = UI::Checkbox("Load Ghost On Map Enter", S_enableGhosts);

        UI::Separator();
        UI::Text("Indexing");

        if (UI::Button("ReInitialize Database")) { Index::InitializeDatabase(); }

        if (UI::Button("Reindex Replays folder")) { startnew(Index::IndexReplays); }
        if (Index::isIndexingReplaysFolder) { UI::SameLine(); UI::Text("Indexing file: " + Index::currentReplaysFileNumber + " out of " + Index::totalReplaysFileNumber); }
        if (Index::isIndexingReplaysFolder && Index::currentReplaysFileNumber > 3754 && Index::currentReplaysFileNumber < 5483) { UI::SameLine(); UI::Text("|  Sorry for the indexing taking some time Sadge!"); }
        if (Index::isIndexingReplaysFolder && Index::currentReplaysFileNumber > 9950 && Index::currentReplaysFileNumber < 10100) { UI::SameLine(); UI::Text("|  Damn, over a 10000 you got a lot of replays huh..."); }
        if (Index::isIndexingReplaysFolder) { Index::NOD_INDEXING_PROCESS_LIMIT = UI::SliderInt("Indexing Speed", Index::NOD_INDEXING_PROCESS_LIMIT, 1, 10); }

        if (UI::Button("Reindex entire game dirs")) { startnew(Index::StartGameFolderFullIndexing); }
        if (Index::isIndexingFolder) { UI::SameLine(); UI::Text("Indexing file: " + Index::currentFolderFileNumber + " out of " + Index::totalFolderFileNumber); }
        if (Index::isIndexingFolder && Index::currentFolderFileNumber > 3754 && Index::currentFolderFileNumber < 5483) { UI::SameLine(); UI::Text("|  Sorry for the indexing taking some time Sadge!"); }
        if (Index::isIndexingFolder && Index::currentFolderFileNumber > 9950 && Index::currentFolderFileNumber < 10100) { UI::SameLine(); UI::Text("|  Damn, over a 10000 you got a lot of replays huh..."); }
        if (Index::isIndexingFolder) { Index::FOLDER_INDEXING_PROCESS_LIMIT = UI::SliderInt("Indexing Speed", Index::FOLDER_INDEXING_PROCESS_LIMIT, 1, 10); }

        if (UI::Button("Index Custom Index Location")) { startnew(CoroutineFuncUserdataString(Index::StartCustomFolderIndexing), S_customIndexLocation); }
        if (Index::isIndexingFolder) { UI::SameLine(); UI::Text("Indexing file: " + Index::currentFolderFileNumber + " out of " + Index::totalFolderFileNumber); }
        if (Index::isIndexingFolder && Index::currentFolderFileNumber > 3754 && Index::currentFolderFileNumber < 5483) { UI::SameLine(); UI::Text("|  Sorry for the indexing taking some time Sadge!"); }
        if (Index::isIndexingFolder && Index::currentFolderFileNumber > 9950 && Index::currentFolderFileNumber < 10100) { UI::SameLine(); UI::Text("|  Damn, over a 10000 you got a lot of replays huh..."); }
        if (Index::isIndexingFolder) { Index::FOLDER_INDEXING_PROCESS_LIMIT = UI::SliderInt("Indexing Speed", Index::FOLDER_INDEXING_PROCESS_LIMIT, 1, 10); }

        UI::SameLine();

        if (UI::ButtonColored(Icons::FolderOpen + " Select Indexing Location", 0.5f, 0.9f, 0.1f)) {
            FileExplorer::fe_Start(
                "Custom indexing location",
                true,
                "path",
                vec2(1, 1),
                IO::FromUserGameFolder("Replays/"),
                "",
                { "replay", "ghost" },
                { "*" }

            );
        }

        auto exampleExlorer_Paths = FileExplorer::fe_GetExplorerById("Custom indexing location");
        if (exampleExlorer_Paths !is null && exampleExlorer_Paths.exports.IsSelectionComplete()) {
            auto paths = exampleExlorer_Paths.exports.GetSelectedPaths();
            if (paths !is null) {
                S_customIndexLocation = paths[0];
                exampleExlorer_Paths.exports.SetSelectionComplete();
            }
        }

        S_customIndexLocation = UI::InputText("Custom Index Location", S_customIndexLocation);

        if (UI::ButtonColored("Delete database", 0.0f, 0.5f, 0.0f)) { Index::RebuildDatabaseFromScratch(); }

        UI::EndChild();
    }
}

[Setting hidden]
bool S_loadPBs = true;
[Setting hidden]
string S_markPluginLoadedPBs = "very secret id";
[Setting hidden]
bool S_onlyUseLocalPBs = false;
[Setting hidden]
bool S_onlyLoadFastestPB = true;

[Setting hidden]
string S_customIndexLocation = IO::FromUserGameFolder("Replays/Autosaves/");


[Setting hidden]
bool S_enableGhosts = true;

[SettingsTab name="Testing" icon="DevTo" order="10"]
void RT_Testing() {
    if (!Meta::IsDeveloperMode()) return;

    if (UI::BeginChild("Testing Settings", vec2(0, 0), true)) {
        UI::Text("Testing Options");

        // if (UI::Button("Test unload g++")) { startnew(UnloadGhost); }

        // if (UI::Button("Find PB")) {  }


        UI::Separator();

        if (UI::Button("Load PB")) { startnew(Loader::LoadPB); }
        if (UI::Button("Remove PB")) { Loader::HidePB(); }

        UI::Separator();

        if (UI::Button("Load PB (Local)")) { startnew(testGetReplaysFromDB); }
        S_TESTING_uid_query = UI::InputText("UID Query", S_TESTING_uid_query);

        if (Loader::IsPBLoaded_Clips()) { UI::Text("PB Loaded"); }
        else { UI::Text("PB Not Loaded"); }

        UI::EndChild();
    }
}

void testGetReplaysFromDB() {
    auto test_replays = Index::GetReplaysFromDB(S_TESTING_uid_query);
    for (uint i = 0; i < test_replays.Length; i++) {
        auto replay = test_replays[i];
        log("Replay: " + replay.FileName + " | " + replay.BestTime + " | " + replay.Path, LogLevel::Info, 0, "testGetReplaysFromDB");
    }
}

string S_TESTING_uid_query = "3oE4EbXGlBdgPheR1ECc4xT2qCd";