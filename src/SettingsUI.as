[SettingsTab name="General" icon="Cog" order="1"]
void RT_Settings() {
    FILE_EXPLORER_BASE_RENDERER();

    if (UI::BeginChild("General Settings", vec2(0, 0), true)) {
        UI::Text("General Options");
        UI::Text("Ghosts");
        UI::Separator();

        S_enableGhosts = UI::Checkbox("Load Ghost On Map Enter (enable plugin)", S_enableGhosts);
        UI::PushItemWidth(25.0f);
        S_markPluginLoadedPBs = UI::InputText("Special Ghost Plugin Indicator", S_markPluginLoadedPBs, false, UI::InputTextFlags::CharsUppercase | UI::InputTextFlags::AlwaysOverwrite | UI::InputTextFlags::NoHorizontalScroll); 
        UI::PopItemWidth();
        if (S_markPluginLoadedPBs.Length > 1) { S_markPluginLoadedPBs = S_markPluginLoadedPBs.SubStr(0, 1); }
        if (S_markPluginLoadedPBs.Length == 0) { S_markPluginLoadedPBs = "P"; }
        S_useLeaderBoardAsLastResort = UI::Checkbox("Use leaderboard as a last resort for loading a pb", S_useLeaderBoardAsLastResort);
        S_onlyLoadFastestPB = UI::Checkbox("Only Load One PB Ghost If Multiple Are Found", S_onlyLoadFastestPB);

        UI::Dummy(vec2(0, 10));
        UI::Text("Indexing");
        UI::Separator();

#if DEPENDENCY_BETTERREPLAYSFOLDER
        S_useBetterReplaysFolder = UI::Checkbox("Use the folder 'Trackmania2020/Replays_Offload/' for all your replays", S_useBetterReplaysFolder);
        if (S_enableGhosts) { S_customFolderIndexingLocation = IO::FromUserGameFolder("Replays_Offload/"); }

        UI::Text("""
        This option will automatically move any replay file in your '/Trackmania2020/Replays/' folder 
        to the '/Trackmania2020/Replays_Offload/' folder. 
        This is very useful if you still want to have the benefit of faster startup times (since indexing 
        all the replays can take a while), but still want to use the functionality of this plugin.
        """
        );
#else
        UI::Checkbox("\\$aaaUse the folder 'Trackmania2020/Replays_Offload/' for all your replays", false);
        UI::Text("Note: Dependency 'Better Replays Folder' is required for this feature."); // Yet to be made :xdd:
#endif

// #if DEPENDENCY_ARCHIVIST
//      S_useArchivistGhostLoader = UI::Checkbox("Use Archivist for loading ghosts", S_useArchivistGhostLoader);
//         UI::Text("This also uses ghost files saved by Archivist, if you have it installed.");
// #else
//      UI::Checkbox("\\$aaaUse Archivist for loading ghosts", false);
//      UI::Text("Note: Dependency 'Archivist' is required for this feature.");
// #endif


        UI::Dummy(vec2(0, 10));

        if (UI::Button("ReInitialize Database")) { Index::InitializeDatabase(); }

        if (UI::Button("Reindex Replays folder")) { startnew(Index::Start_IndexReplayRecords); }
        if (Index::isIndexingReplaysFolder) { UI::SameLine(); UI::Text("Indexing file: " + Index::currentReplaysFileNumber + " out of " + Index::totalReplaysFileNumber); }
        if (Index::isIndexingReplaysFolder && Index::currentReplaysFileNumber > 3754 && Index::currentReplaysFileNumber < 5483) { UI::SameLine(); UI::Text("|  Sorry for the indexing taking some time Sadge!"); }
        if (Index::isIndexingReplaysFolder && Index::currentReplaysFileNumber > 9950 && Index::currentReplaysFileNumber < 10100) { UI::SameLine(); UI::Text("|  Damn, over a 10000 you got a lot of replays huh..."); }
        if (Index::currentReplaysFileNumber > 0) { UI::ProgressBar(float(Index::currentReplaysFileNumber) / Index::totalReplaysFileNumber, vec2(-1, 0)); }
        UI::PushItemWidth(300.0f);
        if (Index::isIndexingReplaysFolder) { Index::NOD_INDEXING_PROCESS_LIMIT = UI::SliderInt("Indexing Speed", Index::NOD_INDEXING_PROCESS_LIMIT, 1, 10); }
        UI::PopItemWidth();

        if (UI::Button("Reindex entire game dirs")) { startnew(CoroutineFuncUserdataString(Index::Start_RecursiveSearch), IO::FromUserGameFolder("")); }
        if (UI::Button("Index Custom Index Location")) { startnew(CoroutineFuncUserdataString(Index::Start_RecursiveSearch), S_customFolderIndexingLocation); }
        UI::PushItemWidth(300.0f);
        if (Index::f_isIndexing_FilePaths) { Index::RECURSIVE_SEARCH_BATCH_SIZE = UI::SliderInt("Indexing Speed", Index::RECURSIVE_SEARCH_BATCH_SIZE, 1, 10); }
        UI::PopItemWidth();

        UI::SameLine();

        if (UI::ButtonColored(Icons::FolderOpen + " Select Indexing Location", 0.5f, 0.9f, 0.1f)) {
            FileExplorer::fe_Start("Custom indexing location", true, "path", vec2(1, 1), IO::FromUserGameFolder("Replays/"), "", { "replay", "ghost" }, { "*" }); }

        auto exampleExlorer_Paths = FileExplorer::fe_GetExplorerById("Custom indexing location");
        if (exampleExlorer_Paths !is null && exampleExlorer_Paths.exports.IsSelectionComplete()) {
            auto paths = exampleExlorer_Paths.exports.GetSelectedPaths();
            if (paths !is null) { S_customFolderIndexingLocation = paths[0]; exampleExlorer_Paths.exports.SetSelectionComplete(); }
        }

        if (Index::f_isIndexing_FilePaths || Index::p_isIndexing_PrepareFiles || Index::d_isIndexing_AddToDatabase) { UI::SameLine(); if (UI::ButtonColored("Stop Indexing", 0.9f, 0.1f, 0.1f)) { Index::Stop_RecursiveSearch(); } }
        
        if (!S_H_showCustomIndexingLocationToolTip) {
            UI::SameLine();
            UI::Text(Icons::ChevronCircleDown);
            if (UI::IsItemHovered() && UI::IsItemClicked()) {
                S_H_showCustomIndexingLocationToolTip = true;
            }
        }
        if (S_H_showCustomIndexingLocationToolTip) UI::Text("If you have a custom backup folder for your replays, like me, you can use the 'Custom Index Location' \nto index all the files in that folder. This is useful if you have a lot of replays in a different folder than \nthe default one.");
        if (UI::IsItemHovered()) { 
            UI::SetTooltip("Click to show/hide the indexing tip."); 
            if (UI::IsItemClicked()) { S_H_showCustomIndexingLocationToolTip = false; }
        }

        S_customFolderIndexingLocation = UI::InputText("Custom Index Location", S_customFolderIndexingLocation);

        if (Index::IsIndexingInProgress() || Index::indexingMessage != "") UI::Text(Index::indexingMessage);
        if (Index::IsIndexingInProgress()) UI::ProgressBar(Index::GetIndexingProgressFraction(), vec2(-0.1, 0));

        if (Index::IsIndexingInProgress()) {
            UI::Text("""
    You are indexing through 'custom folders'. This can take a _while_ depending on the amount of files in the folder.
    If you have a _TON_ of files, I recomend doing this overnight or when you're not actively using the game...
    This is a one-time process, and will not be needed again, files are added to the database automatically after the initial indexing.
            """);
        }

        UI::Dummy(vec2(0, 10));
        UI::Separator();

        if (UI::ButtonColored("Delete database", 0.0f, 0.5f, 0.0f)) {
            Index::DeleteAndReInitialize();
        }

        UI::EndChild();
    }
}

[Setting hidden]
bool S_useBetterReplaysFolder = false;

[Setting hidden]
bool S_H_showCustomIndexingLocationToolTip = true;

[Setting hidden]
string S_markPluginLoadedPBs = "very secret id";
[Setting hidden]
bool S_useLeaderBoardAsLastResort = true;
[Setting hidden]
bool S_onlyLoadFastestPB = true;

[Setting hidden]
string S_customFolderIndexingLocation = IO::FromUserGameFolder("Replays/Autosaves/");


[Setting hidden]
bool S_enableGhosts = true;

[SettingsTab name="Testing" icon="DevTo" order="99999999999999999999"]
void RT_Testing() {
    if (UI::BeginChild("Testing Settings", vec2(0, 0), true)) {
        UI::Text("Testing Options");

        // if (UI::Button("Test unload g++")) { startnew(UnloadGhost); }

        // if (UI::Button("Load Saved pb")) { startnew(Loader::LoadLocalPBsUntillNextMapForEasyLoading); }


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
    auto test_replays = Index::GetReplaysFromDatabase(S_TESTING_uid_query);
    for (uint i = 0; i < test_replays.Length; i++) {
        auto replay = test_replays[i];
        log("Replay: " + replay.FileName + " | " + replay.BestTime + " | " + replay.Path, LogLevel::Info, 219, "testGetReplaysFromDB");
    }
}

string S_TESTING_uid_query = "3oE4EbXGlBdgPheR1ECc4xT2qCd";