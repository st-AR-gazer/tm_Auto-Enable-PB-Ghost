void Main() {
    if (S_markPluginLoadedPBs == "i") {
        S_markPluginLoadedPBs = GetApp().LocalPlayerInfo.Trigram.SubStr(0, 1);
    }
}