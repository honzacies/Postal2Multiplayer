// Client-only visibility guard. Never deletes drops or edits inventory.
class LanCoopAttachmentGuard extends Info;

var array<Actor> HiddenOrphans;

static simulated function bool IsOrphan(Actor Part)
{
    if (Part == None || Part.bDeleteMe || Part.Physics != PHYS_None)
        return false;
    if (BoltonPart(Part) == None && InventoryAttachment(Part) == None)
        return false;
    return Part.Base == None || Part.Base.bDeleteMe;
}

simulated event PostBeginPlay()
{
    SetTimer(0.25, true);
}

simulated event Timer()
{
    local Actor Part;
    local int I;
    // Restore only visibility that this guard changed itself.
    for (I = HiddenOrphans.Length - 1; I >= 0; I--)
        if (HiddenOrphans[I] == None || HiddenOrphans[I].bDeleteMe)
            HiddenOrphans.Remove(I, 1);
        else if (!IsOrphan(HiddenOrphans[I]))
        {
            HiddenOrphans[I].bHidden = false;
            HiddenOrphans.Remove(I, 1);
        }
    foreach DynamicActors(class'Actor', Part)
        if (!Part.bHidden && IsOrphan(Part))
        {
            HiddenOrphans[HiddenOrphans.Length] = Part;
            Part.bHidden = true;
        }
}

defaultproperties
{
    RemoteRole=ROLE_None
}
