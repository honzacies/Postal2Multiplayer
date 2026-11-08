# Test ledger

Update this file and the README status tables when a meaningful result changes.
Keep implementation status, server fixtures and real multiplayer playthroughs separate.
Never mark an untested feature as working merely because it compiled.

## Recorded results — 2026-11-08

| Check | Result | Boundary |
| --- | --- | --- |
| Package compilation/loading | Passed | Development build 5100; two pre-existing initialization warnings. |
| Two real local clients | Passed for connection/visibility | Same PC, not two separate LAN PCs. |
| Real-client direct map round trip | Passed | suburbs-3 → suburbs-2 → suburbs-3; selected inventory/health/ammo/armor/appearance and world flag checked. Not physical portal coverage. |
| Mission event fixtures | 60 passed, 0 failed, 1 skipped | Fake server-side player connections; no full NPC/dialogue playthrough. Sunday scripted slot not covered. |
| Occupied arrival placement | Passed | Dedicated fixture avoids the first player's position and restores walking only for verified floor placement. |
| Explicit portal identity | Passed | Server fixture checks empty remote portal fallback and explicit entry precedence. |
| Quest event player context | Passed | Immediate completion event and directly created scripted controllers; not every asynchronous original script. |
| Camera/control restoration | Passed | Synthetic camera fixture, not complete native Matinee/audio playback. |
| Incomplete-day protection | Passed | One completed errand or an inflated aggregate counter does not finish Monday. All active errand records do. |
| Inventory selection ownership | Passed | Own item accepted; another player's item rejected. |
| Standalone coop dependency audit | Passed for tested paths | 12 base function exports found; isolated lifecycle ran with NicksCoop.u unavailable. |
| Clean installation comparison | Passed | All 62 original System .u/.dll/.exe files matched the previous installation before mod deployment. Original configs/core files preserved. |
| Clean graphical host/menu startup | Passed | Both processes responded; host spawned a pawn. Complete two-client campaign verification remains open. |
| ZIP packaging / launcher bootstrap | Passed | Mod-only archive hashes verified; all three role INIs initialized without development INIs. |

Local evidence logs/artifacts are intentionally excluded from Git. Reports in this
ledger summarize those observations; the public repository cannot replay the game
checks without a matching user-provided installation and compiler tool.

## Active regression checklist

- [ ] Host crime raises only host wanted level.
- [ ] Client crime raises only client wanted level.
- [ ] Police select the actual suspect, independent of the HUD wanted indicator.
- [ ] Dogs retaliate against the actual aggressor, both directions.
- [ ] Ordinary NPC hostility stays attached to the correct player.
- [ ] Personal hostility survives travel without being reassigned to the host.
- [ ] Paycheck protestors treat both coop players as campaign enemies.
- [ ] Quest credit works for a host pickup and a client pickup in separate fresh runs.
- [ ] Cutscene view, dialogue and subtitles match for both players.
- [ ] Host skip and client skip both clean up all associated scripts.
- [ ] Main Street ↔ RWS gates place both players correctly without false stuck recovery.
- [ ] Movement, kicking and separate inventories still work after each transition.
- [ ] Dropped items/attachments/NPC animations match between host and client.
- [ ] LAN discovery shows one entry per server and normal joining defaults to player.
- [ ] Test the session on two separate LAN PCs.

## Completing a campaign day

Record a separate run entry with date, game build/mod commit, player roles,
starting state, route/errands, every failure and the final result. A complete run
must include every required errand, both players' inventory, NPC reactions,
cutscenes/skip behavior, map transitions and the intended end-of-day destination.
Repeat role-sensitive interactions with the other player as initiator.

Current fully tested days: **none**.

## Run template

- Date:
- Mod commit / game build:
- Day / maps:
- Starting state:
- Host / client actions:
- Expected:
- Actual:
- Logs / issue references:
- Result: Passed / Failed / Partial / Not tested
- End-to-end day completion: Yes / No
