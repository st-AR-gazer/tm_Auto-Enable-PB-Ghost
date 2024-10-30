namespace PBVisibilityHook {
    bool pbToggleReceived = false;

    class PBVisibilityUpdateHook : MLHook::HookMLEventsByType {
        PBVisibilityUpdateHook(const string &in typeToHook) {
            super(typeToHook);
        }

        void OnEvent(MLHook::PendingEvent@ event) override {
            if (this.type == "TMGame_Record_TogglePB") {
                pbToggleReceived = true;
                log("PBVisibilityHook: Received TMGame_Record_TogglePB event.", LogLevel::Info, 100, "OnEvent");
            }
            else if (this.type == "TMGame_Record_UpdatePBGhostVisibility") {
                if (!pbToggleReceived) {
                    log("PBVisibilityHook: Ignoring TMGame_Record_UpdatePBGhostVisibility event without prior PB toggle.", LogLevel::Info, 101, "OnEvent");
                    return;
                }

                pbToggleReceived = false;

                bool shouldShow = tostring(event.data[0]).ToLower().Contains("true");

                if (shouldShow) {
                    PBManager::LoadPB();
                    log("PBVisibilityHook: PB ghost set to visible.", LogLevel::Info, 101, "PBVisibilityUpdateHook");
                } else {
                    PBManager::UnloadPB();
                    log("PBVisibilityHook: PB ghost set to hidden.", LogLevel::Info, 102, "PBVisibilityUpdateHook");
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

        log("PBVisibilityHook: Hooks registered for TogglePB and UpdatePBGhostVisibility.", LogLevel::Info, 104, "InitializeHook");
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
        log("PBVisibilityHook: Hooks unregistered for TogglePB and UpdatePBGhostVisibility.", LogLevel::Info, 105, "UninitializeHook");
    }
}