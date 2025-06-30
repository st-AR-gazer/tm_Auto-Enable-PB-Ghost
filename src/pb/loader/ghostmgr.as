namespace GhostMgrHelper {

    const uint CACHE_VALID_MS = 500;

    CGameGhostMgrScript@ s_cached = null;
    uint64               s_stamp  = 0;

    CGameGhostMgrScript@ Get() {
        if (s_cached !is null && (Time::Now - s_stamp) < CACHE_VALID_MS) return s_cached;

        s_stamp  = Time::Now;
        @s_cached = null;

        auto app = cast<CTrackMania>(GetApp());
        if (app is null) return null;

        if (_Game::IsPlayingLocal()) {
            CSmArenaRulesMode@ rules = cast<CSmArenaRulesMode>(app.PlaygroundScript);
            if (rules !is null && rules.GhostMgr !is null) {
                @s_cached = rules.GhostMgr;
                return s_cached;
            }
        }

        if (_Game::IsPlayingOnServer()) {
            const uint16 O_CSmArenaInterfaceUI_GhostMgr = GetOffset("CSmArenaInterfaceUI", "ManialinkPage") - (0x518 - 0x500);

            CSmArenaClient@ pg = cast<CSmArenaClient>(app.CurrentPlayground);
            if (pg !is null && pg.Interface !is null) {
                @s_cached = cast<CGameGhostMgrScript>(Dev::GetOffsetNod(pg.Interface, O_CSmArenaInterfaceUI_GhostMgr));

                if (s_cached !is null) return s_cached;
            }
        }

        return null;
    }

}
