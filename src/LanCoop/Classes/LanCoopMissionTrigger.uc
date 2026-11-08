class LanCoopMissionTrigger extends Info;
var int Calls;
var Pawn LastPawn;
var bool bSpawnContextProbe;
var ScriptedController StartedController;
var P2Player ContextPlayer;
event Trigger(Actor Other, Pawn EventInstigator)
{
    Calls++;
    LastPawn = EventInstigator;
    ContextPlayer = P2GameInfoSingle(Level.Game).GetPlayer();
    if (bSpawnContextProbe)
        StartedController = Spawn(class'ScriptedController');
}
defaultproperties
{
    RemoteRole=ROLE_None
}
