# Targeted multiplayer-fix audit

Scope: the NickP-labelled changes discussed in P2Player, P2Pawn, P2Weapon,
P2PowerupPickup and P2GameInfo in the supplied developer source snapshot.
This is not a decompilation or a complete audit of NicksCoop.u.

## Findings

| Change attributed by source comments | Existing implementation | LanCoop decision |
| --- | --- | --- |
| Client inventory add/remove notifications | P2Pawn invokes reliable P2Weapon client callbacks | Inherit existing implementation; do not send duplicate notifications. |
| Player readiness before UI setup | P2Player.CheckPlayerValid / NotifyPlayerValid | LanCoop waits for InteractionMaster as well as Player before marking setup complete. This matches our local-UI guards. |
| Client subtitle-manager setup | P2Player.ClientSetupSubtitles | Retain inherited setup. Presence of the manager does not establish shared cinematic dialogue/subtitles. |
| Server asks client to switch to hands | P2Player.ClientSwitchToHands | Retain inherited reliable RPC. |
| Client sends selected inventory item | P2Player.ServerOnSelectedItem | Override in LanCoopPlayer to require the caller's pawn ownership and actual chain membership. Iteration is bounded. |
| Weapon client/listen/dedicated distinction | P2Weapon.NotDedOnServer | Retain inherited implementation. Its existence is not proof that every weapon is correct in coop. |
| Dropped pickup notification/lifetime | P2PowerupPickup -> P2GameInfo.NotifyPickupDropped | Retain inherited campaign semantics. The original lifetime branch uses bIsSingleplayer; it does not itself fix floating pickups. |
| Inventory traversal bailout | P2Player.ChangeAllWeaponHandTextures | The supplied source bounds traversal at 5000. Retain it; a bailout does not repair a corrupted chain. |

These contributions are credited to NickP by the provided source comments.
Removing a separately installed coop mod does not remove contributions in the
base game's classes. No authorship or equivalence of every historical binary
revision has been established by this audit.

## Binary/runtime observations before clean-install comparison

LanCoopBaseFixesCommandlet resolved 12 function exports, with owners in
Postal2Game.P2Player, P2Pawn, P2Weapon and P2GameInfo. It reported
BaseFixAuditOk and NicksCoopLoaded=false. This checks availability and ownership;
it does not compare function bytecode with the supplied source snapshot.

tools/Test-WithoutNicksCoop.ps1 created a separate loader directory, copied
System packages/native dependencies while excluding NicksCoop*/Postal2CoOp*,
and restricted .u search to that directory. It shared map/artwork paths with
the development installation and used a fresh empty cache/save directory.
No files were removed or renamed in the user's installation.

That directory passed the base capability audit and a dedicated campaign
lifecycle test with two fake player connections. Inventory selection accepted
the caller's own item and rejected the other player's item. Quest context,
occupied arrival placement, portal identity, camera/control restoration and
incomplete-day checks also passed. This is not a graphical two-client playthrough.

Evidence: artifacts/LatestNoNicksCoopAudit.txt points to the retained directory,
which contains BaseFixes.log, Lifecycle.stdout.txt, SystemFileInventory.json,
LanCoopAudit.ini and Result.txt. Original-core modifications are NOT ruled out
until comparison with the separate clean installation.

## Installation identities

- Postal2CompleteNick: previous development installation with Nick's mod files.
- Postal2Complete: new clean installation; do not write to it until the user
  confirms that copying has finished.

## Clean-install comparison completed

After copying finished, all 62 original System .u/.dll/.exe files in the new
Postal2Complete installation matched their counterparts in Postal2CompleteNick
by SHA-256. The initial targeted 15-file report also matched. No standalone
NicksCoop/Postal2CoOp files were found in the clean System directory.

The verified LanCoop ZIP was installed into the clean game. Original core hashes
and Postal2.ini/User.ini/Default.ini/DefUser.ini were checked and preserved.
Fresh role-specific LanCoop configuration was generated from clean defaults.

The clean game omits UCC.exe. For headless validation only, an existing UCC.exe
was copied into the separate audit directory (not the clean game). All game
script/native packages came from the clean installation. The 12-function audit
and campaign lifecycle probe passed there. AuditTool.json records tool origin.

Evidence: artifacts/CleanGame-BeforeInstall.json, CleanGame-AfterInstall.json,
CleanGame-AllPackages-Comparison.json, CleanGame-ProtectedConfigs.json and
the retained audit identified by artifacts/LatestNoNicksCoopAudit.txt.

This establishes the compared installations' matching base files and the tested
mod's independence from the standalone coop package. It is not a full campaign
or graphical multiplayer compatibility certification.
