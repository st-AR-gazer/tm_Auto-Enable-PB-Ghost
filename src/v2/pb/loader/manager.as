namespace Loader {

    void LoadPB() {
        if (!_Game::IsPlayingMap()) { return; }

    }








    void LoadPersonalBestGhost(const string&in mapUid) {
        auto replays = Index::GetReplaysFromDB(mapUid);

        if (replays.Length == 0) {
            log("Loader::LoadPersonalBestGhost: No local PB ghost found for map UID: " + mapUid, LogLevel::Warn);
            return;
        }

        auto bestReplay = FindBestReplay(replays);
        if (bestReplay !is null) {
            string fullPath = IO::FromUserGameFolder(bestReplay.Path);
            LoadLocalGhost(fullPath);
        } else {
            log("Loader::LoadPersonalBestGhost: Failed to determine the best replay for map UID: " + mapUid, LogLevel::Error);
        }
    }

    ReplayRecord@ FindBestReplay(const array<ReplayRecord@>@ replays) {
        ReplayRecord@ bestReplay = null;
        uint bestTime = 2147483647;

        for (uint i = 0; i < replays.Length; i++) {
            if (replays[i].BestTime < bestTime) {
                @bestReplay = replays[i];
                bestTime = replays[i].BestTime;
            }
        }

        return bestReplay;
    }
}
