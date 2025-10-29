void Main() {
    if (S_markPluginLoadedPBs == "very secret id") {
        S_markPluginLoadedPBs = GetApp().LocalPlayerInfo.Trigram.SubStr(0, 1);
    }
}

void RenderMenu() {
    if (S_enableGhosts) {
        if (UI::MenuItem("\\$2c2" + Icons::SnapchatGhost + Icons::ToggleOn + "\\$z Auto Enable PB Ghost", "", true)) {
            S_enableGhosts = false;
        }
    } else {
        if (UI::MenuItem("\\$c22" + Icons::SnapchatGhost + Icons::ToggleOff + "\\$z Auto Enable PB Ghost", "", false)) {
            S_enableGhosts = true;
        }
    }
}