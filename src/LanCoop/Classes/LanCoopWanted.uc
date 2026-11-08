// Per-player authority state. Never infer a suspect from GameInfo.GetPlayer().
class LanCoopWanted extends Object;

static function Report(PoliceController Cop, FPSPawn Suspect, bool bForce)
{
    local LanCoopPawn P;
    local GameState S;
    P = LanCoopPawn(Suspect);
    if (P == None || Cop.MyPawn == None || !Cop.MyPawn.bHasRadio)
        return;
    // PlayerAttackedMe also distinguishes a new suspect from an old report.
    if (Cop.bReportedPlayer && !bForce && Cop.PlayerAttackedMe == P)
        return;
    S = P2GameInfoSingle(Cop.Level.Game).TheGameState;
    if (S == None)
        return;
    if (P.CoopWantedTime <= 0)
        P.CoopWantedTime = S.CopRadioBase;
    else
        P.CoopWantedTime = FMin(S.CopRadioMax, P.CoopWantedTime + S.CopRadioInc);
    Cop.bReportedPlayer = true;
    Cop.PlayerAttackedMe = P;
    SyncPlayer(P, S.CopRadioMax);
    class'LanCoopLog'.static.WriteEvent(Cop, "WantedReported", "Suspect=" $ P $ " Time=" $ P.CoopWantedTime);
}

static function SyncPlayer(LanCoopPawn P, float MaxTime)
{
    local LanCoopPlayer C;
    if (P == None || MaxTime <= 0)
        return;
    foreach P.DynamicActors(class'LanCoopPlayer', C)
        if (C.MyPawn == P || C.Pawn == P)
            C.CoopWantedPercent = FClamp(P.CoopWantedTime / MaxTime, 0, 1);
}

// Scope original synchronous police decisions to their actual subject, while
// retaining each controller subclass's original crime/arrest behaviour.
static function float BeginCheck(PoliceController Cop, FPSPawn Suspect)
{
    local GameState S;
    local float Previous;
    S = P2GameInfoSingle(Cop.Level.Game).TheGameState;
    if (S == None)
        return 0;
    Previous = S.CopRadioTime;
    S.CopRadioTime = 0;
    if (LanCoopPawn(Suspect) != None)
        S.CopRadioTime = LanCoopPawn(Suspect).CoopWantedTime;
    return Previous;
}

static function EndCheck(PoliceController Cop, float Previous)
{
    if (P2GameInfoSingle(Cop.Level.Game).TheGameState != None)
        P2GameInfoSingle(Cop.Level.Game).TheGameState.CopRadioTime = Previous;
}
