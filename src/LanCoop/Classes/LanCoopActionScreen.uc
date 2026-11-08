// Resolve the event participant instead of the original first-player lookup.
class LanCoopActionScreen extends MoreGame.ACTION_P2Screen;

function P2Player GetPlayer(ScriptedController C)
{
    if (C == None || LanCoopGameInfo(C.Level.Game) == None)
        return None;
    return LanCoopGameInfo(C.Level.Game).ResolveCoopScriptPlayer(C, false);
}

function bool InitActionFor(ScriptedController C)
{
    local P2Player P;
    if (GetPlayer(C) == None)
        return false;
    P = GetPlayer(C);
    if (Screen == ENewsScreen)
    {
        P.DisplayNews();
        return false;
    }
    // Other native screens still need their own client presentation adapter.
    // Never run a remote player's screen interaction on the host by fallback.
    if (P.Player == None || P.Player.InteractionMaster == None)
    {
        class'LanCoopLog'.static.WriteEvent(C, "PersonalScreenPending", "Screen=" $ Screen $ " Player=" $ P);
        return false;
    }
    return Super.InitActionFor(C);
}
