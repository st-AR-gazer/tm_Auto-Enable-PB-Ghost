
namespace AllowCheck {
    void InitializeAllowCheck() {
        startnew(Chester::OnMapLoad);
    }

    string[] GameModeBlackList = {
        "TM_COTDQualifications_Online"/*, "TM_KnockoutDaily_Online"*/ // ghosts are loaded in TM_KnockoutDaily_Online, thanks @TNTree :peepoLove:
    };
    
    bool canLoadRecords = true;
    bool gamemode_AllowCheckIsOk = true;

    bool ConditionCheckMet() {
        return gamemode_AllowCheckIsOk;
    }

    bool AllowdToLoadRecords() {
        if (!ConditionCheckMet()) {
            log("Not all conditions have been checked or passed, records cannot be loaded.", LogLevel::Warn, 20, "AllowdToLoadRecords");
            return false;
        }
        return canLoadRecords;
    }

    string DissalowReason() {
        auto net = cast<CGameCtnNetwork>(GetApp().Network);
        auto cnsi = cast<CGameCtnNetServerInfo>(net.ServerInfo);
        if (!gamemode_AllowCheckIsOk) {
            return "You cannot loab maps in the blacklisted game mode: " + cnsi.ModeName;
        }
        if (!canLoadRecords) {
            return "General error | you cannot load records on this map.";
        }
        return "Unknown reason.";
    }

    namespace Chester {
        bool IsBlacklisted(const string &in mode) {
            for (uint i = 0; i < GameModeBlackList.Length; i++) {
                if (mode.ToLower().Contains(GameModeBlackList[i].ToLower())) {
                    return true;
                }
            }
            return false;
        }

        void OnMapLoad() {
            auto net = cast<CGameCtnNetwork>(GetApp().Network);
            if (net is null) return;

            auto cnsi = cast<CGameCtnNetServerInfo>(net.ServerInfo);
            if (cnsi is null) return;

            wstring mode = cnsi.ModeName;
            if (mode.Length == 0) return;

            if (IsBlacklisted(mode)) {
                log("Map loading disabled due to blacklisted mode: " + mode + "'", LogLevel::Warn, 59, "OnMapLoad");
                canLoadRecords = false;
                return;
            }

            gamemode_AllowCheckIsOk = true;
            canLoadRecords = true;
        }
    }
}
