class LanCoopSessionSettings extends Object config(LanCoopSession);

var config int PlayerLimit, SpectatorLimit, Port;
var config string PlayerName;
var config bool bSkipIntro;

defaultproperties
{
    PlayerLimit=2
    SpectatorLimit=2
    Port=7777
    PlayerName="Dude"
    bSkipIntro=true
}
