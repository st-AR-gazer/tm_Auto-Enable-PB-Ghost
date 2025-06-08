//    ___   _   __  __ ___ __  __  ___  ___  ___   ___ ___     _   _    _    _____      ___  _ ___ ___ ___   __  __  ___  ___  
//   / __| /_\ |  \/  | __|  \/  |/ _ \|   \| __| | _ \ _ )   /_\ | |  | |  / _ \ \    / / \| | __/ __/ __| |  \/  |/ _ \|   \ 
//  | (_ |/ _ \| |\/| | _|| |\/| | (_) | |) | _|  |  _/ _ \  / _ \| |__| |_| (_) \ \/\/ /| .` | _|\__ \__ \ | |\/| | (_) | |) |
//   \___/_/ \_\_|  |_|___|_|  |_|\___/|___/|___| |_| |___/ /_/ \_\____|____\___/ \_/\_/ |_|\_|___|___/___/ |_|  |_|\___/|___/
//  GAMEMODE PB ALLOWNESS MOD

namespace GamemodePBAllownessCheck {

    const string C_MLID_UIModuleUpdate = 'MLHook_PBGhostEnabled';
    const string C_ML_UIModuleUpdate = """
 #Include "TextLib" as TL

main() {
    /* PBGhostEnabled */
    declare netread Boolean Net_TMGame_Record_PBGhostEnabled for Teams[0];
    declare Boolean Last_PBGhostEnabled = Net_TMGame_Record_PBGhostEnabled;
    SendCustomEvent("MLHook_Event_PBGhostEnabled_Update", [ TL::ToText(Last_PBGhostEnabled) ]);

    /* CelebratePB */
    declare netread Boolean Net_TMGame_Record_CelebratePB for Teams[0];
    declare Boolean Last_CelebratePB = Net_TMGame_Record_CelebratePB;
    SendCustomEvent("MLHook_Event_CelebratePB_Update", [ TL::ToText(Last_CelebratePB) ]);

    /* PBGhostIsVisible (UI) */
    declare netread Boolean Net_TMGame_Record_PBGhostIsVisible for UI = True;
    declare Boolean Last_PBGhostIsVisible = Net_TMGame_Record_PBGhostIsVisible;
    if (Last_PBGhostIsVisible) SendCustomEvent("MLHook_Event_PBGhostIsVisible_UI_Update", [ "True" ]);


    /* ---------------------------------------------------------------- */
    while (True) {
        yield;

        /* PBGhostEnabled */
        if (Last_PBGhostEnabled != Net_TMGame_Record_PBGhostEnabled) {
            Last_PBGhostEnabled = Net_TMGame_Record_PBGhostEnabled;
            SendCustomEvent("MLHook_Event_PBGhostEnabled_Update", [ TL::ToText(Last_PBGhostEnabled) ]);
        }

        /* CelebratePB */
        if (Last_CelebratePB != Net_TMGame_Record_CelebratePB) {
            Last_CelebratePB = Net_TMGame_Record_CelebratePB;
            SendCustomEvent("MLHook_Event_CelebratePB_Update", [ TL::ToText(Last_CelebratePB) ]);
        }

        /* PBGhostIsVisible */
    /** 
    * idk why, but for some reason MLHook_Event_PBGhostIsVisible_UI_Update
    * triggers twice, once with the first value, the one we care about, and false 
    * after that, so we just ignore the second one :Shruge:
    */
        if (!Last_PBGhostIsVisible && Net_TMGame_Record_PBGhostIsVisible) {
            Last_PBGhostIsVisible = True;
            SendCustomEvent("MLHook_Event_PBGhostIsVisible_UI_Update", [ "True" ]);
        } else {
            Last_PBGhostIsVisible = Net_TMGame_Record_PBGhostIsVisible;
        }
    }
}
""";

    const array<string> WHITELISTED_MODES = {
        "TM_TimeAttack_Online"
    };

    bool IsWhitelisted(const string &in mode) {
        for (uint i = 0; i < WHITELISTED_MODES.Length; i++) {
            if (WHITELISTED_MODES[i] == mode) return true;
        }
        return false;
    }

    HookCustomizableModuleEvents@ HookEvents = null;

    bool isAllowed = true; // Gotta be global xdd
    class GamemodePBAllownessCheck : AllowCheck::IAllownessCheck {
        bool initialized = false;
        
        void Initialize() {
            OnMapLoad();
            initialized = true;
        }
        bool IsInitialized() { return initialized; }
        bool IsConditionMet() { return isAllowed; }
        string GetDisallowReason() { return isAllowed ? "" : "RESTRICTED GAMEMODE: '" + GetCurrentGameMode() + "' " + isAllowed; }

        // 

        void OnMapLoad() {
            if (!_Game::IsPlayingOnServer()) return;

            @HookEvents = HookCustomizableModuleEvents();
            MLHook::RegisterMLHook(HookEvents, "PBGhostEnabled_Update", false);
            MLHook::RegisterMLHook(HookEvents, "CelebratePB_Update", false);
            MLHook::RegisterMLHook(HookEvents, "PBGhostIsVisible_UI_Update", false);

            MLHook::InjectManialinkToPlayground(C_MLID_UIModuleUpdate, C_ML_UIModuleUpdate, true);
        }
    }
    string GetCurrentGameMode() {
        auto net = cast<CGameCtnNetwork>(GetApp().Network);
        if (net is null) return "";
        auto cnsi = cast<CGameCtnNetServerInfo>(net.ServerInfo);
        if (cnsi is null) return "";
        return cnsi.ModeName;
    }

    void _Unload() {
        log("Unloading all hooks and removing injected ML", LogLevel::Debug, 109, "_Unload");
        MLHook::UnregisterMLHooksAndRemoveInjectedML();
    }

    class HookCustomizableModuleEvents: MLHook::HookMLEventsByType {
        HookCustomizableModuleEvents() {
            super(C_MLID_UIModuleUpdate);
        }

        void OnEvent(MLHook::PendingEvent@ Event) override {
            auto val = string(Event.data[0]).ToLower();
            auto mode = GetCurrentGameMode();
            bool wh = IsWhitelisted(mode);

            if (val == "true" || val == "" || wh) {
                isAllowed = true;
            } else if (val == "false") {
                isAllowed = false;
            } else {
                log("Unknown value for PBGhostEnabled: " + Event.data[0], LogLevel::Error, 128, "_Unload");
            }

            trace(Event.type + ": " + Event.data[0] + " | GM=" + mode + (wh ? " (WHITELISTED)" : ""));
        }
    }

    AllowCheck::IAllownessCheck@ CreateInstance() {
        return GamemodePBAllownessCheck();
    }
}

void OnDestroyed() { GamemodePBAllownessCheck::_Unload(); }
void OnDisabled() { GamemodePBAllownessCheck::_Unload(); }
