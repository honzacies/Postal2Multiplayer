class LanCoopSessionSettings extends Object config(LanCoopSession);

var config int PlayerLimit, SpectatorLimit, Port;
var config int DifficultySelection;
var config string PlayerName;
var config bool bSkipIntro;
var config string ClientId, LastAddress;

static function string GetClientId()
{
    if (Default.ClientId == "")
    {
        Default.ClientId = string(Rand(1000000000)) $ "-" $ Rand(1000000000) $ "-" $ Rand(1000000000);
        StaticSaveConfig();
    }
    return Default.ClientId;
}

defaultproperties
{
    PlayerLimit=2
    SpectatorLimit=2
    Port=7787
    PlayerName="Dude"
    bSkipIntro=true
    DifficultySelection=5
}
