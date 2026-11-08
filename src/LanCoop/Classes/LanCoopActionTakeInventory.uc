// Resolve the event participant instead of the original first-player lookup.
class LanCoopActionTakeInventory extends AWPStuff.ACTION_TakeInventoryFromPlayer;

function P2Player GetPlayer(ScriptedController C)
{
    if (C == None || LanCoopGameInfo(C.Level.Game) == None)
        return None;
    return LanCoopGameInfo(C.Level.Game).ResolveCoopScriptPlayer(C, false);
}

function bool InitActionFor(ScriptedController C)
{
    local P2Player P;
    local Inventory Item, NextItem;
    local bool bWeaponRemoved;
    local int Count;
    if (GetPlayer(C) == None)
        return false;
    P = GetPlayer(C);
    if (P.MyPawn == None || InvType == None)
        return false;
    Item = P.MyPawn.Inventory;
    while (Item != None && Count++ < 5000)
    {
        NextItem = Item.Inventory;
        if (Item.Class == InvType)
        {
            if (P.MyPawn.Weapon == Item)
                bWeaponRemoved = true;
            P.MyPawn.DeleteInventory(Item);
            Item.Destroy();
        }
        Item = NextItem;
    }
    if (bWeaponRemoved && P.Pawn != None)
        P.ToggleToHands(true);
    return false;
}
