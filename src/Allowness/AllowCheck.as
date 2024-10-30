// https://patorjk.com/software/taag/#p=display&f=Small

namespace AllowCheck {
    interface IAllownessCheck {
        void Initialize();
        bool IsConditionMet();
        string GetDisallowReason();
        bool IsInitialized();
    }

    array<IAllownessCheck@> allownessModules;
    bool isInitializing = false;

    void InitializeAllowCheck() {
        if (isInitializing) { return; }
        isInitializing = true;

        while (allownessModules.Length > 0) {allownessModules.RemoveLast();}

        // 

        allownessModules.InsertLast(GamemodeAllowness::CreateInstance());

        // 

        startnew(InitializeAllModules);
    }

    void InitializeAllModules() {
        for (uint i = 0; i < allownessModules.Length; i++) { allownessModules[i].Initialize(); }
        isInitializing = false;
    }

    bool ConditionCheckMet() {
        bool allMet = true;
        for (uint i = 0; i < allownessModules.Length; i++) {
            auto module = allownessModules[i];
            bool initialized = module.IsInitialized();
            bool condition = module.IsConditionMet();
            // log("ConditionCheckMet: Module " + i + " initialized: " + (initialized ? "true" : "false") + ", condition met: " + (condition ? "true" : "false"), LogLevel::Info, 100, "ConditionCheckMet");
            if (!initialized || !condition) { allMet = false; }
        }
        return allMet;
    }

    string DissalowReason() {
        string reason = "";
        for (uint i = 0; i < allownessModules.Length; i++) {
            if (!allownessModules[i].IsConditionMet()) {
                reason += allownessModules[i].GetDisallowReason() + " ";
            }
        }
        return reason.Trim().Length > 0 ? reason.Trim() : "Unknown reason.";
    }
}

//   __  __   _   ___    ___   _   __  __ ___ __  __  ___  ___  ___     _   _    _    _____      ___  _ ___ ___ ___   __  __  ___  ___  
//  |  \/  | /_\ | _ \  / __| /_\ |  \/  | __|  \/  |/ _ \|   \| __|   /_\ | |  | |  / _ \ \    / / \| | __/ __/ __| |  \/  |/ _ \|   \ 
//  | |\/| |/ _ \|  _/ | (_ |/ _ \| |\/| | _|| |\/| | (_) | |) | _|   / _ \| |__| |_| (_) \ \/\/ /| .` | _|\__ \__ \ | |\/| | (_) | |) |
//  |_|  |_/_/ \_\_|    \___/_/ \_\_|  |_|___|_|  |_|\___/|___/|___| /_/ \_\____|____\___/ \_/\_/ |_|\_|___|___/___/ |_|  |_|\___/|___/ 
// MAP GAMEMODE ALLOWNESS MOD

namespace GamemodeAllowness {
    string[] GameModeBlackList = {
        "TM_COTDQualifications_Online", "TM_KnockoutDaily_Online"
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
        string GetDisallowReason() { return isAllowed ? "" : "You cannot load maps in the blacklisted game mode."; }

        // 

        void OnMapLoad() {
            auto net = cast<CGameCtnNetwork>(GetApp().Network);
            if (net is null) return;
            auto cnsi = cast<CGameCtnNetServerInfo>(net.ServerInfo);
            if (cnsi is null) return;
            string mode = cnsi.ModeName;

            if (mode.Length == 0 || !IsBlacklisted(mode)) {
                isAllowed = true;
            } else {
                // log("Map loading disabled due to blacklisted mode: " + mode, LogLevel::Warn, 59, "OnMapLoad");
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

