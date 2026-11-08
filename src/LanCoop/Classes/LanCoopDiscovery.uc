// Small LAN-only discovery protocol. No public master server or account service.
class LanCoopDiscovery extends UdpLink;

var bool bAdvertising;
var LanCoopGameInfo ServerGame;
var LanCoopJoinMenu JoinMenu;
var int Attempts;
var string ServerId;

function StartServer(LanCoopGameInfo G)
{
    ServerGame = G;
    ServerId = string(Rand(2147483647)) $ "-" $ string(Rand(2147483647));
    bAdvertising = true;
    if (BindPort(17877, true) == 0)
        class'LanCoopLog'.static.WriteEvent(Self, "DiscoveryFailed", "Server bind");
    else
        class'LanCoopLog'.static.WriteEvent(Self, "DiscoveryAdvertising", "");
}

function StartSearch(LanCoopJoinMenu Menu)
{
    JoinMenu = Menu;
    if (BindPort() == 0)
    {
        JoinMenu.SetSearchStatus("Could not open LAN discovery.");
        return;
    }
    Search();
    SetTimer(1.0, true);
}

function Search()
{
    local IpAddr Address, LocalAddress;
    local int I;
    Address.Addr = BroadcastAddr;
    StringToIpAddr("127.0.0.1", LocalAddress);
    for (I = 0; I < 10; I++)
    {
        Address.Port = 17877 + I;
        LocalAddress.Port = Address.Port;
        SendText(Address, "P2COOP_DISCOVER_V2");
        SendText(LocalAddress, "P2COOP_DISCOVER_V2");
    }
}

event Timer()
{
    if (JoinMenu == None || Attempts++ >= 4)
    {
        SetTimer(0, false);
        if (JoinMenu != None)
            JoinMenu.SearchFinished();
        return;
    }
    Search();
}

function string TakePart(out string Text)
{
    local int I;
    local string Part;
    I = InStr(Text, "|");
    if (I < 0)
    {
        Part = Text;
        Text = "";
        return Part;
    }
    Part = Left(Text, I);
    Text = Mid(Text, I + 1);
    return Part;
}

event ReceivedText(IpAddr Address, string Text)
{
    local string Name, Host, Port, Players, Capacity, FoundId;
    if (bAdvertising)
    {
        if (Text != "P2COOP_DISCOVER_V2" || ServerGame == None || ServerGame.GameReplicationInfo == None)
            return;
        Name = ServerGame.GameReplicationInfo.ServerName;
        ReplaceText(Name, "|", "_");
        SendText(Address, "P2COOP_V2|" $ ServerGame.CoopGamePort $ "|" $ Left(Name, 80)
            $ "|" $ ServerGame.NumPlayers $ "|" $ ServerGame.MaxPlayers $ "|" $ ServerId);
    }
    else if (JoinMenu != None && Left(Text, 10) == "P2COOP_V2|")
    {
        Text = Mid(Text, 10);
        Port = TakePart(Text);
        Name = TakePart(Text);
        Players = TakePart(Text);
        Capacity = TakePart(Text);
        FoundId = TakePart(Text);
        if (int(Port) < 1 || int(Port) > 65535 || FoundId == "")
            return;
        Host = IpAddrToString(Address);
        Host = Left(Host, InStr(Host, ":"));
        JoinMenu.ServerFound(Host $ ":" $ Port, Name, Players $ "/" $ Capacity, FoundId);
    }
}

defaultproperties
{
    RemoteRole=ROLE_None
}
