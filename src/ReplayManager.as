namespace ReplayManager {
    void ProcessSelectedFile(const string &in filePath) {
        if (PBManager::IsPBLoaded() || PBManager::IsLocalPBLoaded()) { 
            log("PB is already loaded, doing nothing", LogLevel::Info, 4, "ProcessSelectedFile"); 
            return; 
        }

        startnew(CoroutineFuncUserdataString(Coro_ProcessSelectedFile), filePath);
    }

    void Coro_ProcessSelectedFile(const string &in filePath) {
        string fileExt = Path::GetExtension(filePath).ToLower();

        if (fileExt == ".gbx") {
            string properFileExtension = Path::GetExtension(filePath).ToLower();
            if (properFileExtension == ".gbx") {
                int secondLastDotIndex = _Text::NthLastIndexOf(filePath, ".", 2);
                int lastDotIndex = filePath.LastIndexOf(".");
                if (secondLastDotIndex != -1 && lastDotIndex > secondLastDotIndex) {
                    properFileExtension = filePath.SubStr(secondLastDotIndex + 1, lastDotIndex - secondLastDotIndex - 1);
                }
            }
            fileExt = properFileExtension.ToLower();
        }

        if (fileExt == "replay") {
            LoadReplayFromPath(filePath);
        } else {
            log("Unsupported file type: " + fileExt + " " + "Full path: " + filePath, LogLevel::Error, 29, "Coro_ProcessSelectedFile");
            NotifyWarn("Error | Unsupported file type.");
        }
    }

    void LoadReplayFromPath(const string &in path) {
        auto task = GetApp().Network.ClientManiaAppPlayground.DataFileMgr.Replay_Load(path);        

        while (task.IsProcessing) { yield(); }

        if (task.HasFailed || !task.HasSucceeded) {
            NotifyError("Failed to load replay file!");
            log("Failed to load replay file!", LogLevel::Error, 41, "LoadReplayFromPath");
            log(task.ErrorCode, LogLevel::Error, 42, "LoadReplayFromPath");
            log(task.ErrorDescription, LogLevel::Error, 43, "LoadReplayFromPath");
            log(task.ErrorType, LogLevel::Error, 44, "LoadReplayFromPath");
            log(tostring(task.Ghosts.Length), LogLevel::Error, 45, "LoadReplayFromPath");
            return;
        } else {
            log(task.ErrorCode, LogLevel::Info, 48, "LoadReplayFromPath");
            log(task.ErrorDescription, LogLevel::Info, 49, "LoadReplayFromPath");
            log(task.ErrorType, LogLevel::Info, 50, "LoadReplayFromPath");
            log(tostring(task.Ghosts.Length), LogLevel::Info, 51, "LoadReplayFromPath");
        }

        uint timeout = 15000;
        uint startTime = Time::Now;
        while (cast<CSmArenaRulesMode@>(GetApp().PlaygroundScript).GhostMgr is null) {
            if (Time::Now - startTime > timeout) { return; }
            yield();
        }

        auto ghostMgr = cast<CSmArenaRulesMode@>(GetApp().PlaygroundScript).GhostMgr;

        if (PBManager::IsPBLoaded() || PBManager::IsLocalPBLoaded()) {
            log("PB is already loaded, doing nothing", LogLevel::Info, 64, "LoadReplayFromPath");
            return;
        }

        for (uint i = 0; i < task.Ghosts.Length; i++) {
            task.Ghosts[i].IdName = "Personal best";
            task.Ghosts[i].Nickname = /*"$5d8" +*/ "Personal best";
            task.Ghosts[i].Trigram = "PB";
            ghostMgr.Ghost_Add(task.Ghosts[i]);
        }

        if (task.Ghosts.Length == 0) {
            NotifyWarn("No ghosts found in the replay file!");
            log("No ghosts found in the replay file!", LogLevel::Warn, 77, "LoadReplayFromPath");
            return;
        }
    }
}
