namespace MapTracker {
    string oldMapUid = "";

    void MapMonitor() {
        while (true) {
            sleep(273);

            if (!S_enableGhosts) continue;

            if (HasMapChanged() && S_loadPBs) {
                if (get_CurrentMapUID() == "") continue;
                while (!_Game::IsPlayingMap()) yield();

                uint timeout = 500;
                uint startTime = Time::Now;
                AllowCheck::InitializeAllowCheck();
                bool conditionMet = false;
                while (!conditionMet) { 
                    if (Time::Now - startTime > timeout) { NotifyWarn("Condition check timed out ("+timeout+" ms was given), assuming invalid state."); break; }
                    yield(); 
                    conditionMet = AllowCheck::ConditionCheckMet();
                }
                if (AllowCheck::ConditionCheckMet()) {

                    Loader::RemoveLocalPBsUntillNextMapForEasyLoading();
                    Loader::LoadPB();
                    Loader::CullPBsWithSameTime();
                
                } else {
                    NotifyWarn("You cannot load records on this map : " + AllowCheck::DissalowReason());
                }
            }

            if (HasMapChanged()) oldMapUid = get_CurrentMapUID();
        }
    }

    bool HasMapChanged() {
        return oldMapUid != get_CurrentMapUID();
    }
}