namespace ManualIndex {
    bool indexingInProgress = false;
    bool forceStopIndexing = false;
    array<string> dirsToProcess;
    array<string> foundFiles;
    int batchSize = 100;
    float progressFraction = 0.0f;
    string currentMessage = "";

    void StartRecursiveSearch(const string &in startFolder) {
        Stop();
        indexingInProgress = true;
        forceStopIndexing = false;
        foundFiles.Resize(0);
        dirsToProcess.Resize(0);
        dirsToProcess.InsertLast(startFolder);
        progressFraction = 0.0f;
        currentMessage = "Beginning recursive search in: " + startFolder;
        log(currentMessage, LogLevel::Info, 19, "StartRecursiveSearch");
        startnew(CoroutineFuncUserdata(IndexFolderCoroutine), null);
    }

    void Stop() {
        forceStopIndexing = true;
        indexingInProgress = false;
        foundFiles.Resize(0);
        dirsToProcess.Resize(0);
        progressFraction = 0.0f;
        currentMessage = "Stopped indexing.";
        log(currentMessage, LogLevel::Info, 30, "Stop");
    }

    float GetProgress() { return progressFraction; }

    array<string>@ GetFoundFiles() { return foundFiles; }

    void IndexFolderCoroutine(ref@ _) {
        uint totalDirCount = dirsToProcess.Length;
        uint processedDirCount = 0;
        while (indexingInProgress && dirsToProcess.Length > 0 && !forceStopIndexing) {
            string currentDir = dirsToProcess[dirsToProcess.Length - 1];
            dirsToProcess.RemoveAt(dirsToProcess.Length - 1);
            if (!IO::FolderExists(currentDir)) {
                log("Directory not found: " + currentDir, LogLevel::Warn, 44, "IndexFolderCoroutine");
                yield();
                continue;
            }
            string[]@ topLevel = IO::IndexFolder(currentDir, false);
            array<string> subfolders, files;
            for (uint i = 0; i < topLevel.Length; i++) {
                if (_IO::Directory::IsDirectory(topLevel[i])) {
                    currentMessage = topLevel[i];
                    subfolders.InsertLast(topLevel[i]);
                    if (i % 739 == 0) yield();
                } else {
                    currentMessage = topLevel[i];
                    files.InsertLast(topLevel[i]);
                    if (i % 739 == 0) yield();
                }
            }
            for (uint s = 0; s < subfolders.Length; s++) {
                dirsToProcess.InsertLast(subfolders[s]);
            }
            totalDirCount += subfolders.Length;
            uint processedInThisDir = 0;
            for (uint f = 0; f < files.Length && !forceStopIndexing; f++) {
                foundFiles.InsertLast(files[f]);
                processedInThisDir++;
                if (processedInThisDir >= batchSize) {
                    processedInThisDir = 0;
                    yield();
                }
            }
            processedDirCount++;
            progressFraction = totalDirCount == 0 ? 1.0f : float(processedDirCount) / float(totalDirCount);
            currentMessage = "Indexed dir: " + currentDir;
            // log(currentMessage, LogLevel::Debug, 77, "IndexFolderCoroutine");
            yield();
        }
        indexingInProgress = false;
        progressFraction = 1.0f;
        if (forceStopIndexing) {
            log("ManualIndex: Indexing forcibly stopped.", LogLevel::Warn, 83, "IndexFolderCoroutine");
            currentMessage = "Indexing forcibly stopped.";
            sleep(2000);
            currentMessage = "";
        } else {
            log("ManualIndex: Indexing complete.", LogLevel::Info, 88, "IndexFolderCoroutine");
            currentMessage = "Indexing complete.";
            sleep(2000);
            currentMessage = "";
        }
    }
}
