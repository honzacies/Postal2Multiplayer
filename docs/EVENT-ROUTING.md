# Player identity in campaign events

This work is staged separately from the installed test build while the current
LAN session is running. It requires a restart and installation on both PCs before
manual testing. It does not establish complete campaign compatibility.

## Implemented routing

Personal actions resolve the human participant from the active event, a binding
on the running script, or its actual player instigator/pawn. A cached stock
`MyPlayerController` alone is insufficient: the original code can populate it with
the first player. Unknown personal ownership logs `EventPlayerUnresolved` and
does not guess the host.

Runtime adapters cover stock scripted inventory grants/removals, inventory
confiscation, errand goal notifications, weapon conditions, player-caused AI
disturbances, newspaper screens and chained trigger events. Campaign-wide travel,
home checks and end-game actions can still resolve the campaign player when no
individual participant exists. Inventory confiscation retains the stock shared
storage behavior; independent recovery from that storage is not verified.

Exact stock action classes are adapted in memory, preserving their configured
properties. A property-copy mismatch logs `EventAdapterCopyFailed` and keeps the
original action. Unknown subclasses are left intact. Wait-for-trigger stock
scripts receive participant-aware proxies; hard actor references and custom
trigger subclasses still need map-specific checks.

Newspaper content comes from the server's campaign day and is sent only to the
reader's controller. Its local screen keeps the original animation and paper
assets without pausing the other player. Actual client rendering, closing,
cutscene interruption and travel must still be tested on two PCs.

The manual map now receives its background and quest sprites
from the server. Active objectives are explicitly included even when the original
single-player reveal animation never ran. Completed records supply crossouts;
inactive future objectives remain hidden. This presentation does not alter goal
completion, reveal history or campaign counters. A regression fixture starts with
empty reveal arrays and checks objective names, locations and completion marks.
Both host and guest request paths are checked for the same objective payload.

It uses the stock local trail/marker and screen animation. It does
not pause the other player. Scripted reveal/crossout cinematics and other personal
screens (voting, character selection and statistics) still need further client
presentation support. NPC dialogue, hostility, cinematic
scripts, special triggers and the remaining scripted action types are not all
covered by these adapters.

## Verification

The isolated dedicated-server lifecycle fixture uses two simulated player
controllers and native trigger startup. It checks client-only inventory changes,
owner-only newspaper payload, rejection of an ambiguous cached host, chained
event context and delayed startup while game validity is pending. Existing
wanted, quest-context, arrival, scene-state and day-exit checks remain enabled.
This is server-side evidence, not two-PC gameplay validation.

The session fixture also checks an owner-only map payload and reconnect state
through a fresh store instance: money quantity/taint, health, armor, wanted state,
same-area location and campaign isolation. A separate launcher check confirms
resolution, fullscreen and identity survive repeated preparation under Windows
PowerShell. The remote urine effect is visual-only; server fluid collision and
quest triggers remain unchanged. Its visibility still needs two-PC confirmation.

Reconnect identity is local to the game folder/profile. Keep its identity files
and `LanCoopSession.ini` when updating. Returning to the same running campaign
restores inventory; position is restored only in the same area and day when it
is unoccupied. If the group has moved, the returning player joins their current
area. Restarting the host starts a new session, not a saved campaign.

Coop launchers retain their existing per-role game/user INIs and stop forcing
1024×768/windowed mode every launch. New profiles inherit the installation's
current configuration. Host menu limits, name, difficulty and intro selection
are saved, and the join menu remembers its last address.

Manual checks needed, with each player initiating in separate runs:

- Pick up a newspaper, read it again, close it and resume movement/fire.
- Start a cutscene or map transition while the other player reads the paper.
- Repeat the paycheck pickup and inspect who receives reactions/credit.
- Exercise scripted inventory grants/removal and verify the other inventory.
- Check `EventPlayerUnresolved` and `EventAdapterCopyFailed` in the full logs.

## Loading and presentation follow-up

Coop travel now keeps the loading artwork over the temporary Entry camera until
the owning pawn acknowledges arrival. Network progress callbacks do not open a
second connection menu during that transition. Errors still leave the loading
screen and open the stock error window. Coop main menus omit promotional/social
widgets, whose Root-owned windows could otherwise remain over connection screens.
Travel explicitly retains active players as non-spectators.

Server attachment relays supply each character accessory's owning pawn, parent
and bone. The client retries missing attachments and temporarily hides stationary
orphan accessories/weapon attachments while their parents are unavailable. It
does not delete pickups or suppress physically falling/dropped parts. Server
checks verify real map accessory bindings and the orphan-versus-drop distinction;
visibility under real client network relevancy is still unverified.

Player subtitle labels now resolve the speaking pawn/controller's replicated
player name, including sounds sourced from owned attachments. Stock subtitle
language, priority, duration, sound filtering and NPC labels remain in use. This
does not broadcast extra dialogue or repair unrelated cutscene sound delivery.
Checks cover both players, attachment ownership and live name changes; actual
subtitle playback on two PCs still needs testing.

Appearance changes now retain skeletal animation state, reattach the equipped
weapon and refresh the owning client's pawn/foot/urethra references and weapon
selector after leaving the menu. They do not replace the campaign pawn or grant
a loadout. The reported client-only weapon lock still requires reproduction and
confirmation on a real client; `AppearanceCombatPreserved` and
`AppearanceControlsRefreshed` record the server and client sides respectively.

## Shared camera smoothing

Cutscene camera samples carry server timestamps, frame IDs and cut epochs. Each
viewer renders from a bounded buffer delayed by 75 ms, interpolating position,
shortest-path rotation and FOV between samples. Old/reordered frames are ignored;
scene/view changes, large jumps and long gaps snap instead of sweeping across
the level. No player movement or mouse input uses this buffer. Missing samples
hold the last view rather than extrapolating through geometry.

Deterministic engine checks cover interpolation, angle wrap, FOV, rejected late
packets, cuts and long gaps. Two-PC visual confirmation is still needed.
Connection error windows now also emit `ConnectionError` with their full message
in the file log. A 200-second timeout appears in the available host Menu log, but
cannot yet be attributed to the reported failure without the matching client log.
