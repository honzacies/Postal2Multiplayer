POSTAL 2 LAN Coop - experimental clean-install comparison build

INSTALL
1. Use a separate, clean Steam POSTAL 2 Complete installation.
2. Extract this ZIP into the game folder containing System/Postal2.exe.
   Merge the System folder. No original game executable/package is included.
3. Run Start-LanCoop-Host.cmd on the host. Run Start-LanCoop-Menu.cmd
   on the second PC, then Multiplayer -> Join Game. Both use this mod build.
   Direct address is HOST-IP:7787 for the included Host launcher.
   Start-LanCoop-Client.cmd connects to 127.0.0.1:7787 on the same computer.

The launchers create separate LanCoopHost/Menu/Client INIs, user INIs, saves
and cache directories using THIS installation's Default.ini and DefUser.ini.
Postal2.ini and User.ini are not replaced. No Nick's Coop package is required.
Use the supplied launchers to activate this experimental mod.

COMPARISON
Run Capture-Game-Fingerprint.cmd before testing. The JSON report appears in
LanCoopReports. Compare its hashes with DevelopmentBaseline.json from the
development installation. A mismatch is evidence to investigate, not proof
that a file is unofficial. Steam branches/builds may differ.
PackageManifest.json lists our archive files and SHA-256 checksums.
Source/LanCoop/Classes contains the exact UnrealScript sources for this build.
MP-FIX-AUDIT.md explains the base multiplayer fixes and the isolation test.
The optional LanCoopTools/Test-BaseFixes.ps1 capability check uses the game's
own UCC.exe when available; it does not replace a full gameplay test.

TEST ORDER
Join as a player (spectator checkbox should start OFF), move, open inventory,
walk between Main Street and RWS in both directions, then test the paycheck
with the client and with the host in separate fresh sessions.
Check movement and kicking after travel, independent inventory, quest target,
cutscene skip, dialogue/subtitles and floating items.

DEBUG
Open the game console with its ConsoleToggle key (normally below Escape).
Our console event lines are limited to 40 characters. Full data remains in
System/LanCoopHost.log, LanCoopMenu.log or LanCoopClient.log.
CoopDebugConsole on/off controls console echo.

LIMITS
This is not a finished campaign release. Full save-slot support, original
loading/cross-out sequencing, all AI targeting, dialogue/subtitle replication
and client-side item/animation issues remain under development. New quest
context binding covers controllers directly created by the completion event;
it does not yet adapt every original singleplayer scripted action.
Compatibility with a clean installation must still be tested. Compilation
used the installed April 17 2023 POSTAL 2 build and its packages. Different
official builds may require recompilation. No core game package was patched
by our build process, but the development installation was not integrity-verified.

CREDIT
POSTAL 2 and its original code/assets belong to their respective creators.
The supplied developer source attributes several base multiplayer fixes to
NickP. Those remain inherited and credited; this package does not include or
require the separately installed NicksCoop.u or Postal2CoOp.exe mod.
