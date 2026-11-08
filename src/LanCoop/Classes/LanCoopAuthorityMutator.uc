class LanCoopAuthorityMutator extends P2GameMod;
var array<P2MoCapPawn> AttachmentPawns;

function UpdateAttachmentBindings()
{
    local P2MoCapPawn P;
    local LanCoopAttachmentRelay Relay;
    local int I, J;
    local bool bKnown, bHasParts;
    for (I = AttachmentPawns.Length - 1; I >= 0; I--)
        if (AttachmentPawns[I] == None || AttachmentPawns[I].bDeleteMe)
            AttachmentPawns.Remove(I, 1);
    foreach DynamicActors(class'P2MoCapPawn', P)
    {
        bKnown = false;
        for (I = 0; I < AttachmentPawns.Length; I++)
            if (AttachmentPawns[I] == P)
                bKnown = true;
        if (bKnown)
            continue;
        bHasParts = P.TempBolton.Part != None;
        for (J = 0; J < 8; J++)
            bHasParts = bHasParts || P.Boltons[J].Part != None;
        if (bHasParts)
        {
            Relay = Spawn(class'LanCoopAttachmentRelay', P);
            if (Relay != None)
            {
                Relay.SourcePawn = P;
                Relay.Timer();
                Relay.SetTimer(0.5, true);
                AttachmentPawns[AttachmentPawns.Length] = P;
            }
        }
    }
}

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
    UpdateAttachmentBindings();
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
