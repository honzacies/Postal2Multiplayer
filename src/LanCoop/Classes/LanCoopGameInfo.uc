// Campaign compatibility comes from inheritance, networking from Engine.GameInfo.
// Campaign world state is shared; player inventory travels per connection.
class LanCoopGameInfo extends AWPGameInfo;

var P2Player CampaignPlayer;
var bool bWorldPrepared;
var bool bExpectTravelState, bTravelStateRestored, bTravelQueued;
var string PendingCoopURL;
var P2Player TravelCarrier;
var bool bTravelProbe;
var int TravelProbeStage;
var bool bHandlingCoopErrand;
var string PendingErrandURL;
var LanCoopDiscovery Discovery;
var int CoopGamePort;
var bool bCoopMusicCleared;
var bool bNewDayLoadouts;
var int PreviousCoopDay;
var LanCoopSceneRelay SceneRelay;
var string CoopMapPortal;
var P2Player ActiveQuestPlayer;
struct CoopScriptBinding
{
    var ScriptedController Script;
    var P2Player Player;
};
var array<CoopScriptBinding> CoopScriptBindings;
var bool bCoopNoDiscovery;
var string CoopSessionId;
var LanCoopReconnectStore ReconnectStore;
var bool bCampaignBriefingDue;

function P2Player PlayerForCoopPawn(Pawn P)
{
    local LanCoopPlayer C;
    if (P == None)
        return None;
    foreach DynamicActors(class'LanCoopPlayer', C)
        if (!C.bDeleteMe && (C.Pawn == P || C.MyPawn == P))
            return C;
    return None;
}

function BindCoopScript(ScriptedController C, P2Player P)
{
    local int I;
    if (C == None || P == None)
        return;
    for (I = CoopScriptBindings.Length - 1; I >= 0; I--)
    {
        if (CoopScriptBindings[I].Script == None || CoopScriptBindings[I].Script.bDeleteMe)
            CoopScriptBindings.Remove(I, 1);
        else if (CoopScriptBindings[I].Script == C)
        {
            CoopScriptBindings[I].Player = P;
            C.MyPlayerController = P;
            return;
        }
    }
    I = CoopScriptBindings.Length;
    CoopScriptBindings.Length = I + 1;
    CoopScriptBindings[I].Script = C;
    CoopScriptBindings[I].Player = P;
    C.MyPlayerController = P;
}

function P2Player ResolveCoopScriptPlayer(ScriptedController C, optional bool bCampaignFallback)
{
    local P2Player P;
    local int I;
    if (ActiveQuestPlayer != None && !ActiveQuestPlayer.bDeleteMe)
        return ActiveQuestPlayer;
    if (C != None)
    {
        for (I = 0; I < CoopScriptBindings.Length; I++)
            if (CoopScriptBindings[I].Script == C && CoopScriptBindings[I].Player != None
                && !CoopScriptBindings[I].Player.bDeleteMe)
                return CoopScriptBindings[I].Player;
        P = PlayerForCoopPawn(C.Instigator);
        if (P == None)
            P = PlayerForCoopPawn(C.Pawn);
        if (P != None)
            return P;
    }
    if (bCampaignFallback)
        return GetPlayer();
    class'LanCoopLog'.static.WriteEvent(Self, "EventPlayerUnresolved", "Script=" $ C $ " NoHostGuess=true");
    return None;
}

function DispatchCoopScriptEvent(ScriptedController C, name EventName)
{
    local P2Player P, Previous;
    P = ResolveCoopScriptPlayer(C);
    Previous = ActiveQuestPlayer;
    ActiveQuestPlayer = P;
    // Preserve the original NPC/actor instigator for world logic. Player
    // identity is a separate scoped context, not a substituted NPC pawn.
    TriggerEvent(EventName, C.SequenceScript, C.GetInstigator());
    ActiveQuestPlayer = Previous;
}

// Preserve the triggering player for controllers started by an errand event.
// Original ScriptedController.GetMyPlayer otherwise picks an arbitrary player.
function DispatchCoopQuestEvent(name EventName, P2Player EventPlayer)
{
    local array<ScriptedController> Before;
    local ScriptedController C;
    local P2Player Previous;
    local int I;
    local bool bExisted;
    if (EventName == '' || EventPlayer == None)
        return;
    foreach DynamicActors(class'ScriptedController', C)
        Before[Before.Length] = C;
    Previous = ActiveQuestPlayer;
    ActiveQuestPlayer = EventPlayer;
    TriggerEvent(EventName, Self, EventPlayer.MyPawn);
    foreach DynamicActors(class'ScriptedController', C)
    {
        bExisted = false;
        for (I = 0; I < Before.Length; I++)
            if (Before[I] == C)
                bExisted = true;
        if (!bExisted)
        {
            BindCoopScript(C, EventPlayer);
            if (C.Pawn == None)
                C.Instigator = EventPlayer.MyPawn;
            class'LanCoopLog'.static.WriteEvent(Self, "QuestScriptBound", "Script=" $ C $ " Player=" $ EventPlayer);
        }
    }
    ActiveQuestPlayer = Previous;
    class'LanCoopLog'.static.WriteEvent(Self, "QuestEventDispatched", "Event=" $ EventName $ " Player=" $ EventPlayer);
}

// BSP floor traces exclude pawns. The stock placement helper can mistake
// the first player's head for the second player's floor.
function bool PlaceCoopArrival(P2Pawn P, Telepad ArrivalPad)
{
    local vector Candidate, Start, End, HitLocation, HitNormal, Offset, Separation;
    local Actor Floor;
    local Pawn Other;
    local int Attempt;
    local float Angle;
    local bool bBlocked;
    if (P == None || ArrivalPad == None || ArrivalPad.TMarker == None)
        return false;
    for (Attempt = 0; Attempt < 17; Attempt++)
    {
        Offset = vect(0,0,0);
        if (Attempt > 0)
        {
            Angle = ((Attempt - 1) % 8) * 0.785398;
            Offset.X = Cos(Angle) * (96 + ((Attempt - 1) / 8) * 96);
            Offset.Y = Sin(Angle) * (96 + ((Attempt - 1) / 8) * 96);
        }
        Candidate = ArrivalPad.TMarker.Location + Offset;
        Start = Candidate;
        Start.Z += FMax(128, 2 * P.CollisionHeight);
        End = Candidate;
        End.Z -= 256;
        Floor = Trace(HitLocation, HitNormal, End, Start, false);
        if (Floor == None || HitNormal.Z < 0.7)
            continue;
        Candidate = HitLocation;
        Candidate.Z += P.CollisionHeight + 2;
        bBlocked = false;
        foreach CollidingActors(class'Pawn', Other, 192, Candidate)
            if (Other != P && Other.bBlockPlayers && Other.Health > 0)
            {
                Separation = Other.Location - Candidate;
                Separation.Z = 0;
                if (VSize(Separation) < P.CollisionRadius + Other.CollisionRadius + 8
                    && Abs(Other.Location.Z - Candidate.Z) < P.CollisionHeight + Other.CollisionHeight + 4)
                    bBlocked = true;
            }
        if (bBlocked || !P.SetLocation(Candidate))
            continue;
        P.Velocity = vect(0,0,0);
        P.Acceleration = vect(0,0,0);
        P.SetPhysics(PHYS_Walking);
        if (LanCoopPawn(P) != None)
            LanCoopPawn(P).bCoopArrivalPlaced = true;
        if (LanCoopPlayer(P.Controller) != None)
            LanCoopPlayer(P.Controller).ResetCoopArrivalState();
        class'LanCoopLog'.static.WriteEvent(Self, "ArrivalPlaced", "Pawn=" $ P $ " Pad=" $ ArrivalPad $ " Location=" $ P.Location $ " Attempt=" $ Attempt);
        return true;
    }
    class'LanCoopLog'.static.WriteEvent(Self, "ArrivalPlacementFailed", "Pawn=" $ P $ " Pad=" $ ArrivalPad $ " RetainedSpawn=" $ P.Location);
    return false;
}

function string ResolveCoopArrivalPortal(string IncomingPortal, string Options)
{
    local string ExplicitPortal;
    ExplicitPortal = ParseOption(Options, "CoopEntry");
    if (ExplicitPortal != "")
        return ExplicitPortal;
    if (IncomingPortal != "")
        return IncomingPortal;
    return CoopMapPortal;
}

function StartCoopScene(LanCoopPlayer Viewer, SceneManager SM)
{
    if (SM == None || SM.Affect != AFFECT_ViewportCamera)
        return;
    if (SceneRelay == None)
        SceneRelay = Spawn(class'LanCoopSceneRelay');
    if (SceneRelay != None && SceneRelay.Source == None)
        SceneRelay.BeginScene(Viewer, SM);
}

event InitGame(out string Options, out string Error)
{
    local string RequestedName;
    RequestedName = ParseOption(Options, "Name");
    Super.InitGame(Options, Error);
    CoopSessionId = ParseOption(Options, "CoopSession");
    if (CoopSessionId == "")
        CoopSessionId = string(Level.Year) $ Level.Month $ Level.Day $ "-" $ Rand(1000000000) $ Rand(1000000000);
    ReconnectStore = new(None) class'LanCoopReconnectStore';
    bCoopNoDiscovery = ParseOption(Options, "CoopNoDiscovery") == "1";
    AddMutator("LanCoop.LanCoopAuthorityMutator");
    // SP rewrites this out parameter to "Player". On server travel that
    // changes the native inventory lookup key and loses the host's cargo.
    if (RequestedName != "")
        Options = SetURLOption(Options, "Name", RequestedName);
    // Some installed AWP packages leave Sunday's inherited reference empty.
    // Resolve weekend definitions from the actual AW campaign package.
    if (Days[5] == None)
        Days[5] = class'GameTypes.AWGameSP'.Default.Days[0];
    if (Days[6] == None)
        Days[6] = class'GameTypes.AWGameSP'.Default.Days[1];
    MaxPlayers = Clamp(GetIntOption(Options, "MaxPlayers", Default.MaxPlayers), 1, 16);
    MaxSpectators = Clamp(GetIntOption(Options, "MaxSpectators", Default.MaxSpectators), 0, 16);
    CoopGamePort = GetIntOption(Options, "Port", 7777);
    bExpectTravelState = ParseOption(Options, "CoopTravel") == "1";
    CoopMapPortal = ParseOption(Options, "CoopEntry");
    bTravelProbe = ParseOption(Options, "CoopTravelProbe") == "1";
    TravelProbeStage = GetIntOption(Options, "CoopProbeStage", 0);
    if (bTravelProbe)
        Spawn(class'LanCoopTravelProbe');
    if (ParseOption(Options, "CoopMissionProbe") == "1")
        Spawn(class'LanCoopMissionProbe');
    // A shared world must exist before any player joins; it never belongs
    // to the inventory of whichever player happened to connect last.
    TheGameState = Spawn(GameStateClass);
    if (TheGameState == None)
    {
        Error = "LAN Coop: Cannot create campaign state";
        return;
    }
    TheGameState.CurrentDay = 0;
    TheGameState.NextDay = 0;
    TheGameState.bChangeDayPostTravel = false;
    // The original campaign opens a day from PostTravel, before any script
    // runs. Every map's own start-of-day script reads these day flags, so a
    // coop session has to open the day here, ahead of the first login.
    // On travel this state is replaced by the one the players carry, and the
    // day it already holds decides everything below.
    if (IsIntroMap() || IsMainMenuMap() || bExpectTravelState)
        TheGameState.bPreGameMode = true;
    else
        BeginCampaignDay(0, true);
    TheGameState.PlayerCheated("LAN Coop development session");
    SetupDifficultyOnce();
    class'LanCoopEventAdapters'.static.InstallForLevel(Self);
    bDoAutoSave = false;
    if (ParseOption(Options, "LifecycleProbe") == "1")
        Spawn(class'LanCoopLifecycleProbe');
    class'LanCoopLog'.static.WriteEvent(Self, "CampaignInit", "Days=" $ Days.Length $ " State=" $ TheGameState
        $ " Day=" $ TheGameState.CurrentDay $ " FirstOfGame=" $ TheGameState.bFirstLevelOfGame
        $ " FirstOfDay=" $ TheGameState.bFirstLevelOfDay);
}

function bool HasValidCampaignDay()
{
    return TheGameState != None && TheGameState.CurrentDay >= 0
        && TheGameState.CurrentDay < Days.Length
        && Days[TheGameState.CurrentDay] != None;
}

// Mirrors the original "starting a new game" branch of PostTravel: pick the
// day, leave pre-game mode and reset the per-day counters. Map scripts test
// bFirstLevelOfGame and bFirstLevelOfDay to decide whether to hand out work.
function BeginCampaignDay(int DayNumber, bool bFirstOfGame)
{
    TheGameState.CurrentDay = Clamp(DayNumber, 0, Days.Length - 1);
    TheGameState.NextDay = TheGameState.CurrentDay;
    TheGameState.bPreGameMode = false;
    TheGameState.bChangeDayPostTravel = false;
    TheGameState.bFirstLevelOfGame = bFirstOfGame;
    TheGameState.bFirstLevelOfDay = true;
    TheGameState.ErrandsCompletedToday = 0;
    bCampaignBriefingDue = true;
    // Only this day: the shipped Sunday definition carries a deliberate empty
    // errand slot, and validating every day would report it as an error.
    Days[TheGameState.CurrentDay].CheckForValidErrandGoals();
}

// The shipped weekend days include an empty errand entry, so nothing may
// reach a day's errand through the DayBase accessors without this check.
function bool HasCampaignErrand(int Errand)
{
    local DayBase D;
    if (!HasValidCampaignDay())
        return false;
    D = Days[TheGameState.CurrentDay];
    return Errand >= 0 && Errand < D.Errands.Length && D.Errands[Errand] != None;
}

function bool IsCampaignErrandRevealed(int Errand)
{
    local int I;
    for (I = 0; I < TheGameState.RevealedErrands.Length; I++)
        if (TheGameState.RevealedErrands[I].Day == TheGameState.CurrentDay
            && TheGameState.RevealedErrands[I].Errand == Errand)
            return true;
    return false;
}

function bool IsCampaignLocationRevealed(int Errand)
{
    local int I;
    for (I = 0; I < TheGameState.RevealedLocationTex.Length; I++)
        if (TheGameState.RevealedLocationTex[I].Day == TheGameState.CurrentDay
            && TheGameState.RevealedLocationTex[I].Errand == Errand)
            return true;
    return false;
}

// Single player writes these records while one player watches the Dude fill
// in the paper. A shared campaign cannot wait on one client's screen, so the
// server hands the day's active errands out and every map shows the result.
function int RevealCampaignErrands()
{
    local DayBase D;
    local int I, Slot, Added;
    if (!HasValidCampaignDay())
        return 0;
    D = Days[TheGameState.CurrentDay];
    for (I = 0; I < D.NumErrands(); I++)
    {
        if (!HasCampaignErrand(I) || !D.IsErrandActive(I))
            continue;
        if (!IsCampaignErrandRevealed(I))
        {
            Slot = TheGameState.RevealedErrands.Length;
            TheGameState.RevealedErrands.Insert(Slot, 1);
            TheGameState.RevealedErrands[Slot].Day = TheGameState.CurrentDay;
            TheGameState.RevealedErrands[Slot].Errand = I;
            Added++;
        }
        if (D.IsLocationTexActive(I) && !IsCampaignLocationRevealed(I))
        {
            Slot = TheGameState.RevealedLocationTex.Length;
            TheGameState.RevealedLocationTex.Insert(Slot, 1);
            TheGameState.RevealedLocationTex[Slot].Day = TheGameState.CurrentDay;
            TheGameState.RevealedLocationTex[Slot].Errand = I;
        }
    }
    if (Added > 0)
    {
        SyncCampaignView();
        class'LanCoopLog'.static.WriteEvent(Self, "ErrandsHandedOut", "Day=" $ TheGameState.CurrentDay
            $ " New=" $ Added $ " Active=" $ D.NumActiveErrands() $ " Total=" $ D.NumErrands());
    }
    return Added;
}

// Errands activated by a goal during the day are new work for both players.
function ActivateErrand(string UniqueName)
{
    Super.ActivateErrand(UniqueName);
    if (RevealCampaignErrands() > 0)
        bCampaignBriefingDue = true;
}

// 0 active, 1 revealed, 2 revealed location, 3 completed.
function int CampaignErrandMask(int Kind)
{
    local DayBase D;
    local int I, Mask;
    if (!HasValidCampaignDay())
        return 0;
    D = Days[TheGameState.CurrentDay];
    for (I = 0; I < D.NumErrands() && I < 30; I++)
    {
        if (!HasCampaignErrand(I))
            continue;
        switch (Kind)
        {
            case 0:
                if (D.IsErrandActive(I))
                    Mask = Mask | (1 << I);
                break;
            case 1:
                if (IsCampaignErrandRevealed(I))
                    Mask = Mask | (1 << I);
                break;
            case 2:
                if (D.IsLocationTexActive(I) && IsCampaignLocationRevealed(I))
                    Mask = Mask | (1 << I);
                break;
            case 3:
                if (D.IsErrandComplete(I) || IsCampaignErrandCompleted(I))
                    Mask = Mask | (1 << I);
                break;
        }
    }
    return Mask;
}

function bool IsCampaignErrandCompleted(int Errand)
{
    local int I;
    for (I = 0; I < TheGameState.CompletedErrands.Length; I++)
        if (TheGameState.CompletedErrands[I].Day == TheGameState.CurrentDay
            && TheGameState.CompletedErrands[I].Errand == Errand)
            return true;
    return false;
}

// Single player crosses a finished errand off on that player's own map. The
// day belongs to the whole team here, so every player sees the line struck
// through and hears the Dude close it out.
function AnnounceCampaignCrossOut(int Errand)
{
    local Controller C;
    local LanCoopPlayer P;
    if (!HasValidCampaignDay() || IsWeekend())
        return;
    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        P = LanCoopPlayer(C);
        if (P == None || P.bDeleteMe || !P.SendCoopMapCrossOut(Errand))
            continue;
        // That showing is this day's map, so do not replay the handout
        // animation on top of it a second later.
        P.CoopBriefedDay = TheGameState.CurrentDay;
        P.CoopBriefedMask = CampaignErrandMask(1);
    }
}

// The original forces the day's map up on the player who received the work.
// Here every connected player is a recipient, including one who joins later
// in the day or is handed an errand activated by someone else's goal.
function OfferCampaignBriefings()
{
    local Controller C;
    local LanCoopPlayer P;
    local int Day, Revealed;
    // Only when the day was just opened or new errands were just activated.
    // Another level of the same day must not replay the writing animation.
    if (!bCampaignBriefingDue || !bWorldPrepared || !HasValidCampaignDay() || IsWeekend())
        return;
    Day = TheGameState.CurrentDay;
    Revealed = CampaignErrandMask(1);
    if (Revealed == 0)
        return;
    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        P = LanCoopPlayer(C);
        if (P == None || P.bDeleteMe)
            continue;
        if (P.CoopBriefedDay == Day && P.CoopBriefedMask == Revealed)
            continue;
        if (P.CoopBriefingSentAt > 0 && Level.TimeSeconds - P.CoopBriefingSentAt < 5)
            continue;
        P.CoopBriefingSentDay = Day;
        P.CoopBriefingSentMask = Revealed;
        if (!P.SendCoopMap(true))
            continue;
        P.CoopBriefingSentAt = Level.TimeSeconds;
        class'LanCoopLog'.static.WriteEvent(Self, "ErrandBriefingSent", "Player="
            $ P.PlayerReplicationInfo.PlayerName $ " Day=" $ Day $ " Revealed=" $ Revealed);
    }
}

function PostBeginPlay()
{
    Super.PostBeginPlay();
    SyncCampaignView();
    if (!bCoopNoDiscovery && (Level.NetMode == NM_ListenServer || Level.NetMode == NM_DedicatedServer))
    {
        Discovery = Spawn(class'LanCoopDiscovery');
        if (Discovery != None)
            Discovery.StartServer(Self);
    }
    class'LanCoopLog'.static.WriteEvent(Self, "CampaignWaiting", "Map=" $ Level.GetLocalURL());
}

function SyncCampaignView()
{
    local LanCoopReplicationInfo R;
    local int I;
    R = LanCoopReplicationInfo(GameReplicationInfo);
    if (R == None || !HasValidCampaignDay())
        return;
    R.CampaignDay = TheGameState.CurrentDay;
    R.CampaignMap = ParseLevelName(Level.GetLocalURL());
    R.CompletedTaskMask = 0;
    R.TaskCount = Days[TheGameState.CurrentDay].Errands.Length;
    for (I = 0; I < TheGameState.CompletedErrands.Length; I++)
        if (TheGameState.CompletedErrands[I].Day == TheGameState.CurrentDay)
            R.CompletedTaskMask = R.CompletedTaskMask | (1 << TheGameState.CompletedErrands[I].Errand);
    R.ActiveTaskMask = CampaignErrandMask(0);
    R.RevealedTaskMask = CampaignErrandMask(1);
    R.RevealedLocationMask = CampaignErrandMask(2);
    R.CompletedTaskMask = R.CompletedTaskMask | CampaignErrandMask(3);
}

function SyncMusicTo(LanCoopPlayer P)
{
    local int I;
    if (P == None || NetConnection(P.Player) == None)
        return;
    if (bCoopMusicCleared)
        P.ClientClearCoopMusic(0.2);
    for (I = 0; I < ArrayCount(SongInfos); I++)
        if (SongInfos[I].RealHandle > 0 && SongInfos[I].Actor == None && SongInfos[I].Song != "")
            P.ClientCoopMusic(I, SongInfos[I].Song, 0.3, SongInfos[I].VolumeOverride, false);
    class'LanCoopLog'.static.WriteEvent(Self, "MusicSync", "Player=" $ P.PlayerReplicationInfo.PlayerName $ " Map=" $ ParseLevelName(Level.GetLocalURL()) $ " Day=" $ TheGameState.CurrentDay $ " LevelSong=" $ Level.Song);
}

function int PlayMusicExt(string Song, float FadeInTime, optional float VolumeOverride, optional bool bAllowPause)
{
    local int Handle;
    local LanCoopPlayer P;
    Handle = Super.PlayMusicExt(Song, FadeInTime, VolumeOverride, bAllowPause);
    if (Handle > 0)
        foreach DynamicActors(class'LanCoopPlayer', P)
            if (NetConnection(P.Player) != None)
                P.ClientCoopMusic(Handle - 1, Song, FadeInTime, VolumeOverride, bAllowPause);
    return Handle;
}

function StopMusicExt(int Handle, float FadeOutTime)
{
    local LanCoopPlayer P;
    if (Handle <= 0 || Handle > ArrayCount(SongInfos))
        return;
    foreach DynamicActors(class'LanCoopPlayer', P)
        if (NetConnection(P.Player) != None)
            P.ClientStopCoopMusic(Handle - 1, FadeOutTime);
    Super.StopMusicExt(Handle, FadeOutTime);
}

function StopAllMusicExt(float FadeOutTime)
{
    local LanCoopPlayer P;
    bCoopMusicCleared = true;
    Super.StopAllMusicExt(FadeOutTime);
    foreach DynamicActors(class'LanCoopPlayer', P)
        if (NetConnection(P.Player) != None)
            P.ClientClearCoopMusic(FadeOutTime);
}

function SaveCompletedErrand(int Day, int Errand)
{
    local int I;
    for (I = 0; I < TheGameState.CompletedErrands.Length; I++)
        if (TheGameState.CompletedErrands[I].Day == Day && TheGameState.CompletedErrands[I].Errand == Errand)
            return;
    Super.SaveCompletedErrand(Day, Errand);
    SyncCampaignView();
    class'LanCoopLog'.static.WriteEvent(Self, "ErrandSaved", "Day=" $ Day $ " Errand=" $ Errand);
}

// Do not let a stale aggregate counter (or an empty active-errand cache)
// finish a day. The travelling completion records are authoritative.
function bool IsPlayerReadyForHome()
{
    local int I, J, Active;
    local bool bRecorded;
    local ErrandBase E;
    if (!bWorldPrepared || TheGameState == None
        || TheGameState.CurrentDay < 0 || TheGameState.CurrentDay >= Days.Length
        || Days[TheGameState.CurrentDay] == None)
        return false;
    for (I = 0; I < Days[TheGameState.CurrentDay].Errands.Length; I++)
    {
        E = Days[TheGameState.CurrentDay].Errands[I];
        if (E == None || !E.IsActive())
            continue;
        Active++;
        bRecorded = false;
        for (J = 0; J < TheGameState.CompletedErrands.Length; J++)
            if (TheGameState.CompletedErrands[J].Day == TheGameState.CurrentDay
                && TheGameState.CompletedErrands[J].Errand == I)
                bRecorded = true;
        if (!bRecorded)
            return false;
    }
    return Active > 0;
}

function SendPlayerLevelTransition(PlayerController Player, string URL, bool bRealLevelExit)
{
    if (!bWorldPrepared || bTravelQueued)
        return;
    class'LanCoopLog'.static.WriteEvent(Self, "Gate", "Requested=" $ URL $ " Player=" $ Player
        $ " Day=" $ TheGameState.CurrentDay $ " CompletedCounter=" $ TheGameState.ErrandsCompletedToday
        $ " Records=" $ TheGameState.CompletedErrands.Length
        $ " RealExit=" $ bRealLevelExit $ " DivertHome=" $ WillPlayerBeDivertedHome(URL, bRealLevelExit));
    Super.SendPlayerLevelTransition(Player, URL, bRealLevelExit);
}

function bool CheckForErrandCompletion(Actor Other, Actor Another, Pawn ActionPawn,
    P2Player ThisPlayer, bool bPremature, optional string SendToURL)
{
    local bool bCompleted, bAny;
    local int Errand, Count;
    local name CompletionTrigger;
    local string GoalURL;

    if (TheGameState == None || bHandlingCoopErrand)
        return false;
    if (ThisPlayer == None && ActionPawn != None)
        ThisPlayer = P2Player(ActionPawn.Controller);
    if (ThisPlayer == None)
        ThisPlayer = GetPlayer();
    if (ThisPlayer == None)
        return false;
    bHandlingCoopErrand = true;
    do
    {
        GoalURL = "";
        CompletionTrigger = '';
        bCompleted = Days[TheGameState.CurrentDay].CheckForErrandCompletion(
            Other, Another, ActionPawn, bPremature, TheGameState, Errand, CompletionTrigger, GoalURL);
        if (bCompleted)
        {
            bAny = true;
            TheGameState.ErrandsCompletedToday++;
            SaveCompletedErrand(TheGameState.CurrentDay, Errand);
            Broadcast(Self, ThisPlayer.PlayerReplicationInfo.PlayerName $ " completed: " $ Days[TheGameState.CurrentDay].Errands[Errand].UniqueName);
            // The SP implementation waits for one player's map interaction.
            // Run the world event on the server, independently of local UI.
            if (CompletionTrigger != '')
                DispatchCoopQuestEvent(CompletionTrigger, ThisPlayer);
            AnnounceCampaignCrossOut(Errand);
            if (SendToURL != "")
                PendingErrandURL = SendToURL;
            else if (GoalURL != "")
                PendingErrandURL = GoalURL;
            class'LanCoopLog'.static.WriteEvent(Self, "ErrandCompleted", "Player=" $ ThisPlayer.PlayerReplicationInfo.PlayerName $ " Day=" $ TheGameState.CurrentDay $ " Errand=" $ Errand $ " Trigger=" $ CompletionTrigger);
            Other = ThisPlayer;
            Another = ThisPlayer;
            ActionPawn = ThisPlayer.Pawn;
        }
        Count++;
    } until (!bCompleted || Count >= 32);
    bHandlingCoopErrand = false;
    SyncCampaignView();
    return bAny;
}

// Stable compatibility reference for old scripts. It is not an identity,
// an inventory owner, or proof that this player is local to the server.
function P2Player GetPlayer()
{
    local Controller C;
    if (ActiveQuestPlayer != None && !ActiveQuestPlayer.bDeleteMe)
        return ActiveQuestPlayer;
    if (CampaignPlayer != None && !CampaignPlayer.bDeleteMe)
        return CampaignPlayer;
    for (C = Level.ControllerList; C != None; C = C.NextController)
        if (P2Player(C) != None && !C.bDeleteMe && C.PlayerReplicationInfo != None && !C.PlayerReplicationInfo.bOnlySpectator)
        {
            CampaignPlayer = P2Player(C);
            return CampaignPlayer;
        }
    return None;
}

event PostLogin(PlayerController NewPlayer, string Options)
{
    if (CampaignPlayer == None && !NewPlayer.PlayerReplicationInfo.bOnlySpectator)
        CampaignPlayer = P2Player(NewPlayer);
    Super.PostLogin(NewPlayer, Options);
    if (LanCoopPlayer(NewPlayer) != None && ReconnectStore != None)
        ReconnectStore.Restore(Self, LanCoopPlayer(NewPlayer));
    if (NetConnection(NewPlayer.Player) == None && NewPlayer.Player != None && GameReplicationInfo != None)
        GameReplicationInfo.ServerName = NewPlayer.PlayerReplicationInfo.PlayerName $ "'s game";
    class'LanCoopLog'.static.WriteEvent(Self, "PlayerJoin", "Name=" $ NewPlayer.PlayerReplicationInfo.PlayerName $ " Pawn=" $ NewPlayer.Pawn $ " Players=" $ NumPlayers);
}

event PlayerController Login(string Portal, string Options, out string Error)
{
    local string Appearance;
    local PlayerController P;
    local LanCoopPlayer Existing;
    local string Identity;
    Identity = Left(ParseOption(Options, "CoopId"), 80);
    if (Identity != "")
        foreach DynamicActors(class'LanCoopPlayer', Existing)
            if (!Existing.bDeleteMe && Existing.CoopReconnectId == Identity)
            {
                Error = "This coop profile is already connected. Use a separate game folder for another player.";
                return None;
            }
    // A menu's multiplayer class must not replace campaign behavior.
    Appearance = ParseOption(Options, "Class");
    // Remote reconnection can omit FURL's #portal although the listen host
    // receives it. Preserve an explicit option and the server's shared entry.
    Portal = ResolveCoopArrivalPortal(Portal, Options);
    Options = SetURLOption(Options, "Class", "LanCoop.LanCoopPawn");
    P = Super.Login(Portal, Options, Error);
    if (LanCoopPlayer(P) != None)
    {
        LanCoopPlayer(P).CoopReconnectId = Left(ParseOption(Options, "CoopId"), 80);
        LanCoopPlayer(P).CoopArrivalPortal = Portal;
        class'LanCoopLog'.static.WriteEvent(Self, "ArrivalPortalResolved", "Player=" $ P $ " Portal=" $ Portal $ " SharedPortal=" $ CoopMapPortal);
        LanCoopPlayer(P).bAwaitingTravelInventory = ParseOption(Options, "CoopTravel") == "1";
        LanCoopPlayer(P).bCoopTravelLogin = LanCoopPlayer(P).bAwaitingTravelInventory;
        LanCoopPlayer(P).ServerSetAppearance(Appearance);
    }
    return P;
}

function bool AllPlayersReady()
{
    local Controller C;
    for (C = Level.ControllerList; C != None; C = C.NextController)
        if (LanCoopPlayer(C) != None && C.PlayerReplicationInfo != None
            && !C.PlayerReplicationInfo.bOnlySpectator && !LanCoopPlayer(C).bCoopClientReady)
            return false;
    return NumPlayers > 0;
}

// An errand that sends the players onward must not cut off the crossout or
// the newspaper the same errand just put on someone's screen.
function bool AnyCoopScreenShowing()
{
    local Controller C;
    for (C = Level.ControllerList; C != None; C = C.NextController)
        if (LanCoopPlayer(C) != None && !C.bDeleteMe
            && (LanCoopPlayer(C).bCoopNewsReading || LanCoopPlayer(C).bCoopNewsOffered))
            return true;
    return false;
}

function ChangeName(Controller Other, coerce string S, bool bNameChange)
{
    local Controller C;
    local string BaseName;
    local int Suffix;
    local bool bTaken;
    BaseName = S;
    // Native travel matches inventories by player name. Keep those keys
    // unique even when names are changed through the stock Player menu.
    do
    {
        bTaken = false;
        for (C = Level.ControllerList; C != None; C = C.NextController)
            if (C != Other && PlayerController(C) != None && C.PlayerReplicationInfo != None
                && C.PlayerReplicationInfo.PlayerName ~= S)
                bTaken = true;
        if (bTaken)
        {
            S = Left(BaseName, 16) $ "_" $ Suffix;
            Suffix++;
        }
    } until (!bTaken);
    Super.ChangeName(Other, S, bNameChange);
    if (Other.Pawn != None && Other.PlayerReplicationInfo != None)
        Other.Pawn.OwnerName = Other.PlayerReplicationInfo.PlayerName;
}

// Campaign maps often contain a single PlayerStart. Pick a clear nearby
// navigation point for the second player instead of overlapping the host.
function NavigationPoint FindPlayerStart(Controller Player, optional byte InTeam, optional string IncomingName)
{
    local NavigationPoint Preferred, N, Best;
    local Pawn P;
    local bool bBlocked;
    local float Distance, BestDistance;

    Preferred = Super.FindPlayerStart(Player, InTeam, IncomingName);
    if (Preferred == None)
        return None;
    foreach CollidingActors(class'Pawn', P, 96, Preferred.Location)
        if (P.bBlockPlayers && P.Health > 0)
            bBlocked = true;
    if (!bBlocked)
        return Preferred;
    BestDistance = 768;
    for (N = Level.NavigationPointList; N != None; N = N.NextNavigationPoint)
    {
        Distance = VSize(N.Location - Preferred.Location);
        if (Distance < 96 || Distance >= BestDistance
            || Abs(N.Location.Z - Preferred.Location.Z) > 96
            || !FastTrace(N.Location, Preferred.Location))
            continue;
        bBlocked = false;
        foreach CollidingActors(class'Pawn', P, 96, N.Location)
            if (P.bBlockPlayers && P.Health > 0)
                bBlocked = true;
        if (!bBlocked)
        {
            Best = N;
            BestDistance = Distance;
        }
    }
    // Failing explicitly is preferable to spawning on top of another pawn.
    return Best;
}

// Development sessions do not evaluate local Steam achievements on a server.
function CheckAchievments()
{
}

function Logout(Controller Exiting)
{
    if (Exiting == CampaignPlayer)
        CampaignPlayer = None;
    Super.Logout(Exiting);
}

// Never call the SP implementation once per connection: an existing world
// state there is interpreted as loading a save and can change loadout policy.
event PostTravel(P2Pawn PlayerPawn)
{
    local GameState Cargo;
    local Telepad ArrivalPad;
    local Telepad CandidatePad;
    if (PlayerPawn == None)
        return;
    if (LanCoopPawn(PlayerPawn) != None && !LanCoopPawn(PlayerPawn).bCoopArrivalHandled)
    {
        LanCoopPawn(PlayerPawn).bCoopArrivalHandled = true;
        LanCoopPawn(PlayerPawn).RestoreCoopTravelData();
        if (bExpectTravelState && P2Player(PlayerPawn.Controller) != None)
        {
            // FindPlayerStart may move a second player away from an occupied
            // portal. Distance from that spawn is not the arrival identity.
            if (LanCoopPlayer(PlayerPawn.Controller) != None
                && ResolveCoopArrivalPortal(LanCoopPlayer(PlayerPawn.Controller).CoopArrivalPortal, "") != "")
                foreach AllActors(class'Telepad', CandidatePad)
                    if (string(CandidatePad.Tag) ~= ResolveCoopArrivalPortal(LanCoopPlayer(PlayerPawn.Controller).CoopArrivalPortal, ""))
                    {
                        ArrivalPad = CandidatePad;
                        break;
                    }
            if (ArrivalPad != None && ArrivalPad.TMarker != None)
            {
                PlaceCoopArrival(PlayerPawn, ArrivalPad);
                class'LanCoopLog'.static.WriteEvent(Self, "Arrival", "Pad=" $ ArrivalPad $ " Location=" $ PlayerPawn.Location);
            }
            else
                class'LanCoopLog'.static.WriteEvent(Self, "ArrivalPortalMissing", "Pawn=" $ PlayerPawn $ " SharedPortal=" $ CoopMapPortal $ " Pad=" $ ArrivalPad);
        }
    }
    Cargo = GameState(PlayerPawn.FindInventoryType(GameStateClass));
    if (Cargo != None && !bTravelStateRestored)
    {
        if (TheGameState != None && TheGameState != Cargo)
            TheGameState.Destroy();
        TheGameState = Cargo;
        PlayerPawn.DeleteInventory(Cargo);
        Cargo.Inventory = None;
        Cargo.SetOwner(None);
        CampaignPlayer = P2Player(PlayerPawn.Controller);
        bTravelStateRestored = true;
        class'LanCoopLog'.static.WriteEvent(Self, "TravelWorldRestored", "Pawn=" $ PlayerPawn $ " Day=" $ TheGameState.CurrentDay);
    }
    PlayerPawn.PlayerStartingFinished();
    PlayerPawn.ClientPlayerStartingFinished();
    if (LanCoopPawn(PlayerPawn) != None)
        LanCoopPawn(PlayerPawn).RestoreCombatReferences();
    if (bWorldPrepared)
        ApplyCoopDayLoadout(PlayerPawn);
    if (LanCoopPawn(PlayerPawn) != None && LanCoopPlayer(PlayerPawn.Controller) != None)
    {
        LanCoopPlayer(PlayerPawn.Controller).SelectedAppearance = LanCoopPawn(PlayerPawn).CoopAppearance;
        LanCoopPlayer(PlayerPawn.Controller).bAwaitingTravelInventory = false;
    }
    class'LanCoopLog'.static.WriteEvent(Self, "TravelPlayerAccept", "Pawn=" $ PlayerPawn $ " Inventory=" $ PlayerPawn.Inventory $ " Health=" $ PlayerPawn.Health);
}

function AddDefaultInventory(Pawn PlayerPawn)
{
    // Imported native travel inventory is authoritative; do not add a fresh
    // day loadout on top of it while the engine restores the old pawn.
    if (LanCoopPlayer(PlayerPawn.Controller) != None
        && LanCoopPlayer(PlayerPawn.Controller).bAwaitingTravelInventory)
        return;
    Super.AddDefaultInventory(PlayerPawn);
    if (P2Pawn(PlayerPawn) == None)
        return;
    P2Pawn(PlayerPawn).AddDefaultInventory();
    Days[TheGameState.CurrentDay].AddInStartingInventory(P2Pawn(PlayerPawn));
    if (LanCoopPawn(PlayerPawn) != None)
        LanCoopPawn(PlayerPawn).bCoopDayLoadoutApplied = true;
    if (BaseMod != None)
    {
        BaseMod.ModifyPlayer(PlayerPawn);
        BaseMod.ModifyPlayerInventory(PlayerPawn);
    }
    P2Pawn(PlayerPawn).PlayerStartingFinished();
    P2Pawn(PlayerPawn).ClientPlayerStartingFinished();
    if (LanCoopPlayer(PlayerPawn.Controller) != None
        && LanCoopPlayer(PlayerPawn.Controller).SelectedAppearance != None)
        LanCoopPawn(PlayerPawn).SetCoopAppearance(LanCoopPlayer(PlayerPawn.Controller).SelectedAppearance);
}

function PrepareCoopDayTransition()
{
    PreviousCoopDay = TheGameState.CurrentDay;
    if (TheGameState.bChangeDayPostTravel)
    {
        TheGameState.CurrentDay = Clamp(TheGameState.NextDay, 0, Days.Length - 1);
        TheGameState.bChangeDayPostTravel = false;
        TheGameState.bFirstLevelOfGame = false;
        TheGameState.bFirstLevelOfDay = true;
        TheGameState.ErrandsCompletedToday = 0;
        bNewDayLoadouts = true;
        bCampaignBriefingDue = true;
    }
    else if (TheGameState.bPreGameMode && !IsIntroMap())
    {
        TheGameState.bFirstLevelOfDay = true;
        TheGameState.bFirstLevelOfGame = true;
        bNewDayLoadouts = true;
        bCampaignBriefingDue = true;
    }
    else
    {
        // Same day, another level of it: the original clears both flags so
        // start-of-day scripts stay quiet for the rest of the day.
        TheGameState.bFirstLevelOfDay = false;
        TheGameState.bFirstLevelOfGame = false;
    }
    TheGameState.bPreGameMode = IsIntroMap();
}

function ApplyCoopDayLoadout(P2Pawn P)
{
    if (!bNewDayLoadouts || LanCoopPawn(P) == None || LanCoopPawn(P).bCoopDayLoadoutApplied)
        return;
    Days[PreviousCoopDay].TakeInventoryFromPlayer(P);
    Days[TheGameState.CurrentDay].AddInStartingInventory(P);
    LanCoopPawn(P).bCoopDayLoadoutApplied = true;
}

// The SP startup assumes a viewport and immediately autosaves. Defer world
// setup until a real pawn exists, including on a dedicated server.
auto state StartUp
{
    function bool StartingUp() { return true; }
Begin:
    while (GetPlayer() == None || GetPlayer().Pawn == None
        || (bExpectTravelState && !bTravelStateRestored))
    {
        Sleep(0.1);
    }
    if (bTravelStateRestored)
    {
        PrepareCoopDayTransition();
        class'LanCoopLog'.static.WriteEvent(Self, "WorldStage", "RestoreTravelWorld");
        TheGameState.PostLevelChange(P2Pawn(GetPlayer().Pawn), ParseLevelName(Level.GetLocalURL()));
        if (LanCoopPawn(GetPlayer().Pawn) != None)
            LanCoopPawn(GetPlayer().Pawn).AppliedAppearance = None;
        Sleep(0.01);
    }
    // Do not run all these actor walks inside PostLogin. The local host's
    // HUD/possession work shares that event's runaway instruction budget.
    class'LanCoopLog'.static.WriteEvent(Self, "WorldStage", "RestoreDayAndErrands");
    RestoreDayAndErrands();
    RevealCampaignErrands();
    Sleep(0.01);
    class'LanCoopLog'.static.WriteEvent(Self, "WorldStage", "GameInfoIsNowValid");
    GameInfoIsNowValid();
    Sleep(0.01);
    class'LanCoopLog'.static.WriteEvent(Self, "WorldStage", "Environment");
    SetZoneFogPlanes();
    ChangeSkyByDay();
    Sleep(0.01);
    class'LanCoopLog'.static.WriteEvent(Self, "WorldStage", "PrepActorsByGroup");
    PrepActorsByGroup();
    Sleep(0.01);
    class'LanCoopLog'.static.WriteEvent(Self, "WorldStage", "PrepSliderPawns");
    PrepSliderPawns();
    Sleep(0.01);
    class'LanCoopLog'.static.WriteEvent(Self, "WorldStage", "PrepPickupsForErrands");
    PrepPickupsForErrands();
    Sleep(0.01);
    class'LanCoopLog'.static.WriteEvent(Self, "WorldStage", "RemoveGottenPickups");
    RemoveGottenPickups();
    bWorldPrepared = true;
    ApplyCoopDayLoadout(P2Pawn(GetPlayer().Pawn));
    SyncCampaignView();
    class'LanCoopLog'.static.WriteEvent(Self, "WorldReady", "Day=" $ TheGameState.CurrentDay
        $ " Errands=" $ Days[TheGameState.CurrentDay].NumErrands()
        $ " Active=" $ CampaignErrandMask(0) $ " Revealed=" $ CampaignErrandMask(1)
        $ " Locations=" $ CampaignErrandMask(2) $ " Completed=" $ CampaignErrandMask(3));
    GotoState('CoopRunning');
}

state CoopRunning
{
Begin:
    Sleep(1.0);
    if (GetPlayer() != None && GetPlayer().Pawn != None)
        CheckToRevivePawns();
    OfferCampaignBriefings();
    if (PendingErrandURL != "" && AllPlayersReady() && !AnyCoopScreenShowing())
    {
        SendPlayerTo(GetPlayer(), PendingErrandURL);
        PendingErrandURL = "";
    }
    Goto('Begin');
}

// Explicitly unavailable until shared-world travel and snapshots exist.
function bool SaveGame(int Slot, bool bShowMessage)
{
    class'LanCoopLog'.static.WriteEvent(Self, "Unimplemented", "SaveGame Slot=" $ Slot);
    return false;
}

function LoadGame(int Slot, bool bShowScreen)
{
    class'LanCoopLog'.static.WriteEvent(Self, "Unimplemented", "LoadGame Slot=" $ Slot);
}

function SendPlayerTo(PlayerController Player, string URL, optional bool bMaybePawnless)
{
    local string MapName, Portal;
    local int I;
    if (Player != None && Player.Pawn == None && bMaybePawnless && P2Player(Player) != None && P2Player(Player).MyPawn != None)
        Player.Possess(P2Player(Player).MyPawn);
    if (Player == None || !bWorldPrepared || bTravelQueued || Level.NextURL != "")
        return;
    if (!AllPlayersReady())
    {
        Player.ClientMessage("LAN Coop: wait until both players finish loading.");
        return;
    }
    // Keep the map and entry portal, discard SP peer/save and all supplied options.
    I = InStr(URL, "?");
    if (I >= 0)
        URL = Left(URL, I);
    I = InStr(URL, "#");
    if (I >= 0)
    {
        Portal = Mid(URL, I + 1);
        URL = Left(URL, I);
    }
    MapName = URL;
    if (Right(MapName, 4) ~= ".fuk")
        MapName = Left(MapName, Len(MapName) - 4);
    if (MapName == "" || InStr(MapName, ".") >= 0 || InStr(MapName, "/") >= 0
        || InStr(MapName, "\\") >= 0 || InStr(MapName, ":") >= 0 || !DoesMapExist(MapName $ ".fuk"))
    {
        Player.ClientMessage("LAN Coop: unknown or invalid map: " $ MapName);
        return;
    }
    PendingCoopURL = MapName $ ".fuk";
    PendingCoopURL = PendingCoopURL $ "?Game=LanCoop.LanCoopGameInfo?CoopTravel=1";
    PendingCoopURL = PendingCoopURL $ "?MaxPlayers=" $ MaxPlayers $ "?MaxSpectators=" $ MaxSpectators;
    if (bTravelProbe)
        PendingCoopURL = PendingCoopURL $ "?CoopTravelProbe=1?CoopProbeStage=" $ (TravelProbeStage + 1);
    // Explicitly clear an old entry when travelling without a portal;
    // relative network URLs otherwise inherit options from the last map.
    PendingCoopURL = SetURLOption(PendingCoopURL, "CoopEntry", Portal);
    PendingCoopURL = SetURLOption(PendingCoopURL, "CoopSession", CoopSessionId);
    if (Portal != "")
    {
        PendingCoopURL = PendingCoopURL $ "#" $ Portal;
    }
    TravelCarrier = GetPlayer();
    bTravelQueued = true;
    Broadcast(Self, "Travelling together to " $ MapName);
    GotoState('CoopTravelPending');
}

state CoopTravelPending
{
Begin:
    Sleep(0.01);
    class'LanCoopLog'.static.WriteEvent(Self, "TravelPrepare", "URL=" $ PendingCoopURL);
    TheGameState.PreLevelChange(P2Pawn(TravelCarrier.Pawn), ParseLevelName(Level.GetLocalURL()));
    Sleep(0.01);
    if (!TravelCarrier.Pawn.AddInventory(TheGameState))
    {
        class'LanCoopLog'.static.WriteEvent(Self, "TravelFailed", "Cannot attach shared world cargo");
        bTravelQueued = false;
        GotoState('CoopRunning');
    }
    Level.ServerTravel(PendingCoopURL, true);
}

function ProcessServerTravel(string URL, bool bItems)
{
    local PlayerController P, LocalPlayer;
    local string PlayerURL;
    local Texture LoadingBackground;
    local string EntryOptions;
    local int PortalIndex;
    EntryOptions = URL;
    PortalIndex = InStr(EntryOptions, "#");
    if (PortalIndex >= 0)
        EntryOptions = Left(EntryOptions, PortalIndex);
    // Both clients use the original campaign day's loading artwork.
    // Shell/native loading still measures each machine's own disk work.
    if (Days[NextDay()] != None)
        LoadingBackground = Days[NextDay()].GetLoadTexture();
    EndLogging("mapchange");
    foreach DynamicActors(class'PlayerController', P)
    {
        if (P.PlayerReplicationInfo == None)
            continue;
        PlayerURL = SetURLOption(URL, "Name", P.PlayerReplicationInfo.PlayerName);
        PlayerURL = SetURLOption(PlayerURL, "Class", "LanCoop.LanCoopPawn");
        if (LanCoopPlayer(P) != None)
            PlayerURL = SetURLOption(PlayerURL, "CoopId", LanCoopPlayer(P).CoopReconnectId);
        if (LanCoopPlayer(P) != None)
            LanCoopPlayer(P).ClientPrepareCoopTravel(LoadingBackground, URL, ParseOption(EntryOptions, "CoopEntry"));
        if (P.PlayerReplicationInfo.bOnlySpectator)
        {
            PlayerURL = SetURLOption(PlayerURL, "SpectatorOnly", "true");
            P.ClientTravel(PlayerURL, TRAVEL_Relative, false);
            continue;
        }
        if (P.Pawn == None)
            continue;
        PlayerURL = SetURLOption(PlayerURL, "SpectatorOnly", "false");
        P.Pawn.OwnerName = P.PlayerReplicationInfo.PlayerName;
        if (LanCoopPawn(P.Pawn) != None)
            LanCoopPawn(P.Pawn).RecordCoopTravelData();
        if (NetConnection(P.Player) != None)
            P.ClientTravel(PlayerURL, TRAVEL_Relative, true);
        else if (P.Player != None)
        {
            LocalPlayer = P;
            P.PreClientTravel();
            Level.NextURL = PlayerURL;
        }
        class'LanCoopLog'.static.WriteEvent(Self, "TravelSend", "Name=" $ P.PlayerReplicationInfo.PlayerName $ " Inventory=" $ P.Pawn.Inventory);
    }
    Level.NextSwitchCountdown = 1.0;
}

defaultproperties
{
    GameName="LAN Coop - Campaign Prototype"
    HUDType="LanCoop.LanCoopHUD"
    DefaultPlayerClassName="LanCoop.LanCoopPawn"
    PlayerControllerClassName="LanCoop.LanCoopPlayer"
    GameReplicationInfoClass=class'LanCoopReplicationInfo'
    MaxPlayers=2
    MaxSpectators=0
    bRestartLevel=false
    bDelayedStart=false
    bUseAutoSave=false
}
