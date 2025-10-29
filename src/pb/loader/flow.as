namespace Loader {
    void StartPBFlow() {
        while (!AllowCheck::IsPermissionsCheckComplete()) { yield(); }
        AllowCheck::ConditionStatus status = AllowCheck::ConditionCheckStatus();
        if (status == AllowCheck::ConditionStatus::ALLOWED) {
            allownessPassedForCurrentFlowCall = true;

            Local::KickoffPluginPBLoad();
            PBMonitor::Start();
        
        } else {
            if (S_showPermissionWarnings) NotifyWarning("You cannot load records on this map: " + AllowCheck::DissalowReason());
            log("Allowness check failed: " + AllowCheck::DissalowReason(), LogLevel::Warning, 13, "StartPBFlow", "", "\\$f80");
            allownessPassedForCurrentFlowCall = false;
        }
    }

    void StopPBFlow() {
        PBMonitor::Stop();
        Unloader::RemoveAll();
    }
    
}