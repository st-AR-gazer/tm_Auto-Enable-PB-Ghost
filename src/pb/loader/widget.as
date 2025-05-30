namespace UINav {

    funcdef bool FramePredicate(CControlFrame@);

    class Step {
        bool wildcard;
        int index;
        Step() { wildcard = true;  index = -1; }
        Step(int i) { wildcard = false; index = i;  }
    }

    class Path {
        array<Step@> steps;
        Path() {}
        Path(const array<Step@>@ s) { steps = s; }
        
        uint Length() const { return steps.Length; }

        Path@ opAdd(const Path &in other) const {
            Path p;
            p.steps = steps;
            for (uint i = 0; i < other.steps.Length; ++i) { p.steps.InsertLast(other.steps[i]); }
            return p;
        }
    }

    Path@ ParsePath(const string &in spec) {
        Path p;
        string[] parts = spec.Split("/");
        for (uint i = 0; i < parts.Length; ++i) {
            string s = parts[i].Trim();
            if (s == "*" || s == "") {
                p.steps.InsertLast(Step());
            } else {
                p.steps.InsertLast(Step(Text::ParseInt(s)));
            }
        }
        return p;
    }

    CControlFrame@ g_cachedRoot = null;
    uint g_cacheStamp = 0;

    CControlFrame@ Root() {
        if (g_cachedRoot !is null && Time::Now - g_cacheStamp < 10) return g_cachedRoot;

        @g_cachedRoot = null;
        g_cacheStamp  = Time::Now;

        CGameCtnApp@ app = GetApp();
        if (app is null || app.Viewport is null) return null;

        CDx11Viewport@ vp = cast<CDx11Viewport>(app.Viewport); // CGameGetApp.cast<CDx11Viewport@> Viewport (CHmsViewport@)
        for (uint i = 0; i < vp.Overlays.Length; ++i) {
            CHmsZoneOverlay@ ov = cast<CHmsZoneOverlay>(vp.Overlays[i]); // cast<CHmsZoneOverlay@> Viewport.Overlays[n]
            if (ov is null || ov.UserData is null) continue;

            CSceneSector@ sector = cast<CSceneSector>(ov.UserData); // cast<CSceneSector@> Overlays[n].UserData (CMwNod@) "Unassigned"
            if (sector is null || sector.Scene is null) continue;

            CScene2d@ scene = cast<CScene2d>(sector.Scene); // cast<CScene2d@> UserData.Scene (CScene@)
            if (scene.Mobils.Length == 0 || scene.Mobils[0] is null) continue;

            CControlFrameStyled@ rootStyled = cast<CControlFrameStyled>(scene.Mobils[0]); // cast<CScenerMobil@> Scene.Mobils[0]
            if (rootStyled is null) continue;

            @g_cachedRoot = cast<CControlFrame>(rootStyled);
            break;
        }
        return g_cachedRoot;
    }

    CControlFrame@ Traverse(const Path &in p, CControlFrame@ start = Root(), bool skipNull = true) {
        CControlFrame@ cur = start;
        if (cur is null) return null;

        for (uint s = 0; s < p.steps.Length; ++s) {
            Step@ st = p.steps[s];

            if (st.wildcard) {
                bool found = false;
                for (uint c = 0; c < cur.Childs.Length; ++c) {
                    if (cur.Childs[c] is null) { if (skipNull) continue; }
                    @cur = cast<CControlFrame>(cur.Childs[c]);
                    found = true; break;
                }
                if (!found) return null;
            } else {
                int idx = st.index;
                if (idx < 0 || idx >= int(cur.Childs.Length)) return null;
                if (cur.Childs[idx] is null) return null;
                @cur = cast<CControlFrame>(cur.Childs[idx]);
            }
        }
        return cur;
    }

// [   ScriptRuntime] [ERROR] [19:45:33] [tm_Auto-Enable-PB-Ghost]  Script exception: Null pointer access
// [   ScriptRuntime] [ERROR] [19:45:33] [tm_Auto-Enable-PB-Ghost]    C:/Users/ar/OpenplanetNext/Plugins/tm_Auto-Enable-PB-Ghost/src/pb/loader/widget.as (line 91, column 17)
// [   ScriptRuntime] [ERROR] [19:45:33] [tm_Auto-Enable-PB-Ghost]      #0  CControlFrame@ UINav::Traverse(const UINav::Path&in p, CControlFrame@ start = Root(), bool skipNull = true) (C:/Users/ar/OpenplanetNext/Plugins/tm_Auto-Enable-PB-Ghost/src/pb/loader/widget.as line 91)
// [   ScriptRuntime] [ERROR] [19:45:33] [tm_Auto-Enable-PB-Ghost]      #1  bool Loader::RecordsWidgetReady() (C:/Users/ar/OpenplanetNext/Plugins/tm_Auto-Enable-PB-Ghost/src/pb/loader/manager.as line 4)
// [   ScriptRuntime] [ERROR] [19:45:33] [tm_Auto-Enable-PB-Ghost]      #2  bool Loader::WaitUntil(Loader::Predicate@ pred, uint timeoutMs = 4000) (C:/Users/ar/OpenplanetNext/Plugins/tm_Auto-Enable-PB-Ghost/src/pb/loader/common.as line 43)
// [   ScriptRuntime] [ERROR] [19:45:33] [tm_Auto-Enable-PB-Ghost]      #3  void Loader::LoadPBFlow() (C:/Users/ar/OpenplanetNext/Plugins/tm_Auto-Enable-PB-Ghost/src/pb/loader/manager.as line 10)

    CControlFrame@ Traverse(const Path &in p, FramePredicate@ match, CControlFrame@ start = Root()) {
        array<CControlFrame@> layer;
        layer.InsertLast(start);

        for (uint depth = 0; depth < p.steps.Length; ++depth) {
            Step@ st = p.steps[depth];
            array<CControlFrame@> next;

            for (uint i = 0; i < layer.Length; ++i) {
                CControlFrame@ node = layer[i];
                if (node is null) continue;

                if (st.wildcard) {
                    for (uint c = 0; c < node.Childs.Length; ++c) {
                        next.InsertLast(cast<CControlFrame>(node.Childs[c]));
                    }
                } else {
                    int idx = st.index;
                    if (idx < 0 || idx >= int(node.Childs.Length)) continue;
                    next.InsertLast(cast<CControlFrame>(node.Childs[idx]));
                }
            }
            layer = next;
            if (layer.Length == 0) return null;
        }

        for (uint i = 0; i < layer.Length; ++i) {
            if (match(layer[i])) return layer[i];
        }

        return null;
    }

    /********************* utils *************************/

    bool HasLabel(CControlFrame@ n, const string &in txt) {
        if (n is null) return false;
        for (uint i = 0; i < n.Childs.Length; ++i) {
            CControlLabel@ lbl = cast<CControlLabel>(n.Childs[i]);
            if (lbl !is null && lbl.Label == txt) return true;
        }
        return false;
    }

    int ToMs(const string &in lbl) {
        string[] p = lbl.Split(":");  if (p.Length != 2) return -1;
        string[] s = p[1].Split("."); if (s.Length != 2) return -1;
        return Text::ParseInt(p[0])*60000 + Text::ParseInt(s[0])*1000 + Text::ParseInt(s[1]);
    }

    /* ---------------------------------------------- */

    const Path@ RECORDS_WIDGET = ParsePath("0/2/8/*/1/2/0/0/1");
/*  0/ Childs[0] (CControlBase@) > <CControlFrame@> "InterfaceRoot"
    2/ Childs[2] (ccontrolFrame@) > <CControlFrame@> "FrameInGameBase"
    8/ Childs[8] (CControlFrame@) > <CControlFrame@> "FrameManialinkPageContainer" */
//  */ Childs[*] (CControlFrame@) > <CControlFrame@> "nth?" // usually #12/#13/#14 or something along these lines // Full WidgetUI Container (cannot be hid externally)
/*  1/ Childs[1] (CControlFrame@) > <CControlFrame@> "#1" // Full WidgetUI Container
    2/ Childs[2] (CControlFrame@) > <CControlFrame@> "#2" // Full WidgetUI Container
    0/ Childs[0] (CControlFrame@) > <CControlFrame@> "#0" // Full WidgetUI Container
    0/ Childs[0] (CControlFrame@) > <CControlFrame@> "#0" // Full WidgetUI Container
    1/ Childs[1] (CControlFrame@) > <CControlFrame@> "#1" // Widget Records Only // #0 is the button to hide the widget
*/
    const Path@ RECORDS_ROWS   = RECORDS_WIDGET + ParsePath("7");
/*  7/ Childs[7] (CControlFrame@) > <CControlFrame@> "RecordsRows" // Actual dropdowns in the widget itself
*/

    string g_targetLabel;
    bool   _MatchRow(CControlFrame@ n) { return HasLabel(n, g_targetLabel); }

    CControlFrame@ PlayerRow(const string &in name = "") {
        g_targetLabel = (name == "") ? GetApp().LocalPlayerInfo.Name : name;
        return Traverse(RECORDS_ROWS, FramePredicate(@_MatchRow));
    }

    int WidgetPlayerPB() {
        CControlFrame@ row = PlayerRow();
        if (row is null || row.Childs.Length < 8) return -1;

        CControlLabel@ lbl = cast<CControlLabel>(row.Childs[7]);
        if (lbl is null) return -1;
        return ToMs(lbl.Label);
    }

}

/* ------------------ Legacy :ReallyMad: ------------------ */
CControlFrame@ GetRecordsWidget_FullWidgetUI() { return UINav::Traverse(UINav::RECORDS_WIDGET); }
int GetRecordsWidget_PlayerUIPB() { return UINav::WidgetPlayerPB(); }