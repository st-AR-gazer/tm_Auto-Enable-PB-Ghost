//   __  __   _   ___    ___ ___  __  __ __  __ ___ _  _ _____    _   _    _    _____      ___  _ ___ ___ ___   __  __  ___  ___  
//  |  \/  | /_\ | _ \  / __/ _ \|  \/  |  \/  | __| \| |_   _|  /_\ | |  | |  / _ \ \    / / \| | __/ __/ __| |  \/  |/ _ \|   \ 
//  | |\/| |/ _ \|  _/ | (_| (_) | |\/| | |\/| | _|| .` | | |   / _ \| |__| |_| (_) \ \/\/ /| .` | _|\__ \__ \ | |\/| | (_) | |) |
//  |_|  |_/_/ \_\_|    \___\___/|_|  |_|_|  |_|___|_|\_| |_|  /_/ \_\____|____\___/ \_/\_/ |_|\_|___|___/___/ |_|  |_|\___/|___/ 
// MAP COMMENT ALLOWNESS MOD

namespace MapcommentAllowness {
    enum MapperSetting {
        HidePB,
        None
    }

    class MapcommentAllownessCheck : AllowCheck::IAllownessCheck {
        bool isAllowed = true;
        string disallowReason = "";
        bool initialized = false;

        void Initialize() {
            OnMapLoad();
            initialized = true;
        }
        bool IsInitialized() { return initialized; }
        bool IsConditionMet() { return isAllowed; }
        string GetDisallowReason() { return isAllowed ? "" : disallowReason; }

        void OnMapLoad() {
            auto app = cast<CGameManiaPlanet>(GetApp());
            auto map = app.RootMap;
            if (map is null) {
                isAllowed = false;
                disallowReason = "Map is null.";
                return;
            }

            MapperSetting setting = DetermineMapperSetting(map);

            switch (setting) {
                case MapperSetting::HidePB:
                    isAllowed = false;
                    disallowReason = "Map loading disabled due to /hidepb command.";
                    break;

                default:
                    isAllowed = true;
                    disallowReason = "";
                    break;
            }

            // log("MapcommentAllownessCheck: isAllowed set to " + (isAllowed ? "true" : "false"), LogLevel::Info, 49, "OnMapLoad");
        }

        MapperSetting DetermineMapperSetting(CGameCtnChallenge@ map) {
            auto app = cast<CGameManiaPlanet>(GetApp());
            auto playground = cast<CSmArenaClient>(app.CurrentPlayground);
            if (playground is null) { return MapperSetting::None; }

            uint startOrder = 0;
            for (uint i = 0; i < playground.Arena.MapLandmarks.Length; i++) {
                auto lm = playground.Arena.MapLandmarks[i];
                if (lm.Waypoint is null && lm.Order > 65535) { startOrder = lm.Order; break; }
                if (lm.Waypoint is null) continue;
                if (lm.Waypoint.IsMultiLap && lm.Order > 65535) { startOrder = lm.Order; }
            }

            MapperSetting setting = MapperSetting::None;
            if (startOrder == 65537) { setting = MapperSetting::HidePB; }

            string comment = string(map.Comments).ToLower();
            if (comment.Contains("/hidepb")) { setting = MapperSetting::HidePB; }

            // log("MapcommentAllownessCheck: Final MapperSetting determined as " + EnumToString(setting), LogLevel::Info, 71, "OnMapLoad");
            return setting;
        }

        string EnumToString(MapperSetting setting) {
            switch (setting) {
                case MapperSetting::HidePB: return "HidePB";
                default:                    return "Unknown";
            }
        }
    }

    AllowCheck::IAllownessCheck@ CreateInstance() {
        return MapcommentAllownessCheck();
    }
}