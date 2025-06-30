uint16 GetOffset(const string &in className, const string &in memberName) {
    auto ty = Reflection::GetType(className);
    auto memberTy = ty.GetMember(memberName);
    return memberTy.Offset;
}

NGameGhostClips_SMgr@ GetGhostClipsMgr(CGameCtnApp@ app) {
    if (app.GameScene is null) return null;
    auto nod = Dev::GetOffsetNod(app.GameScene, 0x120);
    if (nod is null) return null;
    return Dev::ForceCast<NGameGhostClips_SMgr@>(nod).Get();
}

namespace GhostClipsMgr {
    const uint16 GhostsOffset       = GetOffset("NGameGhostClips_SMgr", "Ghosts");
    const uint16 GhostInstIdsOffset = GhostsOffset + 0x10;

    NGameGhostClips_SMgr@ Get(CGameCtnApp@ app) {
        return GetGhostClipsMgr(app);
    }

    // matches index of .Ghosts
    uint GetInstanceIdAtIx(NGameGhostClips_SMgr@ mgr, uint ix) {
        if (mgr is null) return uint(-1);
        auto bufOffset = GhostInstIdsOffset;
        auto bufPtr = Dev::GetOffsetUint64(mgr, bufOffset);
        auto nextIdOrSomething = Dev::GetOffsetUint32(mgr, bufOffset + 0x8);
        auto bufLen = Dev::GetOffsetUint32(mgr, bufOffset + 0xC);
        auto bufCapacity = Dev::GetOffsetUint32(mgr, bufOffset + 0x10);

        if (bufLen == 0 || bufCapacity == 0) return uint(-1);

        // A bunch of trial and error to figure this out >.<
        if (bufLen <= ix) return uint(-1);
        if (bufPtr == 0 or bufPtr % 8 != 0) return uint(-1);
        auto slot = Dev::ReadUInt32(bufPtr + (bufCapacity*4) + ix * 4);
        auto msb = Dev::ReadUInt32(bufPtr + slot * 4) & 0xFF000000;
        return msb + slot;

        // auto lsb = Dev::ReadUInt32(bufPtr + slot * 4) & 0x00FFFFFF;
        // if (lsb >= bufCapacity) {
        //     warn('lsb outside expected range: ' + lsb + " should be < " + bufCapacity);
        // }
        // auto msb = Dev::ReadUInt32(bufPtr + (bufCapacity*4*2) + slot * 4) & 0xFF000000;
        // trace('msb: ' + msb);
    }

    NGameGhostClips_SClipPlayerGhost@ GetGhostFromInstanceId(NGameGhostClips_SMgr@ mgr, uint instanceId) {
        auto lsb = instanceId & 0x000FFFFF;
        auto bufOffset = GhostInstIdsOffset;
        // auto bufPtr = Dev::GetOffsetUint64(mgr, bufOffset);
        // auto nextIdOrSomething = Dev::GetOffsetUint32(mgr, bufOffset + 0x8);
        // auto bufLen = Dev::GetOffsetUint32(mgr, bufOffset + 0xC);
        auto bufCapacity = Dev::GetOffsetUint32(mgr, bufOffset + 0x10);
        if (lsb > bufCapacity) {
            warn('unexpectedly high ghost instance ID: ' + Text::Format("0x%08x", lsb));
            return null;
        }
        for (uint i = 0; i < bufCapacity; i++) {
            if (GetInstanceIdAtIx(mgr, i) == instanceId) {
                return mgr.Ghosts[i];
            }
        }
        return null;
    }
}

// ty to XertroV for helping with understanding the clips mgr :PeepoHeart: