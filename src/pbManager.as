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
    NGameGhostClips_SMgr@ ghostMgr;

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
            print(dfm.Ghosts[i].IdName);
            if (dfm.Ghosts[i].IdName == "Personal best") {
                return true;
            }
        }
        return false;
    }

    void LoadPBFromIndex() {
        string loadPath = IO::FromStorageFolder("autosaves_index.json");
        if (!IO::FileExists(loadPath)) {
            log("PBManager: Autosaves index file does not exist. Indexing can be done manually with the button in the settings menu labled 're-index autosaves folder manually'.", LogLevel::Info, 48, "LoadPBFromIndex");
            return;
        }

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
        }

        auto currentMapPBRecords = GetPBRecordsForCurrentMap();

        for (uint i = 0; i < currentMapPBRecords.Length; i++) {
            if (IO::FileExists(currentMapPBRecords[i].FullFilePath)) {
                ReplayManager::ProcessSelectedFile(currentMapPBRecords[i].FullFilePath);
            }
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

// Thanks for the code XertroV :peepoLove:

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
}

uint16 GetOffset(const string &in className, const string &in memberName) {
    auto ty = Reflection::GetType(className);
    auto memberTy = ty.GetMember(memberName);
    return memberTy.Offset;
}