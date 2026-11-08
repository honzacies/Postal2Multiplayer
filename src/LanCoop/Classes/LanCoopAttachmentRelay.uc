// One small binding record per character. Stock boltons otherwise have no
// owning pawn and their parent/bone references can arrive out of order.
class LanCoopAttachmentRelay extends Info;

var P2MoCapPawn SourcePawn;
var PeoplePart Parts[9];
var Actor Parents[9];
var name Bones[9];
var byte HiddenParts[9];

replication
{
    reliable if (Role == ROLE_Authority && bNetDirty)
        SourcePawn, Parts, Parents, Bones, HiddenParts;
}

function ReadSlot(int I, PeoplePart Part)
{
    Parts[I] = Part;
    if (Part == None || Part.bDeleteMe)
    {
        Parents[I] = None;
        Bones[I] = '';
        return;
    }
    Part.SetOwner(SourcePawn);
    Part.RemoteRole = ROLE_SimulatedProxy;
    Parents[I] = Part.Base;
    Bones[I] = Part.AttachmentBone;
    if (Part.bHidden)
        HiddenParts[I] = 1;
    else
        HiddenParts[I] = 0;
}

event Timer()
{
    local int I;
    if (SourcePawn == None || SourcePawn.bDeleteMe)
    {
        Destroy();
        return;
    }
    for (I = 0; I < 8; I++)
        ReadSlot(I, SourcePawn.Boltons[I].Part);
    ReadSlot(8, SourcePawn.TempBolton.Part);
}

simulated function Tick(float DeltaTime)
{
    local int I;
    if (Role == ROLE_Authority)
        return;
    for (I = 0; I < 9; I++)
        if (Parts[I] != None && !Parts[I].bDeleteMe && Parts[I].Physics == PHYS_None)
        {
            if (SourcePawn == None || Parents[I] == None || Parents[I].bDeleteMe)
                Parts[I].bHidden = true;
            else
            {
                if ((Parts[I].Base != Parents[I] || Parts[I].AttachmentBone != Bones[I])
                    && Bones[I] != '')
                    Parents[I].AttachToBone(Parts[I], Bones[I]);
                Parts[I].bHidden = HiddenParts[I] != 0 || SourcePawn.bHidden || Parents[I].bHidden;
            }
        }
}

defaultproperties
{
    RemoteRole=ROLE_SimulatedProxy
    bAlwaysRelevant=true
    bReplicateMovement=false
    NetUpdateFrequency=2
}
