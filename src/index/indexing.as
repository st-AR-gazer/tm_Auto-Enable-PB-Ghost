namespace Index {
    string defaultRoot = IO::FromUserGameFolder("Replays_Offload/");

    string EnsureTrailingSep(const string &in p) {
        return (p.EndsWith("\\") || p.EndsWith("/")) ? p : p + (p.Contains("\\") ? "\\" : "/");
    }
    string StripTrailingSep(const string &in p) {
        return (p.EndsWith("\\") || p.EndsWith("/")) ? p.SubStr(0, p.Length - 1) : p;
    }

    const uint MIN_MS = 800;

    /* ------------------------------------------------------------------- */
    class DirNode {
        string path;
        string name;
        array<string> files;

        uint startMs       = 0;
        uint entriesTotal  = 0;
        uint entriesDone   = 0;

        uint filesDiscovered = 0;
        uint filesProcessed  = 0;

        array<DirNode@> children;
        bool listingDone   = false;
        uint currentChild  = 0;

        DirNode(const string &in abs) {
            path    = EnsureTrailingSep(abs);
            startMs = Time::Now;

            array<string> parts = path.Replace("\\", "/").Split("/");
            name = (parts.Length > 1 && parts[parts.Length - 1] == "") ? parts[parts.Length - 2] : parts[parts.Length - 1];
        }

        /* note that this is weighted progress (80 % folders and 20 % files) */
        float Fraction() {
            float rawFolder;
            if (!listingDone && children.Length == 0) {
                rawFolder = (entriesTotal == 0) ? 0.0f : float(entriesDone) / float(entriesTotal);
            } else if (!listingDone) {
                rawFolder = 0.0f;
            } else if (children.Length == 0) {
                rawFolder = 1.0f;
            } else {
                float sum = 0.0f; uint slow = 0; float minP = 2;
                for (uint i = 0; i < children.Length; ++i) {
                    float p = children[i].Fraction();
                    sum += p;
                    if (p < minP) { minP = p; slow = i; }
                }
                rawFolder = sum / float(children.Length);
                currentChild = slow;
            }

            float timeFrac = Math::Clamp(float(Time::Now - startMs) / float(MIN_MS), 0.0f, 1.0f);
            float folderPart = (rawFolder > timeFrac) ? timeFrac : rawFolder;

            float filePart;
            if (listingDone) {
                filePart = 1.0f;
            } else {
                filePart = timeFrac;
            }

            return folderPart * 0.8f + filePart * 0.2f;
        }

        uint TotalFiles() { uint t = filesDiscovered; for (uint i = 0; i < children.Length; ++i) t += children[i].TotalFiles(); return t; }
        uint TotalDirs()  { uint t = children.Length;  for (uint i = 0; i < children.Length; ++i) t += children[i].TotalDirs (); return t; }
    }

    DirNode@ g_Root = null;
    bool g_IsScanning = false;

    bool IsScanning() { return g_IsScanning; }
    DirNode@ Root() { return g_Root; }

    void StartIndexing(const string &in rootPath) {
        if (g_IsScanning) return;
        @g_Root = DirNode(rootPath);
        g_IsScanning = true;
        startnew(Indexer);
    }

    bool IsReplayOrGhost(const string &in lname) {   return lname.EndsWith(".ghost.gbx") || lname.EndsWith(".replay.gbx"); }

    void Indexer() {
        const uint CHUNK    = 4096;
        const uint SLICE_MS = 8;

        array<DirNode@> stack;  stack.InsertLast(g_Root);
        uint lastYield = Time::Now;

        while (stack.Length > 0) {
            DirNode@ cur = stack[stack.Length - 1];
            stack.RemoveLast();

            string[]@ entries = IO::IndexFolder(StripTrailingSep(cur.path), false);
            if (entries is null) { cur.listingDone = true; continue; }

            cur.entriesTotal = entries.Length;

            for (uint i = 0; i < entries.Length; ++i) {
                string full = entries[i];

                if (_IO::Directory::IsDirectory(full)) {
                    DirNode@ child = DirNode(full);
                    cur.children.InsertLast(child);
                    stack.InsertLast(child);
                } else if (IsReplayOrGhost(full.ToLower())) {
                    ++cur.filesDiscovered;
                    cur.files.InsertLast(full);
                }

                ++cur.entriesDone;

                if ((i % CHUNK) == 0 && Time::Now - lastYield > SLICE_MS) {
                    yield();
                    lastYield = Time::Now;
                }
            }

            cur.listingDone = true;

            if (Time::Now - lastYield > SLICE_MS) {
                yield();
                lastYield = Time::Now;
            }
        }

        g_IsScanning = false;
        
        Processing::Start();

        log("Index complete | " + g_Root.TotalDirs()  + " dir(s), " + g_Root.TotalFiles() + " file(s).", LogLevel::Info, 138, "Indexer", "", "\\$f80");
    }
}
