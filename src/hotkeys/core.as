namespace Hotkeys {

    interface IHotkeyModule {
        string        GetId();
        array<string> GetAvailableActions();
        string        GetActionDescription(const string &in act);
        bool          ExecuteAction(const string &in act, Hotkey@ hk);
    }

    void RegisterModule(const string &in pluginId, IHotkeyModule@ m) {
        string key = (pluginId + "." + m.GetId()).ToLower();
        modules[key] = @m;
    }
    void UnregisterModule(const string &in pluginId, IHotkeyModule@ m) {
        string key = (pluginId + "." + m.GetId()).ToLower();
        modules.Delete(key);
    }

    UI::InputBlocking OnKeyPress(bool down, VirtualKey key) {
        kbd.UpdateEdge(key, down);
        return UI::InputBlocking::DoNothing;
    }

    void Poll() {
        _EnsureCfg();

        gpad.Poll();

        for (uint i = 0; i < hotkeys.Length; ++i) {
            Hotkey@ hk = hotkeys[i];

            bool edgeNow = hk.expr.Eval(kbd, gpad, true);
            bool holdNow = hk.expr.Eval(kbd, gpad, false);

            bool isDown = edgeNow || holdNow;

            if (!hk.active && isDown) _Trigger(hk);

            hk.active = isDown;
        }

        kbd.FlushFrame();
    }

    void InitHotkeys() { while (true) { Poll(); yield(); } }

    class Hotkey {
        string pluginId;
        string modId;
        string actId;
        string desc;
        Expr@  expr;
        bool   active = false;
    }

    array<Hotkey@> hotkeys;
    dictionary     modules;

    // KB State
    class KeyboardState {
        dictionary down, edge;

        void UpdateEdge(VirtualKey vk, bool now) {
            string k = "" + vk;
            bool   was = down.Exists(k);

            if (now && !was) edge[k] = true;
            
            if (now) { down[k] = true; } 
            else     { down.Delete(k); }
        }
        void FlushFrame() { edge.DeleteAll(); }

        bool IsDown(int vk)    const { return down.Exists("" + vk); }
        bool IsPressed(int vk) const { return edge.Exists("" + vk); }
    }
    KeyboardState kbd;

    // Gamepad State
    class GamepadState {
        dictionary held, edge;
        float      THR = 0.5f;

        void Poll() {
            held.DeleteAll();
            edge.DeleteAll();

            CInputPort@ ip = GetApp().InputPort;
            for (uint i = 0; i < ip.Script_Pads.Length; ++i) {
                CInputScriptPad@ pad = ip.Script_Pads[i];
                if (pad.Type == CInputScriptPad::EPadType::Keyboard
#if !TURBO
                || pad.Type == CInputScriptPad::EPadType::Mouse
#endif
                ) continue;

                _Held(pad);
                for (uint b = 0; b < pad.ButtonEvents.Length; ++b) {
                    edge["" + int(pad.ButtonEvents[b])] = true;
                }
            }
        }

        void _Set(bool c, CInputScriptPad::EButton b) {
            if (c) held["" + int(b)] = true;
        }

        void _Held(CInputScriptPad@ p) {
            _Set(p.A != 0, CInputScriptPad::EButton::A);
            _Set(p.B != 0, CInputScriptPad::EButton::B);
            _Set(p.X != 0, CInputScriptPad::EButton::X);
            _Set(p.Y != 0, CInputScriptPad::EButton::Y);

            _Set(p.L1 != 0, CInputScriptPad::EButton::L1);
            _Set(p.R1 != 0, CInputScriptPad::EButton::R1);

            _Set(p.LeftStickBut  != 0, CInputScriptPad::EButton::LeftStick);
            _Set(p.RightStickBut != 0, CInputScriptPad::EButton::RightStick);

            _Set(p.Menu != 0, CInputScriptPad::EButton::Menu);
            _Set(p.View != 0, CInputScriptPad::EButton::View);

            _Set(p.Up    != 0, CInputScriptPad::EButton::Up);
            _Set(p.Down  != 0, CInputScriptPad::EButton::Down);
            _Set(p.Left  != 0, CInputScriptPad::EButton::Left);
            _Set(p.Right != 0, CInputScriptPad::EButton::Right);

            _Set(p.L2 > THR, CInputScriptPad::EButton::L2);
            _Set(p.R2 > THR, CInputScriptPad::EButton::R2);
        }

        bool IsDown(int b)    const { return held.Exists("" + b); }
        bool IsPressed(int b) const { return edge.Exists("" + b); }
    }
    GamepadState gpad;


    // Expression Tree

    interface Expr { bool Eval(const KeyboardState&, const GamepadState&, bool edge); void Reset(); }

    class KeyNode : Expr {
        int vk;
        KeyNode(int v) { vk = v; }
        bool Eval(const KeyboardState& k, const GamepadState&, bool e) { return e ? k.IsPressed(vk) : k.IsDown(vk); }
        void Reset() {}
    }

    class GPNode : Expr {
        int btn;
        GPNode(int b) { btn = b; }
        bool Eval(const KeyboardState&, const GamepadState& g, bool e) { return e ? g.IsPressed(btn) : g.IsDown(btn); }
        void Reset() {}
    }

    class OrNode : Expr {
        array<Expr@> a;
        bool Eval(const KeyboardState& k, const GamepadState& g, bool edge) {
            for (uint i = 0; i < a.Length; ++i) {
                if (a[i] is null) continue;

                if (a[i].Eval(k, g, edge)) return true;
            }
            return false;
        }

        void Reset() { for (uint i = 0; i < a.Length; ++i) a[i].Reset(); }
    }
    class AndNode : Expr {
        array<Expr@> a;
        bool Eval(const KeyboardState& k, const GamepadState& g, bool edge) {
            for (uint i = 0; i < a.Length; ++i) {
                if (a[i] is null) return false;

                if (!a[i].Eval(k, g, edge)) return false;
            }
            return true;
        }

        void Reset() { for (uint i = 0; i < a.Length; ++i) a[i].Reset(); }
    }
    class SeqNode : Expr {
        array<Expr@> s;
        uint idx = 0;
        bool active = false;

        bool Eval(const KeyboardState& k, const GamepadState& g, bool e) {
            if (active) {
                for (uint i = 0; i < s.Length; ++i) {
                    if (!s[i].Eval(k, g, false)) { Reset(); return false; }
                }
                return true;
            }

            if (s[idx].Eval(k, g, e)) {
                ++idx;
                if (idx >= s.Length) { active = true; return true; }
            }
            return false;
        }
        void Reset() {
            idx = 0;
            active = false;
            for (uint i = 0; i < s.Length; ++i) {
                s[i].Reset();
            }
        }
    }


    // Parser

    class Parser {
        string t; // the input string
        uint p = 0; // current position in the string

        Parser(const string &in s) { t = s; }

        string _ch(uint idx) const {
            return t.SubStr(idx, 1);
        }

        bool Match(const string &in tok) {
            if (tok.Length == 0) return false;
            if (int(p) < t.Length && _ch(p) == tok) { ++p; return true; }
            return false;
        }

        void Expect(const string &in tok) {
            if (!Match(tok)) log("expected '" + tok + "' at " + ("" + p), LogLevel::Warn, 230, "Expect", "Hotkeys-Parse", "\\$f80");
        }

        // 
        Expr@ Parse() {
            Expr@ n = _Expr();
            _Ws();
            return (int(p) == t.Length ? n : null);
        }

        // 'Expr := Term ('|' Term)
        Expr@ _Expr() {
            Expr@ l = _Term();
            while (true) {
                _Ws();
                if (!Match("|")) break;

                OrNode@ o = OrNode();
                o.a.InsertLast(l);
                do {
                    o.a.InsertLast(_Term());
                    _Ws();
                } while (Match("|"));
                @l = o;
            }
            return l;
        }

        // 'Term := Fac ('+' Fac)
        Expr@ _Term() {
            array<Expr@> parts;
            parts.InsertLast(_Fac());
            while (true) {
                _Ws();
                if (!Match("+")) break;
                parts.InsertLast(_Fac());
            }
            if (parts.Length == 1) return parts[0];
            AndNode@ a = AndNode();
            a.a = parts;
            return a;
        }

        // 'Fac := '(' Expr ')'
        Expr@ _Fac() {
            _Ws();
            if (Match("(")) {
                Expr@ n = _Expr();
                Expect(")");
                return n;
            }
            return _Seq();
        }

        // Seq := Item ('&>' Item)
        Expr@ _Seq() {
            array<Expr@> st;
            st.InsertLast(_Item());
            while (true) {
                _Ws();
                uint save = p;
                if (Match("&") && Match(">")) { st.InsertLast(_Item()); }
                else { p = save; break; }
            }
            if (st.Length == 1) return st[0];
            SeqNode@ s = SeqNode();
            s.s = st;
            return s;
        }

        // Item := identifier | number
        Expr@ _Item() {
            _Ws();
            string id;
            while (int(p) < t.Length && (_IsAlnum(_ch(p)) || _ch(p) == "_" || _ch(p) == "x" || _ch(p) == "X")) {
                id += _ch(p);
                ++p;
            }

            if (id.Length == 0) { /*log("key expected at " + ("" + p), LogLevel::Warn, 309, "Expect", "Hotkeys-Parse", "\\$f80");*/ return null; }

            int vk = _VK(id); if (vk >= 0) return KeyNode(vk);
            int gp = _GP(id); if (gp >= 0) return GPNode(gp);

            int lit;
            if (Text::TryParseInt(id, lit, 0)) return KeyNode(lit);

            log("unknown '" + id + "'", LogLevel::Warn, 317, "Expect", "Hotkeys-Parse", "\\$f80");
            return null;
        }


        void _Ws() {
            while (int(p) < t.Length && (_ch(p) == " " || _ch(p) == "\t")) {
                ++p;
            }
        }

        bool _IsAlnum(const string &in s) const {
            if (s.Length == 0) return false;
            uint8 c = uint8(s[0]);
            return (c >= 65 && c <= 90)  || // A–Z
                   (c >= 97 && c <= 122) || // a–z
                   (c >= 48 && c <= 57);    // 0–9
        }

        int _VK(const string &in n) const {
            string l = n.ToLower();

            if (l == "ctrl"  || l == "control") return int(VirtualKey::Control);
            if (l == "shift")                   return int(VirtualKey::Shift);
            if (l == "alt")                     return int(VirtualKey::Menu);

            if (l.Length == 1) {
                uint8 c = uint8(l[0]);
                if (c >= 97 && c <= 122) {
                    int offset = c - 97;
                    return int(VirtualKey::A) + offset;
                }
            }

            for (int i = 0; i <= 254; ++i) {
                if (tostring(VirtualKey(i)).ToLower() == l) return i;
            }

            return -1;
        }

        int _GP(const string &in raw) const {
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
    }

    // Configuration

    const string CFG = "Hotkeys.cfg";
    bool cfgLoaded   = false;

    void _Load() {
        hotkeys.Resize(0);
        string path = IO::FromDataFolder(CFG);
        if (!IO::FileExists(path)) { log("no " + CFG, LogLevel::Custom, 388, "_Load", "Hotkeys-Info", "\\$f80"); return; }

        IO::File f(path, IO::FileMode::Read);
        array<string>@ lines = f.ReadToEnd().Split("\n");
        f.Close();

        for (uint i = 0; i < lines.Length; ++i) {
            string ln = lines[i].Trim();
            if (ln.Length == 0 || ln.StartsWith("#")) continue;

            int eq = ln.IndexOf("=");
            if (eq < 0) { log("no '=' at line " + (i + 1), LogLevel::Warn, 399, "_Load", "Hotkeys-Warn", "\\$f80"); continue; }
            string lhs = ln.SubStr(0, eq).Trim();
            string rhs = ln.SubStr(eq + 1).Trim();

            string desc;
            int sc = rhs.IndexOf(";");
            if (sc >= 0) { desc = rhs.SubStr(sc + 1).Trim(); rhs = rhs.SubStr(0, sc).Trim(); }

            bool enabled = true;
            if (rhs.StartsWith("!")) { enabled = false; rhs = rhs.SubStr(1).Trim(); }
            if (!enabled) continue;

            int first = lhs.IndexOf(".");
            int last  = lhs.LastIndexOf(".");
            if (first < 0 || last <= first) { log("plugin.module.action missing at line " + (i + 1), LogLevel::Warn, 409, "_Load", "Hotkeys-Warn", "\\$f80"); continue; }
            string plugin = lhs.SubStr(0, first).Trim().ToLower();
            string mod    = lhs.SubStr(first + 1, last - first - 1).Trim().ToLower();
            string act    = lhs.SubStr(last + 1).Trim();

            Hotkeys::Parser p(rhs);
            Hotkeys::Expr@ root = p.Parse();
            if (root is null) { log("parse error in '" + rhs + "' at line " + (i + 1), LogLevel::Warn, 416, "_Load", "Hotkeys-Warn", "\\$f80"); continue; }

            Hotkey hk;
            hk.pluginId = plugin;
            hk.modId    = mod;
            hk.actId    = act;
            hk.desc     = desc;
            @hk.expr    = root;
            hotkeys.InsertLast(hk);
        }

        log("Loaded " + hotkeys.Length + " hotkey(s)", LogLevel::Custom, 427, "_Load", "Hotkeys-Info", "\\$f80");
    }

    void _EnsureCfg() { if (!cfgLoaded) { cfgLoaded = true; _Load(); } }

    // Dispatch

    void _Trigger(Hotkey@ hk) {
        string key = hk.pluginId + "." + hk.modId;
        Hotkeys::IHotkeyModule@ m;
        if (!modules.Get(key, @m)) { log("no module '" + key + "'", LogLevel::Custom, 437, "_Trigger", "Hotkeys-Info", "\\$f80"); return; }
        if (!m.ExecuteAction(hk.actId, hk)) { log("module '" + hk.modId + "' ignored '" + hk.actId + "'", LogLevel::Custom, 438, "_Trigger", "Hotkeys-Info ", "\\$f80"); }
    }
}

UI::InputBlocking OnKeyPress(bool down, VirtualKey key) {
    HotkeyUI::OnKeyPress(down, key);
    Hotkeys::OnKeyPress(down, key);
    return UI::InputBlocking::DoNothing;
}