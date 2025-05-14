namespace Loader {

    bool PBAvailable() { return _Game::CurrentPersonalBest(CurrentMapUID, true) != -1; }
    bool RecordsWidgetReady() { return UINav::Traverse(UINav::RECORDS_WIDGET) !is null; }

    void StartLoadProcess() { startnew(CoroutineFunc(LoadPBFlow)); }

    void LoadPBFlow() {
        WaitUntil(Predicate(@Loader::PBAvailable),       8000);
        WaitUntil(Predicate(@Loader::RecordsWidgetReady), 5000);

        log("Starting PB flow (local=" + _Game::IsPlayingLocal() + ", server=" + _Game::IsPlayingOnServer() + ")", LogLevel::Debug, 16, "LoadPBFlow");

        if      (_Game::IsPlayingLocal())    Local::EnsurePersonalBestLoaded();
        else if (_Game::IsPlayingOnServer()) Server::EnsurePersonalBestLoaded();

        CullPBsSlowerThanFastest();
        CullPBsWithTheSameTime();
    }

    void HidePB()            { UnloadPBGhost(); }
    void CullPBs()           { CullPBsSlowerThanFastest(); CullPBsWithTheSameTime(); }
    bool IsFastestPBLoaded() { return Utils::FastestPBIsLoaded(); }
}
