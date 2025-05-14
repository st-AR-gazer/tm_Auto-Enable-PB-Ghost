namespace GhostMgrHelper {

    const uint16 O_CSmArenaInterfaceUI_GhostMgr = GetOffset("CSmArenaInterfaceUI", "ManialinkPage") - (0x518 - 0x500);

    CGameGhostMgrScript@ g_cached = null;
    uint g_stamp = 0;

    CGameGhostMgrScript@ Get() {
        if (g_cached !is null && Time::Now - g_stamp < 500) return g_cached;

        g_stamp = Time::Now;
        @g_cached = null;

        CSmArenaClient@ pg = cast<CSmArenaClient>(GetApp().CurrentPlayground);
        if (pg is null || pg.Interface is null) return null;

        @g_cached = cast<CGameGhostMgrScript>(Dev::GetOffsetNod(pg.Interface, O_CSmArenaInterfaceUI_GhostMgr));
        return g_cached;
    }
}
