/**
 * Thank you to XertroV for making G++ that could copy off of :upside_down:
 * Original file can be found here:
 * https://github.com/XertroV/tm-ghosts-plus-plus/blob/master/src/GhostClips.as
 */

bool IsPBGhostPresent_Clips() {
    auto mgr = GhostClipsMgr::Get(GetApp());
    if (mgr is null) return false;
    for (uint i = 0; i < mgr.Ghosts.Length; i++) {
        string gName = mgr.Ghosts[i].GhostModel.GhostNickname;
        if (gName.ToLower().Contains("personal best")) {
            return true;
        }
    }
    return false;
}

NGameGhostClips_SMgr@ GetGhostClipsMgr(CGameCtnApp@ app) {
    if (app.GameScene is null) return null;
    auto nod = Dev::GetOffsetNod(app.GameScene, 0x120);
    if (nod is null) return null;
    return Dev::ForceCast<NGameGhostClips_SMgr@>(nod).Get();
}

namespace GhostClipsMgr {
    const uint16 GhostsOffset = GetOffset("NGameGhostClips_SMgr", "Ghosts");
    const uint16 GhostInstIdsOffset = GhostsOffset + 0x10;

    NGameGhostClips_SMgr@ Get(CGameCtnApp@ app) {
        return GetGhostClipsMgr(app);
    }

    array<NGameGhostClips_SClipPlayerGhost@> Find(NGameGhostClips_SMgr@ mgr, const string &in loginOrName) {
        array<NGameGhostClips_SClipPlayerGhost@> ghosts;
        for (uint i = 0; i < mgr.Ghosts.Length; i++) {
            auto @pghost = mgr.Ghosts[i];
            if (pghost.GhostModel.GhostLogin == loginOrName || pghost.GhostModel.GhostNickname == loginOrName) {
                ghosts.InsertLast(pghost);
            }
        }
        return ghosts;
    }

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
}

uint16 GetOffset(const string &in className, const string &in memberName) {
    // throw exception when something goes wrong.
    auto ty = Reflection::GetType(className);
    auto memberTy = ty.GetMember(memberName);
    return memberTy.Offset;
}