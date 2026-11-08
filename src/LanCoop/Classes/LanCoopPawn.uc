// Always retain the campaign pawn's behavior; selection changes appearance only.
class LanCoopPawn extends AWPostalDude;

var travel class<xMpPawn> CoopAppearance;
var class<xMpPawn> AppliedAppearance;
var travel bool bCoopTravelInventory;
var travel float CoopSavedArmorMax;
var travel class<Inventory> CoopSavedArmorClass;
var travel Texture CoopSavedArmorIcon;
var travel bool bCoopSavedGodMode;
var bool bCoopArrivalHandled;
var bool bCoopDayLoadoutApplied;
var bool bCoopArrivalPlaced;
var travel float CoopWantedTime;

function RestoreCombatReferences()
{
    if (Role != ROLE_Authority)
        return;
    // A foot is deliberately outside Inventory, so native travel omits it.
    if (MyFoot == None || MyFoot.bDeleteMe)
    {
        MyFoot = P2Weapon(CreateInventoryByClass(class'Inventory.FootWeapon'));
        if (MyFoot != None)
        {
            MyFoot.SetOwner(Self);
            MyFoot.Instigator = Self;
            MyFoot.bJustMade = false;
            MyFoot.GotoState('Idle');
        }
    }
    if (MyUrethra == None || MyUrethra.bDeleteMe)
        MyUrethra = P2Weapon(FindInventoryType(class'Inventory.UrethraWeapon'));
    if (MyFoot != None)
        ClientSetFoot(MyFoot);
    if (MyUrethra != None)
        ClientSetUrethra(UrethraWeapon(MyUrethra));
    PlayerStartingFinished();
    ClientPlayerStartingFinished();
}

function RecordCoopTravelData()
{
    local P2Player P;
    P = P2Player(Controller);
    bCoopTravelInventory = true;
    CoopSavedArmorMax = ArmorMax;
    if (P != None)
    {
        CoopSavedArmorClass = P.HudArmorClass;
        CoopSavedArmorIcon = P.HudArmorIcon;
        bCoopSavedGodMode = P.bGodMode;
    }
}

function RestoreCoopTravelData()
{
    local P2Player P;
    if (!bCoopTravelInventory)
        return;
    ArmorMax = CoopSavedArmorMax;
    P = P2Player(Controller);
    if (P != None)
    {
        P.HudArmorClass = CoopSavedArmorClass;
        P.HudArmorIcon = CoopSavedArmorIcon;
        P.bGodMode = bCoopSavedGodMode;
    }
}

event TravelPostAccept()
{
    Super.TravelPostAccept();
    if (Role == ROLE_Authority && LanCoopGameInfo(Level.Game) != None)
        LanCoopGameInfo(Level.Game).PostTravel(Self);
}

replication
{
    reliable if (Role == ROLE_Authority && bNetDirty)
        CoopAppearance;
}

function SetCoopAppearance(class<xMpPawn> NewAppearance)
{
    if (NewAppearance == None || NewAppearance.Default.Mesh == None
        || NewAppearance.Default.Skins[0] == None)
        return;
    CoopAppearance = NewAppearance;
    ApplyCoopAppearance();
    class'LanCoopLog'.static.WriteEvent(Self, "Appearance", "Player=" $ OwnerName $ " Class=" $ CoopAppearance $ " Mesh=" $ Mesh $ " Skin=" $ Skins[0]);
}

simulated function ApplyCoopAppearance()
{
    local Mesh Body;
    local rotator HeadRotation;
    local vector HeadOffset;
    if (CoopAppearance == None)
        return;
    Body = CoopAppearance.Default.CoreSPMesh;
    if (Body == None)
        Body = CoopAppearance.Default.Mesh;
    if (AppliedAppearance != CoopAppearance)
    {
        CoreSPMesh = Body;
        LinkMeshAndAnims(Body);
        SetMySkin(CoopAppearance.Default.Skins[0]);
        HeadMesh = CoopAppearance.Default.HeadMesh;
        HeadSkin = CoopAppearance.Default.HeadSkin;
        bShortSleeves = CoopAppearance.Default.bShortSleeves;
        AppliedAppearance = CoopAppearance;
        class'LanCoopLog'.static.WriteEvent(Self, "AppearanceApplied", "NetMode=" $ Level.NetMode $ " Pawn=" $ Self $ " Class=" $ CoopAppearance);
    }
    if (MyHead != None)
    {
        // Changing skeletal meshes can invalidate the existing attachment.
        AttachToBone(MyHead, BONE_HEAD);
        MyHead.Setup(HeadMesh, HeadSkin, HeadScale, AmbientGlow);
        HeadRotation.Yaw = -16384;
        HeadRotation.Roll = 16384;
        MyHead.SetRelativeRotation(HeadRotation);
        HeadOffset.X = ADJUST_RELATIVE_HEAD_X;
        HeadOffset.Y = ADJUST_RELATIVE_HEAD_Y;
        HeadOffset.Z = ADJUST_RELATIVE_HEAD_Z;
        MyHead.SetRelativeLocation(HeadOffset);
    }
}

simulated function PostNetBeginPlay()
{
    Super.PostNetBeginPlay();
    ApplyCoopAppearance();
}

simulated function Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);
    // This engine build has no script PostNetReceive/bNetNotify hook.
    if (CoopAppearance != AppliedAppearance)
        ApplyCoopAppearance();
}

defaultproperties
{
    HeadClass=class'LanCoopHead'
    // Telepad's NPC collector must never serialize the other human as an NPC.
    bCanTeleportWithPlayer=false
}
