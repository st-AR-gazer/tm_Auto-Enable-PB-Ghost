namespace Loader::Unloader {

    void RemoveAll() {
        CGameGhostMgrScript@ gm = GhostMgrHelper::Get();
        if (gm is null) { log("GhostMgr unavailable.", LogLevel::Error); return; }

        auto list = Loader::GhostRegistry::Mutable();
        for (int i = int(list.Length) - 1; i >= 0; --i) {
            MwId id = list[i].instanceId;
            if (IsInstanceIdAlive(id)) { gm.Ghost_Remove(id); }
            Loader::GhostRegistry::Forget(list[i]);
        }
    }

    bool IsInstanceIdAlive(MwId id) {
        NGameGhostClips_SMgr@ clips = GhostClipsMgr::Get(GetApp());
        if (clips is null) return false;

        auto clip = GhostClipsMgr::GetGhostFromInstanceId(clips, id.Value);
        return clip !is null;
    }

}
