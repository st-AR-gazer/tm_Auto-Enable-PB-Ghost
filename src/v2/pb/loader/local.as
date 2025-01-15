namespace Loader {
    void LoadLocalGhost(const string&in filePath) {
        if (!filePath.StartsWith(IO::FromUserGameFolder("Replays/"))) {
            log("Loader::LoadLocalGhost: File is not in the Replays folder.", LogLevel::Error);
            return;
        }

        auto app = GetApp();
        if (app.Network.ClientManiaAppPlayground !is null) {
            app.Network.ClientManiaAppPlayground.DataFileMgr.Replay_Load(filePath);
            log("Loader::LoadLocalGhost: Loaded local ghost: " + filePath, LogLevel::Info);
        } else {
            log("Loader::LoadLocalGhost: Failed to load ghost: ClientManiaAppPlayground is null.", LogLevel::Error);
        }
    }
}
