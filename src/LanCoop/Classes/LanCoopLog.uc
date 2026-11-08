class LanCoopLog extends Object config(LanCoopDebug);

var config bool bVerbose;
var config bool bConsole;

static function WriteEvent(Object Context, string EventName, optional string Data)
{
    local Actor A;
    local PlayerController P;
    local UWindowWindow Window;
    local string Line;
    local string ConsoleLine;
    if (!Default.bVerbose)
        return;
    // Console stays readable; the file retains full diagnostic details.
    ConsoleLine = Left(EventName $ " " $ Data, 100);
    A = Actor(Context);
    if (A != None && A.Level != None)
        Data = "Time=" $ A.Level.TimeSeconds $ " NetMode=" $ A.Level.NetMode $ " Actor=" $ Context $ " " $ Data;
    else
        Data = "Context=" $ Context $ " " $ Data;
    Line = EventName $ " " $ Data;
    Log(Line, 'LanCoop');
    if (!Default.bConsole)
        return;
    if (A != None)
    {
        foreach A.DynamicActors(class'PlayerController', P)
            if (P.Player != None && NetConnection(P.Player) == None && P.Player.Console != None)
                P.Player.Console.Message(ConsoleLine, 0);
    }
    else
    {
        Window = UWindowWindow(Context);
        if (Window != None)
        {
            P = Window.GetPlayerOwner();
            if (P != None && P.Player != None && P.Player.Console != None)
                P.Player.Console.Message(ConsoleLine, 0);
        }
    }
}

defaultproperties
{
    bVerbose=true
    bConsole=true
}
