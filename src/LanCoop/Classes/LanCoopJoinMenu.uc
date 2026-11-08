class LanCoopJoinMenu extends ShellMenuCW;

var UWindowComboControl GamesCombo;
var UWindowEditControl AddressEdit;
var UWindowCheckbox SpectateCheck;
var ShellMenuChoice JoinChoice, RefreshChoice, StatusChoice;
var LanCoopDiscovery SearchLink;
var array<string> FoundAddresses;
var array<string> FoundServerIds;

function CreateMenuContents()
{
    Super.CreateMenuContents();
    AddTitle("Join Game", TitleFont, TA_Left);
    ItemFont = F_FancyM;
    ItemHeight = 28;
    GamesCombo = AddComboBox("LAN games", "Select a game discovered on your local network.", ItemFont);
    AddressEdit = AddEditBox("Direct address", "Optional: enter an IP and port if broadcasts are blocked.", ItemFont);
    AddressEdit.SetValue(class'LanCoopSessionSettings'.Default.LastAddress);
    SpectateCheck = AddCheckbox("Join as spectator", "Uses a spectator slot instead of a player slot.", ItemFont);
    SpectateCheck.SetValue(false);
    StatusChoice = AddChoice("Searching LAN...", "", ItemFont, TA_Left);
    ItemFont = F_FancyL;
    ItemHeight = 32;
    RefreshChoice = AddChoice("Refresh", "Search the LAN again.", ItemFont, TA_Left);
    JoinChoice = AddChoice("Join Game", "Connect to the selected game or direct address.", ItemFont, TA_Left);
    BackChoice = AddChoice(BackText, "", ItemFont, TA_Left, true);
    StartSearch();
}

function StartSearch()
{
    if (SearchLink != None)
        SearchLink.Destroy();
    FoundAddresses.Length = 0;
    FoundServerIds.Length = 0;
    GamesCombo.Clear();
    SetSearchStatus("Searching LAN...");
    SearchLink = GetPlayerOwner().GetEntryLevel().Spawn(class'LanCoopDiscovery');
    if (SearchLink != None)
        SearchLink.StartSearch(Self);
}

function SetSearchStatus(string Status)
{
    if (StatusChoice != None)
        StatusChoice.SetText(Status);
}

function SearchFinished()
{
    if (FoundAddresses.Length == 0)
        SetSearchStatus("No LAN games found. Try Refresh or a direct address.");
    else
        SetSearchStatus(string(FoundAddresses.Length) $ " LAN game(s) found");
}

function ServerFound(string Address, string Name, string Players, string ServerId)
{
    local int I;
    for (I = 0; I < FoundAddresses.Length; I++)
        if (FoundAddresses[I] == Address || (ServerId != "" && FoundServerIds[I] == ServerId))
            return;
    FoundAddresses.Insert(FoundAddresses.Length, 1);
    FoundAddresses[FoundAddresses.Length - 1] = Address;
    FoundServerIds.Length = FoundAddresses.Length;
    FoundServerIds[FoundServerIds.Length - 1] = ServerId;
    GamesCombo.AddItem(Name $ " (" $ Players $ ")", Address);
    if (FoundAddresses.Length == 1)
        GamesCombo.SetSelectedIndex(0);
    SearchFinished();
    class'LanCoopLog'.static.WriteEvent(Self, "LanFound", "Name=" $ Name $ " Address=" $ Address);
}

function Notify(UWindowDialogControl C, byte E)
{
    local string Address, URL;
    Super.Notify(C, E);
    if (E != DE_Click)
        return;
    if (C == BackChoice)
        GoBack();
    else if (C == RefreshChoice)
        StartSearch();
    else if (C == JoinChoice)
    {
        Address = AddressEdit.GetValue();
        if (Address == "")
            Address = GamesCombo.GetValue2();
        if (Address == "" || InStr(Address, "?") >= 0 || InStr(Address, "#") >= 0 || InStr(Address, " ") >= 0)
        {
            SetSearchStatus("Select a LAN game or enter a valid address.");
            return;
        }
        class'LanCoopSessionSettings'.Default.LastAddress = Address;
        class'LanCoopSessionSettings'.static.StaticSaveConfig();
        URL = Address $ "?CoopId=" $ class'LanCoopSessionSettings'.static.GetClientId();
        if (SpectateCheck.GetValue())
            URL = URL $ "?SpectatorOnly=true";
        else
            URL = URL $ "?SpectatorOnly=false";
        ShellRootWindow(Root).bLaunchedMultiplayer = true;
        class'LanCoopLog'.static.WriteEvent(Self, "JoinRequested", "URL=" $ URL $ " Spectator=" $ SpectateCheck.GetValue());
        // Match the original browser's connection lifecycle, including
        // releasing its input window after initiating ClientTravel.
        Root.GoToConnectingWindow("Connecting", Address, false);
        GetPlayerOwner().ClientTravel(URL, TRAVEL_Absolute, false);
        Root.ConsoleClose();
    }
}

function OnCleanUp()
{
    if (SearchLink != None)
    {
        SearchLink.JoinMenu = None;
        SearchLink.Destroy();
        SearchLink = None;
    }
    Super.OnCleanUp();
}
