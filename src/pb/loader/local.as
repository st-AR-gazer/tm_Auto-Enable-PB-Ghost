namespace Loader {

    namespace Local {

        void KickoffPluginPBLoad() {
            string uid = get_CurrentMapUID();
            if (uid == "") return;

            startnew(_Worker, uid);
        }

        void _Worker(const string &in mapUid) {
            const uint MAX_WAIT_MS = 5000;
            uint64 t0 = Time::Now;

            int bestHint = -1;

            while (Time::Now - t0 < MAX_WAIT_MS && bestHint < 0) {
                int gamePB   = _Game::CurrentPersonalBest(mapUid);
                int widgetPB = UINav::WidgetPlayerPB();

                if (gamePB > 0 && widgetPB > 0) bestHint = Math::Min(gamePB, widgetPB);
                else if (gamePB > 0)            bestHint = gamePB;
                else if (widgetPB > 0)          bestHint = widgetPB;

                if (bestHint < 0) yield();
            }

            log("Local PB kickoff: hint=" + bestHint + " ms", LogLevel::Debug, 29, "_Worker", "", "\\$f80");

            auto replays = Database::GetReplays(mapUid);
            
            if (replays.Length == 0) {
                log("No local replays found for map " + mapUid, LogLevel::Info, 34, "_Worker", "", "\\$f80");

                if (bestHint > 0 && !Loader::Remote::AlreadyAskedLB(mapUid)) {
                    Loader::Remote::MarkAskedLB(mapUid);
                    Loader::Remote::DownloadPBFromLeaderboard(mapUid);
                }
                return;
            }

            log("Found " + replays.Length + " local replays for map " + mapUid, LogLevel::Debug, 43, "_Worker", "", "\\$f80");

            if (bestHint > 0) {
                for (uint i = 0; i < replays.Length; ++i) {
                    if (int(replays[i].BestTime) == bestHint) {
                        _LoadReplayAsync(replays[i]);
                        return;
                    }
                }
            }

            ReplayRecord@ fastest = _FindFastestReplay(replays);
            if (fastest !is null) {
                _LoadReplayAsync(fastest);
            }
        }

        void _LoadReplayAsync(ReplayRecord@ rec) {
            if (rec is null) return;
            string key = rec.ReplayHash + "|" + rec.Path;
            startnew(_DoLoadByKey, key);
        }

        void _DoLoadByKey(const string &in key) {
            int sep = key.IndexOf("|");
            string hash = sep >= 0 ? key.SubStr(0, sep) : "";
            string path = sep >= 0 ? key.SubStr(sep + 1) : key;

            ReplayRecord@ rec = null;
            if (hash.Length > 0) {
                @rec = Database::GetReplayByHash(hash);
            }

            if (rec !is null) {
                log("Loading PB replay from: " + rec.Path, LogLevel::Debug, 65, "_DoLoadByKey", "", "\\$f80");
                if (!GhostIO::Load(rec)) { NotifyError("Failed to load PB replay: " + rec.Path); }
                return;
            }

            if (path.Length == 0) return;
            log("Loading PB replay from: " + path, LogLevel::Debug, 72, "_DoLoadByKey", "", "\\$f80");
            if (!GhostIO::Load(path)) { NotifyError("Failed to load PB replay: " + path); }
        }

        ReplayRecord@ _FindFastestReplay(const array<ReplayRecord@>@ replays) {
            ReplayRecord@ best = null;
            uint bestTime = 0xFFFFFFFF;

            for (uint i = 0; i < replays.Length; ++i) {
                if (replays[i].BestTime < bestTime) {
                    @best    = replays[i];
                    bestTime = replays[i].BestTime;
                }
            }
            return best;
        }
    }
}