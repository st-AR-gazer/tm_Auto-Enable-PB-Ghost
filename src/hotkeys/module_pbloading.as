
namespace Hotkey_PBLoadingModule {
    
    namespace Loader_Internal {
        bool ghostVisible = true;

        void StartLoadProcess() { Loader::StartPBFlow(); }
        void HidePB()           { Loader::StopPBFlow(); }

        void TogglePB() {
            if (ghostVisible) {
                HidePB();
                ghostVisible = false; 
            } else {
                StartLoadProcess();
                ghostVisible = true;
            }
        }
    }

    class Module : Hotkeys::IHotkeyModule {
        string GetId() { return "Personal Best Handling"; }
        array<string> acts = { "Load your personal best ghost (on)", "Hide your personal best ghost (off)", "Toggle your personal best ghost (on/off)" };
        array<string> GetAvailableActions() { return acts; }

        string GetActionDescription(const string &in act) {
            if (act == "Load your personal best ghost (on)"      ) return "Load the player's PB ghost";
            if (act == "Hide your personal best ghost (off)"     ) return "Unload / hide the PB ghost";
            if (act == "Toggle your personal best ghost (on/off)") return "Toggle PB ghost visibility";
            return "";
        }

        bool ExecuteAction(const string &in act, Hotkeys::Hotkey@ /*hk*/) {
            if (act == "Load your personal best ghost (on)"      ) { Loader_Internal::StartLoadProcess(); return true; }
            if (act == "Hide your personal best ghost (off)"     ) { Loader_Internal::HidePB();           return true; }
            if (act == "Toggle your personal best ghost (on/off)") { Loader_Internal::TogglePB();         return true; }
            return false;
        }
    }

    Hotkeys::IHotkeyModule@ CreateInstance() { return Module(); }
    void Initialize() {
        const string PLUGIN = Meta::ExecutingPlugin().Name;
        @g_pbMod = Hotkey_PBLoadingModule::CreateInstance();
        Hotkeys::RegisterModule(PLUGIN, g_pbMod);
    }
}

Hotkeys::IHotkeyModule@ g_pbMod;

// Plugin entry for this module
auto pbloadingmod_initializer = startnew(Hotkey_PBLoadingModule::Initialize);
// Unload handler to unregister the module
class Hotkey_PBLoadingModule_OnUnload { ~Hotkey_PBLoadingModule_OnUnload() { if (g_pbMod !is null) Hotkeys::UnregisterModule(Meta::ExecutingPlugin().Name, g_pbMod); } }
Hotkey_PBLoadingModule_OnUnload pbloadingmod_unloader;