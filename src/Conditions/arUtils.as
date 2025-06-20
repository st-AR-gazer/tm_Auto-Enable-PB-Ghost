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
        bool IsFile(const string &in path) {
            if (IO::FileExists(path)) return true;
            return false;
        }

        void WriteFile(string _path, const string &in content, bool verbose = false) {
            string path = _path;
            if (verbose) log("Writing to file: " + path, LogLevel::Info, 84, "WriteFile", "", "\\$f80");

            if (path.EndsWith("/") || path.EndsWith("\\")) { log("Invalid file path: " + path, LogLevel::Error, 86, "WriteFile", "", "\\$f80"); return; }

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

        void WriteJsonFile(const string &in path, const Json::Value &in value) {
            string content = Json::Write(value);
            WriteFile(path, content);
        }

        // Read from file
        string ReadFileToEnd(const string &in path, bool verbose = false) {
            if (verbose) log("Reading file: " + path, LogLevel::Info, 116, "ReadFileToEnd", "", "\\$f80");
            if (!IO::FileExists(path)) { log("File does not exist: " + path, LogLevel::Error, 117, "ReadFileToEnd", "", "\\$f80"); return ""; }

            IO::File file(path, IO::FileMode::Read);
            string content = file.ReadToEnd();
            file.Close();
            return content;
        }
        
        string ReadSourceFileToEnd(const string &in path, bool verbose = false) {
            if (!IO::FileExists(path)) { log("File does not exist: " + path, LogLevel::Error, 126, "ReadSourceFileToEnd", "", "\\$f80"); return ""; }

            IO::FileSource f(path);
            string content = f.ReadToEnd();
            return content;
        }

        // Move file
        void CopySourceFileToNonSource(const string &in originalPath, const string &in storagePath, bool verbose = false) {
            if (verbose) log("Moving the file content", LogLevel::Info, 135, "CopySourceFileToNonSource", "", "\\$f80");
            
            string fileContents = ReadSourceFileToEnd(originalPath, verbose);
            WriteFile(storagePath, fileContents, verbose);

            if (verbose) log("Finished moving the file", LogLevel::Info, 140, "CopySourceFileToNonSource", "", "\\$f80");

            // TODO: Must check how IO::Move works with source files
        }

        // Copy file
        void CopyFileTo(const string &in source, const string &in destination, bool verbose = false) {
            if (!IO::FileExists(source)) { if (verbose) log("Source file does not exist: " + source, LogLevel::Error, 147, "CopyFileTo", "", "\\$f80"); return; }
            if (IO::FileExists(destination)) { if (verbose) log("Destination file already exists: " + destination, LogLevel::Error, 148, "CopyFileTo", "", "\\$f80"); return; }

            string content = ReadFileToEnd(source, verbose);
            WriteFile(destination, content, verbose);
        }

        // Rename file
        void RenameFile(const string &in filePath, const string &in newFileName, bool verbose = false) {
            if (verbose) log("Attempting to rename file: " + filePath, LogLevel::Info, 156, "RenameFile", "", "\\$f80");
            if (!IO::FileExists(filePath)) { log("File does not exist: " + filePath, LogLevel::Error, 157, "RenameFile", "", "\\$f80"); return; }

            string currentPath = filePath;
            string newPath;

            string sanitizedNewName = Path::SanitizeFileName(newFileName);

            if (Directory::IsDirectory(newPath)) {
                while (currentPath.EndsWith("/") || currentPath.EndsWith("\\")) {
                    currentPath = currentPath.SubStr(0, currentPath.Length - 1);
                }

                string parentDirectory = Path::GetDirectoryName(currentPath);
                newPath = Path::Join(parentDirectory, sanitizedNewName);
            } else {
                string directoryPath = Path::GetDirectoryName(currentPath);
                string extension = Path::GetExtension(currentPath);
                newPath = Path::Join(directoryPath, sanitizedNewName + extension);
            }

            IO::Move(currentPath, newPath);
        }
    }

    void OpenFolder(const string &in path, bool verbose = false) {
        if (IO::FolderExists(path)) {
            OpenExplorerPath(path);
        } else {
            if (verbose) log("Folder does not exist: " + path, LogLevel::Info, 185, "OpenFolder", "", "\\$f80");
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

    bool IsInEditor() {
        CTrackMania@ app = cast<CTrackMania>(GetApp());
        if (app is null) return false;

        CSmArenaClient@ e = cast<CSmArenaClient>(app.Editor);
        if (e !is null) return true;
        return false;
    }

    bool IsPlayingInEditor() {
        CTrackMania@ app = cast<CTrackMania>(GetApp());
        if (app is null) return false;

        CSmArenaClient@ e = cast<CSmArenaClient>(app.Editor);
        if (e is null) return false;
        
        CSmArenaClient@ playground = cast<CSmArenaClient>(app.CurrentPlayground);
        if (playground is null) return false;

        return true;
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

        if (verbose) log(mapUid + " | " + pbTime, LogLevel::Debug, 265, "HasPersonalBest", "", "\\$f80");
        return pbTime > 0;
    }

    int CurrentPersonalBest(const string &in mapUid, bool verbose = false) {
        CTrackMania@ app = cast<CTrackMania>(GetApp());
        if (app is null) { if (verbose) log("app is null", LogLevel::Error, 271, "CurrentPersonalBest", "", "\\$f80"); return 0; }

        string _mapUid = mapUid;
        if (_mapUid == "") {
            CGameCtnChallenge@ map = app.RootMap;
            if (map is null || map.MapInfo.MapUid == "") { if (verbose) log("no map or UID", LogLevel::Error, 276, "CurrentPersonalBest", "", "\\$f80"); return 0; }
            _mapUid = map.MapInfo.MapUid;
        }

        if (verbose) log("querying PB for UID '" + _mapUid + "'", LogLevel::Info, 280, "CurrentPersonalBest", "", "\\$f80");

        CTrackManiaNetwork@ network = cast<CTrackManiaNetwork>(app.Network);
        if (network.ClientManiaAppPlayground is null) { if (verbose) log("no playground available", LogLevel::Error, 283, "CurrentPersonalBest", "", "\\$f80"); return 0; }

        CGameUserManagerScript@ userMgr = network.ClientManiaAppPlayground.UserMgr;
        MwId userId = (userMgr.Users.Length > 0) ? userMgr.Users[0].Id : MwId(uint(-1));
        if (verbose) log("using user ID " + userId.GetName(), LogLevel::Debug, 287, "CurrentPersonalBest", "", "\\$f80");

        CGameScoreAndLeaderBoardManagerScript@ scoreMgr = network.ClientManiaAppPlayground.ScoreMgr;
        int pbTime = scoreMgr.Map_GetRecord_v2(userId, _mapUid, "PersonalBest", "", "TimeAttack", "");

        if (verbose) log("result = " + pbTime, LogLevel::Info, 292, "CurrentPersonalBest", "", "\\$f80");
        return pbTime;
    }

    int GetPersonalBestTime() {
        CTrackMania@ app = cast<CTrackMania>(GetApp());
        CGameCtnChallenge@ map = app.RootMap;
        if (map is null || map.MapInfo.MapUid == "") return 0;

        CTrackManiaNetwork@ network = cast<CTrackManiaNetwork>(app.Network);
        if (network.ClientManiaAppPlayground is null) return 0;

        CGameUserManagerScript@ userMgr = network.ClientManiaAppPlayground.UserMgr;
        MwId userId = (userMgr.Users.Length > 0) ? userMgr.Users[0].Id : MwId(uint(-1));

        CGameScoreAndLeaderBoardManagerScript@ scoreMgr = network.ClientManiaAppPlayground.ScoreMgr;
        return scoreMgr.Map_GetRecord_v2(userId, map.MapInfo.MapUid, "PersonalBest", "", "TimeAttack", "");
    }
}

namespace _Net {
    dictionary downloadedData;

    array<UserData@> userData;

    class UserData {
        string key;
        string[] values;

        UserData(const string &in _key, const string[] &_values) {
            key = _key;
            values = _values;
        }
    }

    void GetRequestToEndpoint(const string &in url, const string &in key) {
        auto data = UserData(key, {url});
        userData.InsertLast(data);
        startnew(Hidden::Coro_GetRequestToEndpoint, @data);
    }

    void PostJsonToEndpoint(const string &in url, const string &in payload, const string &in key) {
        auto data = UserData(key, {url, payload});
        userData.InsertLast(data);
        startnew(Hidden::Coro_PostJsonToEndpoint, @data);
    }
    
    void DownloadFileToDestination(const string &in url, const string &in destination, const string &in key, const string &in overwriteFileName = "", bool noTmp = false) {
        auto data = UserData(key, {url, destination, overwriteFileName, noTmp ? "true" : "false"});
        userData.InsertLast(data);
        startnew(Hidden::Coro_DownloadFileToDestination, @data);
    }

    namespace Hidden {
        void Coro_GetRequestToEndpoint(ref@ _ud) {
            UserData@ data = cast<UserData@>(_ud);

            if (data.values.Length < 1) { log("Insufficient data in UserData for GetRequestToEndpoint", LogLevel::Error, 349, "Coro_GetRequestToEndpoint", "", "\\$f80"); return; }

            string url = data.values[0];
            string key = data.key;

            Net::HttpRequest@ request = Net::HttpRequest();
            request.Url = url;
            request.Method = Net::HttpMethod::Get;
            request.Start();

            while (!request.Finished()) { yield(); }

            if (request.ResponseCode() == 200) {
                downloadedData[key] = request.String();
                log("Successfully stored raw response for key: " + key, LogLevel::Info, 363, "Coro_GetRequestToEndpoint", "", "\\$f80");
            } else {
                log("Failed to fetch data from endpoint: " + url + ". Response code: " + request.ResponseCode(), LogLevel::Error, 365, "Coro_GetRequestToEndpoint", "", "\\$f80");
                downloadedData[key] = "{\"error\": \"Failed to fetch data\", \"code\": " + request.ResponseCode() + "}";
            }
        }

        void Coro_PostJsonToEndpoint(ref@ _ud) {
            UserData@ data = cast<UserData@>(_ud);
            if (data.values.Length < 1) { log("Insufficient data in UserData for PostJsonToEndpoint", LogLevel::Error, 372, "Coro_PostJsonToEndpoint", "", "\\$f80"); return; }

            string url = data.values[0];
            string payload = data.values[1];
            string key = data.key;

            Net::HttpRequest@ request = Net::HttpRequest();
            request.Url = url;
            request.Method = Net::HttpMethod::Post;
            request.Body = payload;
            request.Start();

            while (!request.Finished()) { yield(); }

            if (request.ResponseCode() == 200) {
                downloadedData[key] = request.String();
                log("Successfully stored raw response for key: " + key, LogLevel::Info, 388, "Coro_PostJsonToEndpoint", "", "\\$f80");
            } else {
                log("Failed to post JSON to endpoint: " + url + ". Response code: " + request.ResponseCode(), LogLevel::Error, 390, "Coro_PostJsonToEndpoint", "", "\\$f80");
                downloadedData[key] = "{\"error\": \"Failed to fetch data\", \"code\": " + request.ResponseCode() + "}";
            }
        }

        void Coro_DownloadFileToDestination(ref@ _ud) {
            UserData@ data = cast<UserData@>(_ud);
            if (data.values.Length < 4) { log("Insufficient data in UserData for DownloadFileToDestination", LogLevel::Error, 397, "Coro_DownloadFileToDestination", "", "\\$f80"); return; }

            string url = data.values[0];
            string destination = data.values[1];
            string overwriteFileName = data.values[2];
            bool noTmp = data.values[3] == "true";

            destination = Path::GetDirectoryName(destination);

            Net::HttpRequest@ request = Net::HttpRequest();
            request.Url = url;
            request.Method = Net::HttpMethod::Get;
            request.Start();

            while (!request.Finished()) { yield(); }

            if (request.ResponseCode() == 200) {
                string contentDisposition = Json::Write(request.ResponseHeaders().ToJson().Get("content-disposition"));
                string fileName = overwriteFileName;

                if (fileName == "") {
                    if (contentDisposition != "") {
                        int index = contentDisposition.IndexOf("filename=");
                        if (index != -1) {
                            fileName = contentDisposition.SubStr(index + 9);
                            fileName = fileName.Trim();
                            fileName = fileName.Replace("\"", "");
                        }
                    }

                    if (fileName == "") {
                        fileName = Path::GetFileName(url);
                    }
                }

                destination = Path::Join(destination, fileName);
                if (destination.EndsWith("/") || destination.EndsWith("\\")) {
                    destination = destination.SubStr(0, destination.Length - 1);
                }

                string tmpPath = Path::Join(IO::FromUserGameFolder(""), fileName);

                request.SaveToFile(tmpPath);
                _IO::File::CopyFileTo(tmpPath, destination);

                if (!IO::FileExists(tmpPath)) { log("Failed to save file to: " + tmpPath, LogLevel::Error, 442, "Coro_DownloadFileToDestination", "", "\\$f80"); return; }

                if (!IO::FileExists(destination)) { log("Failed to move file to: " + destination, LogLevel::Error, 444, "Coro_DownloadFileToDestination", "", "\\$f80"); return; }

                IO::Delete(tmpPath);

                if (!IO::FileExists(tmpPath) && IO::FileExists(destination)) {
                    log("File downloaded successfully, saving " + fileName + " to: " + destination, LogLevel::Info, 449, "Coro_DownloadFileToDestination", "", "\\$f80");

                    downloadedData[data.key] = destination;

                    while (true) {
                        sleep(10000);
                        array<string> keys = downloadedData.GetKeys();
                        for (uint i = 0; i < keys.Length; i++) {
                            downloadedData.Delete(keys[i]);
                        }
                    }
                }
            } else {
                log("Failed to download file. Response code: " + request.ResponseCode(), LogLevel::Error, 462, "Coro_DownloadFileToDestination", "", "\\$f80");
            }
        }
    }
}