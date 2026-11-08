// Visual-only: fluid collision and quest credit remain on the server.
class LanCoopUrineVisual extends UrineStreamMP;

simulated function Tick(float DeltaTime)
{
    local LanCoopPawn P;
    local rotator Aim;
    P = LanCoopPawn(Owner);
    if (P == None || P.bDeleteMe || !P.bCoopPeeing)
    {
        Destroy();
        return;
    }
    Aim = P.Rotation;
    Aim.Pitch = P.ViewPitch * 256;
    SetLocation(P.Location + vect(0,0,-12) + vector(P.Rotation) * 12);
    SetDir(Location, vector(Aim));
}

defaultproperties
{
    RemoteRole=ROLE_None
}
