// Keep the campaign HUD; add names using replicated PlayerReplicationInfo.
class LanCoopHUD extends AWWrapHUD;

simulated event PostRender(Canvas C)
{
    local Pawn P;
    local vector Eye, Forward, Right, Up, LabelPosition, ScreenPosition;
    local float TextWidth, TextHeight;
    local rotator CameraRotation;

    Super.PostRender(C);
    if (PlayerOwner == None || PlayerOwner.Pawn == None || bHideHUD)
        return;
    C.GetCameraLocation(Eye, CameraRotation);
    GetAxes(CameraRotation, Forward, Right, Up);
    UseSmallFont(C);
    C.Style = ERenderStyle.STY_Normal;
    C.DrawColor = class'Canvas'.Static.MakeColor(255, 220, 100);
    foreach DynamicActors(class'Pawn', P)
    {
        if (P == PlayerOwner.Pawn || P == PlayerOwner.ViewTarget || P.bHidden
            || P.Health <= 0 || P.PlayerReplicationInfo == None
            || P.PlayerReplicationInfo.bIsSpectator
            || VSize(P.Location - Eye) > 3000
            || (Forward Dot (P.Location - Eye)) <= 0)
            continue;
        LabelPosition = P.Location;
        LabelPosition.Z += P.CollisionHeight + 20;
        if (!FastTrace(LabelPosition, Eye))
            continue;
        ScreenPosition = C.WorldToScreen(LabelPosition, Eye, CameraRotation);
        if (ScreenPosition.X < 0 || ScreenPosition.X > C.ClipX
            || ScreenPosition.Y < 0 || ScreenPosition.Y > C.ClipY)
            continue;
        C.StrLen(P.PlayerReplicationInfo.PlayerName, TextWidth, TextHeight);
        C.SetPos(ScreenPosition.X - TextWidth / 2, ScreenPosition.Y - TextHeight);
        C.DrawText(P.PlayerReplicationInfo.PlayerName, false);
    }
}
