namespace Loader::Unloader {

    uint64 g_lastGhostMgrWarn = 0;

    void _LogGhostMgrUnavailable(const string &in fnName, int line) {
        uint64 now = Time::Now;
        if (now - g_lastGhostMgrWarn < 2000) return;
        g_lastGhostMgrWarn = now;
        log("GhostMgr unavailable.", LogLevel::Error, line, fnName, "", "\\$f80");
    }

    void RemoveAll() {
        CGameGhostMgrScript@ gm = GhostMgrHelper::Get();
        if (gm is null) { _LogGhostMgrUnavailable("RemoveAll", 5); return; }

        auto list = Loader::GhostRegistry::Mutable();
        for (int i = int(list.Length) - 1; i >= 0; --i) {
            MwId id = list[i].instanceId;
            if (IsInstanceIdAlive(id)) { gm.Ghost_Remove(id); }
            Loader::GhostRegistry::Forget(list[i]);
        }
    }

    bool IsInstanceIdAlive(MwId id) {
        NGameGhostClips_SMgr@ clips = GhostClipsMgr::GetSafe(GetApp());
        if (clips is null) return false;

        auto clip = GhostClipsMgr::GetGhostFromInstanceId(clips, id.Value);
        return clip !is null;
    }

    void RemoveGhost(CGameGhostMgrScript@ gm, MwId id) {
        if (gm is null) { _LogGhostMgrUnavailable("RemoveGhost", 24); return; }
        if (id.Value == 0) return;

        log("Removing ghost with ID: " + id.Value, LogLevel::Info, 27, "RemoveGhost", "", "\\$f80");

        Loader::GhostRegistry::Forget(Loader::GhostRegistry::FindByInstanceId(id));
        gm.Ghost_Remove(id);
    }

}
