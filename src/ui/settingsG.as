void RT_T_General() {
    UI::Text("General Options");
    UI::Separator();

    S_enableGhosts = UI::Checkbox("Load Ghost On Map Enter (enable plugin)", S_enableGhosts);
    UI::PushItemWidth(25.0f);
    S_markPluginLoadedPBs = UI::InputText("Special Ghost Plugin Indicator", S_markPluginLoadedPBs, false, UI::InputTextFlags::CharsUppercase | UI::InputTextFlags::AlwaysOverwrite | UI::InputTextFlags::NoHorizontalScroll); 
    UI::PopItemWidth();
    if (S_markPluginLoadedPBs.Length > 1) { S_markPluginLoadedPBs = S_markPluginLoadedPBs.SubStr(0, 1); }
    if (S_markPluginLoadedPBs.Length == 0) { S_markPluginLoadedPBs = "P"; }
    S_useLeaderboardWidgetAsAFallbackWhenAttemptingToLoadPBsOnAServer = UI::Checkbox("Use the leaderboard widget as a fallback when trying to enable PBs on a server", S_useLeaderboardWidgetAsAFallbackWhenAttemptingToLoadPBsOnAServer);
    S_useLeaderBoardAsLastResort = UI::Checkbox("Use leaderboard as a last resort for loading a pb", S_useLeaderBoardAsLastResort);
    S_onlyLoadFastestPB = UI::Checkbox("Only Load One PB Ghost If Multiple Are Found", S_onlyLoadFastestPB);

    if (UI::Button("Reset general settings")) {
        S_enableGhosts = true;
        S_markPluginLoadedPBs = GetApp().LocalPlayerInfo.Trigram.SubStr(0, 1).ToUpper();
        S_useLeaderboardWidgetAsAFallbackWhenAttemptingToLoadPBsOnAServer = false;
        S_useLeaderBoardAsLastResort = true;
        S_onlyLoadFastestPB = true;
    }
}