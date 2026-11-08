# Code map

Read this before touching the mod. It exists so nobody has to spend twenty
minutes re-deriving where things are. Everything below is a pointer plus the
reason it matters; the authoritative behaviour is always the UnrealScript.

## 1. What this project is

A LAN co-op mod for POSTAL 2 (Unreal Engine 2, build 5100). The whole original
single-player campaign is driven by one `GameInfo` subclass, so the mod gets
campaign compatibility by *inheriting* that class and gets networking from
`Engine.GameInfo`. Nothing in the original `.u` packages is patched or
replaced; every change is a subclass or a runtime adapter.

## 2. Directory layout

| Path | What it is |
| --- | --- |
| `src/LanCoop/Classes/*.uc` | **The mod.** The only source we own. |
| `p2unrealscript-master/` | Decompiled original game script, read-only reference. This is where you look up how single player does anything. |
| `POSTAL2Complete/` | The game installation that is actually played. Deliberately kept close to a clean install; it has **no `UCC.exe`**. |
| `POSTAL2CompleteNick/` | Second installation that *does* ship `UCC.exe`. Compilation happens here. |
| `tools/*.ps1` | Build, launch and headless test scripts. |
| `artifacts/` | Build logs, probe output, fingerprints. Not in git. |
| `docs/` | This file, `EVENT-ROUTING.md`. |
| `README.md` / `TESTING.md` / `DEBUGGING.md` / `MP-FIX-AUDIT.md` | Player-facing status, test ledger, investigation notes, base-fix audit. |

## 3. Build, deploy, test

`UCC.exe` is missing from `POSTAL2Complete` on purpose (clean-install
comparison), so always build against the other installation and copy the
package over:

```bash
powershell -File tools/Build.ps1 -GameDirectory F:\Coding\Projects\Postal2Multiplayer\POSTAL2CompleteNick
```

```bash
cp POSTAL2CompleteNick/System/LanCoop.u POSTAL2Complete/System/LanCoop.u
```

`Build.ps1` stages `src/LanCoop/Classes/*.uc` into
`<game>/LanCoop/Classes`, regenerates `LanCoop.ini` from the shipped
`Default.ini` (adding `EditPackages=LanCoop` and `ServerPackages=LanCoop`,
stripping the master-server uplink and web admin), deletes `LanCoop.u`, runs
`UCC make`, then runs `LanCoopCheckCommandlet` as a package-load smoke test.
Two `ReadToken: Bad quoted string` warnings and one `Failed to load
'LanCoop.u'` warning are pre-existing and expected.

### Headless test suites

Both run a dedicated server with an opt-in probe actor and look for a marker
in **stdout** (the engine's own log file is buffered and gets truncated when
the process is killed, so always grep the redirected stdout):

| Suite | URL option | Success marker |
| --- | --- | --- |
| Integration lifecycle | `?LifecycleProbe=1` | `LifecycleOk` (failure: `LifecycleFailed`) |
| Mission/event fixtures | `?CoopMissionProbe=1` | `MissionAuditDone Passed=N Failed=0` |
| Travel round trip | `?CoopTravelProbe=1` | see `LanCoopTravelProbe` |

`tools/Test-CampaignBoot.ps1 -Lifecycle` and `tools/Test-Missions.ps1` wrap
these but point at `POSTAL2Complete`, which has no `UCC.exe`. Run `UCC.exe
server <url> ini=LanCoop.ini userini=LanCoopUser.ini log=X.log unattended`
from `POSTAL2CompleteNick/System` instead.

**Gotcha:** `IpDrv.UdpBeacon` and `IpDrv.UdpServerQuery` bind fixed ports and
assert in `PreBeginPlay` when two headless runs overlap, which kills the
server before any probe runs. For back-to-back probe runs, copy `LanCoop.ini`
to `LanCoopProbe.ini` with those two `ServerActors=` lines removed and pass
`ini=LanCoopProbe.ini`.

### Launching the real game

`tools/Start-Instance.ps1 -Role Host|Client|Menu` (also `Start-Host.cmd`,
`Start-Client.cmd`, `Start-Multiplayer.cmd`). Each role gets its own
`LanCoop<Role>.ini`, `LanCoop<Role>User.ini`, save/cache dirs and identity
file, so two instances can run on one PC. Logs land in
`POSTAL2Complete/System/LanCoop<Role>.log`.

## 4. The original campaign: the parts that actually matter

All paths below are under `p2unrealscript-master/`.

### 4.1 Class chain

```
Engine.GameInfo
  └ FPSGame.FPSGameInfo
      └ Postal2Game.P2GameInfo
          └ Postal2Game.P2GameInfoSingle      <- the campaign engine, 5555 lines
              └ GameTypes.GameSinglePlayer    <- POSTAL 2 week: errand/day data
                  └ GameTypes.AWPGameInfo     <- A Week In Paradise: 7 days
                      └ LanCoop.LanCoopGameInfo
```

`Postal2Game.P2GameInfoMulti` is the stock deathmatch side and is **not** in
our chain.

### 4.2 Days and errands are class defaults, not actors

- `Postal2Game/Classes/DayBase.uc` — one day: `UniqueName` (`DAY_A`..`DAY_E`),
  `MapTex`, `NewsTex`, `LoadTex`, `PlayerInvList`, `TakeFromPlayerList`, and
  `Errands` (an `editinline array<ErrandBase>`).
- `Postal2Game/Classes/ErrandBase.uc` — one errand: `UniqueName`, `NameTex`
  (the handwriting on the map), `LocationTex` + `LocationX/Y`, crossout
  textures, the Dude's four voice lines, `SendPlayerURL`, and `Goals`.
- `Postal2Game/Classes/ErrandGoal.uc` + the `ErrandGoal*` subclasses — how an
  errand can be completed (`GetPickup`, `GiveInventory`, `TalkTo`, `KillMe`,
  `Tag`, `UrineQuotaMet`, …).
- `GameTypes/Classes/GameSinglePlayer.uc:318` — `defaultproperties` holding
  every Monday–Friday errand and day as `Begin Object` subobjects, ending with
  `Days(0)..Days(4)`.
- `GameTypes/Classes/AWPGameInfo.uc:160` — re-declares `Days(0)..Days(6)`,
  adding the weekend days `DayBase8`/`DayBase9` defined in
  `GameTypes/Classes/AWGameSP.uc`.

**This is the single most useful fact in this document:** because `Days` is a
class default array of objects living in `GameTypes.u`, it is available on a
network **client** too, via `class'LanCoopGameInfo'.Default.Days[N]`. A client
has no `Level.Game`, but it can still read the entire errand list, its
textures and its map artwork. Prefer that over replicating content.

**Second most useful fact:** `AWGameSP`'s Sunday day has a literal
`Errands(0)=None`. Any loop over a day's errands must null-check
`Days[d].Errands[i]`, or it throws `Accessed None` and `CheckForValidErrandGoals`
logs a scary but harmless `ERROR: this day has errands with missing goals`.

### 4.3 Runtime errand state lives in `GameState`

`Postal2Game/Classes/GameState.uc` (an `Inventory`, so it travels with the
player between levels). The relevant `travel array<SErrand>` fields, each
holding `{Day, Errand}` index pairs:

| Field | Meaning |
| --- | --- |
| `CompletedErrands` | finished |
| `ActivatedErrands` / `DeActivatedErrands` | turned on/off during play |
| `RevealedErrands` | the errand **name** has been written on the map |
| `RevealedLocationTex` | the errand **location** has been written on the map |
| `CurrentHaters` | hate groups shown on the map |
| `bFirstLevelOfGame`, `bFirstLevelOfDay`, `bPreGameMode`, `bChangeDayPostTravel`, `CurrentDay`, `NextDay`, `ErrandsCompletedToday`, `bForceMap` | day lifecycle |

`P2GameInfoSingle.RestoreDayAndErrands()` (line ~3130) re-synchronises the
`DayBase`/`ErrandBase` objects (which are never destroyed, being class
defaults) from these lists after travel or load.

### 4.4 How single player opens a day and hands out errands

1. `P2GameInfoSingle.PostTravel(PlayerPawn)` (line ~1964) is called from
   `P2Player.TravelPostAccept()` (`P2Player.uc:4556`), i.e. when the player
   pawn arrives. It either adopts the `GameState` out of the pawn's inventory
   or, for a new game, spawns one and sets `bFirstLevelOfGame = true`,
   `bPreGameMode = false`, `CurrentDay = NextDay()`, `bFirstLevelOfDay = true`,
   `ErrandsCompletedToday = 0`.
2. It then calls `GameInfoIsNowValid()`, `TheGameState.PostLevelChange()` and
   `RestoreDayAndErrands()`.
3. The `auto state StartUp` (line ~4826) runs `PrepDifficulty`,
   `SetZoneFogPlanes`, `ChangeSkyByDay`, `PrepActorsByGroup`,
   `PrepSliderPawns`, `PrepPickupsForErrands`, `RemoveGottenPickups`, then
   `GotoState(RunningStateName)`.
   - `PrepActorsByGroup()` (line ~3653) walks **every actor** and destroys
     anything whose `Group` names a different day — this is why one map file
     can serve all five days. `NeededForThisDay()` (line ~4067) does the
     matching against `Days[i].UniqueName`.
4. The day's own content is handed out by **scripts inside the map**, not by
   code. A `ScriptedTrigger` tagged `CheckStartDay`, fired by the
   `PlayerStart`'s `Event`, runs `ACTION_IfGameState` tests on
   `bFirstLevelOfGame` / `bFirstLevelOfDay` and then an
   `ACTION_P2Screen` with `bMapRevealErrands=true`
   (`MoreGame/Classes/ACTION_P2Screen.uc`, `MoreGame/Classes/ACTION_IfGameState.uc`).
   On Monday the map is forced up instead, via `GameState.bForceMap` →
   `P2Player.ForceMapUp()`.
5. `ACTION_P2Screen` calls `P2Player.DisplayMapErrands()` →
   `MapScreen.ShowErrands()` → the `RevealErrands`…`RevealErrands5` state
   machine (`Postal2Game/Classes/MapScreen.uc:1487+`), which fades each errand
   name in, plays the Dude's comment, writes the location, **and appends to
   `gs.RevealedErrands` / `gs.RevealedLocationTex`**.

So in stock POSTAL 2, "the errands exist" and "the errands are drawn on the
map" are the same event, performed by one local player's UI. That is exactly
the assumption co-op has to break.

### 4.5 Errand completion

`P2GameInfoSingle.CheckForErrandCompletion()` (line ~2773) → `DayBase` →
`ErrandBase.CheckForCompletion()` → each `ErrandGoal`. On success it bumps
`ErrandsCompletedToday`, calls `SaveCompletedErrand()`, fires the goal's
`TriggerOnCompletionTag` event, may `ActivateErrand()` another errand, adds
haters, and shows the map in `Mode_CrossOutErrand`
(`MapScreen.uc` states `CrossOut`…`CrossOut3`).

### 4.6 The map screen

`Postal2Game/Classes/MapScreen.uc` extends `P2Screen` extends `Interaction`
(client-side UI, never replicated). Key points:

- `Sprites` array + `SpritesNextUnused`; statuses are `SS_Off=0`,
  `SS_Fading=1`, `SS_On=2`.
- `SetupSprites()` allocates four blocks — `ErrandNameBase`, `ErrandLocBase`,
  `ErrandLocCrossBase`, `CrossoutBase` — each `Day.NumErrands()` long, and
  turns names on from `gs.RevealedErrands`.
- Sprite positions come from the class defaults `ErrandPositions` and
  `CrossoutTex` (only 4–7 entries: index-guard them).
- `MapInit()`, `SetupActors()`, `CheckWidescreenPreference()`,
  `CheckReadyForHome` and `RenderMsgBody()` all dereference
  `GetGameSingle()` / `Level.Game` and therefore **cannot run on a client**.
  `LanCoopMapScreen` overrides every one of them.

## 5. The mod, file by file

### 5.1 Core

| File | Role |
| --- | --- |
| `LanCoopGameInfo.uc` | The centre of everything. Owns the shared campaign world, the day lifecycle, the errand handout, travel, discovery, difficulty and the world-staging state machine. Start here. |
| `LanCoopPlayer.uc` | Per-connection controller. Screens (map, newspaper), appearance, readiness handshake, cutscene relay, reconnect, wanted replication, pickup sounds. |
| `LanCoopPawn.uc` | Campaign pawn with a travelling `CoopAppearance`, per-pawn `CoopWantedTime`, combat-reference restoration. |
| `LanCoopReplicationInfo.uc` | The only shared campaign state clients read: `CampaignDay`, `TaskCount`, `CampaignMap`, and the `ActiveTaskMask` / `RevealedTaskMask` / `RevealedLocationMask` / `CompletedTaskMask` bit masks. |
| `LanCoopAuthorityMutator.uc` | `P2GameMod` installed from `InitGame`; swaps in the coop AI controllers and maintains attachment bindings. |
| `LanCoopHUD.uc` | Campaign HUD plus player name tags and the owner-replicated wanted meter. |
| `LanCoopLog.uc` | `class'LanCoopLog'.static.WriteEvent(Context, "Event", "key=value …")`. Every diagnostic in the mod goes through this; grep logs for `LanCoop:`. |

### 5.2 Day and errand flow (what section 4 becomes in co-op)

Server side, all in `LanCoopGameInfo.uc`:

- `InitGame()` — spawns the shared `GameState` **before any login**, patches
  the possibly-empty `Days[5]`/`Days[6]` from `AWGameSP`, then either marks
  pre-game (intro/menu map, or an incoming travel whose carried state wins) or
  calls `BeginCampaignDay(0, true)`.
- `BeginCampaignDay(day, bFirstOfGame)` — the co-op version of single player's
  "starting a new game" branch: sets `CurrentDay`, clears `bPreGameMode`, sets
  `bFirstLevelOfGame`/`bFirstLevelOfDay`, resets `ErrandsCompletedToday`,
  raises `bCampaignBriefingDue`. **This must happen in `InitGame`**, because
  the map's `CheckStartDay` script fires when the first pawn spawns, long
  before the world-staging state runs.
- `HasValidCampaignDay()`, `HasCampaignErrand(i)` — the null guards. Use them.
- `RevealCampaignErrands()` — the handout. Appends the current day's active
  errands to `RevealedErrands` (and `RevealedLocationTex` where the errand
  wants a location mark), idempotent, returns how many were new. This replaces
  the single-player map animation as the *authoritative* record.
- `CampaignErrandMask(kind)` — `0` active, `1` revealed, `2` revealed
  location, `3` completed. One bit per errand index.
- `SyncCampaignView()` — pushes day + masks into `LanCoopReplicationInfo`.
- `OfferCampaignBriefings()` — called once a second from `state CoopRunning`.
  While `bCampaignBriefingDue`, pushes the writing animation to every ready
  player that has not confirmed it (`LanCoopPlayer.CoopBriefed*`), with a
  5-second resend window. The flag is only raised on a new day or a mid-day
  `ActivateErrand`, so another level of the same day never replays it.
- `ActivateErrand()` — override; re-runs the handout for errands switched on
  by a goal.
- `CheckForErrandCompletion()` — loops goals server-side, records completion,
  dispatches the completion event through `DispatchCoopQuestEvent` (never
  through one player's UI), and calls `AnnounceCampaignCrossOut()`.
- `AnnounceCampaignCrossOut(errand)` — shows the crossout animation to every
  player.
- `IsPlayerReadyForHome()` — override that trusts the completion *records*,
  not `ErrandsCompletedToday`, so an inflated counter cannot end the day early.
- `AnyCoopScreenShowing()` — stops a `SendPlayerURL` travel from cutting off
  the crossout or newspaper the same errand just raised.
- `auto state StartUp` — the co-op equivalent of single player's `StartUp`,
  but it waits for a real pawn and spreads the actor walks across ticks
  (`Sleep(0.01)`) to stay under the script runaway limit. Order:
  restore travel world → `RestoreDayAndErrands` → `RevealCampaignErrands` →
  `GameInfoIsNowValid` → fog/sky → `PrepActorsByGroup` → `PrepSliderPawns` →
  `PrepPickupsForErrands` → `RemoveGottenPickups` → `bWorldPrepared = true`.
  Each step logs `WorldStage`; the end logs `WorldReady` with the errand masks.

Client side:

- `LanCoopPlayer.SendCoopMap(bBriefing)` — server entry point; reveals, then
  sends day + four masks to that one player.
- `LanCoopPlayer.ClientCoopMapShow(...)` / `ClientCoopMapCrossOut(...)` —
  rebuild the screen locally and show it; both route the player through
  `state CoopReadNews`, which is what releases `bCoopNewsReading` when the
  screen closes. **A screen path that does not enter `CoopReadNews` leaks that
  flag and blocks every later screen.**
- `LanCoopMapScreen.uc` — `BuildCoopDay()` (day + masks → sprites, from class
  defaults), `BuildCoopSprites()`, `CoopIconCount()`, `ShowCoopErrands()`
  (writing animation), `ShowCoopCrossOut()`, plus overrides of
  `FindUnrevealedErrand`, `RevealErrands2/4/5`, `CrossOut3`, `JustLooking`,
  `Show`, `Start`, `SetupActors`, `CheckWidescreenPreference`, `RenderMsgBody`
  — every place the stock screen would have needed `Level.Game`. Local reveal
  bookkeeping is `CoopRevealedMask`/`CoopLocationMask`, so the UI never
  mutates shared campaign state.
- `LanCoopNewsScreen.uc` — same treatment for the newspaper.

### 5.3 Event routing (campaign scripts with two players)

The original `ScriptedAction`s all call `GetPlayer(C)`, which means "the one
player". `LanCoopEventAdapters` swaps those actions for `LanCoopAction*`
subclasses **on the level's own instances at runtime** — no original package is
modified. `LanCoopContextTrigger` remembers which human triggered a
wait-for-trigger script so the adapters can resolve the right participant via
`LanCoopGameInfo.ResolveCoopScriptPlayer` / `BindCoopScript`. See
`docs/EVENT-ROUTING.md` and `LanCoopEventRoutingChecks`.

### 5.4 Travel, arrival and reconnect

`LanCoopGameInfo.SendPlayerTo` / `ProcessServerTravel` / `state CoopTravelPending`,
`PlaceCoopArrival`, `ResolveCoopArrivalPortal`, `FindPlayerStart`;
`LanCoopPawn.RestoreCoopTravelData`; `LanCoopReconnectStore` (session-bound
inventory recovery, *not* a save system); `LanCoopTravelProbe`.
Native travel matches inventory by player name, which is why
`InitGame` preserves the requested `Name` option and `ChangeName` keeps names
unique.

### 5.5 NPC / police ownership

`LanCoopWanted` plus `LanCoopPoliceController`, `LanCoopMilitaryController`,
`LanCoopAWMilitaryController`, `LanCoopFollowPlayerController`. The rule in the
header comment is the rule: never infer a suspect from
`GameInfo.GetPlayer()`. Wanted level is per-pawn (`CoopWantedTime`) and
replicates to its owner as `LanCoopPlayer.CoopWantedPercent` for the HUD.

### 5.6 Cutscenes, attachments, menus

`LanCoopSceneRelay` + `LanCoopCameraBuffer` (the Matinee runs once on the
server; clients receive camera samples), `LanCoopAttachmentRelay` /
`LanCoopAttachmentGuard` (bolton parts have no owning pawn by default),
`LanCoopRootWindow` / `LanCoopMainMenu` / `LanCoopHostMenu` /
`LanCoopJoinMenu` / `LanCoopMultiplayerMenu` / `LanCoopMenuPlayer`,
`LanCoopSessionSettings` (`LanCoopSession.ini`), `LanCoopDiscovery` (LAN-only
UDP broadcast, no master server).

### 5.7 Test fixtures (not shipped behaviour)

`LanCoopLifecycleProbe` runs, in order: appearance, head, wanted ownership,
inventory selection, quest context, arrival placement, arrival portal, scene
camera, camera smoothing, event routing, session/reconnect, presentation,
**map objectives** (`LanCoopMapChecks`), day exit. `LanCoopMissionProbe` runs
the 60-odd event fixtures. Also `LanCoopCheckCommandlet` (package load),
`LanCoopBaseFixesCommandlet` (engine export audit), and the `LanCoopProbe*` /
`LanCoopMission*` fixture actors. A fixture pass is **not** a gameplay pass —
see the rules at the top of `TESTING.md`.

## 6. UnrealScript rules that bite here

- A client has **no `Level.Game`**. Any inherited UI or actor code that calls
  `GetGameSingle()`, `P2GameInfoSingle(Level.Game)` or `Level.Game` at all must
  be overridden before it can run client-side.
- `Accessed None` does not abort the function, it skips the expression and
  continues. Silent half-executed functions are the normal failure mode.
- Dynamic arrays do not grow on out-of-range assignment, and out-of-range
  reads return zero. Index-guard `ErrandPositions`, `CrossoutTex`, `Days`.
- Default properties, including object sub-objects and dynamic arrays, are
  inherited by subclasses, and `class'X'.Default.Field` reads them anywhere.
- Server functions are `reliable if (Role < ROLE_Authority)`, client functions
  `reliable if (Role == ROLE_Authority)`, declared in the `replication` block.
  On a listen host both execute locally, which hides replication bugs — a
  server-side fixture is not evidence that something reaches a real client.
- Replicating an object reference to a package asset (a `Texture`, a `Sound`)
  only works if the client has that package loaded. Sending day/index data and
  resolving the asset locally from class defaults is strictly safer.
- There is no bitwise `~` in reach here; clear a bit with
  `Mask = Mask - (Mask & Bit)`.
- Long `foreach AllActors` walks in one event hit the script runaway limit;
  spread them over a state with `Sleep`.
- A subclass may re-declare a parent state and override only some of its
  functions; it keeps the parent state's other functions and its `extends`
  chain.

## 7. Where to look when something is wrong

| Symptom | Look at |
| --- | --- |
| No errands anywhere, map blank | `bFirstLevelOfGame`/`bFirstLevelOfDay` in `CampaignInit` log line; `ErrandsHandedOut`; `WorldReady` masks |
| Map opens but nothing is written | `MapRoutedToOwner` (`Active=`/`Revealed=`), then `LanCoopMapScreen.BuildCoopSprites` |
| Map/newspaper never opens again | `bCoopNewsOffered`/`bCoopNewsReading` stuck — a screen path that skipped `state CoopReadNews` |
| Day-specific NPCs or props missing | `PrepActorsByGroup` vs `TheGameState.CurrentDay` and the actors' `Group` |
| A campaign script does nothing | the `ScriptLog:` lines for its tag: `action[n]=…`, `end section`, `reached end of script` |
| Wrong player credited / attacked | `LanCoopWanted`, `ResolveCoopScriptPlayer`, `docs/EVENT-ROUTING.md` |
| Travel loses items or position | `TravelWorldRestored`, `TravelPlayerAccept`, `Arrival*` log lines |

Engine logs: `POSTAL2Complete/System/LanCoop<Role>.log`. Mod lines are
prefixed `LanCoop:`; original script lines `ScriptLog:`. Console event text is
capped at 100 characters; full lines only go to the file.
