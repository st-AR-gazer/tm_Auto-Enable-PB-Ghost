//    ___   _   __  __ ___ __  __  ___  ___  ___     _   _    _    _____      ___  _ ___ ___ ___   __  __  ___  ___  
//   / __| /_\ |  \/  | __|  \/  |/ _ \|   \| __|   /_\ | |  | |  / _ \ \    / / \| | __/ __/ __| |  \/  |/ _ \|   \ 
//  | (_ |/ _ \| |\/| | _|| |\/| | (_) | |) | _|   / _ \| |__| |_| (_) \ \/\/ /| .` | _|\__ \__ \ | |\/| | (_) | |) |
//   \___/_/ \_\_|  |_|___|_|  |_|\___/|___/|___| /_/ \_\____|____\___/ \_/\_/ |_|\_|___|___/___/ |_|  |_|\___/|___/ 
//  GAMEMODE ALLOWNESS MOD

namespace GamemodeAllowness {
    string[] GameModeBlackList = {
        /*"TM_COTDQualifications_Online", */"TM_KnockoutDaily_Online", // You can apperently load PB ghosts in the COTD Qualifications mode, thank you TNTree :peepoLove:
        "TM_Teams_Matchmaking_Online"
    };

    class GamemodeAllownessCheck : AllowCheck::IAllownessCheck {
        bool isAllowed = false;
        bool initialized = false;
        
        void Initialize() {
            OnMapLoad();
            initialized = true;
        }
        bool IsInitialized() { return initialized; }
        bool IsConditionMet() { return isAllowed; }
        string GetDisallowReason() { return isAllowed ? "" : "BLACKLISTED GAMEMODE: '" + GetCurrentGameMode() + "'"; }

        // 

        string GetCurrentGameMode() {
            auto net = cast<CGameCtnNetwork>(GetApp().Network);
            if (net is null) return "";
            auto cnsi = cast<CGameCtnNetServerInfo>(net.ServerInfo);
            if (cnsi is null) return "";
            return cnsi.ModeName;
        }

        void OnMapLoad() {
            auto net = cast<CGameCtnNetwork>(GetApp().Network);
            if (net is null) return;
            auto cnsi = cast<CGameCtnNetServerInfo>(net.ServerInfo);
            if (cnsi is null) return;
            string mode = cnsi.ModeName;

            if (mode.Length == 0 || !IsBlacklisted(mode)) {
                isAllowed = true;
            } else {
                log("Map loading disabled due to blacklisted mode: " + mode, LogLevel::Warn, 45, "OnMapLoad");
                isAllowed = false;
            }
        }

        bool IsBlacklisted(const string &in mode) {
            return GameModeBlackList.Find(mode) >= 0;
        }        
    }

    AllowCheck::IAllownessCheck@ CreateInstance() {
        return GamemodeAllownessCheck();
    }
}