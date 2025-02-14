
namespace Hotkey_PBLoadingModule {
    class Hotkey_PBLoadingHotkeyModule : Hotkeys::IHotkeyModule {
        array<string> actions = {
            "Load PB", "Hide PB"
        };

        void Initialize() { }

        array<string> GetAvailableActions() {
            return actions;
        }

        bool ExecuteAction(const string &in action, Hotkeys::Hotkey@ hotkey) {
            if (action == "Load PB") {
                Loader::LoadPB();
                return true;
            } else if (action == "Hide PB") {
                Loader::HidePB();
                return true;
            }
            return false;
        }
    }

    Hotkeys::IHotkeyModule@ CreateInstance() {
        return Hotkey_PBLoadingHotkeyModule();
    }
}