namespace HotkeyUI {
    const vec4 COL_ERR  = vec4(1, 0.25, 0.25, 1);
    const vec4 COL_OK   = vec4(0.25, 1, 0.25, 1);
    const vec4 COL_DEL  = vec4(1, 0.15, 0.15, 1);
    const vec4 COL_MOVE = vec4(0.5, 0.5, 0.5, 0.65);
    const vec4 COL_ROW  = vec4(0.35, 0.35, 0.15, 0.35);

    const vec2 OP_BTN (34, 0);
    const vec2 MOVE_BTN(30, 0);
    const vec2 TOK_BTN (70, 60);
    const vec2 DEL_BTN (70, 0);
    const vec2 CAP_BTN (90, 0);

    const string DSL_INFO =
        "Hotkey DSL\n"
        "+   AND        - keys can be pressed in any order\n"
        "|   OR         - true when either 'X' or 'Y' as pressed\n"
        "&>  Sequence   - keys have to be pressed in 'first input' > 'second input'\n"
        "( ) Group      - group together different expressions\n\n"
        "Examples:\n"
        "  ( F5 | Ctrl ) + A\nEITHER f5 or ctrl has to be pressed, and A has to be pressed at any time when f5 or ctrl are held down \n"
        "  ( Ctrl + S ) &> F\nCtrl and S have to be pressed and held down, then F has to be pressed, going from holding F to Ctrl and S will not trigger the hotkey\n";

    const string CFGPATH     = IO::FromDataFolder(Hotkeys::CFG);
    const string THIS_PLUGIN = Meta::ExecutingPlugin().Name.ToLower();

    void Hover(const string &in msg) { if (UI::IsItemHovered()) UI::SetTooltip(msg); }


    string FormatExpr(const string &in raw, array<string>@ outTokens) {
        outTokens.Resize(0);
        uint i = 0;
        while (i < raw.Length) {
            string c = raw.SubStr(i, 1);
            if (c == " " || c == "\t") {
                ++i;
                continue;
            }

            if (c == "(" || c == ")" || c == "+" || c == "|") {
                outTokens.InsertLast(c);
                ++i;
                continue;
            }

            if (c == "&" && i + 1 < raw.Length && raw.SubStr(i + 1, 1) == ">") {
                outTokens.InsertLast("&>");
                i += 2;
                continue;
            }

            string word;
            while (i < raw.Length) {
                string d = raw.SubStr(i, 1);
                if (d == " " || d == "\t" || d == "(" || d == ")" || d == "+" || d == "|" || d == "&") break;
                word += d;
                ++i;
            }
            if (word.Length > 0) outTokens.InsertLast(word);
        }
        return string::Join(outTokens, " ");
    }

    bool IsAllowed(uint8 ch) {
        if (ch >= 128) return false;
        if ((ch>= 65 && ch <= 90)  || (ch >= 97 && ch <= 122)) return true; // A‑Z a‑z
        if (ch >= 48 && ch <= 57)  return true;                             // 0‑9
        if (ch == 32 || ch == 9)   return true;                             // space / tab
        if (ch == 40 || ch == 41)  return true;                             // ( )
        if (ch == 43 || ch == 124) return true;                             // + |
        if (ch == 38 || ch == 62)  return true;                             // & >
        if (ch == 95)              return true;                             // _
        return false;
    }
    bool HasUnsupported(const string &in s) {
        for (uint i = 0; i < s.Length; ++i) {
            if (!IsAllowed(uint8(s[i]))) return true;
        }
        return false;
    }


    int ResolveVK(const string &in n) {
        string l = n.ToLower();
        if (l == "ctrl" || l == "control") return int(VirtualKey::Control);
        if (l == "shift")                  return int(VirtualKey::Shift);
        if (l == "alt")                    return int(VirtualKey::Menu);

        if (l.Length == 1) {
            uint8 c = uint8(l[0]);
            if (c >= 97 && c <= 122) return int(VirtualKey::A) + (c - 97);
        }
        for (int i = 0; i <= 254; ++i) {
            if (tostring(VirtualKey(i)).ToLower() == l) return i;
        }
        return -1;
    }
    int ResolveGP(const string &in raw) {
        string k = raw.ToLower();
        if (k == "gp_a")         return int(CInputScriptPad::EButton::A);
        if (k == "gp_b")         return int(CInputScriptPad::EButton::B);
        if (k == "gp_x")         return int(CInputScriptPad::EButton::X);
        if (k == "gp_y")         return int(CInputScriptPad::EButton::Y);
        if (k == "gp_lb")        return int(CInputScriptPad::EButton::L1);
        if (k == "gp_rb")        return int(CInputScriptPad::EButton::R1);
        if (k == "gp_lthumb")    return int(CInputScriptPad::EButton::LeftStick);
        if (k == "gp_rthumb")    return int(CInputScriptPad::EButton::RightStick);
        if (k == "gp_back")      return int(CInputScriptPad::EButton::View);
        if (k == "gp_start")     return int(CInputScriptPad::EButton::Menu);
        if (k == "gp_dpadup")    return int(CInputScriptPad::EButton::Up);
        if (k == "gp_dpaddown")  return int(CInputScriptPad::EButton::Down);
        if (k == "gp_dpadleft")  return int(CInputScriptPad::EButton::Left);
        if (k == "gp_dpadright") return int(CInputScriptPad::EButton::Right);
        if (k == "gp_lt")        return int(CInputScriptPad::EButton::L2);
        if (k == "gp_rt")        return int(CInputScriptPad::EButton::R2);
        return -1;
    }
    bool TokenIsKey(const string &in tok) {
        if (ResolveVK(tok) >= 0) return true;
        if (ResolveGP(tok) >= 0) return true;
        int lit;
        if (Text::TryParseInt(tok, lit, 0)) return true;
        return false;
    }
    bool TokensValid(const array<string>@ toks) {
        for (uint i = 0; i < toks.Length; ++i) {
            string t = toks[i];
            if (t == "+" || t == "|" || t == "&>" || t == "(" || t == ")") continue;
            if (!TokenIsKey(t)) return false;
        }
        return true;
    }


    int g_UidCounter = 0;

    class Binding {
        bool   enabled = true;
        string plugin, mod, act, expr, desc;
    }

    class EditTab {
        int    idx = -1;
        string expr;

        string plugin, mod, act;
        array<string> tokens;

        bool   capture = false;
        dictionary held;

        float  hscroll = 0.0f;
        string uid;
        bool   focus = true;

        string Build() const { return string::Join(tokens, " "); }
        string VisibleName() const { return idx < 0 ? "＋ New" : plugin + "." + mod + "." + act; }
        string Title() const { return VisibleName() + "###" + uid; }
    }

    array<Binding@> g_Binds;
    array<EditTab@> g_Tabs;
    int   g_ActiveTab = -1;

    [Setting hidden] bool g_FilterPlugin = true;
    [Setting hidden] bool g_hideDslHelp = false;

    float g_ChildH = 120;
    int   g_PendingDel = -1;
    bool  g_LaunchPopup = false;

    bool Pass(const Binding@ b) { return !g_FilterPlugin || b.plugin.ToLower() == THIS_PLUGIN; }


    void LoadFile() {
        g_Binds.Resize(0);
        if (!IO::FileExists(CFGPATH)) return;

        IO::File f(CFGPATH, IO::FileMode::Read);
        for (string ln; !f.EOF();) {
            ln = f.ReadLine().Trim();
            if (ln == "" || ln.StartsWith("#")) continue;

            int eq = ln.IndexOf("=");
            if (eq < 0) continue;

            string lhs = ln.SubStr(0, eq).Trim();
            string rhs = ln.SubStr(eq + 1).Trim();

            string desc;
            int sc = rhs.IndexOf(";");
            if (sc >= 0) { desc = rhs.SubStr(sc + 1).Trim(); rhs = rhs.SubStr(0, sc).Trim(); }

            int fi = lhs.IndexOf(".");
            int la = lhs.LastIndexOf(".");
            if (fi < 0 || la <= fi) continue;

            Binding b;
            b.plugin = lhs.SubStr(0, fi).Trim();
            b.mod    = lhs.SubStr(fi + 1, la - fi - 1).Trim();
            b.act    = lhs.SubStr(la + 1).Trim();
            b.expr   = rhs;
            b.desc   = desc;
            g_Binds.InsertLast(b);
        }
        f.Close();
    }

    void SaveFile() {
        IO::File f(CFGPATH, IO::FileMode::Write);
        f.WriteLine("# Hotkeys.cfg - generated by Hotkey Manager");
        for (uint i = 0; i < g_Binds.Length; ++i) {
            auto b = g_Binds[i];
            if (!b.enabled) continue;
            string ln = b.plugin + "." + b.mod + "." + b.act + " = " + b.expr;
            if (b.desc != "") ln += " ; " + b.desc;
            f.WriteLine(ln);
        }
        f.Close();
        Hotkeys::_Load();
    }


    UI::InputBlocking OnKeyPress(bool, VirtualKey key) {
        if (g_ActiveTab < 0) return UI::InputBlocking::DoNothing;
        auto tab = g_Tabs[g_ActiveTab];
        if (!tab.capture) return UI::InputBlocking::DoNothing;

        tab.tokens.InsertLast(tostring(key));
        tab.capture = false;
        tab.held.DeleteAll();
        return UI::InputBlocking::DoNothing;
    }


    void Op(const string &in op, EditTab@ t, const string &in hint) {
        if (UI::Button(op, OP_BTN)) t.tokens.InsertLast(op);
        Hover(hint); UI::SameLine();
    }

    float TokensTotalWidth(EditTab@ t) {
        if (t.tokens.Length == 0) return 0.0f;
        float sp     = UI::GetStyleVarVec2(UI::StyleVar::ItemSpacing).x;
        float moveW  = MOVE_BTN.x + sp + MOVE_BTN.x;
        float widest = Math::Max(Math::Max(TOK_BTN.x, DEL_BTN.x), moveW);
        return t.tokens.Length * widest + (t.tokens.Length - 1) * sp;
    }

    void MoveRow(EditTab@ t) {
        for (uint i = 0; i < t.tokens.Length; ++i) {
            UI::PushID(int(i));
            UI::PushStyleColor(UI::Col::Button, COL_MOVE);

            UI::BeginDisabled(i == 0);
            if (UI::Button(Icons::ChevronLeft, MOVE_BTN)) { string tmp = t.tokens[i - 1]; t.tokens[i - 1] = t.tokens[i]; t.tokens[i] = tmp; }
            Hover("Move left");
            UI::EndDisabled(); UI::SameLine();

            UI::BeginDisabled(i + 1 >= t.tokens.Length);
            if (UI::Button(Icons::ChevronRight, MOVE_BTN)) { string tmp = t.tokens[i + 1]; t.tokens[i + 1] = t.tokens[i]; t.tokens[i] = tmp; }
            Hover("Move right");
            UI::EndDisabled();

            UI::PopStyleColor();
            if (i + 1 < t.tokens.Length) UI::SameLine();
            UI::PopID();
        }
        if (t.tokens.Length > 0) UI::NewLine();
    }

    void TokenRow(EditTab@ t) {
        for (uint i = 0; i < t.tokens.Length; ++i) {
            UI::PushID(int(i));
            UI::Button(t.tokens[i], TOK_BTN);
            Hover("Token: " + t.tokens[i]);
            if (i + 1 < t.tokens.Length) UI::SameLine();
            UI::PopID();
        }
        if (t.tokens.Length > 0) UI::NewLine();
    }

    void DelRow(EditTab@ t) {
        for (uint i = 0; i < t.tokens.Length; ++i) {
            UI::PushID(int(i));
            UI::PushStyleColor(UI::Col::Button, COL_DEL);
            if (UI::Button("×", DEL_BTN)) { t.tokens.RemoveAt(i); UI::PopStyleColor(); UI::PopID(); i--; continue; }
            Hover("Remove");
            UI::PopStyleColor();
            if (i + 1 < t.tokens.Length) UI::SameLine();
            UI::PopID();
        }
        if (t.tokens.Length > 0) UI::NewLine();
    }

    void DrawTokenRows(EditTab@ t, float xOffset) {
        vec2 cur = UI::GetCursorPos();

        UI::SetCursorPos(vec2(cur.x + xOffset, cur.y - 2));
        MoveRow(t);
        float y = UI::GetCursorPos().y;

        UI::SetCursorPos(vec2(cur.x + xOffset, y - 13));
        TokenRow(t);
        y = UI::GetCursorPos().y;

        UI::SetCursorPos(vec2(cur.x + xOffset, y - 11));
        DelRow(t);
    }

    void ScrollableTokenArea(EditTab@ t) {
        float availW = UI::GetContentRegionAvail().x;
        float maxScr = Math::Max(0.0f, TokensTotalWidth(t) - availW);
        t.hscroll    = Math::Clamp(t.hscroll, 0.0f, maxScr);

        UI::BeginChild("tokBlock" + t.uid, vec2(availW, 140), false);
        DrawTokenRows(t, -t.hscroll);
        UI::EndChild();

        if (maxScr > 0.5f) {
            UI::SetNextItemWidth(availW);
            t.hscroll = UI::SliderFloat("##scr" + t.uid, t.hscroll, 0, maxScr, "", UI::SliderFlags::AlwaysClamp);
        } else {
            UI::Dummy(vec2(0, UI::GetFrameHeight()));
        }
    }


    void ModuleActionUI(EditTab@ t) {
        array<string> keys = Hotkeys::modules.GetKeys();
        array<string> modIds, modKeys;
        string prefix = t.plugin.ToLower() + ".";
        for (uint i = 0; i < keys.Length; ++i) {
            if (!keys[i].StartsWith(prefix)) continue;
            modKeys.InsertLast(keys[i]);
            modIds.InsertLast(keys[i].SubStr(prefix.Length));
        }

        if (modIds.Length == 0) { UI::Text("\\$f80<no modules>"); return; }

        int curMod = modIds.Find(t.mod);
        if (UI::BeginCombo("Module", curMod >= 0 ? modIds[uint(curMod)] : "<module>")) {
            for (uint i = 0; i < modIds.Length; ++i) {
                bool sel = int(i) == curMod;
                if (UI::Selectable(modIds[i], sel)) { curMod = int(i); t.mod = modIds[i]; t.act = ""; }
                if (sel) UI::SetItemDefaultFocus();
            }
            UI::EndCombo();
        }

        Hotkeys::IHotkeyModule@ m;
        if (curMod >= 0 && Hotkeys::modules.Get(modKeys[uint(curMod)], @m)) {
            array<string> acts = m.GetAvailableActions();
            int curAct = acts.Find(t.act);
            if (UI::BeginCombo("Action", curAct >= 0 ? acts[uint(curAct)] : "<action>")) {
                for (uint i = 0; i < acts.Length; ++i) {
                    bool sel = int(i) == curAct;
                    if (UI::Selectable(acts[i], sel)) { curAct = int(i); t.act = acts[i]; }
                    if (sel) UI::SetItemDefaultFocus();
                }
                UI::EndCombo();
            }
        }

        UI::Separator();
        g_hideDslHelp = UI::Checkbox("Hide DSL help", g_hideDslHelp);
        if (!g_hideDslHelp) {
            UI::TextWrapped(DSL_INFO);
        } 
    }
    

    void DrawTab(EditTab@ t) {
        if (UI::BeginTable("builder" + t.uid, 2, UI::TableFlags::BordersInnerV | UI::TableFlags::Resizable)) {
            UI::TableSetupColumn("edit", UI::TableColumnFlags::WidthFixed, 650);
            UI::TableNextRow();
            UI::TableSetColumnIndex(0);

            UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(UI::GetStyleVarVec2(UI::StyleVar::ItemSpacing).x, 2));

            if (!t.capture) {
                if (UI::Button(Icons::KeyboardO + " Capture", CAP_BTN)) { t.capture = true; t.held.DeleteAll(); }
                Hover("Capture one key");
            } else { UI::Text("\\$ff0<press>"); }
            UI::SameLine();
            Op("+",  t, "AND");
            Op("|",  t, "OR");
            Op("&>", t, "Sequence");
            Op("(",  t, "(");
            if (UI::Button(")", OP_BTN)) t.tokens.InsertLast(")");
            Hover(")");

            UI::NewLine();
            ScrollableTokenArea(t);
            UI::PopStyleVar();

            string built = t.Build();
            if (built != t.expr) t.expr = built;

            UI::Text("Expression:");
            float availW = UI::GetContentRegionAvail().x;
            UI::SetNextItemWidth(availW);
            string newExpr = UI::InputText("##expr" + t.uid, t.expr);
            if (newExpr != t.expr) {
                array<string> toks;
                string formatted = FormatExpr(newExpr, toks);
                t.expr   = formatted;
                t.tokens = toks;
            }

            UI::TableSetColumnIndex(1);
            ModuleActionUI(t);
            UI::EndTable();
        }

        bool unsupported = HasUnsupported(t.expr);
        bool keysValid   = TokensValid(t.tokens);
        Hotkeys::Parser p(t.expr);
        bool parseOk     = p.Parse() !is null;
        bool exprOk      = !unsupported && keysValid && parseOk;

        bool haveMod = t.mod != "";
        bool haveAct = t.act != "";
        bool ready   = exprOk && haveMod && haveAct;

        UI::PushStyleColor(UI::Col::Text, exprOk ? COL_OK : COL_ERR);
        string msg = exprOk ? "✓ valid" : unsupported ? "× invalid char" : !keysValid ? "× invalid key" : "× parse error";
        UI::Text(msg);
        UI::PopStyleColor();
        UI::SameLine();

        string btnLabel = (t.idx < 0 ? "Add##" : "Confirm##") + t.uid;

        UI::BeginDisabled(!ready);
        bool pressed = UI::Button(btnLabel);
        UI::EndDisabled();

        if (!ready && UI::IsItemHovered(UI::HoveredFlags::AllowWhenDisabled)) {
            string reason;
            if (unsupported)     reason += (reason == "" ? "" : "\n") + "Contains unsupported characters";
            else if (!keysValid) reason += (reason == "" ? "" : "\n") + "Unknown key/button token";
            else if (!parseOk)   reason += (reason == "" ? "" : "\n") + "Expression is syntactically invalid";
            if (!haveMod)        reason += (reason == "" ? "" : "\n") + "Select a module";
            if (!haveAct)        reason += (reason == "" ? "" : "\n") + "Select an action";
            UI::SetTooltip(reason);
        }

        if (pressed) {
            if (t.idx < 0) {
                Binding b;
                b.plugin = t.plugin;
                b.mod    = t.mod;
                b.act    = t.act;
                b.expr   = t.expr;
                g_Binds.InsertLast(b);
                t.idx = int(g_Binds.Length) - 1;
            } else {
                auto b = g_Binds[uint(t.idx)];
                b.plugin = t.plugin;
                b.mod    = t.mod;
                b.act    = t.act;
                b.expr   = t.expr;
            }
            SaveFile();
        }
    }


    [SettingsTab name="Hotkeys" icon="KeyboardO" order="10"]
    void Draw() {
        if (g_Binds.Length == 0) LoadFile();
        float spaceY = UI::GetStyleVarVec2(UI::StyleVar::ItemSpacing).y;

        if (UI::BeginChild("HKMgr", vec2(0, 0), true)) {

            if (UI::Button(Icons::Plus + "  Add")) {
                auto t   = EditTab();
                t.uid    = tostring(g_UidCounter++);
                t.plugin = THIS_PLUGIN;
                array<string> ks = Hotkeys::modules.GetKeys();
                for (uint i = 0; i < ks.Length; ++i) {
                    if (ks[i].StartsWith(THIS_PLUGIN + ".")) {
                        t.mod = ks[i].SubStr((THIS_PLUGIN + ".").Length);
                        break;
                    }
                }
                g_Tabs.InsertLast(t);
                g_ActiveTab = g_Tabs.Length - 1;
            }
            UI::SameLine();
            if (UI::Button(Icons::FloppyO + "  Save & Reload")) SaveFile();
            UI::SameLine();
            g_FilterPlugin = UI::Checkbox("Show only this plugin", g_FilterPlugin);
            UI::Separator();

            if (UI::BeginTable("tbl", 5, UI::TableFlags::Resizable)) {
                UI::TableSetupColumn("✓", UI::TableColumnFlags::WidthFixed, 35);
                UI::TableSetupColumn("Module");
                UI::TableSetupColumn("Action");
                UI::TableSetupColumn("Expression");
                UI::TableSetupColumn("...", UI::TableColumnFlags::WidthFixed, 60);
                UI::TableHeadersRow();

                int activeIdx = (g_ActiveTab >= 0 && g_ActiveTab < int(g_Tabs.Length)) ? g_Tabs[g_ActiveTab].idx : -1;

                for (uint i = 0; i < g_Binds.Length; ++i) {
                    auto b = g_Binds[i];
                    if (!Pass(b)) continue;

                    UI::TableNextRow();
                    if (int(i) == activeIdx) UI::TableSetBgColor(UI::TableBgTarget::RowBg0, COL_ROW);

                    UI::TableSetColumnIndex(0);
                    bool newState = UI::Checkbox("##en" + i, b.enabled);
                    if (newState != b.enabled) { b.enabled = newState; SaveFile(); }

                    UI::TableSetColumnIndex(1); UI::Text(b.mod);
                    UI::TableSetColumnIndex(2); UI::Text(b.act);
                    UI::TableSetColumnIndex(3); UI::Text(b.expr);
                    UI::TableSetColumnIndex(4);

                    if (UI::Button(Icons::Pencil + "##e" + i)) {
                        auto t   = EditTab();
                        t.uid    = tostring(g_UidCounter++);
                        t.idx    = int(i);
                        array<string> toks;
                        t.expr   = FormatExpr(b.expr, toks);
                        t.tokens = toks;
                        t.plugin = b.plugin;
                        t.mod    = b.mod;
                        t.act    = b.act;
                        g_Tabs.InsertLast(t);
                        g_ActiveTab = g_Tabs.Length - 1;
                    }
                    UI::SameLine();

                    UI::PushID(int(i));
                    bool left   = UI::Button(Icons::Trash + "##trash", DEL_BTN);
                    bool middle = UI::IsItemClicked(UI::MouseButton::Middle);
                    UI::PopID();

                    if (middle) { g_Binds.RemoveAt(i--); SaveFile(); continue; }
                    if (left)   { g_PendingDel = int(i); g_LaunchPopup = true; }
                }
                UI::EndTable();
            }

            if (g_LaunchPopup) { UI::OpenPopup("delConfirm"); g_LaunchPopup = false; }
            if (UI::BeginPopupModal("delConfirm", UI::WindowFlags::AlwaysAutoResize)) {
                UI::Text("Delete this hotkey binding?");
                UI::Separator();
                if (UI::Button("Yes", vec2(80, 0))) {
                    if (g_PendingDel >= 0 && g_PendingDel < int(g_Binds.Length)) {
                        g_Binds.RemoveAt(uint(g_PendingDel));
                        SaveFile();
                    }
                    g_PendingDel = -1; UI::CloseCurrentPopup();
                }
                UI::SameLine();
                if (UI::Button("No", vec2(80, 0))) {
                    g_PendingDel = -1;
                    UI::CloseCurrentPopup();
                }
                UI::EndPopup();
            }

            UI::Dummy(vec2(0, UI::GetContentRegionAvail().y - spaceY - g_ChildH));
            vec2 start = UI::GetCursorPos();

            UI::BeginTabBar("editTabs");
            for (uint i = 0; i < g_Tabs.Length; ++i) {
                auto tab = g_Tabs[i];
                bool open  = true;
                int  flags = tab.focus ? UI::TabItemFlags::SetSelected : UI::TabItemFlags::None;

                if (UI::BeginTabItem(tab.Title(), open, flags)) {
                    tab.focus   = false;
                    g_ActiveTab = int(i);
                    DrawTab(tab);
                    UI::EndTabItem();
                }

                if (!open) {
                    g_Tabs.RemoveAt(i);
                    if (g_ActiveTab >= int(i)) g_ActiveTab--;
                    i--;
                }
            }
            UI::EndTabBar();

            g_ChildH = UI::GetCursorPos().y - start.y;
            UI::EndChild();
        }
    }
}