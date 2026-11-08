// Phase 1 only: verify a custom GameInfo loads in the installed engine.
// Multiplayer campaign behavior is intentionally implemented in later phases.
class LanCoopProbeGame extends xDeathMatch;

event InitGame(out string Options, out string Error)
{
    Super.InitGame(Options, Error);
    class'LanCoopLog'.static.WriteEvent(Self, "Phase", "1_INIT Game=" $ Class $ " Error=" $ Error);
}

function PostBeginPlay()
{
    Super.PostBeginPlay();
    class'LanCoopLog'.static.WriteEvent(Self, "Phase", "1_READY Map=" $ Level.GetLocalURL() $ " NetMode=" $ Level.NetMode);
}

defaultproperties
{
    GameName="LAN Coop - Phase 1 Probe"
    MaxPlayers=2
}
