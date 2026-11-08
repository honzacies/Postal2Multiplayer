class LanCoopMainMenu extends MenuMain;

function CreateMenuContents()
{
    bShowMP = true;
    Super.CreateMenuContents();
}

defaultproperties
{
    bShowMP=true
    MultiText="Multiplayer"
    MultiHelp="Host a cooperative campaign or find a game on your LAN."
}
