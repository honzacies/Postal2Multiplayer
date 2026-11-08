// Keep the original controller's states; adapt only player-specific wanted checks.
class LanCoopFollowPlayerController extends AIPack.FollowPlayerController;

var LanCoopPawn CoopReportedSuspect;

function ReportAsWanted(FPSPawn Suspect, optional bool bForce)
{
    if (CoopReportedSuspect != Suspect)
        bReportedPlayer = false;
    class'LanCoopWanted'.static.Report(Self, Suspect, bForce);
    CoopReportedSuspect = LanCoopPawn(Suspect);
}

function AuthorityActOnPawnLooks(FPSPawn LookAtMe, optional out byte StateChange)
{
    local float Previous;
    Previous = class'LanCoopWanted'.static.BeginCheck(Self, LookAtMe);
    Super.AuthorityActOnPawnLooks(LookAtMe, StateChange);
    class'LanCoopWanted'.static.EndCheck(Self, Previous);
}

function DangerPawnBump(Actor Other, optional out byte StateChange)
{
    local float Previous;
    Previous = class'LanCoopWanted'.static.BeginCheck(Self, FPSPawn(Other));
    Super.DangerPawnBump(Other, StateChange);
    class'LanCoopWanted'.static.EndCheck(Self, Previous);
}

function float RadioHQ()
{
    local float Previous, Duration;
    Previous = class'LanCoopWanted'.static.BeginCheck(Self, Attacker);
    Duration = Super.RadioHQ();
    class'LanCoopWanted'.static.EndCheck(Self, Previous);
    return Duration;
}
