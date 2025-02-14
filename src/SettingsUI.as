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
        S_onlyUseLocalPBs = UI::Checkbox("Use leaderboard as a last resort for loading a pb", S_onlyUseLocalPBs);
        S_onlyLoadFastestPB = UI::Checkbox("Only Load One PB Ghost If Multiple Are Found", S_onlyLoadFastestPB);

        UI::Dummy(vec2(0, 10));
        UI::Text("Indexing");
        UI::Separator();

#if DEPENDENCY_BETTERREPLAYSFOLDER
        S_useBetterReplaysFolder = UI::Checkbox("Use the folder 'Trackmania2020/Replays_Offload/' for all your replays", S_useBetterReplaysFolder);
        if (S_enableGhosts) { S_customIndexLocation = IO::FromUserGameFolder("Replays_Offload/"); }

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

        UI::Dummy(vec2(0, 10));

        if (UI::Button("ReInitialize Database")) { Index::InitializeDatabase(); }

        if (UI::Button("Reindex Replays folder")) { startnew(Index::IndexReplays); }
        if (Index::isIndexingReplaysFolder) { UI::SameLine(); UI::Text("Indexing file: " + Index::currentReplaysFileNumber + " out of " + Index::totalReplaysFileNumber); }
        if (Index::isIndexingReplaysFolder && Index::currentReplaysFileNumber > 3754 && Index::currentReplaysFileNumber < 5483) { UI::SameLine(); UI::Text("|  Sorry for the indexing taking some time Sadge!"); }
        if (Index::isIndexingReplaysFolder && Index::currentReplaysFileNumber > 9950 && Index::currentReplaysFileNumber < 10100) { UI::SameLine(); UI::Text("|  Damn, over a 10000 you got a lot of replays huh..."); }
        if (Index::currentReplaysFileNumber > 0) { UI::ProgressBar(float(Index::currentReplaysFileNumber) / Index::totalReplaysFileNumber, vec2(-1, 0)); }
        UI::PushItemWidth(300.0f);
        if (Index::isIndexingReplaysFolder) { Index::NOD_INDEXING_PROCESS_LIMIT = UI::SliderInt("Indexing Speed", Index::NOD_INDEXING_PROCESS_LIMIT, 1, 10); }
        UI::PopItemWidth();

        if (UI::Button("Reindex entire game dirs")) { startnew(Index::StartGameFolderFullIndexing); }

        if (UI::Button("Index Custom Index Location")) { startnew(CoroutineFuncUserdataString(Index::StartCustomFolderIndexing), S_customIndexLocation); }
        // UI::PushItemWidth(300.0f);
        // if (Index::isIndexingFolder) { Index::FOLDER_INDEXING_PROCESS_LIMIT = UI::SliderInt("Indexing Speed", Index::FOLDER_INDEXING_PROCESS_LIMIT, 1, 10); }
        // UI::PopItemWidth();

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

        if (ManualIndex::indexingInProgress) { 
            UI::SameLine();
            if (UI::ButtonColored("Stop Indexing", 0.9f, 0.1f, 0.1f)) { ManualIndex::Stop(); }
        }

        if (Index::enqueueingFilesInProgress) {
            UI::SameLine();
            UI::BeginDisabled();
            if (UI::ButtonColored("Stop Enqueueing", 0.9f, 0.1f, 0.1f)) { Index::StopEnqueueing(); }
            UI::EndDisabled();
        }

        if (Index::isIndexingFolder) { 
            UI::SameLine();
            if (UI::ButtonColored("Stop Indexing Folder", 0.9f, 0.1f, 0.1f)) { Index::StopIndexingFolder(); }
        }

        S_customIndexLocation = UI::InputText("Custom Index Location", S_customIndexLocation);

        if (ManualIndex::indexingInProgress || ManualIndex::currentMessage != "") UI::Text(ManualIndex::currentMessage);
        if (ManualIndex::indexingInProgress) UI::ProgressBar(ManualIndex::GetProgress(), vec2(-0.1, 0));

        if (Index::enqueueingFilesInProgress) {
            UI::Text("Enqueueing files... Latest file indexed: " + Index::lastFileIndexed);
            int remaining = Index::totalFilesToEnqueue - Index::filesEnqueued;
            UI::Text("Files remaining: " + remaining);
            float progress = Index::totalFilesToEnqueue > 0 ? float(Index::filesEnqueued) / float(Index::totalFilesToEnqueue) : 0.0f;
            UI::ProgressBar(progress, vec2(-1, 0));
        }

        if (Index::isIndexingFolder) {
            UI::Text("Indexing file: " + Index::currentFolderFileNumber + " out of " + Index::totalFolderFileNumber);

            // FIXME: this currently doesn't work...
            if (Index::speedCount > 0) {
                UI::SameLine();
                UI::Text(" | Speed: " + Index::speedCount + " files/s");
                uint remain = Index::totalFolderFileNumber - Index::currentFolderFileNumber;
                if (Index::speedCount > 0) {
                    float intervals = float(remain) / float(Index::speedCount);
                    float timeLeftSec = intervals;
                    float timeLeftMin = timeLeftSec / 60.0f;
                    UI::SameLine();
                    UI::Text(" | ETA: " + Text::Format("%.1f", timeLeftMin) + " min");
                }
            }

            if (Index::currentFolderFileNumber > 0) {
                UI::ProgressBar(float(Index::currentFolderFileNumber) / Index::totalFolderFileNumber, vec2(-1, 0));
            }

            if (Index::currentFolderFileNumber > 3754 && Index::currentFolderFileNumber < 5483) {
                UI::SameLine();
                UI::Text("|  Sorry for the indexing taking some time Sadge!");
            }
            if (Index::currentFolderFileNumber > 9950 && Index::currentFolderFileNumber < 10100) {
                UI::SameLine();
                UI::Text("|  Damn, over a 10000 you got a lot of replays huh...");
            }
        }



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
bool S_onlyUseLocalPBs = false;
[Setting hidden]
bool S_onlyLoadFastestPB = true;

[Setting hidden]
string S_customIndexLocation = IO::FromUserGameFolder("Replays/Autosaves/");


[Setting hidden]
bool S_enableGhosts = true;

[SettingsTab name="Testing" icon="DevTo" order="10"]
void RT_Testing() {
    if (UI::BeginChild("Testing Settings", vec2(0, 0), true)) {
        UI::Text("Testing Options");

        // if (UI::Button("Test unload g++")) { startnew(UnloadGhost); }

        if (UI::Button("Load Saved pb")) { startnew(Loader::LoadLocalPBsUntillNextMapForEasyLoading); }


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
        log("Replay: " + replay.FileName + " | " + replay.BestTime + " | " + replay.Path, LogLevel::Info, 219, "testGetReplaysFromDB");
    }
}

string S_TESTING_uid_query = "3oE4EbXGlBdgPheR1ECc4xT2qCd";