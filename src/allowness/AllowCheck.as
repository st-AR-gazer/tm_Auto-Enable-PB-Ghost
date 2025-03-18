// https://patorjk.com/software/taag/#p=display&f=Small

namespace AllowCheck {
    interface IAllownessCheck {
        void Initialize();
        bool IsConditionMet();
        string GetDisallowReason();
        bool IsInitialized();
    }

    array<IAllownessCheck@> allownessModules;
    bool isInitializing = false;

    enum ConditionStatus { ALLOWED, DISALLOWED, UNCHECKED }

    void InitializeAllowCheck() {
        if (isInitializing) { return; }
        isInitializing = true;

        while (allownessModules.Length > 0) {allownessModules.RemoveLast();}

        // 

        allownessModules.InsertLast(GamemodeAllowness::CreateInstance());

        // 

        startnew(InitializeAllModules);
    }

    void InitializeAllModules() {
        for (uint i = 0; i < allownessModules.Length; i++) { allownessModules[i].Initialize(); }
        isInitializing = false;
    }

    ConditionStatus ConditionCheckStatus() {
        bool allInitialized = true;
        bool allConditionsMet = true;
        for (uint i = 0; i < allownessModules.Length; i++) {
            auto module = allownessModules[i];
            if (!module.IsInitialized()) { allInitialized = false; }
            if (!module.IsConditionMet()) { allConditionsMet = false; }
        }
        if (!allInitialized) return ConditionStatus::UNCHECKED;
        if (!allConditionsMet) return ConditionStatus::DISALLOWED;
        return ConditionStatus::ALLOWED;
    }

    string DissalowReason() {
        string reason = "";
        for (uint i = 0; i < allownessModules.Length; i++) {
            if (!allownessModules[i].IsConditionMet()) {
                reason += allownessModules[i].GetDisallowReason() +  " ";
            }
        }
        return reason.Trim().Length > 0 ? reason.Trim() : "Unknown reason.";
    }
}