// Minimal NPC fixture, used only by the opt-in mission event audit.
class LanCoopMissionPawn extends FPSPawn;
defaultproperties
{
    ControllerClass=None
    RemoteRole=ROLE_None
    bCollideActors=false
    bBlockActors=false
    bBlockPlayers=false
    bUseForErrands=true
}
