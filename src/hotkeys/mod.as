
namespace Hotkey_PBLoadingModule {
    
    namespace Loader_Internal {
        bool ghostVisible = true;

        void StartLoadProcess() { Loader::LoadPBFlow(); }
        void HidePB()           { Loader::HidePB(); }

        void TogglePB() {
            if (ghostVisible) { HidePB();
            } else {            StartLoadProcess(); }
        }
    }

    class Module : Hotkeys::IHotkeyModule {
        string GetId() { return "PBLoading"; }
        array<string> acts = { "LoadPB", "HidePB", "TogglePB" };
        array<string> GetAvailableActions() { return acts; }

        string GetActionDescription(const string &in act) {
            if (act == "LoadPB")   return "Load the player's PB ghost";
            if (act == "HidePB")   return "Unload / hide the PB ghost";
            if (act == "TogglePB") return "Toggle PB ghost visibility";
            return "";
        }

        bool ExecuteAction(const string &in act, Hotkeys::Hotkey@ /*hk*/) {
            if (act == "LoadPB")   { Loader_Internal::StartLoadProcess(); return true; }
            if (act == "HidePB")   { Loader_Internal::HidePB();           return true; }
            if (act == "TogglePB") { Loader_Internal::TogglePB();         return true; }
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

auto pbloadingmod_initializer = startnew(Hotkey_PBLoadingModule::Initialize);
void OnUnload() {
    if (g_pbMod !is null) Hotkeys::UnregisterModule(Meta::ExecutingPlugin().Name, g_pbMod);
}