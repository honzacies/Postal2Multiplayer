// Opt-in authoritative integration probe. These controllers have no network
// connections; this does not replace testing two real graphical clients.
class LanCoopLifecycleProbe extends Info;

var PlayerController First, Second;
var GameState World;
var Inventory FirstInventory;
var int ReadyAttempts;

function bool CheckWantedOwnership(LanCoopGameInfo G)
{
    local P2Pawn TestCop;
    local LanCoopPoliceController Cop;
    local float Previous;
    local byte StateChange;
    local bool bPassed;
    TestCop = Spawn(class'LanCoopWantedProbeCop',,, First.Pawn.Location + vect(0,0,256));
    if (TestCop == None)
        return false;
    if (TestCop.Controller == None)
    {
        TestCop.Controller = Spawn(TestCop.ControllerClass);
        TestCop.Controller.Possess(TestCop);
    }
    Cop = LanCoopPoliceController(TestCop.Controller);
    if (Cop == None)
    {
        class'LanCoopLog'.static.WriteEvent(Self, "WantedCheckFailed", "Police controller was not adapted");
        TestCop.Destroy();
        return false;
    }
    Cop.GotoState('');
    LanCoopPawn(First.Pawn).CoopWantedTime = 0;
    LanCoopPawn(Second.Pawn).CoopWantedTime = 0;
    Cop.ReportAsWanted(FPSPawn(Second.Pawn), true);
    bPassed = LanCoopPawn(First.Pawn).CoopWantedTime == 0
        && LanCoopPawn(Second.Pawn).CoopWantedTime == G.TheGameState.CopRadioBase
        && LanCoopPlayer(First).CoopWantedPercent == 0
        && LanCoopPlayer(Second).CoopWantedPercent > 0
        && G.TheGameState.CopRadioTime == 0;
    // An innocent host bump must not enter wanted-driven arrest logic.
    Cop.SetAttacker(None);
    Cop.PlayerAttackedMe = None;
    Cop.DangerPawnBump(First.Pawn, StateChange);
    bPassed = bPassed && StateChange == 0 && Cop.Attacker != First.Pawn;
    StateChange = 0;
    Cop.DangerPawnBump(Second.Pawn, StateChange);
    bPassed = bPassed && StateChange == 1 && Cop.Attacker == Second.Pawn;
    // Reverse the roles with the same cop: report dedup must not lose a player.
    Cop.GotoState('');
    Cop.ReportAsWanted(FPSPawn(First.Pawn), false);
    bPassed = bPassed && LanCoopPawn(First.Pawn).CoopWantedTime > 0;
    Previous = class'LanCoopWanted'.static.BeginCheck(Cop, FPSPawn(First.Pawn));
    class'LanCoopWanted'.static.EndCheck(Cop, Previous);
    bPassed = bPassed && G.TheGameState.CopRadioTime == 0;
    LanCoopPawn(First.Pawn).CoopWantedTime = 0;
    LanCoopPawn(Second.Pawn).CoopWantedTime = 0;
    LanCoopPlayer(First).CoopWantedPercent = 0;
    LanCoopPlayer(Second).CoopWantedPercent = 0;
    Cop.Destroy();
    TestCop.Destroy();
    if (bPassed)
        class'LanCoopLog'.static.WriteEvent(Self, "WantedOwnershipCheckOk", "ClientAndHostSeparated InnocentBumpIgnored SuspectBumpRecognized=true");
    return bPassed;
}

function bool CheckInventorySelection()
{
    local Inventory FirstItem, SecondItem;
    local Powerups Before;
    FirstItem = First.Pawn.FindInventoryType(class'MoneyInv');
    SecondItem = Second.Pawn.FindInventoryType(class'MoneyInv');
    if (Powerups(FirstItem) == None || Powerups(SecondItem) == None)
        return false;
    Before = Second.Pawn.SelectedItem;
    LanCoopPlayer(Second).ServerOnSelectedItem(SecondItem);
    if (Second.Pawn.SelectedItem != SecondItem)
        return false;
    LanCoopPlayer(Second).ServerOnSelectedItem(FirstItem);
    if (Second.Pawn.SelectedItem != SecondItem)
        return false;
    Second.Pawn.SelectedItem = Before;
    class'LanCoopLog'.static.WriteEvent(Self, "InventorySelectionCheckOk", "OwnedAccepted OtherPlayerRejected=true");
    return true;
}

function bool CheckQuestContext(LanCoopGameInfo G)
{
    local LanCoopMissionTrigger Marker;
    local bool bPassed;
    Marker = Spawn(class'LanCoopMissionTrigger');
    if (Marker == None)
        return false;
    Marker.Tag = 'LanCoopContextProbe';
    Marker.bSpawnContextProbe = true;
    G.DispatchCoopQuestEvent(Marker.Tag, P2Player(Second));
    bPassed = Marker.Calls == 1 && Marker.LastPawn == Second.Pawn
        && Marker.ContextPlayer == Second && Marker.StartedController != None;
    if (bPassed)
        bPassed = Marker.StartedController.MyPlayerController == Second
            && Marker.StartedController.Instigator == Second.Pawn
            && G.GetPlayer() == First;
    if (Marker.StartedController != None)
        Marker.StartedController.Destroy();
    Marker.Destroy();
    if (bPassed)
        class'LanCoopLog'.static.WriteEvent(Self, "QuestContextCheckOk", "ClientInstigatorAndScriptTargetPreserved HostReferenceRestored=true");
    return bPassed;
}

function bool CheckArrivalPlacement(LanCoopGameInfo G)
{
    local Telepad Pad;
    local Telemarketer Marker;
    local vector BeforeLocation, Separation;
    local EPhysics BeforePhysics;
    local bool bPlaced, bPassed;
    Pad = Spawn(class'LanCoopProbeTelepad');
    Marker = Spawn(class'LanCoopProbeTelemarketer',,, First.Pawn.Location);
    if (Pad == None || Marker == None)
        return false;
    Pad.TMarker = Marker;
    BeforeLocation = Second.Pawn.Location;
    BeforePhysics = Second.Pawn.Physics;
    bPlaced = G.PlaceCoopArrival(P2Pawn(Second.Pawn), Pad);
    Separation = Second.Pawn.Location - First.Pawn.Location;
    Separation.Z = 0;
    bPassed = bPlaced && VSize(Separation) >= First.Pawn.CollisionRadius + Second.Pawn.CollisionRadius
        && Second.Pawn.Physics == PHYS_Walking;
    if (bPassed)
    {
        Second.Pawn.SetPhysics(PHYS_Falling);
        LanCoopPlayer(Second).ClientConfirmCoopArrival(Second.Pawn.Location, Second.Rotation, "", false);
        bPassed = Second.Pawn.Physics == PHYS_Falling;
        LanCoopPlayer(Second).ClientConfirmCoopArrival(Second.Pawn.Location, Second.Rotation, "probe", true);
        bPassed = bPassed && Second.Pawn.Physics == PHYS_Walking;
    }
    Second.Pawn.SetLocation(BeforeLocation);
    Second.Pawn.SetPhysics(BeforePhysics);
    Pad.Destroy();
    Marker.Destroy();
    if (bPassed)
        class'LanCoopLog'.static.WriteEvent(Self, "ArrivalPlacementCheckOk", "OccupiedCenterAvoided WalkingPhysicsRestored=true");
    return bPassed;
}

function bool CheckArrivalPortal(LanCoopGameInfo G)
{
    local string BeforePortal;
    local bool bPassed;
    BeforePortal = G.CoopMapPortal;
    G.CoopMapPortal = "pod1";
    bPassed = G.ResolveCoopArrivalPortal("", "") == "pod1"
        && G.ResolveCoopArrivalPortal("pod2", "") == "pod2"
        && G.ResolveCoopArrivalPortal("", "?CoopEntry=pod3") == "pod3"
        && G.ResolveCoopArrivalPortal("pod2", "?CoopEntry=pod3") == "pod3";
    G.CoopMapPortal = BeforePortal;
    if (bPassed)
        class'LanCoopLog'.static.WriteEvent(Self, "ArrivalPortalCheckOk", "EmptyRemotePortalUsesSharedEntry ExplicitEntryWins=true");
    return bPassed;
}

function bool CheckSceneCamera()
{
    local LanCoopPlayer P;
    local actor ViewActor;
    local vector CameraLocation;
    local rotator CameraRotation;
    local name BeforeState;
    local bool BeforePlayerFlag;
    P = LanCoopPlayer(Second);
    BeforeState = P.GetStateName();
    BeforePlayerFlag = P2Pawn(P.Pawn).bPlayer;
    P.BeginCoopScene(true);
    P.ClientBeginCoopScene(false);
    P.ClientCoopSceneFrame(vect(100,200,300), rot(1024,2048,0), 77, true);
    P.PlayerCalcView(ViewActor, CameraLocation, CameraRotation);
    if (!P.IsInState('CoopWatchingScene') || CameraLocation != vect(100,200,300)
        || CameraRotation != rot(1024,2048,0) || P.FOVAngle != 77
        || P2Pawn(P.Pawn).bPlayer)
        return false;
    P.EndCoopScene();
    P.ClientEndCoopScene();
    if (P.bCoopScene || P.bCoopSceneHasFrame || P.GetStateName() != BeforeState
        || P2Pawn(P.Pawn).bPlayer != BeforePlayerFlag)
        return false;
    class'LanCoopLog'.static.WriteEvent(Self, "SceneCameraCheckOk", "CameraAndControlRestored NativeMatineeNotCovered=true");
    return true;
}

function bool CheckDayExit(LanCoopGameInfo G)
{
    local int I, N, Active, SavedCounter;
    if (G.TheGameState.CompletedErrands.Length != 0)
        return false;
    SavedCounter = G.TheGameState.ErrandsCompletedToday;
    G.TheGameState.ErrandsCompletedToday = 999;
    if (G.IsPlayerReadyForHome())
        return false;
    for (I = 0; I < G.Days[0].Errands.Length; I++)
        if (G.Days[0].Errands[I] != None && G.Days[0].Errands[I].IsActive())
        {
            N = G.TheGameState.CompletedErrands.Length;
            G.TheGameState.CompletedErrands.Length = N + 1;
            G.TheGameState.CompletedErrands[N].Day = 0;
            G.TheGameState.CompletedErrands[N].Errand = I;
            Active++;
            if (Active == 1 && G.IsPlayerReadyForHome())
                return false;
        }
    if (Active < 3 || !G.IsPlayerReadyForHome())
        return false;
    G.TheGameState.CompletedErrands.Length = 0;
    G.TheGameState.ErrandsCompletedToday = SavedCounter;
    class'LanCoopLog'.static.WriteEvent(Self, "DayExitCheckOk", "IncompleteAndInflatedCounterBlocked AllActiveCompleteAllowed Active=" $ Active);
    return true;
}

event PostBeginPlay()
{
    Super.PostBeginPlay();
    SetTimer(1.0, false);
}

event Timer()
{
    local LanCoopGameInfo G;
    local string Error;
    local Inventory BeforeAppearance;
    local int BeforeHealth;

    G = LanCoopGameInfo(Level.Game);
    if (G == None)
    {
        class'LanCoopLog'.static.WriteEvent(Self, "LifecycleFailed", "No GameInfo");
        return;
    }
    if (Second != None)
    {
        if (!G.bWorldPrepared && ReadyAttempts++ < 50)
        {
            SetTimer(0.1, false);
            return;
        }
        G.PostTravel(P2Pawn(First.Pawn));
        G.PostTravel(P2Pawn(Second.Pawn));
        if (G.TheGameState != World || G.bLoadedSavedGame || !G.bWorldPrepared
            || G.GetPlayer() != First || FirstInventory == None
            || First.Pawn.Inventory != FirstInventory || G.NumPlayers != 2)
        {
            class'LanCoopLog'.static.WriteEvent(Self, "LifecycleFailed", "World/player state changed on second join");
            return;
        }
        if (!CheckWantedOwnership(G))
        {
            class'LanCoopLog'.static.WriteEvent(Self, "LifecycleFailed", "Wanted ownership or police suspect selection");
            return;
        }
        if (!CheckInventorySelection())
        {
            class'LanCoopLog'.static.WriteEvent(Self, "LifecycleFailed", "Inventory selection ownership");
            return;
        }
        if (!CheckQuestContext(G) || !CheckArrivalPlacement(G))
        {
            class'LanCoopLog'.static.WriteEvent(Self, "LifecycleFailed", "Quest context or occupied arrival placement");
            return;
        }
        if (!CheckArrivalPortal(G))
        {
            class'LanCoopLog'.static.WriteEvent(Self, "LifecycleFailed", "Arrival portal resolution");
            return;
        }
        if (!CheckSceneCamera())
        {
            class'LanCoopLog'.static.WriteEvent(Self, "LifecycleFailed", "Scene camera/control state");
            return;
        }
        if (!CheckDayExit(G))
        {
            class'LanCoopLog'.static.WriteEvent(Self, "LifecycleFailed", "Premature day exit guard");
            return;
        }
        class'LanCoopLog'.static.WriteEvent(Self, "LifecycleOk", "Players=" $ G.NumPlayers $ " World=" $ World $ " First=" $ First.Pawn $ " Second=" $ Second.Pawn);
        return;
    }
    World = G.TheGameState;
    First = G.Login("", "?Name=ProbeOne?Class=GameTypes.AWPostalDude", Error);
    if (First == None || Error != "")
    {
        class'LanCoopLog'.static.WriteEvent(Self, "LifecycleFailed", "First login: " $ Error);
        return;
    }
    G.PostLogin(First, "?Name=ProbeOne");
    if (First.Pawn == None)
    {
        class'LanCoopLog'.static.WriteEvent(Self, "LifecycleFailed", "First pawn missing");
        return;
    }
    FirstInventory = First.Pawn.Inventory;
    Second = G.Login("", "?Name=ProbeTwo?Class=GameTypes.AWPostalDude", Error);
    if (Second == None || Error != "")
    {
        class'LanCoopLog'.static.WriteEvent(Self, "LifecycleFailed", "Second login: " $ Error);
        return;
    }
    G.PostLogin(Second, "?Name=ProbeTwo");
    if (Second.Pawn == None || First.Pawn == Second.Pawn || First.Pawn.Health <= 0)
    {
        class'LanCoopLog'.static.WriteEvent(Self, "LifecycleFailed", "Invalid second pawn or spawn killed first player");
        return;
    }
    BeforeAppearance = Second.Pawn.Inventory;
    BeforeHealth = Second.Pawn.Health;
    LanCoopPlayer(Second).ServerSetAppearance("MultiStuff.MpBandmember");
    if (LanCoopPawn(Second.Pawn).CoopAppearance != class'MultiStuff.MpBandmember'
        || Second.Pawn.Skins[0] != class'MultiStuff.MpBandmember'.Default.Skins[0]
        || Second.Pawn.Inventory != BeforeAppearance || Second.Pawn.Health != BeforeHealth)
    {
        class'LanCoopLog'.static.WriteEvent(Self, "LifecycleFailed", "Appearance change altered inventory/health or did not apply");
        return;
    }
    LanCoopPlayer(Second).ServerSetAppearance("GameTypes.AWPostalDude");
    if (LanCoopPawn(Second.Pawn).CoopAppearance != class'MultiStuff.MpBandmember')
    {
        class'LanCoopLog'.static.WriteEvent(Self, "LifecycleFailed", "Unapproved appearance class accepted");
        return;
    }
    class'LanCoopLog'.static.WriteEvent(Self, "AppearanceCheckOk", "InventoryAndHealthPreserved");
    if (LanCoopHead(LanCoopPawn(Second.Pawn).MyHead) == None
        || LanCoopHead(LanCoopPawn(Second.Pawn).MyHead).HeadSkinIndex != 0
        || LanCoopPawn(Second.Pawn).MyHead.Skins[0] != class'MultiStuff.MpBandmember'.Default.HeadSkin)
    {
        class'LanCoopLog'.static.WriteEvent(Self, "LifecycleFailed", "Head missing or wrong material slot");
        return;
    }
    class'LanCoopLog'.static.WriteEvent(Self, "HeadCheckOk", "NormalHeadUsesSlotZero");
    SetTimer(0.1, false);
}

defaultproperties
{
    RemoteRole=ROLE_None
}
