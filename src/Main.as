void Main() {
    if (S_markPluginLoadedPBs == "i") { S_markPluginLoadedPBs = GetApp().LocalPlayerInfo.Trigram.SubStr(0, 1); }

    startnew(Hotkeys::InitHotkeys);
    // Ghost::SetMapNod();
    startnew(MapTracker::MapMonitor);
    startnew(PBVisibilityHook::InitializeHook);
}