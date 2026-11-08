// Session-bound reconnect snapshots, not a campaign save/load system.
class LanCoopReconnectStore extends Object config(LanCoopReconnect);

struct SavedItem
{
    var string SessionId, PlayerId;
    var string ItemClass;
    var float Amount;
    var int Ammo;
    var int Charge, Tainted, UseForErrands;
    var Material Skin;
};
struct SavedPlayer
{
    var string SessionId, PlayerId, MapName;
    var int Day, Health;
    var float Armor, ArmorMax, Wanted;
    var vector Position;
    var rotator Facing;
    var string Appearance, HeldWeapon;
};
var config array<SavedPlayer> Players;
var config array<SavedItem> Items;

function Commit()
{
    // New map GameInfos instantiate from class defaults in the same process.
    // Keep those defaults current as well as writing the reconnect file.
    Default.Players = Players;
    Default.Items = Items;
    SaveConfig();
}

function Capture(LanCoopGameInfo G, LanCoopPlayer P)
{
    local int I, N, Count;
    local Inventory Item;
    local LanCoopPawn Dude;
    Dude = LanCoopPawn(P.Pawn);
    if (Dude == None || Dude.Health <= 0 || P.CoopReconnectId == "" || G.bTravelQueued)
        return;
    for (I = 0; I < Players.Length; I++)
        if (Players[I].SessionId == G.CoopSessionId && Players[I].PlayerId == P.CoopReconnectId)
            break;
    if (I == Players.Length)
        Players.Length = I + 1;
    Players[I].SessionId = G.CoopSessionId;
    Players[I].PlayerId = P.CoopReconnectId;
    Players[I].MapName = string(G.Level.Outer.Name);
    Players[I].Day = G.TheGameState.CurrentDay;
    Players[I].Health = Dude.Health;
    Players[I].Armor = Dude.Armor;
    Players[I].ArmorMax = Dude.ArmorMax;
    Players[I].Wanted = Dude.CoopWantedTime;
    Players[I].Position = Dude.Location;
    Players[I].Facing = P.Rotation;
    Players[I].Appearance = string(Dude.CoopAppearance);
    if (Dude.Weapon != None)
        Players[I].HeldWeapon = string(Dude.Weapon.Class);
    for (N = Items.Length - 1; N >= 0; N--)
        if (Items[N].SessionId == G.CoopSessionId && Items[N].PlayerId == P.CoopReconnectId)
            Items.Remove(N, 1);
    for (Item = Dude.Inventory; Item != None && Count++ < 5000; Item = Item.Inventory)
        if (GameState(Item) == None)
        {
            N = Items.Length;
            Items.Length = N + 1;
            Items[N].SessionId = G.CoopSessionId;
            Items[N].PlayerId = P.CoopReconnectId;
            Items[N].ItemClass = string(Item.Class);
            Items[N].Charge = Item.Charge;
            if (Item.Skins.Length > 0)
                Items[N].Skin = Item.Skins[0];
            if (P2PowerupInv(Item) != None)
            {
                Items[N].Amount = P2PowerupInv(Item).Amount;
                Items[N].Tainted = P2PowerupInv(Item).Tainted;
                Items[N].UseForErrands = P2PowerupInv(Item).UseForErrands;
            }
            if (Ammunition(Item) != None)
                Items[N].Ammo = Ammunition(Item).AmmoAmount;
        }
    Commit();
    class'LanCoopLog'.static.WriteEvent(P, "ReconnectSaved", "Player=" $ P.PlayerReplicationInfo.PlayerName $ " Items=" $ N + 1);
}

function bool Restore(LanCoopGameInfo G, LanCoopPlayer P)
{
    local int I, N, Count;
    local Inventory Item, NextItem;
    local class<Inventory> ItemClass;
    local LanCoopPawn Dude;
    Dude = LanCoopPawn(P.Pawn);
    if (Dude == None || P.CoopReconnectId == "" || P.bCoopTravelLogin)
        return false;
    for (I = 0; I < Players.Length; I++)
        if (Players[I].SessionId == G.CoopSessionId && Players[I].PlayerId == P.CoopReconnectId)
            break;
    if (I == Players.Length)
        return false;
    // Resolve every class before altering the new pawn's inventory.
    for (N = 0; N < Items.Length; N++)
        if (Items[N].SessionId == G.CoopSessionId && Items[N].PlayerId == P.CoopReconnectId
            && class<Inventory>(DynamicLoadObject(Items[N].ItemClass, class'Class', true)) == None)
            return false;
    Item = Dude.Inventory;
    while (Item != None && Count++ < 5000)
    {
        NextItem = Item.Inventory;
        Dude.DeleteInventory(Item);
        Item.Destroy();
        Item = NextItem;
    }
    Dude.Weapon = None;
    Dude.PendingWeapon = None;
    Dude.SelectedItem = None;
    Dude.MyUrethra = None;
    for (N = 0; N < Items.Length; N++)
    {
        if (Items[N].SessionId != G.CoopSessionId || Items[N].PlayerId != P.CoopReconnectId)
            continue;
        ItemClass = class<Inventory>(DynamicLoadObject(Items[N].ItemClass, class'Class'));
        Dude.CreateInventoryByClass(ItemClass);
    }
    // Set counts after all weapons have created their ammunition.
    for (N = 0; N < Items.Length; N++)
    {
        if (Items[N].SessionId != G.CoopSessionId || Items[N].PlayerId != P.CoopReconnectId)
            continue;
        ItemClass = class<Inventory>(DynamicLoadObject(Items[N].ItemClass, class'Class'));
        Item = Dude.FindInventoryType(ItemClass);
        if (Item != None)
        {
            Item.Charge = Items[N].Charge;
            if (Items[N].Skin != None)
                Item.Skins[0] = Items[N].Skin;
        }
        if (P2PowerupInv(Item) != None)
        {
            P2PowerupInv(Item).Amount = Items[N].Amount;
            P2PowerupInv(Item).Tainted = Items[N].Tainted;
            P2PowerupInv(Item).UseForErrands = Items[N].UseForErrands;
        }
        if (Ammunition(Item) != None)
            Ammunition(Item).AmmoAmount = Items[N].Ammo;
    }
    Dude.Health = Players[I].Health;
    Dude.Armor = Players[I].Armor;
    Dude.ArmorMax = Players[I].ArmorMax;
    Dude.CoopWantedTime = Players[I].Wanted;
    P.ServerSetAppearance(Players[I].Appearance);
    Dude.RestoreCombatReferences();
    P.ToggleToHands(true);
    if (Players[I].MapName ~= string(G.Level.Outer.Name) && Players[I].Day == G.TheGameState.CurrentDay)
    {
        if (Dude.SetLocation(Players[I].Position))
            P.ClientSetLocation(Dude.Location, Players[I].Facing);
    }
    P.ResetCoopArrivalState();
    P.bCoopReconnectRestored = true;
    class'LanCoopLog'.static.WriteEvent(P, "ReconnectRestored", "Player=" $ P.PlayerReplicationInfo.PlayerName);
    for (N = Items.Length - 1; N >= 0; N--)
        if (Items[N].SessionId == G.CoopSessionId && Items[N].PlayerId == P.CoopReconnectId)
            Items.Remove(N, 1);
    Players.Remove(I, 1);
    Commit();
    return true;
}
