class LanCoopInventorySelector extends P2InventorySelector;

function ShowMenu()
{
    // A remote client has no Level.Game. The stock selector requires that
    // server-only object even though it renders the local pawn's inventory.
    if (PlayerOwner == None || PlayerOwner.Pawn == None || PlayerOwner.CurrentScreen != None)
        return;
    if (P2GameInfo(PlayerOwner.Level.Game) != None
        && P2GameInfo(PlayerOwner.Level.Game).IsCinematic())
        return;
    SetupSelector(false, false);
    bMenuVisible = true;
    PauseGame();
    SortItemsIntoArray();
    class'LanCoopLog'.static.WriteEvent(Self, "InventoryOpen", "Items=" $ DisplayItems.Length);
}
