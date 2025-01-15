namespace Loader {
    bool isPBVisible = false;

    void ToggleLeaderboardPB() {
        string pid = GetApp().LocalPlayerInfo.WebServicesUserId;
        if (pid == "") {
            log("Loader::ToggleLeaderboardPB: Player ID is empty. Cannot toggle leaderboard PB ghost.", LogLevel::Error);
            return;
        }

        MLHook::Queue_SH_SendCustomEvent("TMGame_Record_ToggleGhost", {pid});
        isPBVisible = !isPBVisible;
        log("Loader::ToggleLeaderboardPB: Toggled PB ghost visibility to: " + (isPBVisible ? "Visible" : "Hidden"), LogLevel::Info);
    }

    void SetPBVisibility(bool shouldShow) {
        isPBVisible = shouldShow;
        log("Loader::SetPBVisibility: PB ghost visibility set to: " + (shouldShow ? "Visible" : "Hidden"), LogLevel::Info);
    }
}
