uint16 GetOffset(const string &in className, const string &in memberName) {
    auto ty = Reflection::GetType(className);
    auto memberTy = ty.GetMember(memberName);
    return memberTy.Offset;
}

uint16 GhostClipsMgrOffset = 0;
const uint16 O_ISceneVis_HackScene = GetOffset("ISceneVis", "HackScene");

NGameGhostClips_SMgr@ GetGhostClipsMgr(CGameCtnApp@ app) {
    if (app is null || app.GameScene is null) return null;
    if (GhostClipsMgrOffset == 0) {
        TryReadingGhostClipsMgrOffset();
        if (GhostClipsMgrOffset == 0) return null;
    }
    auto nod = Dev::GetOffsetNod(app.GameScene, GhostClipsMgrOffset);
    if (nod is null) return null;
    return Dev::ForceCast<NGameGhostClips_SMgr@>(nod).Get();
}

void TryReadingGhostClipsMgrOffset() {
    if (GhostClipsMgrOffset != 0) return;
    auto gcMgrClsId = Reflection::GetType("NGameGhostClips_SMgr").ID;
    ManagerDesc@ desc = FindManager(gcMgrClsId);
    if (desc is null) return;
    GhostClipsMgrOffset = desc.Offset;
}

ManagerDesc@ FindManager(uint wantedTypeId) {
    auto app = GetApp();
    if (app is null || app.GameScene is null) return null;
    auto mgrsListOff = O_ISceneVis_HackScene - 0x18;
    auto mgrs = Dev::GetOffsetNod(app.GameScene, mgrsListOff);
    if (mgrs is null) return null;
    auto mgrCount = Dev::GetOffsetUint32(app.GameScene, mgrsListOff + 0x8);
    for (uint i = 0; i < mgrCount; i++) {
        auto typeId = Dev::GetOffsetUint32(mgrs, i * 0x18);
        if (typeId != wantedTypeId) continue;
        auto ptr = Dev::GetOffsetUint64(mgrs, i * 0x18 + 0x8);
        auto mgrIx = Dev::GetOffsetUint32(mgrs, i * 0x18 + 0x10);
        auto ty = Reflection::GetType(typeId);
        auto name = (ty is null ? "Unknown" : ty.Name) + " (" + Text::Format("%08x", typeId) + ")";
        return ManagerDesc(name, typeId, ptr, mgrIx);
    }
    return null;
}

class ManagerDesc {
    string name;
    uint32 typeId;
    uint64 ptr;
    uint32 index;
    ManagerDesc(const string &in name, uint32 typeId, uint64 ptr, uint32 index) {
        this.name = name;
        this.typeId = typeId;
        this.ptr = ptr;
        this.index = index;
    }
    uint16 get_Offset() {
        return index * 0x8 + 0x10;
    }
}

namespace GhostClipsMgr {
    const uint MAX_GHOSTS_LEN = 100000;
    const uint16 GhostsOffset       = GetOffset("NGameGhostClips_SMgr", "Ghosts");
    const uint16 GhostInstIdsOffset = GhostsOffset + 0x10;

    NGameGhostClips_SMgr@ Get(CGameCtnApp@ app) {
        return GetGhostClipsMgr(app);
    }

    NGameGhostClips_SMgr@ GetSafe(CGameCtnApp@ app) {
        NGameGhostClips_SMgr@ mgr = Get(app);
        if (mgr is null) return null;
        uint len = mgr.Ghosts.Length;
        if (len > MAX_GHOSTS_LEN) {
            log("GhostClipsMgr length looks invalid (" + len + ") treating as null.", LogLevel::Warning, 78, "get_Offset", "", "\\$f80");
            return null;
        }
        return mgr;
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