// Mod example:
namespace Hotkey_MODULE_NAME_HERE {
    
    namespace MODULE_Internal {

        // call other functions from other parts of the plugin here.

        bool exampleVar = true;

        void Example_Function() {
            Loader::LoadPBFlow();
        }

        void Other_Example_Functions() {
            if (exampleVar) {
                Example_Function();
                exampleVar = false; 
            } else {
                Example_Function();
                exampleVar = true;
            }
        }
    }

    class Module : Hotkeys::IHotkeyModule {
        // Define the module ID and actions.
        string GetId() { return "MODULE ID HERE"; }
        // Define the actions available in this module.
        array<string> acts = { "MODULE ACTION HERE _1", "MODULE ACTION HERE _2" };
        array<string> GetAvailableActions() { return acts; }

        string GetActionDescription(const string &in act) {
            // Provide a description for each action.
            if (act == "MODULE ACTION HERE _1") return "MODULE ACTION DESCRIPTION HERE _1";
            if (act == "MODULE ACTION HERE _2") return "MODULE ACTION DESCRIPTION HERE _2";
            return "";
        }

        bool ExecuteAction(const string &in act, Hotkeys::Hotkey@ /*hk*/) {
            // Execute the action based on the action string.
            // You can call functions from MODULE_Internal here, or any other part of your plugin, if you so desire.
            // Return true to show that the action was executed.
            if (act == "MODULE ACTION HERE _1") { MODULE_Internal::Example_Function();        return true; }
            if (act == "MODULE ACTION HERE _2") { MODULE_Internal::Other_Example_Functions(); return true; }
            return false;
        }
    }

    Hotkeys::IHotkeyModule@ CreateInstance() { return Module(); }
    void Initialize() {
        // Register the module with the Hotkeys system.
        // This is called when the plugin is loaded.
        const string PLUGIN = Meta::ExecutingPlugin().Name;
        // OBS: Don't forget to change the g_MODULE_NAME_HERE variable to match your module name.
        @g_MODULE_NAME_HERE = CreateInstance();
        Hotkeys::RegisterModule(PLUGIN, g_MODULE_NAME_HERE);
    }
}

// Create an instance of the module and initialize it.
Hotkeys::IHotkeyModule@ g_MODULE_NAME_HERE;
// This method under can be used to provide another entry point for script execution, this is done here so that we don't have to call this from void Main()
// Don't forget to change both the variable and the function name to match your module name.
auto MODULE_NAME_HERE_initializer = startnew(Hotkey_MODULE_NAME_HERE::Initialize);

// To my knowledge there isn't a way to provide an entry point for unloading the module without using the OnDestroyed / OnDisabled callbacks, make sure to 
// call this function when the plugin is meant to be unloaded, though something like this:
/**
void OnDisabled() { Hotkey_MODULE_NAME_HERE_OnUnload(); }
void OnDestroyed() { OnDisabled(); }
 */
void Hotkey_MODULE_NAME_HERE_OnUnload() {
    if (g_MODULE_NAME_HERE !is null) Hotkeys::UnregisterModule(Meta::ExecutingPlugin().Name, g_MODULE_NAME_HERE);
}