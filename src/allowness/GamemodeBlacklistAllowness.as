// //    ___   _   __  __ ___ __  __  ___  ___  ___     _   _    _    _____      ___  _ ___ ___ ___   __  __  ___  ___  
// //   / __| /_\ |  \/  | __|  \/  |/ _ \|   \| __|   /_\ | |  | |  / _ \ \    / / \| | __/ __/ __| |  \/  |/ _ \|   \ 
// //  | (_ |/ _ \| |\/| | _|| |\/| | (_) | |) | _|   / _ \| |__| |_| (_) \ \/\/ /| .` | _|\__ \__ \ | |\/| | (_) | |) |
// //   \___/_/ \_\_|  |_|___|_|  |_|\___/|___/|___| /_/ \_\____|____\___/ \_/\_/ |_|\_|___|___/___/ |_|  |_|\___/|___/ 
// //  GAMEMODE ALLOWNESS MOD

/**
 * 
 * This file is no longer needed as "GamemodePBAllownessCheck" is now used for all 
 * gamemodes and dynamically checks if the gamemode is allowed or not.
 * 
 */



// namespace GamemodeAllowness {
//     string[] GameModeBlackList = {
//         /*"TM_COTDQualifications_Online", */"TM_KnockoutDaily_Online", // You can apperently load PB ghosts in the COTD Qualifications mode, thank you TNTree :peepoLove:

//         // "TM_PlayMap_Local",
//         "TM_TMWTTeams_Online",
//         "TM_TMWC2023_Online",
//         "TM_Teams_Matchmaking_Online",
//         // "TM_StuntValidation_Local",
//         // "TM_StuntSolo_Local", D:
//         // "TM_RoyalValidation_Local",
//         // "TM_RoyalTimeAttack_Local",
//         "TM_RoyalStars_Online",
//         "TM_Royal_Online",
//         // "TM_RaceValidation_Local",
//         // "TM_RaceTest_Local",
//         // "TM_PlayMap_Local", D:
//         // "TM_PlatformValidation_Local",
//         // "TM_Platform_Local", D:
//         // "TM_HotSeat_Local", D:
//         // "TM_COTDQualifications_Online",
//         // "TM_Campaign_Local", D:

//         // "TM_RoyalTimeAttack_Online"
//         // "TM_StuntMulti_Online", /* C_DisplayRecordGhost is explicitally set to true */
//         // "TM_TimeAttack_Online" /* C_DisplayRecordGhost is explicitally set to true */
//         "TM_Cup_Online",
//         "TM_Knockout_Online",
//         "TM_Laps_Online", 
//         "TM_Platform_Online",
//         "TM_Rounds_Online", 
//         "TM_Teams_Online"
//     };

//     class GamemodeAllownessCheck : AllowCheck::IAllownessCheck {
//         bool isAllowed = false;
//         bool initialized = false;
        
//         void Initialize() {
//             OnMapLoad();
//             initialized = true;
//         }
//         bool IsInitialized() { return initialized; }
//         bool IsConditionMet() { return isAllowed; }
//         string GetDisallowReason() { return isAllowed ? "" : "BLACKLISTED GAMEMODE: '" + GetCurrentGameMode() + "'"; }

//         // 

//         string GetCurrentGameMode() {
//             auto net = cast<CGameCtnNetwork>(GetApp().Network);
//             if (net is null) return "";
//             auto cnsi = cast<CGameCtnNetServerInfo>(net.ServerInfo);
//             if (cnsi is null) return "";
//             return cnsi.ModeName;
//         }

//         void OnMapLoad() {
//             auto net = cast<CGameCtnNetwork>(GetApp().Network);
//             if (net is null) return;
//             auto cnsi = cast<CGameCtnNetServerInfo>(net.ServerInfo);
//             if (cnsi is null) return;
//             string mode = cnsi.ModeName;

//             if (mode.Length == 0 || !IsBlacklisted(mode)) {
//                 isAllowed = true;
//             } else {
//                 log("Map loading disabled due to blacklisted mode: " + mode, LogLevel::Warn, 82, "OnMapLoad");
//                 isAllowed = false;
//             }
//         }

//         bool IsBlacklisted(const string &in mode) {
//             return GameModeBlackList.Find(mode) >= 0;
//         }        
//     }

//     AllowCheck::IAllownessCheck@ CreateInstance() {
//         return GamemodeAllownessCheck();
//     }
// }