// Isolated server fixture: native trigger execution, not a graphical LAN test.
class LanCoopEventRoutingChecks extends Object;

static function bool Run(LanCoopGameInfo G, LanCoopPlayer Host, LanCoopPlayer Guest)
{
    local LanCoopContextTrigger T;
    local ScriptedController Ambiguous;
    local ACTION_GiveInventoryToPlayer Give;
    local LanCoopActionTakeInventory Take;
    local LanCoopActionTrigger Forward;
    local Inventory HostPaper, GuestPaper;
    local bool Passed, WasValid;

    HostPaper = Host.Pawn.FindInventoryType(class'Inventory.NewspaperInv');
    GuestPaper = Guest.Pawn.FindInventoryType(class'Inventory.NewspaperInv');
    if (GuestPaper != None)
    {
        Guest.Pawn.DeleteInventory(GuestPaper);
        GuestPaper.Destroy();
    }
    T = G.Spawn(class'LanCoopContextTrigger');
    Give = new(T) class'AWPStuff.ACTION_GiveInventoryToPlayer';
    Give.InvType = class'Inventory.NewspaperInv';
    T.Actions.Length = 1;
    T.Actions[0] = class'LanCoopEventAdapters'.static.Adapt(T, Give);
    if (LanCoopActionGiveInventory(T.Actions[0]) == None)
        return false;
    // Original trigger startup executes its first action synchronously.
    T.Trigger(Guest.Pawn, Guest.Pawn);
    Passed = Guest.Pawn.FindInventoryType(class'Inventory.NewspaperInv') != None
        && Host.Pawn.FindInventoryType(class'Inventory.NewspaperInv') == HostPaper;
    Guest.ServerRequestCoopNews();
    Passed = Passed && Guest.bPendingCoopNews
        && Guest.PendingCoopNewsTexture == G.GetNewsTexture()
        && !Host.bPendingCoopNews;
    Guest.bPendingCoopNews = false;
    Guest.ServerSetCoopNewsReading(false);

    Ambiguous = G.Spawn(class'ScriptedController');
    Ambiguous.MyPlayerController = Host;
    Passed = Passed && G.ResolveCoopScriptPlayer(Ambiguous) == None;
    G.BindCoopScript(Ambiguous, Guest);
    Take = new(T) class'LanCoopActionTakeInventory';
    Take.InvType = class'Inventory.NewspaperInv';
    Take.InitActionFor(Ambiguous);
    Passed = Passed && Guest.Pawn.FindInventoryType(class'Inventory.NewspaperInv') == None
        && Host.Pawn.FindInventoryType(class'Inventory.NewspaperInv') == HostPaper;

    // The native NPC/actor instigator is distinct from the human participant.
    T.Tag = 'CoopEventRoutingFixture';
    Ambiguous.Instigator = Host.Pawn;
    Forward = new(T) class'LanCoopActionTrigger';
    Forward.Event = T.Tag;
    Forward.InitActionFor(Ambiguous);
    Passed = Passed && Guest.Pawn.FindInventoryType(class'Inventory.NewspaperInv') != None
        && Host.Pawn.FindInventoryType(class'Inventory.NewspaperInv') == HostPaper;
    Take.InitActionFor(Ambiguous);

    // Preserve the participant while native startup waits for game validity.
    WasValid = G.bIsValid;
    G.bIsValid = false;
    T.bRequiresValidGameInfo = true;
    T.Trigger(Guest.Pawn, Guest.Pawn);
    Passed = Passed && Guest.Pawn.FindInventoryType(class'Inventory.NewspaperInv') == None;
    G.bIsValid = WasValid;
    T.GameInfoIsNowValid();
    Passed = Passed && Guest.Pawn.FindInventoryType(class'Inventory.NewspaperInv') != None
        && Host.Pawn.FindInventoryType(class'Inventory.NewspaperInv') == HostPaper;
    Take.InitActionFor(Ambiguous);
    Ambiguous.Destroy();
    T.Destroy();
    if (Passed)
        class'LanCoopLog'.static.WriteEvent(G, "EventRoutingCheckOk", "GuestGrant NewsOwner Removal Chained Deferred NoHostGuess");
    return Passed;
}
