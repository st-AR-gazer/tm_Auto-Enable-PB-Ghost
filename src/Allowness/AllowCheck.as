namespace AllowCheck {
    interface IAllownessCheck {
        void Initialize();
        bool IsConditionMet();
        string GetDisallowReason();
    }

    array<IAllownessCheck@> allownessModules;

    void InitializeAllowCheck() {
        allownessModules.InsertLast(GamemodeAllowness::CreateInstance());

        if (allownessModules.Length > 0) startnew(InitializeWrapper0);
    }
    void InitializeWrapper0() { allownessModules[0].Initialize(); }


    bool ConditionCheckMet() {
        for (uint i = 0; i < allownessModules.Length; i++) {
            if (!allownessModules[i].IsConditionMet()) {
                return false;
            }
        }
        return true;
    }

    bool AllowedToLoadRecords() {
        if (!ConditionCheckMet()) {
            log("Not all conditions have been checked or passed, records cannot be loaded.", LogLevel::Warn, 20, "AllowedToLoadRecords");
            return false;
        }
        return true;
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

//       ___           ___           ___                    ___           ___           ___           ___           ___           ___           ___           ___                    ___           ___       ___       ___           ___           ___           ___           ___           ___                    ___           ___           ___     
//      /\__\         /\  \         /\  \                  /\  \         /\  \         /\__\         /\  \         /\__\         /\  \         /\  \         /\  \                  /\  \         /\__\     /\__\     /\  \         /\__\         /\__\         /\  \         /\  \         /\  \                  /\__\         /\  \         /\  \    
//     /::|  |       /::\  \       /::\  \                /::\  \       /::\  \       /::|  |       /::\  \       /::|  |       /::\  \       /::\  \       /::\  \                /::\  \       /:/  /    /:/  /    /::\  \       /:/ _/_       /::|  |       /::\  \       /::\  \       /::\  \                /::|  |       /::\  \       /::\  \   
//    /:|:|  |      /:/\:\  \     /:/\:\  \              /:/\:\  \     /:/\:\  \     /:|:|  |      /:/\:\  \     /:|:|  |      /:/\:\  \     /:/\:\  \     /:/\:\  \              /:/\:\  \     /:/  /    /:/  /    /:/\:\  \     /:/ /\__\     /:|:|  |      /:/\:\  \     /:/\ \  \     /:/\ \  \              /:|:|  |      /:/\:\  \     /:/\:\  \  
//   /:/|:|__|__   /::\~\:\  \   /::\~\:\  \            /:/  \:\  \   /::\~\:\  \   /:/|:|__|__   /::\~\:\  \   /:/|:|__|__   /:/  \:\  \   /:/  \:\__\   /::\~\:\  \            /::\~\:\  \   /:/  /    /:/  /    /:/  \:\  \   /:/ /:/ _/_   /:/|:|  |__   /::\~\:\  \   _\:\~\ \  \   _\:\~\ \  \            /:/|:|__|__   /:/  \:\  \   /:/  \:\__\ 
//  /:/ |::::\__\ /:/\:\ \:\__\ /:/\:\ \:\__\          /:/__/_\:\__\ /:/\:\ \:\__\ /:/ |::::\__\ /:/\:\ \:\__\ /:/ |::::\__\ /:/__/ \:\__\ /:/__/ \:|__| /:/\:\ \:\__\          /:/\:\ \:\__\ /:/__/    /:/__/    /:/__/ \:\__\ /:/_/:/ /\__\ /:/ |:| /\__\ /:/\:\ \:\__\ /\ \:\ \ \__\ /\ \:\ \ \__\          /:/ |::::\__\ /:/__/ \:\__\ /:/__/ \:|__|
//  \/__/~~/:/  / \/__\:\/:/  / \/__\:\/:/  /          \:\  /\ \/__/ \/__\:\/:/  / \/__/~~/:/  / \:\~\:\ \/__/ \/__/~~/:/  / \:\  \ /:/  / \:\  \ /:/  / \:\~\:\ \/__/          \/__\:\/:/  / \:\  \    \:\  \    \:\  \ /:/  / \:\/:/ /:/  / \/__|:|/:/  / \:\~\:\ \/__/ \:\ \:\ \/__/ \:\ \:\ \/__/          \/__/~~/:/  / \:\  \ /:/  / \:\  \ /:/  /
//        /:/  /       \::/  /       \::/  /            \:\ \:\__\        \::/  /        /:/  /   \:\ \:\__\         /:/  /   \:\  /:/  /   \:\  /:/  /   \:\ \:\__\                 \::/  /   \:\  \    \:\  \    \:\  /:/  /   \::/_/:/  /      |:/:/  /   \:\ \:\__\    \:\ \:\__\    \:\ \:\__\                  /:/  /   \:\  /:/  /   \:\  /:/  / 
//       /:/  /        /:/  /         \/__/              \:\/:/  /        /:/  /        /:/  /     \:\ \/__/        /:/  /     \:\/:/  /     \:\/:/  /     \:\ \/__/                 /:/  /     \:\  \    \:\  \    \:\/:/  /     \:\/:/  /       |::/  /     \:\ \/__/     \:\/:/  /     \:\/:/  /                 /:/  /     \:\/:/  /     \:\/:/  /  
//      /:/  /        /:/  /                              \::/  /        /:/  /        /:/  /       \:\__\         /:/  /       \::/  /       \::/__/       \:\__\                  /:/  /       \:\__\    \:\__\    \::/  /       \::/  /        /:/  /       \:\__\        \::/  /       \::/  /                 /:/  /       \::/  /       \::/__/   
//      \/__/         \/__/                                \/__/         \/__/         \/__/         \/__/         \/__/         \/__/         ~~            \/__/                  \/__/         \/__/     \/__/     \/__/         \/__/         \/__/         \/__/         \/__/         \/__/                  \/__/         \/__/                
// MAP GAMEMODE ALLOWNESS MOD

namespace GamemodeAllowness {
    string[] GameModeBlackList = {
        "TM_COTDQualifications_Online", "TM_KnockoutDaily_Online"
    };

    class GamemodeAllownessCheck : AllowCheck::IAllownessCheck {
        bool isAllowed = false;
        
        void Initialize() {
            OnMapLoad();
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
                log("Map loading disabled due to blacklisted mode: " + mode, LogLevel::Warn, 59, "OnMapLoad");
                isAllowed = false;
            }
        }

        bool IsConditionMet() { return isAllowed; }

        string GetDisallowReason() {
            return isAllowed ? "" : "You cannot load maps in the blacklisted game mode.";
        }

        bool IsBlacklisted(const string &in mode) {
            return GameModeBlackList.Find(mode) >= 0;
        }
    }

    AllowCheck::IAllownessCheck@ CreateInstance() {
        return GamemodeAllownessCheck();
    }
}