class LanCoopHead extends AWDudeHead;

var class<xMpPawn> AppliedHeadAppearance;
var bool bHeadAppearanceInitialized;

// AW Dude uses an alpha material in slot 0 and its face in slot 1. Most
// selectable MP heads have only slot 0; keeping AW's slot layout hides them.
simulated function Setup(Mesh NewMesh, Material NewSkin, Vector NewScale, byte NewAmbientGlow)
{
    if (NewMesh == class'GameTypes.AWPostalDude'.Default.ExpectedHeadMesh)
    {
        HeadSkinIndex = 1;
        Skins.Length = 3;
        Skins[0] = class'BasePeople.AWDudeHead'.Default.Skins[0];
        Skins[2] = class'BasePeople.AWDudeHead'.Default.Skins[2];
    }
    else
    {
        HeadSkinIndex = 0;
        Skins.Length = 1;
    }
    Super.Setup(NewMesh, NewSkin, NewScale, NewAmbientGlow);
}

simulated function SyncPawnAppearance()
{
    local LanCoopPawn P;
    P = LanCoopPawn(Owner);
    if (P == None || (bHeadAppearanceInitialized && AppliedHeadAppearance == P.CoopAppearance))
        return;
    if (P.CoopAppearance != None)
        Setup(P.CoopAppearance.Default.HeadMesh, P.CoopAppearance.Default.HeadSkin, P.HeadScale, P.AmbientGlow);
    else
        Setup(P.HeadMesh, P.HeadSkin, P.HeadScale, P.AmbientGlow);
    AppliedHeadAppearance = P.CoopAppearance;
    bHeadAppearanceInitialized = true;
    class'LanCoopLog'.static.WriteEvent(Self, "HeadApplied", "NetMode=" $ Level.NetMode $ " Mesh=" $ Mesh $ " Slot=" $ HeadSkinIndex);
}

simulated function PostNetBeginPlay()
{
    Super.PostNetBeginPlay();
    SyncPawnAppearance();
}

simulated function Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);
    SyncPawnAppearance();
}
