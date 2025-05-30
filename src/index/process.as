namespace Processing {

    // Update this so that the user can change these values in the UI at some point
    const uint   BUILD_CHUNK       = 2377;
    const uint   MAX_IN_FLIGHT     = 3;
    const uint   SIZE_SKIP_BYTES   = 50 * 1024 * 1024;
    const uint   HASH_THRESHOLD    = 5  * 1024 * 1024;

    const string REPLAYS_ROOT = IO::FromUserGameFolder("Replays/");
    const string DOC_ROOT     = IO::FromUserGameFolder("");
    const string TMP_DIR      = IO::FromUserGameFolder("Replays/zzAutoEnablePBGhost/tmp/");

    /* state */
    bool g_Running = false;
    array<ReplayRecord@> g_Records;

    /* build */
    uint g_BuildDone = 0;
    uint g_BuildTotal = 0;
    bool g_BuildFinished = false;

    /* parse */
    array<string> g_FileQueue;
    uint g_Dispatched = 0;
    uint g_WorkersAlive = 0;
    uint g_Parsed = 0;
    uint g_SkippedFormat = 0;
    uint g_SkippedLarge = 0;
    uint g_SkippedTimeout = 0;
    uint g_SkippedLogin = 0;
    bool g_ParseFinished = false;

    /* hash */
    uint g_HashIdx = 0;
    uint g_HashSkipped = 0;
    bool g_HashFinished = false;

    /* API getters (for the UI) */
    bool  IsProcessing()   { return g_Running; }
    uint  BuildDone()      { return g_BuildDone; }
    uint  BuildTotal()     { return g_BuildTotal; }
    float BuildFraction()  { return g_BuildTotal == 0 ? 0 : float(g_BuildDone) / g_BuildTotal; }
    bool  BuildFinished()  { return g_BuildFinished; }
    uint  Parsed()         { return g_Parsed; }
    uint  SkippedFormat()  { return g_SkippedFormat; }
    uint  SkippedLarge()   { return g_SkippedLarge; }
    uint  SkippedTimeout() { return g_SkippedTimeout; }
    uint  SkippedLogin()   { return g_SkippedLogin; }
    uint  SkippedTotal()   { return g_SkippedFormat + g_SkippedLarge + g_SkippedTimeout + g_SkippedLogin; }
    uint  TotalToParse()   { return g_FileQueue.Length; }
    float ParseFraction()  { return g_FileQueue.Length == 0 ? 0 : float(g_Parsed + g_SkippedFormat + g_SkippedLarge) / g_FileQueue.Length; }
    bool  ParseFinished()  { return g_ParseFinished; }
    uint  HashDone()       { return g_HashIdx; }
    uint  HashTotal()      { return g_Records.Length; }
    float HashFraction()   { return g_Records.Length == 0 ? 0 : float(g_HashIdx) / g_Records.Length; }
    bool  HashFinished()   { return g_HashFinished; }
    uint  HashSkipped()    { return g_HashSkipped; }

    // 

    void Start() {
        if (g_Running) return;

        g_Records.Resize(0);
        g_FileQueue.Resize(0);
        g_BuildDone=0;
        g_BuildTotal = Index::Root() is null ? 0 : Index::Root().TotalFiles();
        g_BuildFinished = false;

        g_Dispatched = 0;
        g_WorkersAlive = 0;
        g_Parsed = 0;
        g_SkippedFormat = 0;
        g_SkippedLarge = 0;
        g_SkippedTimeout = 0;
        g_SkippedLogin = 0;
        g_ParseFinished = false;

        g_HashIdx = 0;
        g_HashSkipped = 0;
        g_HashFinished=false;

        g_Running = true;
        IO::CreateFolder(TMP_DIR);

        startnew(QueueBuilderCoroutine);
    }

    void QueueBuilderCoroutine() {
        array<Index::DirNode@> st;
        st.InsertLast(Index::Root());
        uint processed = 0;
        uint lastYield = Time::Now;

        while (st.Length > 0) {
            Index::DirNode@ n = st[st.Length-1]; st.RemoveLast();
            if (n is null) continue;

            for (uint i = 0; i < n.files.Length; ++i) {
                g_FileQueue.InsertLast(n.files[i]);
                ++g_BuildDone;
                ++processed;

                if (processed >= BUILD_CHUNK || Time::Now - lastYield > 24) {
                    processed = 0;
                    yield();
                    lastYield = Time::Now;
                }
            }
            for (uint i = 0; i < n.children.Length; ++i) {
                st.InsertLast(n.children[i]);
            }
        }

        g_BuildFinished = true;
        log("Queue built " + g_FileQueue.Length + " file(s).", LogLevel::Debug);
        startnew(LauncherCoroutine);
    }

    void LauncherCoroutine() {
        if (g_WorkersAlive > MAX_IN_FLIGHT) {
            g_WorkersAlive = MAX_IN_FLIGHT;
            ++g_SkippedTimeout;
        }

        while (g_Dispatched < g_FileQueue.Length || g_WorkersAlive > 0) {
            while (g_WorkersAlive < MAX_IN_FLIGHT && g_Dispatched < g_FileQueue.Length) {
                string p=g_FileQueue[g_Dispatched++];
                ++g_WorkersAlive;
                startnew(ParseOneCoroutine, p);
            }
            yield();
        }
        g_ParseFinished = true;
        log("Parsing done | ok:" + g_Parsed + ", skipFmt:" + g_SkippedFormat + ", skipSize:" + g_SkippedLarge + ", timeout:" + g_SkippedTimeout + ", login: " + g_SkippedLogin, LogLevel::Debug);
        startnew(HashCoroutine);
    }

    void ParseOneCoroutine(const string &in origPath) {
        uint t0 = Time::Now;

        if (IO::FileSize(origPath) > SIZE_SKIP_BYTES) { ++g_SkippedLarge; --g_WorkersAlive; return; }

        bool copied = false;
        string parsePath;

        if (origPath.StartsWith(REPLAYS_ROOT)) {
            parsePath = origPath;
        } else {
            parsePath = MakeUniqueTemp(Path::GetFileName(origPath));
            IO::Copy(origPath, parsePath);
            copied=true;
        }

        string rel = parsePath.StartsWith(DOC_ROOT) ? parsePath.SubStr(DOC_ROOT.Length) : parsePath;

        CSystemFidFile@ fid = Fids::GetUser(rel);
        if (fid is null) { ++g_SkippedFormat; CleanupTemp(copied,parsePath); --g_WorkersAlive; return; }

        CMwNod@ nod = Fids::Preload(fid);
        if (Time::Now - t0 > 900) { ++g_SkippedTimeout; CleanupTemp(copied,parsePath); --g_WorkersAlive; return; }

        if (nod !is null) {
            Dispatch(nod, parsePath, origPath);
        } else {
            ++g_SkippedFormat;
        }

        CleanupTemp(copied, parsePath);
        ++g_Parsed;
        --g_WorkersAlive;
    }

    void HashCoroutine() {
        while (g_HashIdx < g_Records.Length) {
            ReplayRecord@ r = g_Records[g_HashIdx];
            if (r.ReplayHash.Length == 0 && IO::FileSize(r.Path) <= HASH_THRESHOLD) {
                r.ReplayHash = Crypto::MD5(_IO::File::ReadFileToEnd(r.Path));
            } else if (r.ReplayHash.Length == 0) {
                ++g_HashSkipped;
            }
            ++g_HashIdx;
            yield();
        }
        g_HashFinished = true;
        g_Running = false;
        log("Hashing done | " + g_HashIdx + " hashed, " + g_HashSkipped + " skipped (>5 MB).", LogLevel::Debug);

        // Now that everything is done, we can add the records to the database :D
        Database::AddRecords(g_Records);
    }

    /* helpers */
    string MakeUniqueTemp(const string &in base) {
        string dst = TMP_DIR + base;
        uint n = 1;
        while (IO::FileExists(dst)) {
            dst = TMP_DIR + tostring(n) + "_" + base;
            ++n;
        }
        return dst;
    }

    void CleanupTemp(bool copied,const string &in p) {
        if (copied && IO::FileExists(p)) { IO::Delete(p); }
    }
        
    /* correct nod handling + the nod handling xdd */
    void Dispatch(CMwNod@ n, const string &in parseP, const string &in fileP) {
        CGameCtnReplayRecordInfo@ info = cast<CGameCtnReplayRecordInfo>(n);
        if (info !is null) { Handle(info); return; }

        CGameCtnReplayRecord@ rec = cast<CGameCtnReplayRecord>(n);
        if (rec !is null) { Handle(rec, parseP, fileP); return; }

        CGameCtnGhost@ gh = cast<CGameCtnGhost>(n);
        if (gh !is null) { Handle(gh, fileP); }
    }

    void Handle(CGameCtnReplayRecord@ rec, const string &in parseP, const string &in fileP) {
        if (rec.Ghosts.Length == 0
        || rec.Ghosts[0].RaceTime == 0xFFFFFFFF
        || rec.Challenge.IdName.Length == 0) { 
            ++g_SkippedFormat;
            return;
        }
        if (rec.Ghosts[0].GhostLogin != GetApp().LocalPlayerInfo.Login) {
            ++g_SkippedLogin;
            return;
        }

        ReplayRecord r;
        r.MapUid         = rec.Challenge.IdName;
        r.PlayerLogin    = rec.Ghosts[0].GhostLogin;
        r.PlayerNickname = rec.Ghosts[0].GhostNickname;
        r.FileName       = Path::GetFileName(fileP);
        r.Path           = fileP;
        r.BestTime       = rec.Ghosts[0].RaceTime;
        r.FoundThrough   = "Folder Indexing";
        r.NodeType       = Reflection::TypeOf(rec).Name;
        g_Records.InsertLast(r);
    }

    void Handle(CGameCtnGhost@ gh, const string &in fileP) {
        if (gh.RaceTime == 0xFFFFFFFF
        || gh.Validate_ChallengeUid.GetName().Length == 0) {
            ++g_SkippedFormat;
            return;
        }
        if (gh.GhostLogin != GetApp().LocalPlayerInfo.Login) {
            ++g_SkippedLogin;
            return;
        }

        ReplayRecord r;
        r.MapUid         = gh.Validate_ChallengeUid.GetName();
        r.PlayerLogin    = gh.GhostLogin;
        r.PlayerNickname = gh.GhostNickname;
        r.FileName       = Path::GetFileName(fileP);
        r.Path           = fileP;
        r.BestTime       = gh.RaceTime;
        r.FoundThrough   = "Folder Indexing";
        r.NodeType       = Reflection::TypeOf(gh).Name;
        g_Records.InsertLast(r);
    }

    void Handle(CGameCtnReplayRecordInfo@ info) {
        if (info.BestTime == 0xFFFFFFFF 
        || info.MapUid.Length == 0) {
            ++g_SkippedFormat;
            return;
        }
        if (info.PlayerLogin != GetApp().LocalPlayerInfo.Login) {
            ++g_SkippedLogin;
            return;
        }

        ReplayRecord r;
        r.MapUid         = info.MapUid;
        r.PlayerLogin    = info.PlayerLogin;
        r.PlayerNickname = info.PlayerNickname;
        r.FileName       = info.FileName;
        r.Path           = info.Path;
        r.BestTime       = info.BestTime;
        r.FoundThrough   = "Folder Indexing";
        r.NodeType       = Reflection::TypeOf(info).Name;
        g_Records.InsertLast(r);
    }
}
