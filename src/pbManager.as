[Setting name="Special Ghost Plugin Indicator" category="General"]
string S_specialGhostPluginIdicator = ".";

[Setting name="Use leaderboard as a last resort for loading a pb" category="General"]
bool S_useLeaderboardAsLastResort = true;

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
    array<PBRecord@> currentMapPBRecords;
    array<uint> saving;

    void Initialize(CGameCtnApp@ app) {
        @ghostMgr = GhostClipsMgr::Get(app);
        needsRefresh = true;
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

    bool needsRefresh = true;
    void LoadPB() {
        if (!_Game::IsPlayingMap()) { return; }
        UnloadAllPBs();
        if (needsRefresh) LoadPBFromIndex();
        needsRefresh = false;
        LoadPBFromCache();
        if ((IsLocalPBLoaded() || IsPBLoaded()) && !S_useLeaderboardAsLastResort) { log("Failed to load local PB ghosts, trying from nadeo servers (if applicable).", LogLevel::Error, 62, "LoadPB"); return; } 
        LoadPBFromLeaderboards();
    }
    
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
        }

        currentMapPBRecords = GetPBRecordsForCurrentMap();
    }

    void LoadPBFromCache() {
        currentMapPBRecords = GetPBRecordsForCurrentMap();
        if (cast<CSmArenaRulesMode>(GetApp().PlaygroundScript) is null) { return; }
        auto ghostMgr = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript).GhostMgr;

        for (uint i = 0; i < currentMapPBRecords.Length; i++) {
            if (IO::FileExists(currentMapPBRecords[i].FullFilePath)) {
                auto task = GetApp().Network.ClientManiaAppPlayground.DataFileMgr.Replay_Load(currentMapPBRecords[i].FullFilePath);
                while (task.IsProcessing) { yield(); }

                if (task.HasFailed || !task.HasSucceeded) {
                    log("Failed to load replay file from cache: " + currentMapPBRecords[i].FullFilePath, LogLevel::Error, 98, "LoadPBFromCache");
                    continue;
                }

                for (uint j = 0; j < task.Ghosts.Length; j++) {
                    auto ghost = task.Ghosts[j];
                    ghost.IdName = "Personal best";
                    ghost.Nickname = "$5d8" + "Personal best";
                    ghost.Trigram = "PB" + S_specialGhostPluginIdicator;
                    ghostMgr.Ghost_Add(ghost);
                }
                
                log("Loaded PB ghost from " + currentMapPBRecords[i].FullFilePath, LogLevel::Info, 110, "LoadPBFromCache");
            }
        }
    }

    void LoadPBFromLeaderboards() {
        startnew(Coro_LoadPBFromLeaderboards);
    }
    
    void Coro_LoadPBFromLeaderboards() {
        NadeoServices::AddAudience("NadeoServices");
        while (!NadeoServices::IsAuthenticated("NadeoServices")) { yield(); }

        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        if (ps is null) { return; }
        CGameDataFileManagerScript@ dfm = ps.DataFileMgr;
        if (dfm is null) { return; }

        LeaderboardManager lbmgr;
        string url = lbmgr.GetUrlForCurrentMap();

        while (url.Length == 0) { yield(); }

        CWebServicesTaskResult_GhostScript@ task = dfm.Ghost_Download("", url);

        while (task.IsProcessing) { yield(); }

        if (task.HasFailed || !task.HasSucceeded) {
            log('Ghost_Download failed: ' + task.ErrorCode + ", " + task.ErrorType + ", " + task.ErrorDescription + " Url used: " + url, LogLevel::Error, 138, "Coro_LoadPBFromLeaderboards");
            return;
        }

        task.Ghost.IdName = "Personal best";
        task.Ghost.Nickname = "$5d8" + "Personal best";
        task.Ghost.Trigram = "PB" + S_specialGhostPluginIdicator;

        CGameGhostMgrScript@ gm = ps.GhostMgr;
        MwId instId = gm.Ghost_Add(task.Ghost, true);
        log('Instance ID: ' + instId.GetName() + " / " + Text::Format("%08x", instId.Value), LogLevel::Info, 148, "Coro_LoadPBFromLeaderboards");

        dfm.TaskResult_Release(task.Id);
    }

    class LeaderboardManager {
        string accountId;
        string mapId;
        string fetchGhostUrl;

        string ghostUrl;

        string mapUid;

        bool accountIdFetched;
        bool mapIdFetched;
        bool ghostUrlFetched;

        string get_CurrentMapUID() {
            if (_Game::IsMapLoaded()) {
                CTrackMania@ app = cast<CTrackMania>(GetApp());
                if (app is null) return "";
                CGameCtnChallenge@ map = app.RootMap;
                if (map is null) return "";
                return map.MapInfo.MapUid;
            }
            return "";
        }

        string GetUrlForCurrentMap() {
            string currentMapUid = get_CurrentMapUID();
            if (currentMapUid.Length == 0) { log("Current map UID not found.", LogLevel::Error, 179, "GetUrlForCurrentMap"); return ""; }

            mapUid = currentMapUid;

            accountIdFetched = false;
            mapIdFetched = false;

            startnew(CoroutineFunc(Coro_FetchAccountId));
            startnew(CoroutineFunc(Coro_FetchMapId));

            while (!(accountIdFetched && mapIdFetched)) { yield(); }

            accountIdFetched = false;
            mapIdFetched = false;

            fetchGhostUrl = "https://prod.trackmania.core.nadeo.online/v2/mapRecords/?accountIdList=" + accountId + "&mapId=" + mapId;

            startnew(CoroutineFunc(Coro_FetchGhostUrl));
            log("Found ghost URL: " + ghostUrl, LogLevel::Info, 197, "GetUrlForCurrentMap");

            while (ghostUrl.Length == 0) { yield(); }

            string t_ghostUrl = ghostUrl;
            ghostUrl = "";


            return t_ghostUrl;
        }

        void Coro_FetchAccountId() {
            FetchAccountId();
            accountIdFetched = true;
        }

        void Coro_FetchMapId() {
            FetchMapId(mapUid);
            mapIdFetched = true;
        }

        void Coro_FetchGhostUrl() {
            FetchGhostUrl(fetchGhostUrl);
            ghostUrlFetched = true;
        }

        void FetchAccountId() {
            auto app = cast<CGameCtnApp>(GetApp());
            if (app is null) { log("Failed to fetch account ID, app not found.", LogLevel::Error, 225, "FetchAccountId"); return; }
            auto net = cast<CTrackManiaNetwork>(app.Network);
            if (net is null) { log("Failed to fetch account ID, network not found.", LogLevel::Error, 227, "FetchAccountId"); return; }
            accountId = net.PlayerInfo.WebServicesUserId;

            log("Found account ID: " + accountId, LogLevel::Info, 230, "FetchAccountId");
        }

        void FetchMapId(const string &in mapUid) {
            string url = "https://prod.trackmania.core.nadeo.online/maps/?mapUidList=" + mapUid;
            auto req = NadeoServices::Get("NadeoServices", url);

            req.Start();

            while (!req.Finished()) { yield(); }

            if (req.ResponseCode() != 200) {
                log("Failed to fetch map ID, response code: " + req.ResponseCode(), LogLevel::Error, 242, "FetchMapId");
            } else {
                Json::Value data = Json::Parse(req.String());
                if (data.GetType() == Json::Type::Null) {
                    log("Failed to parse response for map ID.", LogLevel::Error, 246, "FetchMapId");
                } else {
                    if (data.GetType() != Json::Type::Array || data.Length == 0) {
                        log("Invalid map data in response.", LogLevel::Error, 249, "FetchMapId");
                    } else {
                        log("Found map ID: " + string(data[0]["mapId"]), LogLevel::Info, 251, "FetchMapId");
                        mapId = data[0]["mapId"];
                    }
                }
            }
        }

        void FetchGhostUrl(const string &in url) {
            auto request = NadeoServices::Get("NadeoServices", url);

            request.Start();

            while (!request.Finished()) { yield(); }

            print(request.ResponseCode());

            if (request.ResponseCode() == 200) {
                Json::Value data = Json::Parse(request.String());

                print(request.String());

                if (data.GetType() == Json::Type::Array) {
                    for (uint i = 0; i < data.Length; i++) {
                        auto record = data[i];
                        string url = string(record["url"]);

                        ghostUrl = url;

                        ghostUrlFetched = true;

                        log(url, LogLevel::Info, 281, "FetchGhostUrl");
                    }
                }
            }
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
                log("UnloadAllPBs: Failed to access GhostNickname for ghost at index " + i, LogLevel::Warn, 299, "UnloadAllPBs");
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