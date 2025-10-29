// Fun Utils I use from time to time

namespace _Text {
    int NthLastIndexOf(const string &in str, const string &in value, int n) {
        int index = -1;
        for (int i = str.Length - 1; i >= 0; --i) {
            if (str.SubStr(i, value.Length) == value) {
                if (n == 1) {
                    index = i;
                    break;
                }
                --n;
            }
        }
        return index;
    }
}

namespace _UI {
    void SimpleTooltip(const string &in msg) {
        if (UI::IsItemHovered()) {
            UI::SetNextWindowSize(400, 0, UI::Cond::Appearing);
            UI::BeginTooltip();
            UI::TextWrapped(msg);
            UI::EndTooltip();
        }
    }

    void DisabledButton(const string &in text, const vec2 &in size = vec2 ( )) {
        UI::BeginDisabled();
        UI::Button(text, size);
        UI::EndDisabled();
    }

    bool DisabledButton(bool disabled, const string &in text, const vec2 &in size = vec2 ( )) {
        if (disabled) {
            DisabledButton(text, size);
            return false;
        } else {
            return UI::Button(text, size);
        }
    }
}

namespace _IO {
    namespace Directory {
        bool IsDirectory(const string &in path) {
            if (path.EndsWith("/") || path.EndsWith("\\")) return true;
            return false;
        }
        
        string GetParentDirectoryName(const string &in path) {
            string trimmedPath = path;

            if (!IsDirectory(trimmedPath)) {
                return _IO::File::GetFilePathWithoutFileName(trimmedPath);
            }

            if (trimmedPath.EndsWith("/") || trimmedPath.EndsWith("\\")) {
                trimmedPath = trimmedPath.SubStr(0, trimmedPath.Length - 1);
            }
            
            int index = trimmedPath.LastIndexOf("/");
            int index2 = trimmedPath.LastIndexOf("\\");

            index = Math::Max(index, index2);

            if (index == -1) {
                return "";
            }

            return trimmedPath.SubStr(index + 1);
        }
    }

    namespace File {
        void WriteFile(string _path, const string &in content, bool verbose = false) {
            string path = _path;
            if (verbose) log("Writing to file: " + path, LogLevel::Info, 79, "WriteFile", "", "\\$f80");

            if (path.EndsWith("/") || path.EndsWith("\\")) { log("Invalid file path: " + path, LogLevel::Error, 81, "WriteFile", "", "\\$f80"); return; }

            if (!IO::FolderExists(Path::GetDirectoryName(path))) { IO::CreateFolder(Path::GetDirectoryName(path), true); }

            IO::File file;
            file.Open(path, IO::FileMode::Write);
            file.Write(content);
            file.Close();
        }

        string GetFilePathWithoutFileName(const string &in path) {
            int index = path.LastIndexOf("/");
            int index2 = path.LastIndexOf("\\");

            index = Math::Max(index, index2);

            if (index == -1) {
                return "";
            }
        
            return path.SubStr(0, index);
        }

        // Read from file
        string ReadFileToEnd(const string &in path, bool verbose = false) {
            if (verbose) log("Reading file: " + path, LogLevel::Info, 106, "ReadFileToEnd", "", "\\$f80");
            if (!IO::FileExists(path)) { log("File does not exist: " + path, LogLevel::Error, 107, "ReadFileToEnd", "", "\\$f80"); return ""; }

            IO::File file(path, IO::FileMode::Read);
            string content = file.ReadToEnd();
            file.Close();
            return content;
        }
        
        string ReadSourceFileToEnd(const string &in path, bool verbose = false) {
            if (!IO::FileExists(path)) { log("File does not exist: " + path, LogLevel::Error, 116, "ReadSourceFileToEnd", "", "\\$f80"); return ""; }

            IO::FileSource f(path);
            string content = f.ReadToEnd();
            return content;
        }

        // Move file
        void CopySourceFileToNonSource(const string &in originalPath, const string &in storagePath, bool verbose = false) {
            if (verbose) log("Moving the file content", LogLevel::Info, 125, "CopySourceFileToNonSource", "", "\\$f80");
            
            string fileContents = ReadSourceFileToEnd(originalPath, verbose);
            WriteFile(storagePath, fileContents, verbose);

            if (verbose) log("Finished moving the file", LogLevel::Info, 130, "CopySourceFileToNonSource", "", "\\$f80");

            // TODO: Must check how IO::Move works with source files
        }

        // Copy file
        void CopyFileTo(const string &in source, const string &in destination, bool verbose = false) {
            if (!IO::FileExists(source)) { if (verbose) log("Source file does not exist: " + source, LogLevel::Error, 137, "CopyFileTo", "", "\\$f80"); return; }
            if (IO::FileExists(destination)) { if (verbose) log("Destination file already exists: " + destination, LogLevel::Error, 138, "CopyFileTo", "", "\\$f80"); return; }

            string content = ReadFileToEnd(source, verbose);
            WriteFile(destination, content, verbose);
        }

    }

    void OpenFolder(const string &in path, bool verbose = false) {
        if (IO::FolderExists(path)) {
            OpenExplorerPath(path);
        } else {
            if (verbose) log("Folder does not exist: " + path, LogLevel::Info, 150, "OpenFolder", "", "\\$f80");
        }
    }
}

namespace _Game {
    bool IsMapLoaded() {
        CTrackMania@ app = cast<CTrackMania>(GetApp());
        if (app.RootMap is null) return false;
        return true;
    }

    bool IsPlayingMap() {
        CTrackMania@ app = cast<CTrackMania>(GetApp());
        if (app is null) return false;

        CSmArenaClient@ playground = cast<CSmArenaClient>(app.CurrentPlayground);
        return !(playground is null || playground.Arena.Players.Length == 0);
    }

    bool IsPlayingLocal() {
        if (!IsPlayingMap()) return false;

        CTrackMania@ app = cast<CTrackMania>(GetApp());
        if (app is null) return false;
        CGamePlaygroundScript@ ps = app.PlaygroundScript;
        if (ps is null) return false;
        return true;
    }

    bool IsPlayingOnServer() {
        if (!IsPlayingMap()) return false;

        CTrackMania@ app = cast<CTrackMania>(GetApp());
        if (app is null) return false;
        CGamePlaygroundScript@ ps = app.PlaygroundScript;
        if (ps is null) return true; // temp messure until I know of a better way to detect this...
        return false;
    }

    bool HasPersonalBest(const string &in mapUid, bool verbose = false) {
        CTrackMania@ app = cast<CTrackMania>(GetApp());
        string _mapUid = mapUid;
        if (_mapUid == "") {
            CGameCtnChallenge@ map = app.RootMap;
            if (map is null || map.MapInfo.MapUid == "") return false;
            _mapUid = map.MapInfo.MapUid;
        }

        CTrackManiaNetwork@ network = cast<CTrackManiaNetwork>(app.Network);
        if (network.ClientManiaAppPlayground is null) return false;

        CGameUserManagerScript@ userMgr = network.ClientManiaAppPlayground.UserMgr;
        MwId userId = (userMgr.Users.Length > 0) ? userMgr.Users[0].Id : MwId(uint(-1));

        CGameScoreAndLeaderBoardManagerScript@ scoreMgr = network.ClientManiaAppPlayground.ScoreMgr;
        int pbTime = scoreMgr.Map_GetRecord_v2(userId, _mapUid, "PersonalBest", "", "TimeAttack", "");

        if (verbose) log(mapUid + " | " + pbTime, LogLevel::Debug, 208, "HasPersonalBest", "", "\\$f80");
        return pbTime > 0;
    }

    int CurrentPersonalBest(const string &in mapUid, bool verbose = false) {
        CTrackMania@ app = cast<CTrackMania>(GetApp());
        if (app is null) { if (verbose) log("app is null", LogLevel::Error, 214, "CurrentPersonalBest", "", "\\$f80"); return 0; }

        string _mapUid = mapUid;
        if (_mapUid == "") {
            CGameCtnChallenge@ map = app.RootMap;
            if (map is null || map.MapInfo.MapUid == "") { if (verbose) log("no map or UID", LogLevel::Error, 219, "CurrentPersonalBest", "", "\\$f80"); return 0; }
            _mapUid = map.MapInfo.MapUid;
        }

        if (verbose) log("querying PB for UID '" + _mapUid + "'", LogLevel::Info, 223, "CurrentPersonalBest", "", "\\$f80");

        CTrackManiaNetwork@ network = cast<CTrackManiaNetwork>(app.Network);
        if (network.ClientManiaAppPlayground is null) { if (verbose) log("no playground available", LogLevel::Error, 226, "CurrentPersonalBest", "", "\\$f80"); return 0; }

        CGameUserManagerScript@ userMgr = network.ClientManiaAppPlayground.UserMgr;
        MwId userId = (userMgr.Users.Length > 0) ? userMgr.Users[0].Id : MwId(uint(-1));
        if (verbose) log("using user ID " + userId.GetName(), LogLevel::Debug, 230, "CurrentPersonalBest", "", "\\$f80");

        CGameScoreAndLeaderBoardManagerScript@ scoreMgr = network.ClientManiaAppPlayground.ScoreMgr;
        int pbTime = scoreMgr.Map_GetRecord_v2(userId, _mapUid, "PersonalBest", "", "TimeAttack", "");

        if (verbose) log("result = " + pbTime, LogLevel::Info, 235, "CurrentPersonalBest", "", "\\$f80");
        return pbTime;
    }
}
