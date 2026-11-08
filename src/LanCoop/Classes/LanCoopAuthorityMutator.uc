class LanCoopAuthorityMutator extends P2GameMod;

function bool CheckReplacement(Actor Other, out byte bSuperRelevant)
{
    local Pawn P;
    P = Pawn(Other);
    if (P != None && P.Controller == None)
    {
        if (P.ControllerClass == class'AIPack.PoliceController')
            P.ControllerClass = class'LanCoopPoliceController';
        else if (P.ControllerClass == class'AIPack.MilitaryController')
            P.ControllerClass = class'LanCoopMilitaryController';
        else if (P.ControllerClass == class'AWPawns.AWMilitaryController')
            P.ControllerClass = class'LanCoopAWMilitaryController';
        else if (P.ControllerClass == class'AIPack.FollowPlayerController')
            P.ControllerClass = class'LanCoopFollowPlayerController';
    }
    return true;
}

event PostBeginPlay()
{
    Super.PostBeginPlay();
    SetTimer(0.5, true);
}

event Timer()
{
    local LanCoopPawn P;
    local PoliceController Cop;
    local GameState S;
    local bool bPursued;
    if (P2GameInfoSingle(Level.Game) == None)
        return;
    S = P2GameInfoSingle(Level.Game).TheGameState;
    if (S == None)
        return;
    foreach DynamicActors(class'LanCoopPawn', P)
    {
        bPursued = false;
        foreach DynamicActors(class'PoliceController', Cop)
            if (Cop.Attacker == P && Cop.Pawn != None && Cop.Pawn.Health > 0)
                bPursued = true;
        if (P.CoopWantedTime > 0)
        {
            P.CoopWantedTime = FMax(0, P.CoopWantedTime - S.CopRadioDec);
            if (bPursued && P.Health > 0)
                P.CoopWantedTime = FMax(S.CopRadioBase, P.CoopWantedTime);
        }
        class'LanCoopWanted'.static.SyncPlayer(P, S.CopRadioMax);
    }
}
