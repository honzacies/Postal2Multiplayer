// Opt-in real-engine round-trip test. Never enabled by ordinary launchers.
class LanCoopTravelProbe extends Info config(LanCoopTravelProbe);

var int Attempts;
var bool bFinished;
var config bool bPassed, bFailed;
var config int LastCheckedStage;
var int ReadyTicks;

event PostBeginPlay()
{
    Super.PostBeginPlay();
    if (LanCoopGameInfo(Level.Game).TravelProbeStage == 0)
    {
        bPassed = false;
        bFailed = false;
        LastCheckedStage = -1;
        SaveConfig();
    }
    SetTimer(0.5, true);
}

event Timer()
{
    local LanCoopGameInfo G;
    local Controller C;
    local LanCoopPlayer Host, Guest;
    local MoneyInv HostMoney, GuestMoney;
    local Weapon HostGun, GuestGun;
    local Telepad Pad, ExitPad;
    local string WantedMap;

    if (bFinished)
        return;
    G = LanCoopGameInfo(Level.Game);
    if (G == None)
        return;
    for (C = Level.ControllerList; C != None; C = C.NextController)
        if (LanCoopPlayer(C) != None && C.PlayerReplicationInfo != None)
        {
            if (C.PlayerReplicationInfo.PlayerName == "Dude")
                Host = LanCoopPlayer(C);
            else if (C.PlayerReplicationInfo.PlayerName == "Guest")
                Guest = LanCoopPlayer(C);
        }
    if (!G.bWorldPrepared || Host == None || Guest == None || Host.Pawn == None || Guest.Pawn == None
        || !G.AllPlayersReady())
    {
        if (Attempts++ > 240)
        {
            class'LanCoopLog'.static.WriteEvent(Self, "TravelProbeFailed", "Timeout Stage=" $ G.TravelProbeStage);
            bFinished = true;
            bFailed = true;
            SaveConfig();
        }
        return;
    }
    if (ReadyTicks++ < 3)
        return;
    if (Host.MyPawn.MyFoot == None || Guest.MyPawn.MyFoot == None)
    {
        class'LanCoopLog'.static.WriteEvent(Self, "TravelProbeFailed", "Foot missing after travel");
        bFailed = true;
        bFinished = true;
        SaveConfig();
        return;
    }
    Host.ClientProbeCombat();
    Guest.ClientProbeCombat();
    HostMoney = MoneyInv(Host.Pawn.FindInventoryType(class'MoneyInv'));
    GuestMoney = MoneyInv(Guest.Pawn.FindInventoryType(class'MoneyInv'));
    if (G.TravelProbeStage == 0)
    {
        Host.bGodMode = true;
        Guest.bGodMode = true;
        Host.Pawn.Health = 81;
        Guest.Pawn.Health = 64;
        HostMoney.Amount = 111;
        GuestMoney.Amount = 222;
        HostGun = Weapon(P2Pawn(Host.Pawn).CreateInventoryByClass(class'Inventory.PistolWeapon'));
        GuestGun = Weapon(P2Pawn(Guest.Pawn).CreateInventoryByClass(class'Inventory.PistolWeapon'));
        if (HostGun == None || GuestGun == None || HostGun.AmmoType == None || GuestGun.AmmoType == None)
        {
            class'LanCoopLog'.static.WriteEvent(Self, "TravelProbeFailed", "Cannot seed weapons");
            bFailed = true;
            bFinished = true;
            SaveConfig();
            return;
        }
        HostGun.AmmoType.AmmoAmount = 13;
        GuestGun.AmmoType.AmmoAmount = 29;
        P2Pawn(Host.Pawn).Armor = 17;
        P2Pawn(Guest.Pawn).Armor = 36;
        Host.ServerSetAppearance("MultiStuff.MpDude");
        Guest.ServerSetAppearance("MultiStuff.MpBandmember");
        G.TheGameState.bNiceDude = true;
        Host.ClientProbeInventory();
        Guest.ClientProbeInventory();
        class'LanCoopLog'.static.WriteEvent(Self, "TravelProbeSeeded", "HostMoney=111 GuestMoney=222 HostHealth=81 GuestHealth=64");
    }
    else
    {
        HostGun = Weapon(Host.Pawn.FindInventoryType(class'Inventory.PistolWeapon'));
        GuestGun = Weapon(Guest.Pawn.FindInventoryType(class'Inventory.PistolWeapon'));
        if (HostMoney == None || GuestMoney == None || HostMoney.Amount != 111 || GuestMoney.Amount != 222
            || Host.Pawn.Health != 81 || Guest.Pawn.Health != 64
            || !G.TheGameState.bNiceDude
            || LanCoopPawn(Host.Pawn).CoopAppearance != class'MultiStuff.MpDude'
            || LanCoopPawn(Guest.Pawn).CoopAppearance != class'MultiStuff.MpBandmember'
            || HostGun == None || GuestGun == None || HostGun.AmmoType == None || GuestGun.AmmoType == None
            || HostGun.AmmoType.AmmoAmount != 13 || GuestGun.AmmoType.AmmoAmount != 29
            || P2Pawn(Host.Pawn).Armor != 17 || P2Pawn(Guest.Pawn).Armor != 36)
        {
            class'LanCoopLog'.static.WriteEvent(Self, "TravelProbeFailed", "State Stage=" $ G.TravelProbeStage $ " HostMoney=" $ HostMoney $ " GuestMoney=" $ GuestMoney $ " HostHealth=" $ Host.Pawn.Health $ " GuestHealth=" $ Guest.Pawn.Health);
            bFinished = true;
            bFailed = true;
            SaveConfig();
            return;
        }
        class'LanCoopLog'.static.WriteEvent(Self, "TravelProbeCheckOk", "Stage=" $ G.TravelProbeStage $ " Map=" $ Level.GetLocalURL());
        LastCheckedStage = G.TravelProbeStage;
        SaveConfig();
    }
    bFinished = true;
    if (G.TravelProbeStage >= 2)
    {
        class'LanCoopLog'.static.WriteEvent(Self, "TravelRoundtripOk", "SeparateInventoriesHealthNamesAppearanceAndSharedState");
        bPassed = true;
        SaveConfig();
        return;
    }
    if (G.TravelProbeStage == 0)
        WantedMap = "SUBURBS-2";
    else
        WantedMap = "SUBURBS-3";
    foreach AllActors(class'Telepad', Pad)
        if (Pad.bEnabled && InStr(Caps(Pad.URL), WantedMap) >= 0)
        {
            ExitPad = Pad;
            break;
        }
    if (ExitPad != None)
    {
        class'LanCoopLog'.static.WriteEvent(Self, "TravelProbeTelepad", "Tag=" $ ExitPad.Tag $ " URL=" $ ExitPad.URL);
        ExitPad.Touch(Host.Pawn);
    }
    else
    {
        class'LanCoopLog'.static.WriteEvent(Self, "TravelProbeDirect", "No matching telepad for " $ WantedMap);
        G.SendPlayerTo(Host, WantedMap);
    }
}

defaultproperties
{
    RemoteRole=ROLE_None
}
