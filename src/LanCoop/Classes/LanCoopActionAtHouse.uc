// Resolve the event participant instead of the original first-player lookup.
class LanCoopActionAtHouse extends MoreGame.ACTION_AtMyHouse;

function P2Player GetPlayer(ScriptedController C)
{
    if (C == None || LanCoopGameInfo(C.Level.Game) == None)
        return None;
    return LanCoopGameInfo(C.Level.Game).ResolveCoopScriptPlayer(C, true);
}

function bool InitActionFor(ScriptedController C)
{
    if (GetPlayer(C) == None)
        return false;
    return Super.InitActionFor(C);
}
