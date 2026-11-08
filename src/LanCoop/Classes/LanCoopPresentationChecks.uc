// Server-side relationship checks. Rendering/relevancy still need LAN testing.
class LanCoopPresentationChecks extends Object;

static function bool Run(LanCoopGameInfo G, LanCoopPlayer Host, LanCoopPlayer Guest)
{
    local BoltonPart Part;
    local LanCoopAttachmentRelay Relay;
    local LanCoopAuthorityMutator M;
    local string GuestName;
    local int I, Bindings;
    local bool Passed;
    Passed = class'LanCoopPlayer'.static.CoopSpeakerName(Host.Pawn) == Host.PlayerReplicationInfo.PlayerName
        && class'LanCoopPlayer'.static.CoopSpeakerName(Guest.Pawn) == Guest.PlayerReplicationInfo.PlayerName;
    Part = G.Spawn(class'BoltonPart', Guest.Pawn);
    Passed = Passed && class'LanCoopAttachmentGuard'.static.IsOrphan(Part)
        && class'LanCoopPlayer'.static.CoopSpeakerName(Part) == Guest.PlayerReplicationInfo.PlayerName;
    GuestName = Guest.PlayerReplicationInfo.PlayerName;
    Guest.PlayerReplicationInfo.PlayerName = "RenamedGuest";
    Passed = Passed && class'LanCoopPlayer'.static.CoopSpeakerName(Part) == "RenamedGuest";
    Guest.PlayerReplicationInfo.PlayerName = GuestName;
    Part.SetBase(Guest.Pawn);
    Passed = Passed && !class'LanCoopAttachmentGuard'.static.IsOrphan(Part);
    Part.SetBase(None);
    Part.SetPhysics(PHYS_Falling);
    Passed = Passed && !class'LanCoopAttachmentGuard'.static.IsOrphan(Part);
    Part.Destroy();
    foreach G.DynamicActors(class'LanCoopAuthorityMutator', M)
        M.UpdateAttachmentBindings();
    foreach G.DynamicActors(class'LanCoopAttachmentRelay', Relay)
        for (I = 0; I < 9; I++)
            if (Relay.Parts[I] != None)
            {
                Bindings++;
                Passed = Passed && Relay.Parts[I].Owner == Relay.SourcePawn
                    && Relay.Parents[I] == Relay.Parts[I].Base
                    && Relay.Bones[I] == Relay.Parts[I].AttachmentBone;
            }
    Passed = Passed && Bindings > 0 && class'LanCoopPlayer'.static.CoopSpeakerName(G) == "";
    if (Passed)
        class'LanCoopLog'.static.WriteEvent(G, "PresentationChecksOk", "SpeakerIdentity Rename OrphanHide DroppedPartPreserved Bindings=" $ Bindings);
    return Passed;
}
