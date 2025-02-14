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

                print("Map changed to: " + get_CurrentMapUID());

                uint timeout = 500;
                uint startTime = Time::Now;
                AllowCheck::InitializeAllowCheck();
                bool conditionMet = false;

                while (!conditionMet) {
                    if (Time::Now - startTime > timeout) { NotifyWarn("Condition check timed out (" + timeout + " ms)."); break; }
                    yield();
                    conditionMet = AllowCheck::ConditionCheckMet();
                }

                if (AllowCheck::ConditionCheckMet()) {
                    Loader::RemoveLocalPBsUntillNextMapForEasyLoading();
                    Loader::LoadPB();
                    Loader::CullPBsWithSameTime();
                } else {
                    NotifyWarn("You cannot load records on this map: " + AllowCheck::DissalowReason());
                }
            }

            oldMapUid = get_CurrentMapUID();
        }
    }
}