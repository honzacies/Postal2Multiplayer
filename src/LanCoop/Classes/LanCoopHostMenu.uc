class LanCoopHostMenu extends ShellMenuCW;

var UWindowEditControl NameEdit;
var UWindowComboControl PlayersCombo, SpectatorsCombo;
var UWindowCheckbox SkipIntroCheck, AutosaveCheck;
var ShellMenuChoice StartChoice;
var LanCoopSessionSettings Settings;

function CreateMenuContents()
{
    local int I;
    local P2GameInfoSingle Campaign;
    Super.CreateMenuContents();
    Settings = new(None) class'LanCoopSessionSettings';
    AddTitle("Host Game", TitleFont, TA_Left);
    ItemFont = F_FancyM;
    ItemHeight = 27;
    NameEdit = AddEditBox("Your name", "The LAN listing will use this name followed by 's game.", ItemFont);
    NameEdit.SetValue(Settings.PlayerName);
    Campaign = P2GameInfoSingle(GetPlayerOwner().Level.Game);
    DifficultyCombo = AddComboBox("Difficulty", "Choose an original campaign difficulty preset, including the special modes.", ItemFont);
    if (Campaign != None)
        for (I = 0; I < 16 && I < ArrayCount(Campaign.DifficultyNames); I++)
            DifficultyCombo.AddItem(Campaign.DifficultyNames[I], string(I));
    DifficultyCombo.SetSelectedIndex(Clamp(Settings.DifficultySelection, 0, 15));
    PlayersCombo = AddComboBox("Max players", "Includes the host. More than two players is experimental.", ItemFont);
    SpectatorsCombo = AddComboBox("Max spectators", "Spectators watch without controlling a character.", ItemFont);
    for (I = 1; I <= 16; I++)
        PlayersCombo.AddItem(string(I), string(I));
    for (I = 0; I <= 16; I++)
        SpectatorsCombo.AddItem(string(I), string(I));
    PlayersCombo.SetSelectedIndex(Clamp(Settings.PlayerLimit, 1, 16) - 1);
    SpectatorsCombo.SetSelectedIndex(Clamp(Settings.SpectatorLimit, 0, 16));
    SkipIntroCheck = AddCheckbox("Skip intro", "Start directly in the first campaign area.", ItemFont);
    SkipIntroCheck.SetValue(Settings.bSkipIntro);
    AutosaveCheck = AddCheckbox("Auto save (not available yet)", "Cooperative save/load is not implemented. Map travel preserves your inventory.", ItemFont);
    AutosaveCheck.SetValue(false);
    AutosaveCheck.bDisabled = true;
    ItemFont = F_FancyL;
    ItemHeight = 32;
    StartChoice = AddChoice("Host Game", "Launch the campaign and advertise it on the LAN.", ItemFont, TA_Left);
    BackChoice = AddChoice(BackText, "", ItemFont, TA_Left, true);
}

function Notify(UWindowDialogControl C, byte E)
{
    local string URL, Name;
    Super.Notify(C, E);
    if (E != DE_Click)
        return;
    if (C == BackChoice)
        GoBack();
    else if (C == StartChoice)
    {
        Name = Left(NameEdit.GetValue(), 20);
        ReplaceText(Name, " ", "_");
        ReplaceText(Name, "?", "_");
        ReplaceText(Name, "#", "_");
        ReplaceText(Name, "|", "_");
        if (Name == "")
            Name = "Dude";
        Settings.PlayerName = Name;
        Settings.PlayerLimit = int(PlayersCombo.GetValue2());
        Settings.SpectatorLimit = int(SpectatorsCombo.GetValue2());
        Settings.bSkipIntro = SkipIntroCheck.GetValue();
        Settings.DifficultySelection = int(DifficultyCombo.GetValue2());
        // Reuse the stock menu's mapping of preset to numeric AI difficulty
        // and its special-mode flags (POSTAL/Impossible/Ludicrous etc.).
        SetDiff();
        Settings.SaveConfig();
        GetPlayerOwner().UpdateURL("Name", Name, true);
        if (Settings.bSkipIntro)
            URL = "suburbs-3.fuk";
        else
            URL = "intro.fuk";
        URL = URL $ "?Game=LanCoop.LanCoopGameInfo?listen?Port=" $ Settings.Port
            $ "?Name=" $ Name $ "?MaxPlayers=" $ Settings.PlayerLimit $ "?MaxSpectators=" $ Settings.SpectatorLimit
            $ "?CoopId=" $ class'LanCoopSessionSettings'.static.GetClientId();
        Root.SetLoadingTexture(URL);
        class'LanCoopLog'.static.WriteEvent(Self, "HostRequested", "URL=" $ URL);
        ShellRootWindow(Root).HideMenu();
        GetPlayerOwner().ClientTravel(URL, TRAVEL_Absolute, false);
    }
}
