![Signed](https://img.shields.io/badge/Signed-Yes-33BB33)
![Trackmania2020](https://img.shields.io/badge/Game-Trackmania-blue)

## Auto Enable PB Ghost  

---

In a recent update, Nadeo broke the automatic loading of PB ghosts when opening a map. This plugin aims to fix this (more mimic the original functionality).  

After installation, the plugin will automatically download your PB ghost on map load from the Nadeo leaderboard, it then loads the record, and saves it locally to avoid repeated downloads, unless you improve your time.  

This should resolve most issues caused by Nadeo's changes. However, there are cases where your PB exists, but doesn't appear on the leaderboard. To address this, the plugin also allows indexing of locally saved replays, whether in the main replays folder or an offload location (e.g if your replays are stored elsewhere for backups or faster startup). To access these you cna use the "Index Custom Location" option in the settings to ensure your PBs are added to the local database.
You can also index _just_ the `C:/[...]/Trackmania(2020)/Replays/` folder if you so choose.

Since this plugin aims to replicate the original PB ghost behavior, ghosts will **not** load in KO rounds (as they didn’t previously). However, they **will** load in the Time Attack phase of COTD. Thanks to @TNTree for the info.
PB Ghosts will also **not** be loaded in mactmaking. Thanks to @Airwam the info.  
