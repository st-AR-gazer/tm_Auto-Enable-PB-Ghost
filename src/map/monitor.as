namespace MapTracker {
    string oldMapUid = "";

    void MapMonitor() {
        while (true) {
            sleep(273);
            if (!S_enableGhosts) continue;

            if (!_Game::IsPlayingMap()) { oldMapUid = ""; continue; }

            if (oldMapUid != get_CurrentMapUID() && S_enableGhosts) {
                if (get_CurrentMapUID() == "") { oldMapUid = ""; continue; }
                while (!_Game::IsPlayingMap()) yield();

                log("Map changed to: " + get_CurrentMapUID(), LogLevel::Debug, 15, "MapMonitor", "", "\\$f80");

                uint timeout = 500;
                uint startTime = Time::Now;
                AllowCheck::ConditionStatus status = AllowCheck::ConditionStatus::UNCHECKED;
                AllowCheck::InitializeAllowCheck();
                while (status == AllowCheck::ConditionStatus::UNCHECKED) {
                    if (Time::Now - startTime > timeout) { NotifyWarn("Condition check timed out (" + timeout + " ms)."); break; }
                    yield();
                    status = AllowCheck::ConditionCheckStatus();
                }

                if (status == AllowCheck::ConditionStatus::ALLOWED) {
                    Loader::StartLoadProcess();
                } else {
                    NotifyWarn("You cannot load records on this map: " + AllowCheck::DissalowReason());
                }
            }

            oldMapUid = get_CurrentMapUID();
        }
    }
}