// Reuse the stock menus; only replace Player Change's missing coop callback.
class LanCoopRootWindow extends ShellRootWindow;

var Texture CoopLoadingTexture;
var bool bCoopLoading;

function SetLoadingTexture(string MapName)
{
    if (CoopLoadingTexture != None)
        LoadingTexture = CoopLoadingTexture;
    else
        Super.SetLoadingTexture(MapName);
}

function BeginCoopLoading(Texture Background, string Destination)
{
    bCoopLoading = true;
    bLaunchedMultiplayer = true;
    CoopLoadingTexture = Background;
    SetLoadingTexture(Destination);
    HideMenu();
    ConsoleClose();
    DisableMenu();
}

function EndCoopLoading()
{
    if (bCoopLoading)
    {
        HideMenu();
        ConsoleClose();
        EnableMenu();
    }
    bCoopLoading = false;
    CoopLoadingTexture = None;
}

function ShowMenu()
{
    // Entry's temporary player is a loading camera, not a game spectator.
    // Network progress callbacks must not expose its menus during travel.
    if (!bCoopLoading)
        Super.ShowMenu();
}

function GoToConnectingWindow(string Msg1, string Msg2, bool bDownloading)
{
    if (bCoopLoading)
        return;
    Super.GoToConnectingWindow(Msg1, Msg2, bDownloading);
}

function GoToErrorWindow(string Msg1, string Msg2, optional bool bLock)
{
    class'LanCoopLog'.static.WriteEvent(Self, "ConnectionError", "Message=" $ Msg1 $ " Detail=" $ Msg2);
    // A failed connection must remain actionable, not hidden by the overlay.
    EndCoopLoading();
    Super.GoToErrorWindow(Msg1, Msg2, bLock);
}

function PostRender(Canvas C)
{
    if (!bCoopLoading)
    {
        Super.PostRender(C);
        return;
    }
    // Cover Entry and its temporary camera until the pawn's arrival ack.
    // Native disk loading/progress continues underneath; no menu widgets.
    C.Style = 1;
    C.SetDrawColor(255, 255, 255, 255);
    C.SetPos(0, 0);
    if (LoadingTexture != None)
        C.DrawTile(LoadingTexture, C.ClipX, C.ClipY, 0, 0, LoadingTexture.USize, LoadingTexture.VSize);
    DrawStatusMessage(C, LoadingMessage);
}

function CreateMenu(class<ShellMenuCW> MenuClass)
{
    if (bCoopLoading && (MenuClass == class'Shell.MenuMain'
        || MenuClass == class'Shell.MenuConnecting' || MenuClass == class'Shell.MenuGame'
        || MenuClass == class'Shell.MenuGameMulti'))
        return;
    if (MenuClass == class'Shell.MenuMain')
        MenuClass = class'LanCoopMainMenu';
    if (MenuClass == class'Shell.MenuMulti')
        MenuClass = class'LanCoopMultiplayerMenu';
    if (MenuClass == class'Shell.MenuPlayer')
        MenuClass = class'LanCoopMenuPlayer';
    // A listen host has a campaign GameInfo and the stock shell therefore
    // chooses the SP pause menu, which contains no Player Change entry.
    if (MenuClass == class'Shell.MenuGame' && LanCoopPlayer(GetPlayerOwner()) != None)
        MenuClass = class'Shell.MenuGameMulti';
    Super.CreateMenu(MenuClass);
}
