const float INDENT = 20.0f;
const vec2  BAR_W  = vec2(520, 0);

bool UI_ButtonColored(const string &in label, float r, float g, float b) {
    UI::PushStyleColor(UI::Col::Button,        vec4(r, g, b, 1));
    UI::PushStyleColor(UI::Col::ButtonHovered, vec4(r, g, b, 1) * 1.20f);
    UI::PushStyleColor(UI::Col::ButtonActive,  vec4(r, g, b, 1) * 1.40f);
    bool hit = UI::Button(label);
    UI::PopStyleColor(3);
    return hit;
}

void UI_DrawFullTree(Index::DirNode@ n, int depth = 0) {
    if (n is null) return;

    if (depth > 0) UI::Indent(INDENT);

    UI::Text(n.name);
    UI::SameLine();
    UI::ProgressBar(n.Fraction(), BAR_W);

    for (uint i = 0; i < n.children.Length; ++i) UI_DrawFullTree(n.children[i], depth + 1);

    if (depth > 0) UI::Unindent(INDENT);
}

array<string> selectedPaths;

void RT_T_Indexing() {

    UI::Text("Indexing Options");
    UI::Separator();

    // File Explorer dings
    if (UI::Button(Colorize(Icons::FolderOpen + " Select location through a File Explorer", { "#fff", "#ddd" }, colorize::GradientMode::linear))) {
        FileExplorer::fe_Start("Select Path for 'additional location for replay indexing' setting", true, "path", vec2(1, 1), IO::FromUserGameFolder(""), "", { "*" }, { "*" });
    }
    // File Explorer dings
    
    UI::SameLine(); UI::Text(Icons::QuestionCircle);
    _UI::SimpleTooltip(
        "This will open a file-explorer window where you can choose a folder to use in the 'Additional Location for Replay Indexing' setting.\n\n"
        "Please keep in mind that I built the file explorer a while ago, so it isn't the most optimized thing ever. xD"
    );
    
    // File Explorer dings
    auto exampleExlorer_Paths = FileExplorer::fe_GetExplorerById("Select Path for 'additional location for replay indexing' setting");
    if (exampleExlorer_Paths !is null && exampleExlorer_Paths.exports.IsSelectionComplete()) {
        auto paths = exampleExlorer_Paths.exports.GetSelectedPaths();
        if (paths !is null) {
            S_customFolderIndexingLocation = paths[0]; // Only one path is expected to be returned so we only ever select the first one xdd
            exampleExlorer_Paths.exports.SetSelectionComplete();
        }
    }
    // File Explorer dings

    S_customFolderIndexingLocation = UI::InputText("##", S_customFolderIndexingLocation); UI::SameLine(); UI::Text("Additional location for replay indexing " + Icons::QuestionCircle);
    _UI::SimpleTooltip(
        "Many players prefer to store their replays in a location separate from the default one provided by Nadeo."
        "This is useful if you want to e.g. boot your game faster, since it takes a while for Nadeo "
        "to index all the files in the Replays/ folder, as this is something that is done on game start. "
        "But since this data is not stored in the game itself, as it was never indexed, we have to "
        "index this data ourselves, which is what this setting is for.\n\n"

        "This is the default location where I assume people store their offloaded replays, but you can "
        "change it to wherever you store yours."
        + IO::FromUserGameFolder("Replays_Offload/"));

    UI::BeginDisabled(Index::IsScanning());
    if (UI_ButtonColored("Index folder", 0.55f, 0.80f, 0.60f)) {
        if (IO::FolderExists(S_customFolderIndexingLocation)) {
            Index::StartIndexing(S_customFolderIndexingLocation);
        } else {
            NotifyWarn("Folder does not exist!");
        }
    }
    UI::EndDisabled();

    UI::SameLine();

    if (UI_ButtonColored("Delete database", 0.50f, 0.00f, 0.12f)) Database::DeleteDatabase();

    UI::Separator();

    if (Index::IsScanning()) {
        UI::Text("\\$aaaIndexing personal-best ghosts...");
        UI_DrawFullTree(Index::Root());

    } else if (Database::IsAddingToDatabase()) {
        UI::Text("\\$aaaAdding ghosts to database...");
        UI::Text("Total: " + Database::AddTotal() + " / Done: " + Database::AddDone());
        UI::ProgressBar(Database::AddFraction(), BAR_W);

    } else if (Processing::IsProcessing()) {
        if (!Processing::BuildFinished()) {
            UI::Text("\\$aaaBuilding file list...");
            UI::Text("Files: " + Processing::BuildDone() + " / " + Processing::BuildTotal());
            UI::ProgressBar(Processing::BuildFraction(), BAR_W);
            return;
        }

        if (!Processing::ParseFinished()) {
            UI::Text("\\$aaaParsing ghosts...");
            UI::Text("Parsed: " + Processing::Parsed() + " / " + Processing::TotalToParse());
            UI::Text("Skipped format: " + Processing::SkippedFormat());
            UI::Text("Skipped >50 MB: " + Processing::SkippedLarge());
            UI::Text("Skipped timeout: " + Processing::SkippedTimeout()); // Timeout is set to 0, so this will never happen xpp
            UI::Text("Skipped login: " + Processing::SkippedLogin());
            UI::Text("Skipped total: " + Processing::SkippedTotal());
            UI::ProgressBar(Processing::ParseFraction(), BAR_W);
            return;
        }

        if (!Processing::HashFinished()) {
            UI::Text("\\$aaaHashing replays (< 5 MB)...");
            UI::Text("Hashed: " + Processing::HashDone() + " / " + Processing::HashTotal());
            UI::Text("Skipped >5 MB: " + Processing::HashSkipped());
            UI::ProgressBar(Processing::HashFraction(), BAR_W);
            return;
        }

        UI::Text("\\$0f0Processing complete!");
        UI::ProgressBar(1.0f, BAR_W);

    } else if (Index::Root() !is null) {
        // I should change this so that data is only gotten once, and then stored instead of calling this every frame...
        uint d = Index::Root().TotalDirs();
        uint f = Index::Root().TotalFiles();

        UI::Text("\\$0f0Last scan:");
        UI::Text("Folders: " + d);
        UI::Text("Files: " + f + " (.ghost/.replay)");

        if (Processing::BuildFinished() && Processing::ParseFinished()) {
            UI::Text("Queued: " + Processing::TotalToParse());
            UI::Text("Parsed: " + Processing::Parsed());
            UI::Text("Skipped (Format): " + Processing::SkippedFormat());
            UI::Text("Skipped (Large): " + Processing::SkippedLarge());
            UI::Text("Skipped (Timeout): " + Processing::SkippedTimeout());
            UI::Text("Skipped (Login): " + Processing::SkippedLogin());
            UI::Text("Skipped (Total): " + Processing::SkippedTotal());
            UI::Text("Hashed: " + Processing::HashDone() + " / " + Processing::HashTotal());
        }

        if (!Processing::HashFinished()) {
            UI::Text("\\$aaaHashing replays (< 5 MB)...");
            UI::Text("Hashed: " + Processing::HashDone() + " / " + Processing::HashTotal() + " (Skipped big: " + Processing::HashSkipped() + ")");
            UI::ProgressBar(Processing::HashFraction(), BAR_W);
            return;
        }

        UI::ProgressBar(Index::Root().Fraction(), BAR_W);

    } else {
        UI::Text("\\$888No scan yet.");
    }
}
