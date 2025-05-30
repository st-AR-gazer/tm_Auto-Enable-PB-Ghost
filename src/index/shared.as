class ReplayRecord {
    string ReplayHash;
    string MapUid;
    string PlayerLogin;
    string PlayerNickname;
    string FileName;
    string Path;
    uint   BestTime = 0;
    string NodeType;
    string FoundThrough;

    void CalculateHash() {
        string buf = _IO::File::ReadFileToEnd(Path);
        ReplayHash = Crypto::MD5(buf);
    }
}