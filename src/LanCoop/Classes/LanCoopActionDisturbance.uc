class LanCoopActionDisturbance extends MoreGame.ACTION_AIDisturbance;

function bool InitActionFor(ScriptedController C)
{
    local LanCoopGameInfo G;
    local P2Player Participant, Previous;
    local bool bResult;
    G = LanCoopGameInfo(C.Level.Game);
    if (G == None)
        return false;
    if (!bPlayerDidIt)
        return Super.InitActionFor(C);
    Participant = G.ResolveCoopScriptPlayer(C);
    if (Participant == None)
        return false;
    Previous = G.ActiveQuestPlayer;
    G.ActiveQuestPlayer = Participant;
    bResult = Super.InitActionFor(C);
    G.ActiveQuestPlayer = Previous;
    return bResult;
}
