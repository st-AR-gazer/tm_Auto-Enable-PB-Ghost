auto hook_initializer = startnew(PBVisibilityHook::InitializeHook);

namespace PBVisibilityHook {
    bool pbToggleReceived = false;

    class PBVisibilityUpdateHook : MLHook::HookMLEventsByType {
        PBVisibilityUpdateHook(const string &in typeToHook) {
            super(typeToHook);
        }

        void OnEvent(MLHook::PendingEvent@ event) override {
            if (this.type == "TMGame_Record_TogglePB") {
                pbToggleReceived = true;
            } else if (this.type == "TMGame_Record_UpdatePBGhostVisibility") {
                if (!pbToggleReceived) {
                    return;
                }

                pbToggleReceived = false;

                bool shouldShow = tostring(event.data[0]).ToLower().Contains("true");

                if (shouldShow) {
                    t_hook_shouldLoadPBnow = true;
                    // log("PBVisibilityHook: Showing PB ghosts.", LogLevel::Debug, 25, "Unknown", "", "\\$f80");
                } else {
                    t_hook_shouldUnloadPBnow = true;
                    // log("PBVisibilityHook: Hiding PB ghosts.", LogLevel::Debug, 28, "Unknown", "", "\\$f80");
                }
            }
        }
    }

    PBVisibilityUpdateHook@ togglePBHook;
    PBVisibilityUpdateHook@ updateVisibilityHook;

    void InitializeHook() {
        @togglePBHook = PBVisibilityUpdateHook("TMGame_Record_TogglePB");
        MLHook::RegisterMLHook(togglePBHook, "TMGame_Record_TogglePB", true);

        @updateVisibilityHook = PBVisibilityUpdateHook("TMGame_Record_UpdatePBGhostVisibility");
        MLHook::RegisterMLHook(updateVisibilityHook, "TMGame_Record_UpdatePBGhostVisibility", true);

        // log("PBVisibilityHook: Hooks registered for TogglePB and UpdatePBGhostVisibility.", LogLevel::Debug, 44, "InitializeHook", "", "\\$f80");
    }
    
    void UninitializeHook() {
        if (togglePBHook !is null) {
            MLHook::UnregisterMLHookFromAll(togglePBHook);
            @togglePBHook = null;
        }
        if (updateVisibilityHook !is null) {
            MLHook::UnregisterMLHookFromAll(updateVisibilityHook);
            @updateVisibilityHook = null;
        }
        // log("PBVisibilityHook: Hooks unregistered for TogglePB and UpdatePBGhostVisibility.", LogLevel::Info, 56, "UninitializeHook", "", "\\$f80");
    }

    bool t_hook_shouldLoadPBnow = false;
    bool t_hook_shouldUnloadPBnow = false;
}

void Update(float dt) {
    // I hate that this took me so long to think of :xdd:
    if (PBVisibilityHook::t_hook_shouldLoadPBnow) {
        PBVisibilityHook::t_hook_shouldLoadPBnow = false;
        startnew(Loader::StartPBFlow);
    }
    if (PBVisibilityHook::t_hook_shouldUnloadPBnow) {
        PBVisibilityHook::t_hook_shouldUnloadPBnow = false;
        startnew(Loader::StopPBFlow);
    }
}