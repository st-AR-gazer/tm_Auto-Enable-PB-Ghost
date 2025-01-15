namespace GhostClipsMgr {
    const uint16 GhostsOffset = GetOffset("NGameGhostClips_SMgr", "Ghosts");
    const uint16 GhostInstIdsOffset = GhostsOffset + 0x10;

    NGameGhostClips_SMgr@ Get(CGameCtnApp@ app) {
        return GetGhostClipsMgr(app);
    }

    NGameGhostClips_SMgr@ GetGhostClipsMgr(CGameCtnApp@ app) {
        if (app.GameScene is null) return null;
        auto nod = Dev::GetOffsetNod(app.GameScene, 0x120);
        if (nod is null) return null;
        return Dev::ForceCast<NGameGhostClips_SMgr@>(nod).Get();
    }

    CGameCtnMediaClipPlayer@ GetPBClipPlayer(NGameGhostClips_SMgr@ mgr) {
        return cast<CGameCtnMediaClipPlayer>(Dev::GetOffsetNod(mgr, 0x40));
    }

    uint GetInstanceIdAtIx(NGameGhostClips_SMgr@ mgr, uint ix) {
        if (mgr is null) return uint(-1);
        uint bufOffset = GhostInstIdsOffset;
        uint64 bufPtr = Dev::GetOffsetUint64(mgr, bufOffset);
        uint nextIdOrSomething = Dev::GetOffsetUint32(mgr, bufOffset + 0x8);
        uint bufLen = Dev::GetOffsetUint32(mgr, bufOffset + 0xC);
        uint bufCapacity = Dev::GetOffsetUint32(mgr, bufOffset + 0x10);

        if (bufLen == 0 || bufCapacity == 0) return uint(-1);

        // A bunch of trial and error to figure this out >.< // Thank you XertroV :peeepoLove:
        if (bufLen <= ix) return uint(-1);
        if (bufPtr == 0 || bufPtr % 8 != 0) return uint(-1);
        uint slot = Dev::ReadUInt32(bufPtr + (bufCapacity * 4) + ix * 4);
        uint msb = Dev::ReadUInt32(bufPtr + slot * 4) & 0xFF000000;
        return msb + slot;
    }
}

uint16 GetOffset(const string &in className, const string &in memberName) {
    auto ty = Reflection::GetType(className);
    auto memberTy = ty.GetMember(memberName);
    return memberTy.Offset;
}

namespace Utils {
    string BufferToHex(MemoryBuffer@ buf) {
        buf.Seek(0);
        uint size = buf.GetSize();
        string ret;
        for (uint i = 0; i < size; i++) {
            ret += Uint8ToHex(buf.ReadUInt8());
        }
        return ret;
    }

    string Uint8ToHex(uint8 val) {
        return Uint4ToHex(val >> 4) + Uint4ToHex(val & 0xF);
    }

    string Uint4ToHex(uint8 val) {
        if (val > 0xF) throw('val out of range: ' + val);
        string ret = " ";
        if (val < 10) {
            ret[0] = val + 0x30;
        } else {
            // 0x61 = a
            ret[0] = val - 10 + 0x61;
        }
        return ret;
    }
}