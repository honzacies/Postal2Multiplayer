class LanCoopActionTrigger extends FPSGame.ACTION_TriggerEvent;

function bool InitActionFor(ScriptedController C)
{
    if (C != None && LanCoopGameInfo(C.Level.Game) != None)
        LanCoopGameInfo(C.Level.Game).DispatchCoopScriptEvent(C, Event);
    return false;
}
