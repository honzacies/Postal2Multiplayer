class LanCoopCheckCommandlet extends Commandlet;

function int Main(string Parms)
{
    local class<GameInfo> Probe;
    local class<LanCoopGameInfo> Campaign;

    Probe = class<GameInfo>(DynamicLoadObject("LanCoop.LanCoopProbeGame", class'Class'));
    if (Probe == None)
    {
        class'LanCoopLog'.static.WriteEvent(Self, "CheckFailed", ": Cannot load probe GameInfo");
        return 1;
    }
    if (Probe.Default.MaxPlayers != 2)
    {
        class'LanCoopLog'.static.WriteEvent(Self, "CheckFailed", ": Unexpected MaxPlayers");
        return 2;
    }
    class'LanCoopLog'.static.WriteEvent(Self, "CheckOk", "Class=" $ Probe $ " MaxPlayers=" $ Probe.Default.MaxPlayers);
    Campaign = class<LanCoopGameInfo>(DynamicLoadObject("LanCoop.LanCoopGameInfo", class'Class'));
    if (Campaign == None || Campaign.Default.Days.Length != 7
        || Campaign.Default.MaxPlayers != 2
        || Campaign.Default.PlayerControllerClassName != "LanCoop.LanCoopPlayer")
    {
        class'LanCoopLog'.static.WriteEvent(Self, "CheckFailed", ": Campaign class configuration");
        return 3;
    }
    class'LanCoopLog'.static.WriteEvent(Self, "CampaignCheckOk", "Days=" $ Campaign.Default.Days.Length);
    return 0;
}

defaultproperties
{
    LogToStdout=true
    IsClient=false
    IsEditor=false
    ShowErrorCount=true
}
