[SettingsTab name="General" icon="Cog" order="1"]
void RT_Settings() {
    if (UI::BeginChild("General Settings", vec2(0, 0), true)) {

        RT_T_General();

        UI::Dummy(vec2(0, 20));

        RT_T_Indexing();

        UI::EndChild();
    }
}

[Setting hidden]
bool S_showPermissionWarnings = true;

[Setting hidden]
bool S_skipPathsWith_Archivist_InTheName = true;

[Setting hidden]
bool S_useBetterReplaysFolder = false;

[Setting hidden]
bool S_H_showCustomIndexingLocationToolTip = true;

[Setting hidden]
string S_customFolderIndexingLocation = IO::FromUserGameFolder("Replays_Offload/");

[Setting hidden]
string S_markPluginLoadedPBs = "very secret id";
[Setting hidden]
bool S_useLeaderboardWidgetAsAFallbackWhenAttemptingToLoadPBsOnAServer = false;


[Setting hidden]
bool S_enableGhosts = true;


void RenderInterface() {
    FILE_EXPLORER_BASE_RENDERER();
}