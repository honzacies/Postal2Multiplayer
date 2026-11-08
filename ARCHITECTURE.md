# Campaign GameInfo foundation

Current update: two real instances, client inventory and coordinated map
round trips now work. See `TRAVEL.md` for current behavior and evidence.
The sections below retain the earlier foundation's design and test history;
single-map limitations and the no-inventory-ownership statement are superseded
by the temporary native travel-cargo handling documented there.

## Decision

`LanCoopGameInfo` derives from `GameTypes.AWPGameInfo`, preserving the
`P2GameInfoSingle` type expected by campaign actors and the seven configured
days (Monday-Friday plus Apocalypse Weekend).

`bIsSinglePlayer` remains inherited for campaign gameplay semantics. Actual
network mode is `Level.NetMode`. Engine.GameInfo already provides login,
capacity checks, possession and network-player creation; deriving from a
deathmatch GameInfo is not required to use those engine facilities.
This does not prove every native networking path accepts these settings;
real-client tests are still required.

## World versus players

- InitGame creates one server-owned AWGameState before players connect.
- Startup waits for a player pawn, instead of invoking SP viewport/autosave
  initialization on an empty dedicated server.
- World setup is divided across latent startup steps, separated by a tick.
  It never performs all actor walks synchronously inside PostLogin. The ready
  flag is set only after all stages have completed.
- World preparation runs once per loaded level, separately from each pawn's
  default/starting loadout.
- PostTravel does not execute the SP branch that treats an existing GameState
  as a loaded save. This avoids that particular ambiguity on a second join.
- GetPlayer returns a stable compatibility player, not the newest item in
  the controller list. It must not be used as a persistent player identity.
- A nearby clear navigation point is selected when the campaign's preferred
  PlayerStart is occupied. This is a prototype fallback: other maps, geometry,
  doors, slopes and simultaneous spawning still need testing.
- LanCoopPlayer guards local interactions/screens/selectors when a controller
  has no local InteractionMaster. It also avoids SP save-preparation waiting.

The original state actor is not sent to clients yet. GameInfo exists on the
server; clients will need a replicated campaign view (GameReplicationInfo or
a dedicated replicated actor), plus client UI that reads it. Replicating that
view does not move authority away from the server.

## Validation on 2026-11-07

`tools/Build.ps1` succeeds with zero compilation errors and the same two
initialization ReadToken warnings seen in phase 1. The commandlet verifies
seven inherited days, the two-player limit and our controller class name.

```powershell
.\tools\Test-CampaignBoot.ps1 -Lifecycle
```

Successful run: `CampaignLifecycle OK PID=34668 UDP=7787`.
The opt-in `LifecycleProbe=1` actor calls actual engine Login/PostLogin paths
with two test controllers. It checks:

- two different living player pawns and NumPlayers=2;
- no change in world-state actor identity;
- no mistaken loaded-save flag on second join;
- stable compatibility-player reference;
- nonempty first-player inventory with the same inventory-chain head after
  second join and repeated PostTravel callbacks;
- successful once-only world preparation and UDP socket ownership.

These controllers have no network connections. This is an authoritative
integration test, not a two-client multiplayer test or a full inventory
snapshot/quantity test. The runner detects readiness from stdout as well as
the engine log because the latter buffers short runs. It stops its own server.

The original deathmatch campaign probe log contained 1,899 occurrences of
`Accessed None 'Game'`; the new campaign lifecycle log has none. This is a
specific comparison of two short runs, not proof that campaign logic is clean.
Remaining diagnostics include a stock shovel skin-array error, NPC damage
with a missing instigator/PRI, initial weapon inventory warnings and unbased
NPC boltons. These remain unresolved; nothing suppresses those warnings.

## Current limits and next steps

This is a fresh Monday, single-map prototype. SaveGame/LoadGame and the normal
SendPlayerTo route report unimplemented instead of running SP save/travel.
Those overrides are not a comprehensive interception of all console/native
travel commands. There is no player persistence or host migration yet.
AW's configured days are inherited; no AW mission has been tested.

Next: real client connection and possession, remote pawn/appearance visibility,
movement and a small replicated campaign view. Inspect client HUD/screens
for assumptions that Level.Game is locally available. Then validate combat,
NPC replication and inventory ownership before implementing coordinated travel.

## Listen-host crash fix

The first user listen-host run reached PostLogin and then hit the engine's
one-million-instruction runaway guard at GetGameDifficulty. The getter itself
has no loop; the error location does not establish recursive difficulty calls.
The original implementation performed all world preparation in that same
PostLogin event, alongside the local player's possession/HUD work.

World preparation now runs in the latent StartUp state, with a short sleep
between stages. PostLogin and PostTravel no longer call the actor walks.
This follows the asynchronous startup approach of the original campaign.
The lifecycle probe now waits for asynchronous world readiness before checking
state invariants instead of assuming startup finishes inside PostLogin.

`tools/Test-ListenHost.ps1` launches an actual windowed listen host, checks for
WORLD_READY and absence of fatal/runaway messages, waits three more seconds,
then terminates only the process it created. This test passed with PID 23620;
every startup stage completed. It does not verify the rendered view, movement
or a remote client's connection. The automatic test's closing of the window
is intentional; Start-Host.cmd does not contain this automatic shutdown.

Original crash log: artifacts/LanCoopHost.before-world-staging.log.
Fixed listen-host log: artifacts/LanCoopListenTest.log.
