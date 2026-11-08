// Resolve the event participant instead of the original first-player lookup.
class LanCoopActionErrand extends MoreGame.ACTION_Errand;

function P2Player GetPlayer(ScriptedController C)
{
    if (C == None || LanCoopGameInfo(C.Level.Game) == None)
        return None;
    return LanCoopGameInfo(C.Level.Game).ResolveCoopScriptPlayer(C, false);
}

function bool InitActionFor(ScriptedController C)
{
    if (ErrandAction == EEA_ErrandGoalMet_UniqueTag && GetPlayer(C) == None)
        return false;
    return Super.InitActionFor(C);
}
