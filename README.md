![Signed](https://img.shields.io/badge/Signed-Yes-33BB33)
![Trackmania2020](https://img.shields.io/badge/Game-Trackmania-blue)

# Auto Enable PB Ghost

This plugin fixes the issue of PBs not loading on decently old maps. 
The plugin fixes this by indexing and managing the files in `C:/[...]/Trackmania(2020)/Replays/Autosaves/`. 
The plugin then automatically loads and unloads your PB ghosts dynamically.

## Overview

The Auto Enable PB Ghost plugin automatically indexes personal best replays and loads them when entering a map. It supports only specific game modes and ensures that blacklisted modes do not allow PB ghost loading.

## Features

- **Automatic Indexing:** Automatically indexes replay files from `C:/[...]/Trackmania(2020)/Replays/Autosaves/` note: moving a file away from this location will not allow it to be loaded as a 'Personal best' ghost.
- **PB Ghost Loading/Unloading:** Loads PB ghosts dynamically based on the current map and unloads them as needed.
- **Mode Restriction:** Disables PB ghost loading in specified game modes.

## ⚠️ Important Notes

1. **Limitations:** Works only with Trackmania 2020.
2. **Game Mode Restrictions:** Does not function in certain modes like "COTD Knockout."
3. **Storage Dependency:** Requires `C:/[...]/Trackmania(2020)/Replays/Autosaves/` files to exist for accurate indexing, so please don't tamper with it.

## Prerequisites

- [Trackmania](http://trackmania.com/) game installed

## How It Works

- **Indexing:** Scans and indexes replay files from the autosaves folder.
- **Dynamic Loading:** Loads PB ghosts when entering a compatible map.
- **Mode Check:** Checks game mode and prevents ghost loading if blacklisted.

## Credits

- **Author:** .ar
