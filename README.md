![Signed](https://img.shields.io/badge/Signed-Yes-33BB33)
![Trackmania 2020](https://img.shields.io/badge/Game-Trackmania-blue)

## Auto-Enable PB Ghost

In a recent Trackmania update, Nando removed automatic loading of your personal-best (PB) ghost when you open a map.
This plugin restores (and slightly extends) the original behaviour.

After installation, the plugin will automatically download your PB ghost on map load from the Nadeo leaderboard, it then loads the record, and saves it locally to avoid repeated downloads, unless you improve your time.  

This should resolve most issues caused by Nadeo's changes. However, there are cases where your PB exists, but doesn't appear on the leaderboard. To address this, the plugin also allows indexing of locally saved replays, whether in the main replays folder or an offload location (e.g if your replays are stored elsewhere for backups or faster startup). To allow the plugin to access these, you can use the "Index Custom Location" option in the settings to ensure your PBs are added to the local database.
You can also index _just_ the `C:/[...]/Trackmania(2020)/Replays/` folder if you so choose.
**OOPS:** There now exists an exe for those of you who have an insane amount of replays ~100k+ (me included), see below for how this works!

> **Note:**
> * PB ghosts do not load in Knock-Out rounds.
> * PB ghosts do load in COTD Time-Attack. (Thanks @TNTree)
> * PB ghosts do not load in Matchmaking. (Thanks @Airwam)

---

## Using the companion CLI (`pbghost-cli.exe`)

1. Download **`pbghost-cli.exe`** from the [latest release](...) or directly from
   `github/st-ar-gazer/tm_Auto-Enable-PB-Ghost/pbghost-cli/pbghost-cli.exe`.

2. Run the file -- you'll see a prompt like this:

   ![CLI Screenshot](https://github.com/user-attachments/assets/65065c06-6ac1-4770-b3a2-a013607fdf0f)

3. Enter the folder that contains all your replays.
   do not store my ~200 000 replays in the main Replays/ folder, as this massively increases boot time. So I have to enter this path:
   ```
   C:\Users\ar\Documents\Trackmania2020\Replays_Offload\
   ```
   However, it's very likely that this is something completely different for you.

5. Optional: type your **login identifier** to filter out other players' replays (or use `*` to index everything).
   You can find your login on your profile at **trackmania.io**—it looks like `0QzczTHnSR-VBNcu46cN5g`.

   > **OOPS:** a trackmania login-identifier is NOT the same as your login credentials, the login-identifier (internally just called a 'login') is the identifier used for your account, mine is `0QzczTHnSR-VBNcu46cN5g`, and you can find yours by login in on the `trackmania.io` and opening your user profile.

   ![image](https://github.com/user-attachments/assets/c40bb234-cf8c-43ca-b83d-496f17d378c8)


6. The tool now indexes, parses and adds the replays to the PB-ghost database:

   ![Indexing Screenshot](https://github.com/user-attachments/assets/fdad42ee-b00b-4a2d-8b00-bcb29a20c043)

### Why the CLI is so much faster

| Step          | Plugin                                                                                   | CLI                                                  |
| ------------- | ---------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| **Indexing**  | \~ 20–30 s for \~ 200 k replays                                                          | Same                                                 |
| **Parsing**   | * Copy replay to a game-readable folder<br>* Pre-load into memory<br>* Cast data to read | Skips copy & preload and reads directly with GBX.NET |
| **DB insert** | Near instant                                                                             | Near instant                                         |

Because the CLI bypasses the games folder restrictions, the heaviest steps disappear.
A process that took **2–3 hours with the plugin** now finishes in **≈ 10 minutes**, with no FPS drops, as the main game isn't being bogged down by using the same process for the copy/preload functionality that the game uses.

---

#### Building / running from source

The source code for the exe can be found here: https://github.com/st-AR-gazer/tm_Auto-Enable-PB-Ghost/tree/main/pbghost-cli
Feel free to run it from source or look through my shitty C# code xD
