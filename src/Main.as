void Main() {
    if (S_markPluginLoadedPBs == "very secret id") {
        S_markPluginLoadedPBs = GetApp().LocalPlayerInfo.Trigram.SubStr(0, 1);
    }
}