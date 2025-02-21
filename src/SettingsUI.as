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
        S_allowLoadingPBsOnServers = UI::Checkbox("Allow loading PB ghosts on servers", S_allowLoadingPBsOnServers);
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

        if (UI::Button("Reindex Replays Folder")) { startnew(Index::Start_IndexReplayRecords); }

if (Index::nodIsIndexing) {
    UI::SameLine();
    UI::Text("Indexing file: " + Index::nodCurrentCount + " out of " + Index::nodTotalCount);
    
    UI::PushItemWidth(500.0f);
    
    if (Index::nodPhaseGather) {
        Index::NOD_GATHER_BATCH_SIZE = UI::SliderInt("Indexing Speed (Gather)", Index::NOD_GATHER_BATCH_SIZE, 1, 50);
        if (Index::NOD_GATHER_BATCH_SIZE > 25) UI::Text("\\$ff0Warning: High values may cause lag.");
    }
    if (Index::nodPhasePrepare && !Index::nodPhaseGather) {
        Index::NOD_PREPARE_BATCH_SIZE = UI::SliderInt("Indexing Speed (Prepare)", Index::NOD_PREPARE_BATCH_SIZE, 1, 25);
        if (Index::NOD_PREPARE_BATCH_SIZE > 10) UI::Text("\\$ff0Warning: High values may cause lag.");
    }
    if (Index::nodPhaseAdd && !Index::nodPhasePrepare && !Index::nodPhaseGather) {
        Index::NOD_ADD_BATCH_SIZE = UI::SliderInt("Indexing Speed (Database)", Index::NOD_ADD_BATCH_SIZE, 1, 25);
        if (Index::NOD_ADD_BATCH_SIZE > 10) UI::Text("\\$ff0Warning: High values may cause lag.");
    }
    
    UI::PopItemWidth();
    
    UI::ProgressBar(Index::GetNodIndexProgressFraction(), vec2(-0.1, 0));

    UI::Text(Index::nodIndexingMessage);

    if (UI::ButtonColored("Stop Indexing", 0.9f, 0.1f, 0.1f)) { Index::Stop_NodIndexing(); }
}



        if (UI::Button("Reindex entire game dirs")) { startnew(CoroutineFuncUserdataString(Index::Start_RecursiveSearch), IO::FromUserGameFolder("")); }
        if (UI::Button("Index Custom Index Location")) { startnew(CoroutineFuncUserdataString(Index::Start_RecursiveSearch), S_customFolderIndexingLocation); }

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

        UI::PushItemWidth(500.0f);
        if (Index::f_isIndexing_FilePaths) {
                Index::RECURSIVE_SEARCH_BATCH_SIZE = UI::SliderInt("Indexing Speed", Index::RECURSIVE_SEARCH_BATCH_SIZE, 1, 600);
            if (Index::RECURSIVE_SEARCH_BATCH_SIZE > 200) UI::Text("\\$ff0Warning: High batch sizes can cause the game to freeze, and potentially stop the indexing process, use with caution.");
        }
        if (Index::p_isIndexing_PrepareFiles && !Index::f_isIndexing_FilePaths) {
                Index::PREPARE_FILES_BATCH_SIZE = UI::SliderInt("Indexing Speed", Index::PREPARE_FILES_BATCH_SIZE, 1, 10);
            if (Index::PREPARE_FILES_BATCH_SIZE > 5) UI::Text("\\$ff0Warning: High batch sizes can cause the game to freeze, and potentially stop the indexing process, use with caution.");
        }
        if (Index::d_isIndexing_AddToDatabase && !Index::p_isIndexing_PrepareFiles && !Index::f_isIndexing_FilePaths) {
                Index::ADD_FILES_TO_DATABASE_BATCH_SIZE = UI::SliderInt("Indexing Speed", Index::ADD_FILES_TO_DATABASE_BATCH_SIZE, 1, 25);
            if (Index::ADD_FILES_TO_DATABASE_BATCH_SIZE > 15) UI::Text("\\$ff0Warning: High batch sizes can cause the game to freeze, and potentially stop the indexing process, use with caution.");
        }
        UI::PopItemWidth();
        UI::SameLine();
        if (Index::IsIndexingInProgress()) S_skipPathsWith_Archivist_InTheName = UI::Checkbox("Skip 'Archivist' paths", S_skipPathsWith_Archivist_InTheName);

        if (Index::IsIndexingInProgress() || Index::indexingMessage != "") UI::Text(Index::indexingMessage);
        if (Index::IsIndexingInProgress() || Index::indexingMessageDebug != "") UI::Text(Index::indexingMessageDebug);
        if (Index::IsIndexingInProgress() && !Index::f_isIndexing_FilePaths) UI::ProgressBar(Index::Get_Indexing_ProgressFraction(), vec2(-0.1, 0));

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
bool S_skipPathsWith_Archivist_InTheName = true;

[Setting hidden]
bool S_useBetterReplaysFolder = false;

[Setting hidden]
bool S_H_showCustomIndexingLocationToolTip = true;

[Setting hidden]
string S_markPluginLoadedPBs = "very secret id";
[Setting hidden]
bool S_allowLoadingPBsOnServers = false;
[Setting hidden]
bool S_useLeaderBoardAsLastResort = true;
[Setting hidden]
bool S_onlyLoadFastestPB = true;

[Setting hidden]
string S_customFolderIndexingLocation = IO::FromUserGameFolder("Replays/Autosaves/");


[Setting hidden]
bool S_enableGhosts = true;