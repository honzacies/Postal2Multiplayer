// Resolve the event participant instead of the original first-player lookup.
class LanCoopActionGiveInventory extends AWPStuff.ACTION_GiveInventoryToPlayer;

function P2Player GetPlayer(ScriptedController C)
{
    if (C == None || LanCoopGameInfo(C.Level.Game) == None)
        return None;
    return LanCoopGameInfo(C.Level.Game).ResolveCoopScriptPlayer(C, false);
}

function bool InitActionFor(ScriptedController C)
{
    if (GetPlayer(C) == None)
        return false;
    return Super.InitActionFor(C);
}
