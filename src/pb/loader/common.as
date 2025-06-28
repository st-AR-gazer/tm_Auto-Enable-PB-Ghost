namespace Loader {

    bool IsPB(const string &in name)          { return name.ToLower().Contains("personal best"); }
    bool IsPluginGhost(const string &in nick) { return nick.Contains("$g$h$o$s$t$"); }
    bool IsGameGhost(const string &in nick)   { return nick.StartsWith("") && IsPB(nick); }
    // OBS: The game loaded ghosts DO NOT star with "?" they start with what ever this: "" is xD

    enum PBGhostSource { Clips, DfmNetwork, DfmPlaygroundScript, Disk, Leaderboard, GhostMgr }

    string SrcStr(PBGhostSource s) {
        switch (s) {
            case PBGhostSource::Clips:               return "Clips";
            case PBGhostSource::DfmNetwork:          return "DFM-N";
            case PBGhostSource::DfmPlaygroundScript: return "DFM-P";
            case PBGhostSource::Disk:                return "Disk";
            case PBGhostSource::Leaderboard:         return "LB";
            case PBGhostSource::GhostMgr:            return "GhostMgr";
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

    bool   gLbRequested = false;
    string gLbMapUid    = "";

    void  ResetLeaderboardPBFlag()  { gLbRequested = false; gLbMapUid = CurrentMapUID; }
    bool  AlreadyAskedLB(const string &in uid) { return gLbRequested && gLbMapUid == uid; }
    void  MarkAskedLB   (const string &in uid) { gLbRequested = true;  gLbMapUid = uid; }

}
