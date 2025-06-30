namespace Loader {
    enum SourceFormat {
        ReplayFile,
        GhostFile
    }

    SourceFormat FromNodeType(const string &in nodeType) {
        string t = nodeType.ToLower();
        if (t == "cgamectnghost" || t == "cgameghostscript") return SourceFormat::GhostFile;
        return SourceFormat::ReplayFile;
    }

    class PBGhost {
        CGameGhostScript@ script;
        MwId              instanceId;
        string            path;
        SourceFormat      srcFmt;
        uint              durationMs;
        uint64            loadedAt;

        PBGhost(CGameGhostScript@ g, MwId id, const string &in p, SourceFormat f) {
            @script    = g;
            instanceId = id;
            path       = p;
            srcFmt     = f;
            durationMs = g.Result.Time;
            loadedAt   = Time::Now;
        }
    }


    namespace GhostRegistry {
        array<PBGhost@> s_items;

        void Track(PBGhost@ g) { if (g !is null) s_items.InsertLast(g); }

        void Forget(PBGhost@ g) {
            for (int i = int(s_items.Length) - 1; i >= 0; --i) {
                if (s_items[i] is g) {
                    s_items.RemoveAt(i);
                    break;
                }
            }
        }

        void Clear() { s_items.RemoveRange(0, s_items.Length); }

        const array<PBGhost@>@ All() { return s_items; }

        array<PBGhost@>@ Mutable() { return s_items; }

        uint Count() { return s_items.Length; }

        PBGhost@ FindByInstanceId(MwId id) {
            for (uint i = 0; i < s_items.Length; ++i) {
                if (s_items[i].instanceId.Value == id.Value) return s_items[i];
            }
            return null;
        }
    }

}