# Map transitions and client inventory

## Manual use

Use normal map boundaries to request a coordinated server transition. Both
players must finish loading before another transition is accepted. The host
can also use these console commands for testing:

```text
CoopMap suburbs-2
CoopMap suburbs-3
```

`CoopMap` is restricted to the local host or a server administrator. An unknown
map is rejected. Direct commands use the map's default start; ordinary map
boundaries retain their destination portal and reposition arriving pawns using
the original campaign's telemarker logic.

## Implementation

- ServerTravel carries each player's native travel inventory separately.
- The shared GameState and original campaign persistence records are carried
  once in the compatibility player's inventory during transit only. The new
  server detaches the cargo and restores its shared world reference. This
  replaces the previous always-new-state behavior; it is not a disk save slot.
- SP InitGame's forced `Name=Player` is corrected after the parent call so the
  host retains its native inventory lookup identity. Duplicate player names
  are disambiguated because those names are native travel lookup keys.
- Fresh day inventory is skipped only for expected travel arrivals, not every
  player who joins a previously travelled map. Native travel callbacks restore
  the arriving inventory; a second join does not reset the shared world.
- Appearance, armor HUD metadata and armor capacity travel per pawn. Human
  pawns are excluded from Telepad's accompanying-NPC collector.
- A per-player ready acknowledgement prevents a second transition while a
  client is still completing the first load.
- LanCoopInventorySelector removes the stock inventory UI's requirement for
  client-side Level.Game, which exists only on the server. The owning pawn's
  inventory is used; opening it does not pause the network game.

## Validation on 2026-11-07

`tools/Test-TwoInstances.ps1 -TravelRoundTrip` passed with two actual graphical
instances, PIDs 17080 and 16976. The route was suburbs-3 -> suburbs-2 -> suburbs-3.
The opt-in probe checked distinct money (111/222), health (81/64), pistol ammo
(13/29), armor (17/36), both appearance classes, names and a shared world flag
after both transitions. Both players acknowledged loaded state on each map.
The client inventory opened successfully in NM_Client, after readiness.

The probe found no direct Telepad link between these particular two maps and
explicitly fell back to direct map changes. Thus this run does not validate
walking through a boundary, destination portal placement, arbitrary map pairs,
every weapon/inventory type, all world persistence or campaign mission sync.
Manual boundary testing is the next check. Ordinary launchers never enable
the probe, its seeded inventory or automatic map changes.

Relevant evidence: artifacts/TwoInstances.result.txt,
artifacts/LanCoopTravelProbe.ini, artifacts/Travel-latest-before-manual-test.log
and artifacts/LanCoopTwoClient.log. The probe persists its result to its own INI
because short-run engine log output is buffered.

No game save slot import/export, host migration, reconnect persistence or
independent maps per player is implemented by this change.
