// Reuse the stock menus; only replace Player Change's missing coop callback.
class LanCoopRootWindow extends ShellRootWindow;

var Texture CoopLoadingTexture;

function SetLoadingTexture(string MapName)
{
    if (CoopLoadingTexture != None)
        LoadingTexture = CoopLoadingTexture;
    else
        Super.SetLoadingTexture(MapName);
}

function BeginCoopLoading(Texture Background, string Destination)
{
    bLaunchedMultiplayer = true;
    CoopLoadingTexture = Background;
    SetLoadingTexture(Destination);
    HideMenu();
    ConsoleClose();
}

function EndCoopLoading()
{
    CoopLoadingTexture = None;
}

function CreateMenu(class<ShellMenuCW> MenuClass)
{
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
