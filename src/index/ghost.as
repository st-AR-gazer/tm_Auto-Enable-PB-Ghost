namespace Ghost {
    string PrepareFileForLoading(const string &in filePath) {
        string path = filePath;

        if (!path.StartsWith(IO::FromUserGameFolder("Replay/"))) {
            log("File is not in the 'Replays' folder, copying over to temporary 'zzAutoEnablePBGhost/tmp' folder...", LogLevel::Info, 101, "PrepareFilesForAdditionToDatabase");

            string originalPath = path;
            string tempPath = IO::FromUserGameFolder(Index::GetRelative_zzReplayPath() + "/tmp/") + Path::GetFileName(path);

            if (IO::FileExists(tempPath)) {
                log("File already exists in temporary folder, deleting...", LogLevel::Warn, 106, "PrepareFilesForAdditionToDatabase");
                IO::Delete(tempPath);
            }

            _IO::File::CopyFileTo(originalPath, tempPath, true);

            path = tempPath;

            if (!IO::FileExists(path)) {
                log("Failed to copy file to temporary folder: " + path, LogLevel::Error, 113, "PrepareFilesForAdditionToDatabase");
                return "";
            }
        }

        if (path.StartsWith(IO::FromUserGameFolder("Replay/"))) {
            path = path.SubStr(IO::FromUserGameFolder("Replay/").Length, path.Length - IO::FromUserGameFolder("Replay/").Length);
        }

        return path;
    }

    void AddGhostToDatabase(const string &in filePath) {
        if (!filePath.ToLower().EndsWith(".ghost.gbx")) {
            log("File is not a ghost file: " + filePath, LogLevel::Error, 9, "AddGhostToDatabase");
            return;
        }

        CGameCtnGhost@ ctnGhost = GetCGameCtnGhost(filePath);
        if (ctnGhost is null) { log("Failed to get ghost nod", LogLevel::Error, 13, "AddGhostToDatabase"); return; }
        CGameGhostScript@ scriptGhost = GetCGameGhostScript(filePath);
        if (scriptGhost is null) { log("Failed to get script ghost nod", LogLevel::Error, 13, "AddGhostToDatabase"); return; }

        CGameCtnChallenge@ map = GetMapNod();
        if (map is null) { log("Failed to get map nod", LogLevel::Error, 15, "AddGhostToDatabase"); return; }
        CGameDataFileManagerScript@ dataFileMgr = GetDataFileMgr();
        if (dataFileMgr is null) { log("Failed to get data file manager", LogLevel::Error, 19, "AddGhostToDatabase"); return; }

        string fileContents = _IO::File::ReadFileToEnd(filePath);
        string fileHash = Crypto::Sha256(fileContents);
        string ghostPath = Index::GetFull_zzReplayPath() + "/gst/" + fileHash + ".ghost.gbx";
        IO::CreateFolder(ghostPath.SubStr(0, ghostPath.LastIndexOf("/")));

        if (ctnGhost !is null) {
            // CGameGhostScript@ tmpScriptGhost = ConvertCGameCtnGhostToCGameGhostScript(ctnGhost);
            // dataFileMgr.Replay_Save(ghostPath, map, tmpScriptGhost);
            log("Afaik it is not possible to save a ghost file using CGameCtnGhost...", LogLevel::Error, 26, "AddGhostToDatabase");
            return;
        }

        if (scriptGhost !is null) {
            dataFileMgr.Replay_Save(ghostPath, map, scriptGhost);
        }

        Index::AddFileToDatabase(filePath);
    }

    CGameCtnGhost@ GetCGameCtnGhost(const string &in filePath) {
        string finalPath = PrepareFileForLoading(filePath);
        if (finalPath == "") return null;

        CSystemFidFile@ fid = Fids::GetUser(finalPath);
        if (fid is null) { log("Failed to get fid for file: " + finalPath, LogLevel::Error, 125, "PrepareFilesForAdditionToDatabase"); return null; }

        CMwNod@ nod = Fids::Preload(fid);
        if (nod is null) { log("Failed to preload nod for file: " + finalPath, LogLevel::Error, 128, "PrepareFilesForAdditionToDatabase"); return null; }

        CGameCtnGhost@ ghost = cast<CGameCtnGhost>(nod);
        if (ghost is null) { log("Failed to cast nod to CGameCtnGhost: " + finalPath, LogLevel::Error, 132, "PrepareFilesForAdditionToDatabase"); return null; }

        return ghost;
    }

    CGameGhostScript@ GetCGameGhostScript(const string &in filePath) {
        string finalPath = PrepareFileForLoading(filePath);
        if (finalPath == "") return null;

        CSystemFidFile@ fid = Fids::GetUser(finalPath);
        if (fid is null) { log("Failed to get fid for file: " + finalPath, LogLevel::Error, 125, "PrepareFilesForAdditionToDatabase"); return null; }

        CMwNod@ nod = Fids::Preload(fid);
        if (nod is null) { log("Failed to preload nod for file: " + finalPath, LogLevel::Error, 128, "PrepareFilesForAdditionToDatabase"); return null; }

        CGameGhostScript@ scriptGhost = cast<CGameGhostScript>(nod);
        if (scriptGhost is null) { log("Failed to cast nod to CGameGhostScript: " + finalPath, LogLevel::Error, 132, "PrepareFilesForAdditionToDatabase"); return null; }

        return scriptGhost;
    }

    CGameCtnChallenge@ map_voidbase = CGameCtnChallenge();
    void SetMapNod() {
        string VOID_TEMPLATE_MAP_FILE = _IO::File::ReadSourceFileToEnd("/src/map/voidbase.map.gbx");
        string hash = Crypto::Sha256(VOID_TEMPLATE_MAP_FILE);
        _IO::File::WriteFile(IO::FromUserGameFolder("Maps/" + hash + ".Map.Gbx"), VOID_TEMPLATE_MAP_FILE, true);
        startnew(CoroutineFuncUserdataString(Index::DeleteFileWith200msDelay), IO::FromUserGameFolder("Maps/" + hash + ".Map.Gbx"));

        CSystemFidFile@ fid = Fids::GetUser(IO::FromUserGameFolder("Maps/" + hash + ".Map.Gbx"));
        if (fid is null) { log("Failed to get fid for file: " + IO::FromUserGameFolder("Maps/" + hash + ".Map.Gbx"), LogLevel::Error, 125, "PrepareFilesForAdditionToDatabase"); return; }
        CMwNod@ nod = Fids::Preload(fid);
        if (nod is null) { log("Failed to preload nod for file: " + IO::FromUserGameFolder("Maps/" + hash + ".Map.Gbx"), LogLevel::Error, 128, "PrepareFilesForAdditionToDatabase"); return; }
        CGameCtnChallenge@ map = cast<CGameCtnChallenge>(nod);
        if (map is null) { log("Failed to cast nod to CGameCtnChallenge for file: " + IO::FromUserGameFolder("Maps/" + hash + ".Map.Gbx"), LogLevel::Error, 128, "PrepareFilesForAdditionToDatabase"); return; }

        map_voidbase = cast<CGameCtnChallenge>(map);
    }

    CGameCtnChallenge@ GetMapNod() {
        return map_voidbase;
    }

    CGameDataFileManagerScript@ GetDataFileMgr() {
        CTrackMania@ app = cast<CTrackMania>(GetApp());
        if (app is null) return null;
        CSmArenaRulesMode@ playgroundScript = cast<CSmArenaRulesMode>(app.PlaygroundScript);
        if (playgroundScript is null) return null;
        CGameDataFileManagerScript@ dataFileMgr = cast<CGameDataFileManagerScript>(playgroundScript.DataFileMgr);
        return dataFileMgr;
    }

    // CGameCtnGhost@ ConvertCGameGhostScriptToCGameCtnGhost(CGameGhostScript@ ghost) {
    //     return cast<CGameCtnGhost>(Dev::GetOffsetNod(ghost, 0x20));
    // }

    // CGameGhostScript@ ConvertCGameCtnGhostToCGameGhostScript(CGameCtnGhost@ ghost) {
    //     return cast<CGameGhostScript>(Dev::GetOffsetNod(ghost, 0x20));
    // }
}