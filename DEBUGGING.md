# Coop debugging, 2026-11-08

Mod events use PascalCase followed by key/value details in the normal engine
log. Examples: `PlayerJoin`, `ClientReady`, `Gate`, `TravelPrepare`,
`Arrival`, `SceneBegin`, `SceneClientBegin`, `PlayerInputState`,
`PrimaryFireRequested`, `PlayerRestarted`. Actor events include map-qualified
actor identity, game time and network mode. Original engine messages remain
unchanged. This instruments important mod transitions, not every engine call.

Verbose logging defaults on. It can be disabled with
`[LanCoop.LanCoopLog] bVerbose=False` in System/LanCoopDebug.ini.
Events also print directly to the local game's console by default (ConsoleToggle,
normally tilde below Escape). `CoopDebugConsole off` / `CoopDebugConsole on`
changes and saves the console echo setting. File logging continues independently.
Echo uses the console directly without HUD messages. Server events appear in the
host's console; each client sees events executed in its own instance.
Input snapshots occur on controller state/pawn changes and every three seconds;
fire input is logged separately. Snapshot data includes pawn, cached MyPawn,
view target, active screen, menu state, Windows mouse flag and camera rotation.

Normal host log: POSTAL2Complete/System/LanCoopHost.log.
An instance started through Start-Multiplayer.cmd keeps using LanCoopMenu.log,
including after joining. Start-Client.cmd uses LanCoopClient.log.
Events from the same computer's instances must be compared by their own game
time, not treated as a shared clock.

## Changes and limits

- Day-end eligibility now checks completion records for every active errand,
  instead of trusting the aggregate completed counter or cached active count.
  Empty days do not qualify for ordinary home diversion. The existing original
  weekend/final-Friday exceptions still run in WillPlayerBeDivertedHome.
- Arrival placement resolves the incoming portal tag. It no longer guesses
  another portal from a second player's displaced spawn location. Direct map
  commands without a portal keep normal spawn selection.
- Join menu now uses the original browser's connecting-window / ClientTravel /
  ConsoleClose sequence. This addresses missing menu input cleanup; graphical
  menu-to-join movement still requires manual verification.
- Cutscene relay keeps native server Matinee and broadcasts its camera/FOV at
  up to 40 Hz. Observers cannot move/fire during the scene. Scene cleanup restores
  their state and HUD. Skip requests go to the native viewer so native permissions
  still apply. This is experimental: native scene chains, Vince dialogue, skipping,
  scene-triggered travel and late joins require real playthrough verification.
  This is camera-state transmission, not video streaming or frame-lock sync.
- The original campaign's day/errand/loading interactions are not yet reproduced
  fully by network travel. Missing original loading UI is a known difference;
  the SP loading interaction also initiates travel, so invoking it unchanged
  alongside ServerTravel would be unsafe.
- Reported firing/aim jumps remain unresolved. Added input/camera logs collect
  evidence without disabling original weapon recoil.

## Evidence before final manual-test build

Build and package load checks succeeded. An earlier build in this session passed
the lifecycle test, including rejecting an inflated completed counter and allowing
all three completed Monday errands. Mission event fixtures reported 60 passed,
0 failed and 1 skipped null/scripted slot. These are not campaign playthroughs.

Two real instances passed a direct suburbs-3 -> suburbs-2 -> suburbs-3 round trip
with separate inventories and no fatal error (PIDs 7884/3012). This was before the
last menu-cleanup/logging changes and did not walk through physical portals or
exercise native cutscenes. A camera/control restoration check was added to the
lifecycle probe afterward; it has not yet been run. The final build was handed
to the user for manual testing instead of launching more automatic game tests.

## Follow-up: missing client portal / LAN menu

ManualPortal-before-fix-Host.log shows native travel acceptance for both players
but an Arrival event only for the host on rwsblock and suburbs-1. Travel now
includes an explicit CoopEntry option. The destination GameInfo keeps that value
and supplies it when a remote login has an empty portal argument, including to
native spawn selection. After the owning client reports pawn readiness, a reliable
message confirms the final server position/rotation and clears spawn predictions.

The subsequent lifecycle run passed ArrivalPortalCheckOk, SceneCameraCheckOk,
DayExitCheckOk and LifecycleOk. The camera check validates state restoration,
not native Matinee playback. Actual two-client physical portal travel remains
for the user's manual retest.

Spectator checkbox starts false; ordinary join explicitly sends
SpectatorOnly=false. Discovery V2 carries a server-instance ID so loopback and
LAN replies become one row. Refresh clears old results.

Reliable pre-travel messages supply the same original campaign loading artwork
to both local loading renderers. Their disk progress is independent. Full SP
loading-screen/cross-out sequencing is still not reproduced; the visual update
is independent of authoritative arrival placement.

## Clean-install comparison build

Console event text is capped at 40 characters, using the event name and the
original data before long context prefixes. Full file log lines are unchanged.

Arrival placement now traces BSP floor without actors and tries an unoccupied
nearby location, avoiding placement on another player's head. Successful placement
sets walking physics and resets stuck detection. A two-second arrival grace
period covers initialization; ordinary stuck detection resumes afterward.
Walking physics is enforced only for a verified floor placement. Arrival
confirmation without such placement retains the native airborne physics.

DispatchCoopQuestEvent exposes the actual player during synchronous completion
callbacks and binds newly created ScriptedControllers to that player's controller.
The previous campaign player reference is restored afterward. Coverage is limited:
pre-existing controllers, asynchronous chains, native GetMyPlayer fallback while
the player is unpossessed, and P2ScriptedAction's ControllerList lookup still need
separate compatibility work. This is not proof that protestors target correctly.

Validation: build/package load succeeded; dedicated lifecycle checks passed
QuestContextCheckOk, ArrivalPlacementCheckOk, ArrivalPortalCheckOk,
SceneCameraCheckOk, DayExitCheckOk and LifecycleOk. Mission fixtures passed 60,
failed 0, skipped 1. These checks use fake player connections, not real clients.
Launcher bootstrap passed for all three roles without a development LanCoop.ini,
preserving the target Default.ini. The bootstrap fixture did not run the engine.

tools/Package-Mod.ps1 emits a drop-in ZIP with only our compiled package,
sources, launchers, documentation and hash manifests. The launcher initializes
from the destination game's own Default.ini/DefUser.ini. The development baseline
hash report is for comparison and does not certify the development installation
as pristine. Clean Steam compatibility remains unverified until that test runs.

Targeted base-fix audit: see MP-FIX-AUDIT.md. BaseFixAuditOk was observed with
12 required function exports, followed by an isolated lifecycle pass with
NicksCoop.u/Postal2CoOp files unavailable to the script package loader. The
new InventorySelectionCheckOk rejects another player's inventory selection.
CheckPlayerValid now waits for local InteractionMaster before UI initialization.
This does not establish bytecode equivalence with the supplied source or pristine
base binaries; clean-copy hash/runtime comparison is still pending.

Clean-copy follow-up completed: 62 original System .u/.dll/.exe files matched
the old installation by SHA-256 before mod deployment. The installed mod passed
the base capability and headless lifecycle checks using the clean game's packages.
Original core/config hashes were preserved. UCC.exe was used only in a separate
audit directory because the clean game does not ship it. See MP-FIX-AUDIT.md.
