namespace Loader {

    bool PBAvailable() { return _Game::CurrentPersonalBest(CurrentMapUID) != -1; }
    bool RecordsWidgetReady() { return UINav::Traverse(UINav::RECORDS_WIDGET) !is null; }

    void StartLoadProcess() { startnew(CoroutineFunc(LoadPBFlow)); }

    void LoadPBFlow() {
        WaitUntil(Predicate(@Loader::PBAvailable),        8000);
        WaitUntil(Predicate(@Loader::RecordsWidgetReady), 5000);

        Loader::ResetLeaderboardPBFlag();
        Loader::ResetEnsurePBFlag();

        log("Starting PB flow (local=" + _Game::IsPlayingLocal() + ", server=" + _Game::IsPlayingOnServer() + ")", LogLevel::Debug, 15, "LoadPBFlow", "", "\\$f80");

        if      (_Game::IsPlayingLocal())    Local::EnsurePersonalBestLoaded();
        else if (_Game::IsPlayingOnServer()) Server::EnsurePersonalBestLoaded();

        CullPBsSlowerThanFastest();
        CullPBsWithTheSameTime();

        StartPostLoadMonitor();
    }

    void StartPostLoadMonitor() { startnew(CoroutineFunc(PostLoadMonitor)); }
    void PostLoadMonitor() {
        const uint start = Time::Now;
        while (Time::Now - start < 8000) {
            Loader::CullPBs();
            yield(250);
        }
    }

    void HidePB()            { UnloadPBGhost(); }
    // void CullPBs()        { CullPBsSlowerThanFastest(); CullPBsWithTheSameTime(); } // moved to remove.as
    bool IsFastestPBLoaded() { return Utils::FastestPBIsLoaded(); }
}
