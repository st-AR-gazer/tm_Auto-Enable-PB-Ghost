[SettingsTab name="General" icon="" order="1"]
void RT_Settings() {
    if (UI::BeginChild("General Settings", vec2(0, 0), true)) {
        UI::Text("General Options");
        UI::Separator();

        UI::Text("Ghosts");

        S_loadPBs = UI::Checkbox("Load Ghost on Map Enter", S_loadPBs);
        S_markPluginLoadedPBs = UI::InputText("Special Ghost Plugin Indicator", S_markPluginLoadedPBs);
        S_onlyUseLocalPBs = UI::Checkbox("Use leaderboard as a last resort for loading a pb", S_onlyUseLocalPBs);
        S_onlyLoadFastestPB = UI::Checkbox("Only Load One PB Ghost If Multiple Are Found", S_onlyLoadFastestPB);

        UI::Separator();
        UI::Text("Indexing");

        if (UI::Button("Reindex Replays folder")) { Index::IndexReplays(); }

        if (UI::Button("Reindex entire game dirs")) { Index::StartFolderIndexing(); }

        if (UI::Button("Index Custom Index Location")) { Index::StartCustomFolderIndexing(S_customIndexLocation); }
        S_customIndexLocation = UI::InputText("Custom Index Location", S_customIndexLocation);

        if (UI::ButtonColored("Rebuild database", 0.0f, 0.5f, 0.0f)) { Index::RebuildDatabaseFromScratch(); }

        UI::EndChild();
    }
}

[Setting hidden]
bool S_loadPBs = true;
[Setting hidden]
string S_markPluginLoadedPBs = ;
[Setting hidden]
bool S_onlyUseLocalPBs = false;
[Setting hidden]
bool S_onlyLoadFastestPB = true;

[Setting hidden]
string S_customIndexLocation = IO::FromUserGameFolder("Replays/Autosaves/");