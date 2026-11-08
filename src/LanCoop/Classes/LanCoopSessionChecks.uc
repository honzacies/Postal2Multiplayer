class LanCoopSessionChecks extends Object;

static function bool Run(LanCoopGameInfo G, LanCoopPlayer Host, LanCoopPlayer Guest)
{
    local LanCoopReconnectStore Store;
    local P2PowerupInv Money;
    local Inventory HostInventory;
    local bool Passed, ExpectedTravel;
    local vector SavedPosition;
    local string Session;
    HostInventory = Host.Pawn.Inventory;
    Guest.ServerSetCoopNewsReading(false);
    P2Pawn(Guest.Pawn).CreateInventoryByClass(class'Inventory.MapInv');
    Guest.ServerRequestCoopMapScreen();
    Passed = Guest.LastCoopMapTexture == G.GetCurrentDayBase().GetMapTexture()
        && Host.LastCoopMapTexture == None && Guest.LastCoopMapIconCount >= 3;
    P2Pawn(Host.Pawn).CreateInventoryByClass(class'Inventory.MapInv');
    Host.ServerRequestCoopMapScreen();
    Passed = Passed && Host.LastCoopMapTexture == Guest.LastCoopMapTexture
        && Host.LastCoopMapIconCount == Guest.LastCoopMapIconCount;
    Store = new(None) class'LanCoopReconnectStore';
    class'LanCoopLog'.static.WriteEvent(G, "SessionProbeStage", "StoreCreated");
    Store.Players.Length = 0;
    Store.Items.Length = 0;
    Guest.CoopReconnectId = "IsolatedReconnectFixture";
    Money = P2PowerupInv(P2Pawn(Guest.Pawn).CreateInventoryByClass(class'Inventory.MoneyInv'));
    Money.Amount = 37;
    Money.Tainted = 1;
    Guest.Pawn.Health = 87;
    LanCoopPawn(Guest.Pawn).Armor = 23;
    LanCoopPawn(Guest.Pawn).CoopWantedTime = 17;
    SavedPosition = Guest.Pawn.Location;
    class'LanCoopLog'.static.WriteEvent(G, "SessionProbeStage", "BeforeCapture");
    Store.Capture(G, Guest);
    Store = new(None) class'LanCoopReconnectStore';
    class'LanCoopLog'.static.WriteEvent(G, "SessionProbeStage", "AfterCapture");
    Money.Amount = 2;
    Guest.Pawn.Health = 51;
    Session = G.CoopSessionId;
    G.CoopSessionId = "UnrelatedCampaign";
    Passed = Passed && !Store.Restore(G, Guest) && Money.Amount == 2;
    G.CoopSessionId = Session;
    ExpectedTravel = G.bExpectTravelState;
    G.bExpectTravelState = true;
    Passed = Store.Restore(G, Guest) && Passed;
    G.bExpectTravelState = ExpectedTravel;
    Money = P2PowerupInv(Guest.Pawn.FindInventoryType(class'Inventory.MoneyInv'));
    Passed = Passed && Money != None && Money.Amount == 37 && Money.Tainted == 1
        && Guest.Pawn.Health == 87 && LanCoopPawn(Guest.Pawn).Armor == 23
        && LanCoopPawn(Guest.Pawn).CoopWantedTime == 17
        && VSize(Guest.Pawn.Location - SavedPosition) < 1
        && Host.Pawn.Inventory == HostInventory && Store.Players.Length == 0;
    Guest.CoopReconnectId = "";
    if (Passed)
        class'LanCoopLog'.static.WriteEvent(G, "SessionChecksOk", "OwnerMap ReconnectInventory Amounts Health Wanted Position SessionIsolation");
    return Passed;
}
