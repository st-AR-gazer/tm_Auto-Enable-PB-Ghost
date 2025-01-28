void Main() {
    if (!IO::FileExists(Index::GetDatabasePath())) {
        Index::InitializeDatabase();
    }
}