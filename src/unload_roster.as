void OnDestroyed() {
    Hotkeys_Unload();

    Allowness_Unload();

    Hotkey_PBLoadingModule_OnUnload();
}

void OnDisabled() {
    OnDestroyed();
}