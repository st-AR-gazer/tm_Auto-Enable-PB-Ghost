string pluginName = Meta::ExecutingPlugin().Name;

void NotifyDebug(const string &in msg = "", const string &in overwritePluginName = pluginName, int time = 6000) {
    UI::ShowNotification(overwritePluginName, msg, vec4(.5, .5, .5, .3), time);
}
void NotifyInfo(const string &in msg = "", const string &in overwritePluginName = pluginName, int time = 6000) {
    UI::ShowNotification(overwritePluginName, msg, vec4(.2, .8, .5, .3), time);
}
void NotifyNotice(const string &in msg = "", const string &in overwritePluginName = pluginName, int time = 6000) {
    UI::ShowNotification(overwritePluginName, msg, vec4(.2, .8, .5, .3), time);
}
void NotifyWarn(const string &in msg = "", const string &in overwritePluginName = pluginName, int time = 6000) {
    UI::ShowNotification(overwritePluginName, msg, vec4(1, .5, .1, .5), time);
}
void NotifyError(const string &in msg = "", const string &in overwritePluginName = pluginName, int time = 6000) {
    UI::ShowNotification(overwritePluginName, msg, vec4(1, .2, .2, .3), time);
}
void NotifyCritical(const string &in msg = "", const string &in overwritePluginName = pluginName, int time = 6000) {
    UI::ShowNotification(overwritePluginName, msg, vec4(1, .2, .2, .3), time);
}

enum LogLevel {
    Debug,
    Info,
    Notice,
    Warn,
    Error,
    Critical,

    Custom
}

// ********** Settings **********

//////////// CHANGE TO "true" ON RELEASE  ////////////
[Setting category="z~DEV" name="Show default OP logs" hidden]
bool S_showDefaultLogs = false;
//////////////////////////////////////////////////////

[Setting category="z~DEV" name="Show Custom logs" hidden]
bool DEV_S_sCustom = true;
[Setting category="z~DEV" name="Show Debug logs" hidden]
bool DEV_S_sDebug = true;
[Setting category="z~DEV" name="Show Info logs (INFO)" hidden]
bool DEV_S_sInfo = true;
[Setting category="z~DEV" name="Show InfoG logs (INFO-G)" hidden]
bool DEV_S_sNotice = true;
[Setting category="z~DEV" name="Show Warn logs (WARN)" hidden]
bool DEV_S_sWarn = true;
[Setting category="z~DEV" name="Show Error logs (ERROR)" hidden]
bool DEV_S_sError = true;
[Setting category="z~DEV" name="Show Critical logs (CRITICAL)" hidden]
bool DEV_S_sCritical = true;

[Setting category="z~DEV" name="Set log level" min="0" max="5" hidden]
int DEV_S_sLogLevelSlider = 0;

[Setting category="z~DEV" name="Show function name in logs" hidden]
bool S_showFunctionNameInLogs = true;
[Setting category="z~DEV" name="Set max function name length in logs" min="0" max="50" hidden]
int S_maxFunctionNameLength = 15;

int lastSliderValue = DEV_S_sLogLevelSlider;

namespace logging {
    [SettingsTab name="Logs" icon="DevTo" order="99999999999999999999999999999999999999999999999999"]
    void RT_LOGs() {
        if (UI::BeginChild("Logging Settings", vec2(0, 0), true)) {
            UI::Text("Logging Options");
            UI::Separator();

            S_showDefaultLogs = UI::Checkbox("Show default OP logs", S_showDefaultLogs);
            DEV_S_sDebug = UI::Checkbox("Show Debug logs", DEV_S_sDebug);
            DEV_S_sInfo = UI::Checkbox("Show Info logs (INFO)", DEV_S_sInfo);
            DEV_S_sNotice = UI::Checkbox("Show InfoG logs (INFO-G)", DEV_S_sNotice);
            DEV_S_sWarn = UI::Checkbox("Show Warn logs (WARN)", DEV_S_sWarn);
            DEV_S_sError = UI::Checkbox("Show Error logs (ERROR)", DEV_S_sError);
            DEV_S_sCritical = UI::Checkbox("Show Critical logs (CRITICAL)", DEV_S_sCritical);

            int newSliderValue = UI::SliderInt("Set log level", DEV_S_sLogLevelSlider, 0, 5);
            
            if (newSliderValue != DEV_S_sLogLevelSlider) {
                DEV_S_sLogLevelSlider = newSliderValue;
                lastSliderValue       = newSliderValue;

                switch (DEV_S_sLogLevelSlider) {
                    case 0: DEV_S_sDebug = true; DEV_S_sCustom = true; DEV_S_sInfo = true; DEV_S_sNotice = true; DEV_S_sWarn = true; DEV_S_sError = true; DEV_S_sCritical = true; break;
                    case 1: DEV_S_sDebug = false; DEV_S_sCustom = true; DEV_S_sInfo = true; DEV_S_sNotice = true; DEV_S_sWarn = true; DEV_S_sError = true; DEV_S_sCritical = true; break;
                    case 2: DEV_S_sDebug = false; DEV_S_sCustom = false; DEV_S_sInfo = true; DEV_S_sNotice = true; DEV_S_sWarn = true; DEV_S_sError = true; DEV_S_sCritical = true; break;
                    case 3: DEV_S_sDebug = false; DEV_S_sCustom = false; DEV_S_sInfo = false; DEV_S_sNotice = true; DEV_S_sWarn = true; DEV_S_sError = true; DEV_S_sCritical = true; break;
                    case 4: DEV_S_sDebug = false; DEV_S_sCustom = false; DEV_S_sInfo = false; DEV_S_sNotice = false; DEV_S_sWarn = true; DEV_S_sError = true; DEV_S_sCritical = true; break;
                    case 5: DEV_S_sDebug = false; DEV_S_sCustom = false; DEV_S_sInfo = false; DEV_S_sNotice = false; DEV_S_sWarn = false; DEV_S_sError = true; DEV_S_sCritical = true; break;
                    case 6: DEV_S_sDebug = false; DEV_S_sCustom = false; DEV_S_sInfo = false; DEV_S_sNotice = false; DEV_S_sWarn = false; DEV_S_sError = false; DEV_S_sCritical = true; break;
                }
            }

            UI::Separator();
            UI::Text("Function Name Settings");

            S_showFunctionNameInLogs = UI::Checkbox("Show function name in logs", S_showFunctionNameInLogs);
            S_maxFunctionNameLength = UI::SliderInt("Set max function name length in logs", S_maxFunctionNameLength, 0, 50);

            UI::EndChild();
        }
    }

    string _Tag(const string &in txt, const string &in col) {
        string t = txt.ToUpper();
        while (t.Length < 7) t += " ";
        return col + "[" + t + "] ";
    }

}

// ********** Logging Function **********

void log(const string &in msg,
         LogLevel     level         = LogLevel::Info,
         int          line          = -1,
         string       _fnName        = "",
         string       _customTag     = "",
         string       _customColor   = "\\$f80")
{
    array<bool> enabled = {
        DEV_S_sDebug, DEV_S_sInfo, DEV_S_sNotice,
        DEV_S_sWarn,  DEV_S_sError, DEV_S_sCritical
    };
    if (level != LogLevel::Custom && !enabled[int(level)]) return;
    if (level == LogLevel::Custom && !DEV_S_sCustom)       return;

    string lineInfo = line >= 0 ? " " + tostring(line) : "";
    if (lineInfo.Length == 2)      { lineInfo += "  "; }
    else if (lineInfo.Length == 3) { lineInfo += " "; }

    if (_fnName.Length > S_maxFunctionNameLength) _fnName = _fnName.SubStr(0, S_maxFunctionNameLength);
    while (_fnName.Length < S_maxFunctionNameLength) { _fnName += " "; }
    if (!S_showFunctionNameInLogs) _fnName = "";

    array<string> tags = {
        "\\$0ff[DEBUG]  ", // Debug
        "\\$0f0[INFO]   ", // Info
        "\\$0ff[NOTICE] ", // Notice (InfoG)
        "\\$ff0[WARN]   ", // Warn
        "\\$f00[ERROR]  ", // Error
        "\\$f00\\$o\\$i\\$w[CRITICAL] " // Critical
    };
    array<string> bodies = {
        "\\$0cc", // Debug
        "\\$0c0", // Info
        "\\$0cc", // Notice (InfoG)
        "\\$cc0", // Warn
        "\\$c00", // Error
        "\\$f00\\$o\\$i\\$w" // Critical
    };

    string prefix;
    string body;
    if (level == LogLevel::Custom) {
        prefix = logging::_Tag(_customTag, _customColor);
        body   = _customColor;
    } else {
        prefix = tags[int(level)];
        body   = bodies[int(level)];
    }

    string full = prefix + "\\$z" + body + lineInfo + " : " + _fnName + " : \\$z" + msg;

    if (S_showDefaultLogs && level != LogLevel::Custom) {
        switch (level) {
            case LogLevel::Warn:      warn(msg);  break;
            case LogLevel::Error:
            case LogLevel::Critical:  error(msg); break;
            default:                  trace(msg); break;
        }
    } else {
        print(full);
    }
}
