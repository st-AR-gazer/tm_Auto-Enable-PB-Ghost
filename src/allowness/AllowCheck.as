namespace AllowCheck {

    bool permissionsCheckInitialized = false;
    uint permissionsCheckStartTime = 0;
    uint permissionsCheckTimeout = 500;

    bool IsPermissionsCheckComplete() {
        if (!permissionsCheckInitialized) {
            AllowCheck::InitializeAllowCheck();
            permissionsCheckStartTime = Time::Now;
            permissionsCheckInitialized = true;
        }
        
        AllowCheck::ConditionStatus status = AllowCheck::ConditionCheckStatus();
        
        if (status != AllowCheck::ConditionStatus::UNCHECKED) {
            permissionsCheckInitialized = false;
            return true;
        }
        
        if (Time::Now - permissionsCheckStartTime > permissionsCheckTimeout) {
            NotifyWarn("Condition check timed out (" + permissionsCheckTimeout + " ms).");
            permissionsCheckInitialized = false;
            return true;
        }
        
        return false;
    }

}