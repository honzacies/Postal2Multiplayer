// Resolve the event participant instead of the original first-player lookup.
class LanCoopActionWeaponCondition extends MoreGame.ACTION_IfPlayerWeaponState;

function P2Player GetPlayer(ScriptedController C)
{
    if (C == None || LanCoopGameInfo(C.Level.Game) == None)
        return None;
    return LanCoopGameInfo(C.Level.Game).ResolveCoopScriptPlayer(C, false);
}

function bool InitActionFor(ScriptedController C)
{
    if (C == None)
        return false;
    return Super.InitActionFor(C);
}

function ProceedToNextAction(ScriptedController C)
{
    local P2Player P;
    P = GetPlayer(C);
    if (P == None || P.MyPawn == None || P.MyPawn.Weapon == None)
    {
        C.ActionNum++;
        ProceedToSectionEnd(C);
        return;
    }
    Super.ProceedToNextAction(C);
}
