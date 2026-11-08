// Keep the campaign HUD; add names using replicated PlayerReplicationInfo.
class LanCoopHUD extends AWWrapHUD;

// Original wanted icon/bar layout, including the base HUD coordinate fix;
// the value now comes from the owning player's replicated state.
simulated function DrawPlayerWantedStatus(Canvas C, float Scale)
{
    local LanCoopPlayer P;
    local Texture Icon, Bar;
    local float X, Y, Fraction, Width;
    local P2Weapon W;
    local string Hint1, Hint2;
    P = LanCoopPlayer(PlayerOwner);
    if (P == None || PawnOwner == None)
        return;
    Icon = Texture(WantedIcon);
    Bar = Texture(WantedBar);
    if (Icon == None || Bar == None)
        return;
    Fraction = FClamp(P.CoopWantedPercent, 0, 1);
    X = IconPos[WantedIndex].X * C.ClipX - Scale * Icon.USize / 2;
    Y = IconPos[WantedIndex].Y * CanvasHeight - Scale * Icon.VSize / 2;
    C.Style = ERenderStyle.STY_Masked;
    C.DrawColor = DefaultIconColor;
    if (Fraction > 0)
    {
        C.SetPos(X, Y);
        C.DrawIcon(Icon, Scale);
        Width = Fraction * HUD_WANTED_BAR_SCALE_WIDTH * Icon.USize;
        C.SetPos(X + Icon.USize * Scale * HUD_WANTED_BAR_OFF_X,
            Y + Icon.VSize * Scale * HUD_WANTED_BAR_OFF_Y);
        C.DrawTile(Bar, Scale * Width, Scale * Bar.VSize, 0, 0, Bar.USize, Bar.VSize);
    }
    W = P2Weapon(PawnOwner.Weapon);
    if (W != None && W.GetCopHints(Hint1, Hint2))
    {
        if (Hint1 != "")
            MyFont.DrawTextEx(C, CanvasWidth, X + Scale * Icon.USize / HUD_N_HINT_ALIGN_X,
                (IconPos[WantedIndex].Y + WantedTextPos[0].Y) * CanvasHeight, Hint1, 0, true, EJ_Right);
        if (Hint2 != "")
            MyFont.DrawTextEx(C, CanvasWidth, X + Scale * Icon.USize / HUD_N_HINT_ALIGN_X,
                (IconPos[WantedIndex].Y + WantedTextPos[1].Y) * CanvasHeight, Hint2, 0, true, EJ_Right);
    }
}

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
