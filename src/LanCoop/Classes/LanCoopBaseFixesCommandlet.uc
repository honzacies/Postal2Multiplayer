// Engine-side capability check. Export presence is not a bytecode equivalence
// claim; behavioural verification and clean-install comparison are separate.
class LanCoopBaseFixesCommandlet extends Commandlet;

var string RequiredFunctions[12];

function int Main(string Parms)
{
    local Object Capability;
    local int I, Missing;
    for (I = 0; I < ArrayCount(RequiredFunctions); I++)
    {
        Capability = DynamicLoadObject(RequiredFunctions[I], class'Object', true);
        if (Capability == None || !Capability.IsA('Function'))
        {
            Missing++;
            Log("BaseFixMissing Function=" $ RequiredFunctions[I]);
        }
        else
            Log("BaseFixPresent Function=" $ Capability $ " Owner=" $ Capability.Outer);
    }
    if (FindObject("NicksCoop", class'Object') != None
        || FindObject("Postal2CoOp", class'Object') != None)
    {
        Log("BaseFixAuditFailed StandaloneCoopPackageLoaded=true");
        return 2;
    }
    if (Missing != 0)
    {
        Log("BaseFixAuditFailed Missing=" $ Missing);
        return 1;
    }
    Log("BaseFixAuditOk Functions=" $ ArrayCount(RequiredFunctions) $ " NicksCoopLoaded=false");
    return 0;
}

defaultproperties
{
    RequiredFunctions(0)="Postal2Game.P2Player.CheckPlayerValid"
    RequiredFunctions(1)="Postal2Game.P2Player.NotifyPlayerValid"
    RequiredFunctions(2)="Postal2Game.P2Player.ClientSetupSubtitles"
    RequiredFunctions(3)="Postal2Game.P2Player.ClientSwitchToHands"
    RequiredFunctions(4)="Postal2Game.P2Player.ServerOnSelectedItem"
    RequiredFunctions(5)="Postal2Game.P2Player.ChangeAllWeaponHandTextures"
    RequiredFunctions(6)="Postal2Game.P2Weapon.ClientInventoryAdded"
    RequiredFunctions(7)="Postal2Game.P2Weapon.ClientInventoryDeleted"
    RequiredFunctions(8)="Postal2Game.P2Weapon.NotDedOnServer"
    RequiredFunctions(9)="Postal2Game.P2GameInfo.NotifyPickupDropped"
    RequiredFunctions(10)="Postal2Game.P2Pawn.AddInventory"
    RequiredFunctions(11)="Postal2Game.P2Pawn.DeleteInventory"
    LogToStdout=true
    IsClient=false
    IsEditor=false
    ShowErrorCount=true
}
