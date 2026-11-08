// A tagged proxy for an original wait-for-trigger script. Keep the native
// script actions and lifecycle while retaining the human participant separately.
class LanCoopContextTrigger extends ScriptedTrigger;
var array<P2Player> PendingParticipants;

function Trigger(Actor Other, Pawn EventInstigator)
{
    local LanCoopGameInfo G;
    local P2Player Participant;
    G = LanCoopGameInfo(Level.Game);
    if (G == None || !bWaitForTrigger)
        return;
    Participant = G.ActiveQuestPlayer;
    if (Participant == None)
        Participant = G.PlayerForCoopPawn(EventInstigator);
    PendingParticipants[PendingParticipants.Length] = Participant;
    Super.Trigger(Other, EventInstigator);
}

function GameInfoIsNowValid()
{
    while (PendingParticipants.Length > 0)
        StartUp();
}

function StartUp()
{
    local LanCoopGameInfo G;
    local P2Player Participant, Previous;
    local ScriptedController C;
    local array<ScriptedController> Before;
    local int I;
    local bool bKnown;
    G = LanCoopGameInfo(Level.Game);
    if (G == None || PendingParticipants.Length == 0)
        return;
    Participant = PendingParticipants[0];
    PendingParticipants.Remove(0, 1);
    foreach DynamicActors(class'ScriptedController', C)
        Before[Before.Length] = C;
    Previous = G.ActiveQuestPlayer;
    G.ActiveQuestPlayer = Participant;
    Super.StartUp();
    foreach DynamicActors(class'ScriptedController', C)
    {
        bKnown = false;
        for (I = 0; I < Before.Length; I++)
            if (Before[I] == C)
                bKnown = true;
        if (!bKnown && Participant != None)
            G.BindCoopScript(C, Participant);
    }
    G.ActiveQuestPlayer = Previous;
    class'LanCoopLog'.static.WriteEvent(Self, "TriggerPlayerContext", "Tag=" $ Tag $ " Player=" $ Participant);
}

defaultproperties
{
    bStatic=false
    bNoDelete=false
    bWaitForTrigger=true
    RemoteRole=ROLE_None
}
