namespace Loader {
    bool IsPB(const string &in name)           { return name.ToLower().Contains("personal best"); }
    bool IsPluginGhost(const string &in nick)  { return nick.Contains("$g$h$o$s$t$"); }

    enum PBGhostSource { Clips, DfmClient, DfmArena, Disk, Leaderboard }

    string SrcStr(PBGhostSource s) {
        switch (s) {
            case PBGhostSource::Clips:       return "Clips";
            case PBGhostSource::DfmClient:   return "DFM-C";
            case PBGhostSource::DfmArena:    return "DFM-A";
            case PBGhostSource::Disk:        return "Disk";
            case PBGhostSource::Leaderboard: return "LB";
        }
        return "?";
    }

    class PBGhost {
        PBGhostSource src;
        uint          time;
        string        name;
        MwId          id;
        string        path;
        string        trigram;

        bool IsPlugin() const { return IsPluginGhost(name); }

        PBGhost(PBGhostSource s, uint t, const string &in n, MwId i, const string &in p = "", const string &in tri = "") {
            src     = s;
            time    = t;
            name    = n;
            id      = i;
            path    = p;
            trigram = tri;
        }
    }

    funcdef bool Predicate();

    bool WaitUntil(Predicate@ pred, uint timeoutMs = 4000) {
        const uint start = Time::Now;
        while (!pred() && Time::Now - start < timeoutMs) yield();
        return pred();
    }

    bool WaitUntilFileExists(const string &in path, uint timeoutMs = 2000) {
        const uint start = Time::Now;
        while (!IO::FileExists(path) && Time::Now - start < timeoutMs) yield();
        return IO::FileExists(path);
    }
}
