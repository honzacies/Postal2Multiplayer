class LanCoopMainMenu extends MenuMain;

// Stock icons are Root children and can outlive the hidden main menu,
// leaving advertisements over the client's connection/loading screen.
function AddSocialIcons() {}

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
