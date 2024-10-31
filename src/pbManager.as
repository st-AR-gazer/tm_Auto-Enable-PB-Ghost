class PBRecord {
    string MapUid;
    string FileName;
    string FullFilePath;

    PBRecord(const string &in mapUid, const string &in fileName, const string &in fullFilePath) {
        MapUid = mapUid;
        FileName = fileName;
        FullFilePath = fullFilePath;
    }
}

namespace PBManager {
    array<PBRecord@> pbRecords;
    string autosaves_index = IO::FromStorageFolder("autosaves_index.json");

    NGameGhostClips_SMgr@ ghostMgr;
    CGameCtnMediaClipPlayer@ currentPBGhostPlayer;

    array<uint> saving;

    void Initialize(CGameCtnApp@ app) {
        @ghostMgr = GhostClipsMgr::Get(app);
    }

    bool IsPBLoaded() {
        if (ghostMgr is null) return false;
        
        CGameCtnMediaClipPlayer@ pbClipPlayer = GhostClipsMgr::GetPBClipPlayer(ghostMgr);
        
        return pbClipPlayer !is null;
    }

    bool IsLocalPBLoaded() {
        auto net = cast<CGameCtnNetwork>(GetApp().Network);
        if (net is null) return false;
        auto cmap = cast<CGameManiaAppPlayground>(net.ClientManiaAppPlayground);
        if (cmap is null) return false;
        auto dfm = cmap.DataFileMgr;
        if (dfm is null) return false;
        
        for (uint i = 0; i < dfm.Ghosts.Length; i++) {
            if (dfm.Ghosts[i].IdName.ToLower().Contains("personal best")) {
                return true;
            }
        }
        return false;
    }

    array<PBRecord@> currentMapPBRecords;
    
    void LoadPBFromIndex() {
        string loadPath = autosaves_index;
        if (!IO::FileExists(loadPath)) { return; }

        string str_jsonData = _IO::File::ReadFileToEnd(loadPath);
        Json::Value jsonData = Json::Parse(str_jsonData);

        pbRecords.RemoveRange(0, pbRecords.Length);

        for (uint i = 0; i < jsonData.Length; i++) {
            auto j = jsonData[i];
            string mapUid = j["MapUid"];
            string fileName = j["FileName"];
            string fullFilePath = j["FullFilePath"];
            PBRecord@ pbRecord = PBRecord(mapUid, fileName, fullFilePath);
            pbRecords.InsertLast(pbRecord);
            // log("LoadPBFromIndex: Loaded PBRecord for MapUid: " + mapUid + ", FileName: " + fileName, LogLevel::Dark, 48, "LoadPBFromIndex");
        }

        currentMapPBRecords = GetPBRecordsForCurrentMap();
    }

    void LoadPBFromCache() {
        for (uint i = 0; i < currentMapPBRecords.Length; i++) {
            if (IO::FileExists(currentMapPBRecords[i].FullFilePath)) {
                ReplayManager::ProcessSelectedFile(currentMapPBRecords[i].FullFilePath);
                log("LoadPBFromCache: Loaded PB ghost from " + currentMapPBRecords[i].FullFilePath, LogLevel::Info, 48, "LoadPBFromCache");
            }
        }
    }

    void LoadPB() {
        UnloadAllPBs();
        LoadPBFromIndex();
        LoadPBFromCache();
    }

    const string SetFocusedRecord_PageUID = "SetFocusedRecord";

    dictionary ghostWsidsLoaded;

    void Update_ML_SetGhostUnloaded(const string &in wsid) {
        if (ghostWsidsLoaded.Exists(wsid)) {
            ghostWsidsLoaded.Delete(wsid);
        }
        MLHook::Queue_MessageManialinkPlayground(SetFocusedRecord_PageUID, {"SetGhostUnloaded", wsid});
    }

    string LoginToWSID(const string &in login) {
        try {
            auto buf = MemoryBuffer();
            buf.WriteFromBase64(login, true);
            string hex = Utils::BufferToHex(buf);
            string wsid = hex.SubStr(0, 8)
                + "-" + hex.SubStr(8, 4)
                + "-" + hex.SubStr(12, 4)
                + "-" + hex.SubStr(16, 4)
                + "-" + hex.SubStr(20);
            return wsid;
        } catch {
            return login;
        }
    }

    void UnloadAllPBs() {
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        if (ps is null) { return; }
        auto mgr = GhostClipsMgr::Get(GetApp());
        if (mgr is null) { return; }

        for (int i = int(mgr.Ghosts.Length) - 1; i >= 0; i--) {
            string ghostNickname;
            try {
                ghostNickname = mgr.Ghosts[i].GhostModel.GhostNickname;
            } catch {
                log("UnloadAllPBs: Failed to access GhostNickname for ghost at index " + i, LogLevel::Warn, 48, "UnloadAllPBs");
                continue;
            }

            if (ghostNickname.ToLower().Contains("personal best")) {
                UnloadPB(uint(i));
            }
        }

        auto net = cast<CGameCtnNetwork>(GetApp().Network);
        if (net is null) return;
        auto cmap = cast<CGameManiaAppPlayground>(net.ClientManiaAppPlayground);
        if (cmap is null) return;
        auto dfm = cmap.DataFileMgr;
        if (dfm is null) return;
        
        array<MwId> ghostIds;

        for (uint i = 0; i < dfm.Ghosts.Length; i++) {
            if (dfm.Ghosts[i].IdName.ToLower().Contains("personal best")) {
                ghostIds.InsertLast(dfm.Ghosts[i].Id);
            }
        }

        for (uint i = 0; i < ghostIds.Length; i++) {
            dfm.Ghost_Release(ghostIds[i]);
        }

        currentMapPBRecords.RemoveRange(0, currentMapPBRecords.Length);
    }


    void UnloadPB(uint i) {
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        if (ps is null) { return; }
        auto mgr = GhostClipsMgr::Get(GetApp());
        if (mgr is null) { return; }
        if (i >= mgr.Ghosts.Length) { return; }

        uint id = GhostClipsMgr::GetInstanceIdAtIx(mgr, i);
        if (id == uint(-1)) { return; }

        string wsid = LoginToWSID(mgr.Ghosts[i].GhostModel.GhostLogin);
        Update_ML_SetGhostUnloaded(wsid);

        ps.GhostMgr.Ghost_Remove(MwId(id));

        int ix = saving.Find(id);
        if (ix >= 0) { saving.RemoveAt(ix); }

        if (i < currentMapPBRecords.Length) {
            string removedMapUid = currentMapPBRecords[i].MapUid;
            string removedFilePath = currentMapPBRecords[i].FullFilePath;
            currentMapPBRecords.RemoveAt(i);
        }
    }

    array<PBRecord@>@ GetPBRecordsForCurrentMap() {
        string currentMapUid = get_CurrentMapUID();
        array<PBRecord@> currentMapRecords;
        currentMapRecords.Resize(0);

        for (uint i = 0; i < pbRecords.Length; i++) {
            if (pbRecords[i].MapUid == currentMapUid) {
                currentMapRecords.InsertLast(pbRecords[i]);
            }
        }

        return currentMapRecords;
    }
}

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