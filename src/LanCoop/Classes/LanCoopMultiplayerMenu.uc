class LanCoopMultiplayerMenu extends ShellMenuCW;

var ShellMenuChoice HostChoice, JoinChoice, PlayerChoice;

function CreateMenuContents()
{
    Super.CreateMenuContents();
    AddTitle("Multiplayer", TitleFont, TA_Left);
    HostChoice = AddChoice("Host Game", "Start a LAN cooperative campaign.", ItemFont, TA_Left);
    JoinChoice = AddChoice("Join Game", "Find cooperative games on your LAN.", ItemFont, TA_Left);
    PlayerChoice = AddChoice("Player Change", "Choose your name and appearance.", ItemFont, TA_Left);
    BackChoice = AddChoice(BackText, "", ItemFont, TA_Left, true);
}

function Notify(UWindowDialogControl C, byte E)
{
    Super.Notify(C, E);
    if (E != DE_Click)
        return;
    if (C == HostChoice)
        GotoMenu(class'LanCoopHostMenu');
    else if (C == JoinChoice)
        GotoMenu(class'LanCoopJoinMenu');
    else if (C == PlayerChoice)
        GotoMenu(class'LanCoopMenuPlayer');
    else if (C == BackChoice)
        GoBack();
}
