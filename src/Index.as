array<PBRecord@> pbRecords;
string autosaves_index = IO::FromStorageFolder("autosaves_index.json");

void IndexAndSaveToFile() {
    pbRecords.RemoveRange(0, pbRecords.Length);

    for (uint i = 0; i < GetApp().ReplayRecordInfos.Length; i++) {
        auto record = GetApp().ReplayRecordInfos[i];
        string path = record.Path;

        if (path.StartsWith("Autosaves\\")) {
            string mapUid = record.MapUid;
            string fileName = record.FileName;

            string relativePath = "Replays/" + fileName;
            string fullFilePath = IO::FromUserGameFolder(relativePath);

            PBRecord@ pbRecord = PBRecord(mapUid, fileName, fullFilePath);
            pbRecords.InsertLast(pbRecord);
        }
    }

    SavePBRecordsToFile();
}

void SavePBRecordsToFile() {
    string savePath = autosaves_index;
    Json::Value jsonData = Json::Array();

    for (uint i = 0; i < pbRecords.Length; i++) {
        Json::Value@ record = Json::Object();
        record["MapUid"] = pbRecords[i].MapUid;
        record["FileName"] = pbRecords[i].FileName;
        record["FullFilePath"] = pbRecords[i].FullFilePath;
        jsonData.Add(record);
    }

    string saveData = Json::Write(jsonData, true);

    _IO::File::WriteFile(savePath, saveData, true);
}

void LoadPBRecordsFromFile() {
    string loadPath = autosaves_index;
    if (!IO::FileExists(loadPath)) {
        log("PBManager: Autosaves index file does not exist. Indexing will be performed on map load.", LogLevel::Info, 46, "LoadPBRecordsFromFile");
        return;
    }

    // change this so that it just reads from the file instead of parsing every time?
    string str_jsonData = _IO::File::ReadFileToEnd(loadPath);
    Json::Value jsonData = Json::Parse(str_jsonData);

    pbRecords.RemoveRange(0, pbRecords.Length);

    for (uint i = 0; i < jsonData.Length; i++) {
        auto j = jsonData[i];
        string mapUid = j["MapUid"];
        string fileName = j["FileName"];
        string fullFilePath = j["FullFilePath"];
        PBRecord@ pbRecord = PBRecord(mapUid, fileName, fullFilePath);
        pbRecords.InsertLast(pbRecord);
    }

    log("PBManager: Successfully loaded autosaves index from " + loadPath, LogLevel::Info, 65, "LoadPBRecordsFromFile");
}