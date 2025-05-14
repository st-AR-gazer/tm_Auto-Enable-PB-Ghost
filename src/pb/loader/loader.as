namespace Loader::GhostLoad {

    bool InjectReplay(const string &in path, CGameGhostMgrScript@ gm) {
        auto dfm  = GetApp().Network.ClientManiaAppPlayground.DataFileMgr;
        auto task = dfm.Replay_Load(path);
        while (task.IsProcessing) yield();

        if (!task.HasSucceeded) return false;

        for (uint i = 0; i < task.Ghosts.Length; ++i) {
            CGameGhostScript@ g = cast<CGameGhostScript>(task.Ghosts[i]);
            g.IdName   = "Personal best";
            /* "$fd8" <-- yellow-ish, used for testing */ 
            /* "$5d8" <-- green-ish, non default pb color */
            /* "$7fa" <-- green-ish, default pb color */
            g.Nickname = "$fd8"+"Personal Best"+"$g$h$o$s$t$" + Math::Rand(0, 999);
            g.Trigram  = "PB"+S_markPluginLoadedPBs;
            gm.Ghost_Add(g);
        }
        return true;
    }
}