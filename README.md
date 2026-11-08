# POSTAL 2 LAN Coop

Experimental two-player cooperative campaign mod for **POSTAL 2 Complete**.
Scope: **Monday–Friday and Apocalypse Weekend**. Paradise Lost is out of scope.

**Work in progress. No campaign day has passed a complete two-player playthrough yet.**

## Status

Last updated: 2026-11-08. "Implemented" does not mean "fully tested".

| Feature | Implementation | Verification / remaining work |
| --- | --- | --- |
| Two local game instances without a VM | Implemented | Two real instances connected and players saw each other. Two separate LAN PCs still need verification. |
| Player names and selectable appearance | Partial | Names work; appearance handling exists. Full skin/head matrix unverified. |
| Independent inventories | Implemented, experimental | Both players opened inventory; selected items/ammo/health/armor survived tested map round trips. Save slots are not implemented. |
| Coordinated map travel | Partial | Direct round trip passed with real clients; physical gates tested manually. Arrival fixes passed server tests; broad portal coverage remains. |
| LAN host/join menu | Implemented, experimental | Manual joining exercised. Discovery deduplication and spectator-default fixes need broader LAN testing. |
| Shared quest completion | Partial | 60 server-side goal fixtures passed for both player roles; this does not verify full NPC scenarios. |
| Shared cutscene camera | Partial | Camera relay exists; dialogue, subtitles, skipping and cleanup remain incomplete. |
| Per-player wanted level | Known bug | Shared singleplayer state can attribute the client's wanted level to the host. Active investigation. |
| NPC and dog target ownership | Known bug | Personal hostility can target the wrong player; travel can lose target identity. Active investigation. |
| Paycheck protestor hostility | Incomplete | Campaign hostility should apply to both coop players; needs implementation and gameplay verification. |
| Client NPC/item replication | Known bugs | Floating/unowned-looking items and stalled NPC animation have been reported. |
| Campaign save/load and autosave | Not implemented | Autosave control is disabled; do not rely on save-slot persistence. |
| Mod-only ZIP | Implemented | Archive content/checksums validated; installed on a separate clean game copy. |
| Independence from standalone Nick's Coop | Verified for tested paths | Base-function audit and isolated server lifecycle passed without NicksCoop.u. Full campaign remains unverified. |
| Verbose debugging | Implemented | Console lines capped at 40 characters; complete details remain in per-instance log files. |

## Campaign playthrough coverage

A day is marked complete only after a recorded two-player end-to-end run, including
quest credit, inventory preservation, transitions, cutscenes and advancing to the next day.

| Day | Manual coop coverage | Fully tested |
| --- | --- | --- |
| Monday | Partial exploration, Main Street/RWS transitions and paycheck scenario. Known AI/wanted/cutscene bugs. | **No** |
| Tuesday | No complete manual run recorded. | **No** |
| Wednesday | No complete manual run recorded. | **No** |
| Thursday | No complete manual run recorded. | **No** |
| Friday | No complete manual run recorded. | **No** |
| Apocalypse Weekend: Saturday | No complete manual run recorded. | **No** |
| Apocalypse Weekend: Sunday | No complete manual run recorded; scripted/boss flow unverified. | **No** |

See [TESTING.md](TESTING.md) for the test ledger and completion criteria.
Automated goal fixtures are never counted as completed campaign days.

## What is included

Our UnrealScript classes, Windows development/test tools, launchers and documentation.
This repository does **not** include the game, original developer source dump,
Nick's standalone mod, game assets, player saves, private logs or compiled packages.
A legally obtained matching installation is required on each player machine.

Original classes include multiplayer contributions attributed to NickP. We inherit
those base-game fixes; this does not require NicksCoop.u. See
[MP-FIX-AUDIT.md](MP-FIX-AUDIT.md) and [CREDITS.md](CREDITS.md).

## Development setup

1. Place your own clean game in `POSTAL2Complete` beside this README.
2. Provide a matching `System/UCC.exe` compiler tool; the tested clean Steam copy
   did not include it. The repository does not redistribute that tool.
3. Close running test instances before rebuilding their package.
4. Run `./tools/Build.ps1` in PowerShell to compile only our `LanCoop.u` package.

Compilation has been tested against build 5100, dated April 17, 2023. Other builds
may require source changes or recompilation. The supplied developer source snapshot
used for investigation was dated April 22, 2023; it is not included here.

`Build.ps1` resets only our development INIs and generated package. It does not
rebuild the original game packages. Do not copy files from an unrelated game build
to satisfy a missing dependency.

## Run

After building, use `Start-Host.cmd` and `Start-Client.cmd` for a same-PC test.
Use `Start-Multiplayer.cmd` for the host/join menus. The root Host launcher listens
on port **7787**; the menu's host port is configurable and defaults to **7777**.
Join the matching address and port. Separate INIs/cache/save directories and
`-NewWindow` allow two instances; this is experimental.

A mod ZIP produced by `tools/Package-Mod.ps1` has separate `Start-LanCoop-*`
launchers intended to be extracted into the target game directory. See
[PACKAGING-README.txt](PACKAGING-README.txt).

## Debugging and bug reports

Open the game console with ConsoleToggle (normally the key below Escape).
`CoopDebugConsole on` / `CoopDebugConsole off` controls console echo.
Full logs are `System/LanCoopHost.log`, `LanCoopClient.log` or `LanCoopMenu.log`.
An instance started through the menu keeps its Menu log after joining.

Report the day/map, who performed the action (host/client), steps, expected and
actual behavior, and the relevant log excerpt. Use the bug-report issue template.
See [DEBUGGING.md](DEBUGGING.md) for log details and current implementation limits.

Historical implementation notes live in [ARCHITECTURE.md](ARCHITECTURE.md),
[TRAVEL.md](TRAVEL.md) and [PHASE1.md](PHASE1.md). Older entries describe their
then-current state; the tables above and test ledger are the current status.
