namespace PBVisibilityHook {
    bool pbToggleReceived = false;

    class PBVisibilityUpdateHook : MLHook::HookMLEventsByType {
        PBVisibilityUpdateHook(const string &in typeToHook) {
            super(typeToHook);
        }

        void OnEvent(MLHook::PendingEvent@ event) override {
            if (this.type == "TMGame_Record_TogglePB") {
                pbToggleReceived = true;
            }
            else if (this.type == "TMGame_Record_UpdatePBGhostVisibility") {
                if (!pbToggleReceived) {
                    return;
                }

                pbToggleReceived = false;

                bool shouldShow = tostring(event.data[0]).ToLower().Contains("true");
                Loader::SetPBVisibility(shouldShow);

                if (shouldShow) {
                    Loader::LoadPB();
                    log("PBVisibilityHook: Showing PB ghosts.", LogLevel::Info, 25, "UnknownFunction");
                } else {
                    Loader::RemovePBs();
                    log("PBVisibilityHook: Hiding PB ghosts.", LogLevel::Info, 28, "UnknownFunction");
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

        log("PBVisibilityHook: Hooks registered for TogglePB and UpdatePBGhostVisibility.", LogLevel::Info, 44, "InitializeHook");
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
        log("PBVisibilityHook: Hooks unregistered for TogglePB and UpdatePBGhostVisibility.", LogLevel::Info, 56, "UninitializeHook");
    }
}