// namespace Hotkey_TESTING {
    
//     namespace TESTING_Internal {
//         void Testing_Function() {
//             print("Func called from hotkey module!");
//         }
//     }

//     class Module : Hotkeys::IHotkeyModule {
//         string GetId() { return "print test"; }
//         array<string> acts = { "testing_v1" };
//         array<string> GetAvailableActions() { return acts; }

//         string GetActionDescription(const string &in act) {
//             if (act == "testing_v1") return "prints a test string to the console";
//             return "";
//         }

//         bool ExecuteAction(const string &in act, Hotkeys::Hotkey@ /*hk*/) {
//             if (act == "testing_v1") { TESTING_Internal::Testing_Function(); return true; }
//             return false;
//         }
//     }

//     Hotkeys::IHotkeyModule@ CreateInstance() { return Module(); }
//     void Initialize() {
//         const string PLUGIN = Meta::ExecutingPlugin().Name;
//         @g_TestingModule = CreateInstance();
//         Hotkeys::RegisterModule(PLUGIN, g_TestingModule);
//     }
// }

// Hotkeys::IHotkeyModule@ g_TestingModule;
// auto TestingModule_initializer = startnew(Hotkey_TESTING::Initialize);

// void Hotkey_TESTING_OnUnload() {
//     if (g_TestingModule !is null) Hotkeys::UnregisterModule(Meta::ExecutingPlugin().Name, g_TestingModule);
// }