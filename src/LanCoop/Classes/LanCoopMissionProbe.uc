// Event-level regression tests, not a claim of complete campaign playthroughs.
class LanCoopMissionProbe extends Info config(LanCoopMissionProbe);

var LanCoopPlayer TestPlayers[2];
var int DayIndex, ErrandIndex, GoalIndex, PlayerIndex;
var bool bPlayersCreated;
var config bool bFinished;
var config int Passed, Failed, Skipped;

event PostBeginPlay()
{
    Super.PostBeginPlay();
    bFinished = false;
    Passed = 0;
    Failed = 0;
    Skipped = 0;
    SaveConfig();
    SetTimer(0.1, true);
}

function class<Actor> ResolveClass(string ClassName)
{
    local class<Actor> Result;
    if (InStr(ClassName, ".") >= 0)
        return class<Actor>(DynamicLoadObject(ClassName, class'Class', true));
    Result = class<Actor>(DynamicLoadObject("Inventory." $ ClassName, class'Class', true));
    if (Result == None)
        Result = class<Actor>(DynamicLoadObject("AWInventory." $ ClassName, class'Class', true));
    if (Result == None)
        Result = class<Actor>(DynamicLoadObject("AWPStuff." $ ClassName, class'Class', true));
    return Result;
}

function bool MakeFixture(ErrandGoal Goal, P2Player P, out Actor Other, out Actor Another, out Pawn ActionPawn)
{
    local class<Actor> ItemClass;
    local LanCoopMissionPawn NPC;
    local LanCoopMissionPickup Pick;
    local Weapon W;
    ActionPawn = P.Pawn;
    if (ErrandGoalGetPickup(Goal) != None)
    {
        if (ErrandGoalGetPickup(Goal).PickupTag != '')
        {
            Pick = Spawn(class'LanCoopMissionPickup');
            Pick.Tag = ErrandGoalGetPickup(Goal).PickupTag;
            Other = Pick;
        }
        else
        {
            ItemClass = ResolveClass(string(ErrandGoalGetPickup(Goal).PickupClassName));
            if (ItemClass != None)
                Other = Spawn(ItemClass);
        }
        if (ErrandGoalDropOffPickup(Goal) != None)
        {
            Another = Spawn(class'LanCoopMissionTrigger');
            Another.Tag = ErrandGoalDropOffPickup(Goal).DropIntoHereTriggerTag;
        }
        return Other != None;
    }
    if (ErrandGoalGetInvClass(Goal) != None || ErrandGoalGiveInventory(Goal) != None || ErrandGoalUseUpInventory(Goal) != None)
    {
        if (ErrandGoalGetInvClass(Goal) != None)
            ItemClass = ResolveClass(string(ErrandGoalGetInvClass(Goal).InvClassName));
        else if (ErrandGoalGiveInventory(Goal) != None)
            ItemClass = ResolveClass(string(ErrandGoalGiveInventory(Goal).InvClassName));
        else
            ItemClass = ResolveClass(string(ErrandGoalUseUpInventory(Goal).InvClassName));
        if (ItemClass == None)
            return false;
        Other = Spawn(ItemClass, P.Pawn);
        if (ErrandGoalGetAmmoMax(Goal) != None)
        {
            W = Weapon(Other);
            if (W == None || W.AmmoName == None)
                return false;
            W.AmmoType = Spawn(W.AmmoName, P.Pawn);
            W.AmmoType.AmmoAmount = W.AmmoType.MaxAmmo;
        }
        if (ErrandGoalUseUpInventory(Goal) != None && P2PowerupInv(Other) != None)
            P2PowerupInv(Other).Amount = 0;
        if (ErrandGoalGetInvClassFromPerson(Goal) != None || ErrandGoalGiveInventory(Goal) != None)
        {
            NPC = Spawn(class'LanCoopMissionPawn');
            if (ErrandGoalGiveInventory(Goal) != None)
                NPC.Tag = ErrandGoalGiveInventory(Goal).GiveToMeTag;
            else
                NPC.Tag = ErrandGoalGetInvClassFromPerson(Goal).TalkToMeTag;
            ActionPawn = NPC;
        }
        return Other != None;
    }
    if (ErrandGoalTalkTo(Goal) != None || ErrandGoalKillMe(Goal) != None)
    {
        NPC = Spawn(class'LanCoopMissionPawn');
        if (ErrandGoalTalkTo(Goal) != None)
            NPC.Tag = ErrandGoalTalkTo(Goal).TalkToMeTag;
        else
        {
            NPC.Tag = ErrandGoalKillMe(Goal).KillMeTag;
            NPC.Health = 0;
        }
        ActionPawn = NPC;
        return true;
    }
    if (ErrandGoalTag(Goal) != None || ErrandGoalUrineQuotaMet(Goal) != None)
    {
        Other = Spawn(class'LanCoopMissionTrigger');
        if (ErrandGoalTag(Goal) != None)
            Other.Tag = ErrandGoalTag(Goal).UniqueTag;
        else
            Other.Tag = ErrandGoalUrineQuotaMet(Goal).UrineRecorderTag;
        return true;
    }
    return false;
}

function RunCase(LanCoopGameInfo G, ErrandBase Errand, ErrandGoal Goal, LanCoopPlayer P)
{
    local Actor Other, Another;
    local Pawn ActionPawn;
    local LanCoopMissionTrigger Completion;
    local int I, Records;
    local bool bNegative, bPositive, bRepeat;
    if (!MakeFixture(Goal, P, Other, Another, ActionPawn))
    {
        Skipped++;
        class'LanCoopLog'.static.WriteEvent(Self, "MissionSkip", "Day=" $ DayIndex $ " Errand=" $ Errand.UniqueName $ " Goal=" $ Goal.Class $ " Player=" $ PlayerIndex);
        return;
    }
    G.TheGameState.CurrentDay = DayIndex;
    G.TheGameState.CompletedErrands.Length = 0;
    G.TheGameState.ActivatedErrands.Length = 0;
    G.TheGameState.DeActivatedErrands.Length = 0;
    G.RestoreDayAndErrands();
    for (I = 0; I < G.Days[DayIndex].Errands.Length; I++)
        G.Days[DayIndex].Errands[I].bActivated = false;
    Errand.bActivated = true;
    if (Goal.TriggerOnCompletionTag != '')
    {
        Completion = Spawn(class'LanCoopMissionTrigger');
        Completion.Tag = Goal.TriggerOnCompletionTag;
    }
    bNegative = G.CheckForErrandCompletion(Self, Self, P.Pawn, P, false);
    bPositive = G.CheckForErrandCompletion(Other, Another, ActionPawn, P, false);
    bRepeat = G.CheckForErrandCompletion(Other, Another, ActionPawn, P, false);
    for (I = 0; I < G.TheGameState.CompletedErrands.Length; I++)
        if (G.TheGameState.CompletedErrands[I].Day == DayIndex && G.TheGameState.CompletedErrands[I].Errand == ErrandIndex)
            Records++;
    if (!bNegative && bPositive && !bRepeat && Records == 1
        && (Completion == None || (Completion.Calls == 1 && Completion.LastPawn == P.Pawn)))
    {
        Passed++;
        class'LanCoopLog'.static.WriteEvent(Self, "MissionPass", "Day=" $ DayIndex $ " Errand=" $ Errand.UniqueName $ " Goal=" $ Goal.Class $ " Player=" $ PlayerIndex);
    }
    else
    {
        Failed++;
        class'LanCoopLog'.static.WriteEvent(Self, "MissionFail", "Day=" $ DayIndex $ " Errand=" $ Errand.UniqueName $ " Goal=" $ Goal.Class $ " Player=" $ PlayerIndex $ " Negative=" $ bNegative $ " Positive=" $ bPositive $ " Repeat=" $ bRepeat $ " Records=" $ Records);
    }
    G.PendingErrandURL = "";
    if (Completion != None)
        Completion.Destroy();
    if (Weapon(Other) != None && Weapon(Other).AmmoType != None)
        Weapon(Other).AmmoType.Destroy();
    if (Other != None)
        Other.Destroy();
    if (Another != None)
        Another.Destroy();
    if (ActionPawn != None && ActionPawn != P.Pawn)
        ActionPawn.Destroy();
}

event Timer()
{
    local LanCoopGameInfo G;
    local PlayerController P;
    local string Error;
    local int I;
    G = LanCoopGameInfo(Level.Game);
    if (G == None || bFinished)
        return;
    if (!bPlayersCreated)
    {
        for (I = 0; I < 2; I++)
        {
            P = G.Login("", "?Name=MissionPlayer" $ I, Error);
            if (P == None)
            {
                Failed++;
                bFinished = true;
                SaveConfig();
                return;
            }
            G.PostLogin(P, "");
            TestPlayers[I] = LanCoopPlayer(P);
            P.bGodMode = true;
        }
        bPlayersCreated = true;
        return;
    }
    if (!G.bWorldPrepared)
        return;
    if (DayIndex >= G.Days.Length)
    {
        bFinished = true;
        SetTimer(0, false);
        SaveConfig();
        class'LanCoopLog'.static.WriteEvent(Self, "MissionAuditDone", "Passed=" $ Passed $ " Failed=" $ Failed $ " Skipped=" $ Skipped);
        return;
    }
    if (G.Days[DayIndex] == None)
    {
        Failed++;
        class'LanCoopLog'.static.WriteEvent(Self, "MissionDayMissing", "Day=" $ DayIndex);
        DayIndex++;
        ErrandIndex = 0;
        GoalIndex = 0;
        return;
    }
    if (ErrandIndex >= G.Days[DayIndex].Errands.Length)
    {
        if (G.Days[DayIndex].Errands.Length == 0)
            class'LanCoopLog'.static.WriteEvent(Self, "MissionScriptedDay", "Day=" $ DayIndex $ " No ordinary errands; requires scene/boss playthrough tests");
        DayIndex++;
        ErrandIndex = 0;
        GoalIndex = 0;
        return;
    }
    if (G.Days[DayIndex].Errands[ErrandIndex] == None)
    {
        Skipped++;
        class'LanCoopLog'.static.WriteEvent(Self, "MissionScriptedSlot", "Day=" $ DayIndex $ " Errand=" $ ErrandIndex $ " No errand object; requires playthrough testing");
        ErrandIndex++;
        GoalIndex = 0;
        return;
    }
    if (GoalIndex >= G.Days[DayIndex].Errands[ErrandIndex].Goals.Length)
    {
        ErrandIndex++;
        GoalIndex = 0;
        return;
    }
    RunCase(G, G.Days[DayIndex].Errands[ErrandIndex], G.Days[DayIndex].Errands[ErrandIndex].Goals[GoalIndex], TestPlayers[PlayerIndex]);
    PlayerIndex++;
    if (PlayerIndex == 2)
    {
        PlayerIndex = 0;
        GoalIndex++;
    }
}

defaultproperties
{
    RemoteRole=ROLE_None
}
