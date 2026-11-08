class LanCoopPlayer extends AWDudePlayer;

var class<xMpPawn> SelectedAppearance;
var bool bCoopClientReady, bReadySent, bAwaitingTravelInventory;
var int CoopMusicHandles[9];
var string CoopArrivalPortal;
var bool bCoopScene, bCoopSceneObserver, bCoopSceneWasPlayer;
var bool bCoopSceneHUDHidden, bCoopSceneLetterbox;
var name CoopScenePreviousState;
var vector CoopSceneCameraLocation;
var rotator CoopSceneCameraRotation;
var float CoopScenePreviousFOV;
var bool bCoopSceneHasFrame, bCoopSkipPressed;
var float NextCoopInputLog;
var name LastCoopState;
var Pawn LastCoopPawn;
var float CoopArrivalGraceUntil;
var float CoopWantedPercent;

// The base readiness fix waits for Player, but our UI guards also require
// InteractionMaster. Do not permanently mark a skipped setup as complete.
simulated function CheckPlayerValid()
{
    if (!bPlayerIsValid && Player != None && Player.InteractionMaster != None)
    {
        NotifyPlayerValid();
        bPlayerIsValid = true;
        class'LanCoopLog'.static.WriteEvent(Self, "LocalPlayerInitialized", "InteractionMasterReady=true");
    }
}

// Keep the base client->server selection RPC, but only accept items owned
// by this pawn and actually present in its bounded inventory chain.
function ServerOnSelectedItem(Inventory UseInv)
{
    local Inventory Item;
    local int Count;
    if (Pawn == None || Powerups(UseInv) == None || UseInv.Owner != Pawn)
        return;
    for (Item = Pawn.Inventory; Item != None && Count < 5000; Item = Item.Inventory)
    {
        if (Item == UseInv)
        {
            Pawn.SelectedItem = Powerups(UseInv);
            return;
        }
        Count++;
    }
    class'LanCoopLog'.static.WriteEvent(Self, "InventorySelectionRejected", "Item=" $ UseInv $ " NotInOwnedChain=true");
}

function ResetCoopArrivalState()
{
    StuckTime = 0;
    StuckCheckRadius = STUCK_RADIUS;
    CoopArrivalGraceUntil = Level.TimeSeconds + 2.0;
}

function bool DetectStuckPlayer(float DeltaTime)
{
    if (Level.TimeSeconds < CoopArrivalGraceUntil)
    {
        StuckTime = 0;
        return false;
    }
    return Super.DetectStuckPlayer(DeltaTime);
}

exec function CoopDebugConsole(optional string Mode)
{
    if (Mode ~= "on")
        class'LanCoopLog'.Default.bConsole = true;
    else if (Mode ~= "off")
        class'LanCoopLog'.Default.bConsole = false;
    else
        class'LanCoopLog'.Default.bConsole = !class'LanCoopLog'.Default.bConsole;
    class'LanCoopLog'.static.StaticSaveConfig();
    if (Player != None && Player.Console != None)
        Player.Console.Message("CoopDebugConsole Enabled=" $ class'LanCoopLog'.Default.bConsole, 0);
}

function LogCoopInput(string EventName)
{
    local name MenuState;
    if (Player == None || Player.InteractionMaster == None)
        return;
    if (Player.InteractionMaster.BaseMenu != None)
        MenuState = Player.InteractionMaster.BaseMenu.GetStateName();
    class'LanCoopLog'.static.WriteEvent(Self, EventName,
        "State=" $ GetStateName() $ " Pawn=" $ Pawn $ " MyPawn=" $ MyPawn
        $ " ViewTarget=" $ ViewTarget $ " Screen=" $ CurrentScreen
        $ " MenuState=" $ MenuState
        $ " WindowsMouse=" $ Player.bShowWindowsMouse
        $ " Rotation=" $ Rotation $ " Shake=" $ ShakeRot
        $ " MoveForward=" $ aForward $ " MoveStrafe=" $ aStrafe);
}

exec function Fire(optional float F)
{
    LogCoopInput("PrimaryFireRequested");
    Super.Fire(F);
}

exec function AltFire(optional float F)
{
    LogCoopInput("SecondaryFireRequested");
    Super.AltFire(F);
}

function ClientRestart()
{
    Super.ClientRestart();
    LogCoopInput("PlayerRestarted");
}

replication
{
    reliable if (Role < ROLE_Authority)
        ServerSetAppearance, ServerCoopMap, ServerCoopReady, ServerCoopSceneSkip;
    reliable if (Role == ROLE_Authority)
        CoopWantedPercent;
    reliable if (Role == ROLE_Authority)
        ClientProbeInventory, ClientProbeCombat, ClientCoopMusic, ClientStopCoopMusic, ClientClearCoopMusic,
        ClientBeginCoopScene, ClientEndCoopScene, ClientPrepareCoopTravel,
        ClientConfirmCoopArrival;
    unreliable if (Role == ROLE_Authority)
        ClientCoopSceneFrame;
}

function ClientPrepareCoopTravel(Texture Background, string Destination, string EntryPortal)
{
    local LanCoopRootWindow Root;
    if (Player == None || Player.InteractionMaster == None)
        return;
    Root = LanCoopRootWindow(Player.InteractionMaster.BaseMenu);
    if (Root != None)
        Root.BeginCoopLoading(Background, Destination);
    class'LanCoopLog'.static.WriteEvent(Self, "LoadingPrepared", "Destination=" $ Destination $ " Portal=" $ EntryPortal $ " Background=" $ Background);
}

function ClientConfirmCoopArrival(vector NewLocation, rotator NewRotation, string EntryPortal, bool bGroundedArrival)
{
    local LanCoopRootWindow Root;
    if (Pawn == None)
        return;
    CoopArrivalPortal = EntryPortal;
    // The acknowledgement arrives after the owning client has its pawn.
    // Discard prediction recorded around its provisional spawn position.
    CleanOutSavedMoves();
    ClientSetLocation(NewLocation, NewRotation);
    // Only a verified portal-floor placement may force walking physics.
    // Direct travel and scripted airborne starts retain native physics.
    if (bGroundedArrival)
    {
        Pawn.Velocity = vect(0,0,0);
        Pawn.SetPhysics(PHYS_Walking);
    }
    ResetCoopArrivalState();
    if (Player != None && Player.InteractionMaster != None)
    {
        Root = LanCoopRootWindow(Player.InteractionMaster.BaseMenu);
        if (Root != None)
            Root.EndCoopLoading();
    }
    class'LanCoopLog'.static.WriteEvent(Self, "ArrivalConfirmed", "Portal=" $ EntryPortal $ " Requested=" $ NewLocation $ " Actual=" $ Pawn.Location);
}

simulated function StartCutscene()
{
    Super.StartCutscene();
    if (Role == ROLE_Authority && LanCoopGameInfo(Level.Game) != None)
        LanCoopGameInfo(Level.Game).StartCoopScene(Self, GetCurrentSceneManager());
}

function BeginCoopScene(bool bObserver)
{
    if (bCoopScene)
        return;
    bCoopScene = true;
    bCoopSceneObserver = bObserver;
    CoopScenePreviousState = GetStateName();
    if (bObserver && P2Pawn(Pawn) != None)
    {
        bCoopSceneWasPlayer = P2Pawn(Pawn).bPlayer;
        // Keep extra players out of proximity dialogue while the original
        // scripted actor performs the scene.
        P2Pawn(Pawn).bPlayer = false;
        Pawn.Velocity = vect(0,0,0);
        Pawn.Acceleration = vect(0,0,0);
        GotoState('CoopWatchingScene');
    }
}

function EndCoopScene()
{
    if (bCoopSceneObserver)
    {
        if (P2Pawn(Pawn) != None)
            P2Pawn(Pawn).bPlayer = bCoopSceneWasPlayer;
        if (IsInState('CoopWatchingScene'))
            GotoState(CoopScenePreviousState);
    }
    bCoopSceneObserver = false;
    bCoopScene = false;
}

function ClientBeginCoopScene(bool bOriginalViewer)
{
    // Listen host also receives this locally; server observer state is kept.
    CoopScenePreviousFOV = FOVAngle;
    if (MyHUD != None)
    {
        bCoopSceneHUDHidden = MyHUD.bHideHUD;
        bCoopSceneLetterbox = MyHUD.bCinematicView;
        if (bOriginalViewer && Role == ROLE_Authority)
        {
            // SceneStarted already hid the native viewer's HUD.
            bCoopSceneHUDHidden = false;
            bCoopSceneLetterbox = false;
        }
        MyHUD.bHideHUD = true;
    }
    if (Role < ROLE_Authority)
        BeginCoopScene(true);
    class'LanCoopLog'.static.WriteEvent(Self, "SceneClientBegin", "");
}

function ClientCoopSceneFrame(vector CameraLocation, rotator CameraRotation, float CameraFOV, bool bLetterbox)
{
    if (!bCoopScene)
        return;
    CoopSceneCameraLocation = CameraLocation;
    CoopSceneCameraRotation = CameraRotation;
    bCoopSceneHasFrame = true;
    FOVAngle = CameraFOV;
    if (MyHUD != None)
        MyHUD.bCinematicView = bLetterbox;
}

function ClientEndCoopScene()
{
    if (Role < ROLE_Authority)
        EndCoopScene();
    FOVAngle = CoopScenePreviousFOV;
    bCoopSceneHasFrame = false;
    bCoopSkipPressed = false;
    if (MyHUD != None)
    {
        MyHUD.bHideHUD = bCoopSceneHUDHidden;
        MyHUD.bCinematicView = bCoopSceneLetterbox;
    }
    class'LanCoopLog'.static.WriteEvent(Self, "SceneClientEnd", "");
}

function GetOriginalSceneView(out actor ViewActor, out vector CameraLocation, out rotator CameraRotation)
{
    Super.PlayerCalcView(ViewActor, CameraLocation, CameraRotation);
}

event PlayerCalcView(out actor ViewActor, out vector CameraLocation, out rotator CameraRotation)
{
    if (bCoopScene && bCoopSceneHasFrame)
    {
        ViewActor = Self;
        CameraLocation = CoopSceneCameraLocation;
        CameraRotation = CoopSceneCameraRotation;
        return;
    }
    Super.PlayerCalcView(ViewActor, CameraLocation, CameraRotation);
}

function ServerCoopSceneSkip()
{
    local LanCoopSceneRelay Relay;
    if (LanCoopGameInfo(Level.Game) == None)
        return;
    Relay = LanCoopGameInfo(Level.Game).SceneRelay;
    // Let the original engine enforce skip/fast-forward permissions.
    if (Relay != None && Relay.Source != None && Relay.Scene != None && Relay.Scene.bIsRunning)
        Relay.Source.bWantsToSkip = 1;
}

state CoopWatchingScene
{
    ignores Fire, AltFire, DoKick, InventoryMenu, SwitchWeapon;
    function PlayerMove(float DeltaTime) {}
    function ProcessMove(float DeltaTime, vector NewAccel, eDoubleClickDir DoubleClickMove, rotator DeltaRot) {}
}

function ServerCoopReady()
{
    if (Pawn != None && PlayerReplicationInfo != None)
    {
        if (LanCoopPawn(Pawn) != None)
            LanCoopPawn(Pawn).RestoreCombatReferences();
        bCoopClientReady = true;
        if (LanCoopGameInfo(Level.Game) != None)
        {
            if (LanCoopGameInfo(Level.Game).bExpectTravelState)
                ClientConfirmCoopArrival(Pawn.Location, Rotation,
                    LanCoopGameInfo(Level.Game).ResolveCoopArrivalPortal(CoopArrivalPortal, ""),
                    LanCoopPawn(Pawn) != None && LanCoopPawn(Pawn).bCoopArrivalPlaced);
            LanCoopGameInfo(Level.Game).SyncMusicTo(Self);
        }
        class'LanCoopLog'.static.WriteEvent(Self, "ClientReady", "Name=" $ PlayerReplicationInfo.PlayerName);
    }
}

function ClientCoopMusic(int Slot, string Song, float Fade, float VolumeOverride, bool bAllowPause)
{
    if (Slot < 0 || Slot >= ArrayCount(CoopMusicHandles))
        return;
    if (CoopMusicHandles[Slot] != 0)
        StopMusic(CoopMusicHandles[Slot], Fade);
    CoopMusicHandles[Slot] = PlayMusic(Song, Fade, VolumeOverride, bAllowPause);
    class'LanCoopLog'.static.WriteEvent(Self, "MusicPlay", "Song=" $ Song $ " Slot=" $ Slot);
}

function ClientStopCoopMusic(int Slot, float Fade)
{
    if (Slot >= 0 && Slot < ArrayCount(CoopMusicHandles) && CoopMusicHandles[Slot] != 0)
    {
        StopMusic(CoopMusicHandles[Slot], Fade);
        CoopMusicHandles[Slot] = 0;
    }
}

function ClientClearCoopMusic(float Fade)
{
    local int I;
    StopAllMusic(Fade);
    for (I = 0; I < ArrayCount(CoopMusicHandles); I++)
        CoopMusicHandles[I] = 0;
    class'LanCoopLog'.static.WriteEvent(Self, "MusicCleared", "");
}

function ClientProbeCombat()
{
    if (MyPawn == None || MyPawn.MyFoot == None || MyPawn.MyUrethra == None)
    {
        class'LanCoopLog'.static.WriteEvent(Self, "CombatClientCheckFailed", "Missing foot or urethra");
        return;
    }
    DoKick();
    class'LanCoopLog'.static.WriteEvent(Self, "CombatClientCheckOk", "Name=" $ PlayerReplicationInfo.PlayerName $ " Foot=" $ MyPawn.MyFoot $ " State=" $ MyPawn.MyFoot.GetStateName());
}

function PlayerTick(float DeltaTime)
{
    if (bCoopScene)
    {
        if (bWantsToSkip != 0 && !bCoopSkipPressed)
            ServerCoopSceneSkip();
        bCoopSkipPressed = bWantsToSkip != 0;
    }
    Super.PlayerTick(DeltaTime);
    if (Player != None && Player.InteractionMaster != None
        && (LastCoopState != GetStateName() || LastCoopPawn != Pawn || Level.TimeSeconds >= NextCoopInputLog))
    {
        LogCoopInput("PlayerInputState");
        LastCoopState = GetStateName();
        LastCoopPawn = Pawn;
        NextCoopInputLog = Level.TimeSeconds + 3.0;
    }
    if (!bReadySent && Pawn != None && MyPawn != None && PlayerReplicationInfo != None
        && PlayerReplicationInfo.PlayerName != "" && Player != None && Player.InteractionMaster != None)
    {
        bReadySent = true;
        ServerCoopReady();
    }
}

exec function InventoryMenu()
{
    if (Pawn == None || Player == None || Player.InteractionMaster == None)
        return;
    if (InventorySelector == None)
        AddInventorySelector();
    Super.InventoryMenu();
}

// Used only by the opt-in round-trip integration test.
function ClientProbeInventory()
{
    InventoryMenu();
    if (InventorySelector != None && InventorySelector.bMenuVisible)
    {
        class'LanCoopLog'.static.WriteEvent(Self, "InventoryClientCheckOk", "Name=" $ PlayerReplicationInfo.PlayerName $ " NetMode=" $ Level.NetMode);
        InventorySelector.HideMenu();
    }
    else
        class'LanCoopLog'.static.WriteEvent(Self, "InventoryClientCheckFailed", "");
}

exec function CoopMap(string MapName)
{
    ServerCoopMap(MapName);
}

exec function CoopStatus()
{
    local LanCoopReplicationInfo R;
    R = LanCoopReplicationInfo(GameReplicationInfo);
    if (R != None)
        ClientMessage("Coop map=" $ R.CampaignMap $ " day=" $ (R.CampaignDay + 1) $ " completed mask=" $ R.CompletedTaskMask);
    else
        ClientMessage("Coop state is still loading.");
}

function ServerCoopMap(string MapName)
{
    if (LanCoopGameInfo(Level.Game) == None)
        return;
    if (NetConnection(Player) != None && (PlayerReplicationInfo == None || !PlayerReplicationInfo.bAdmin))
    {
        ClientMessage("Only the host or an administrator can use CoopMap.");
        return;
    }
    LanCoopGameInfo(Level.Game).SendPlayerTo(Self, MapName);
}

function ServerSetAppearance(string ClassName)
{
    local class<xMpPawn> Appearance;
    if (Len(ClassName) > 80 || !(Left(ClassName, 11) ~= "MultiStuff."))
        return;
    Appearance = class<xMpPawn>(DynamicLoadObject(ClassName, class'Class', true));
    if (Appearance == None)
        return;
    SelectedAppearance = Appearance;
    if (LanCoopPawn(Pawn) != None && LanCoopPawn(Pawn).CoopAppearance != Appearance)
        LanCoopPawn(Pawn).SetCoopAppearance(Appearance);
}

function SetupInteractions()
{
    if (Player != None && Player.InteractionMaster != None)
        Super.SetupInteractions();
}

function float ApplyAspectRatio(float FOV)
{
    if (Player == None || Player.InteractionMaster == None)
        return FOV;
    return Super.ApplyAspectRatio(FOV);
}

function SetupCatnipUseage(float StartTime)
{
    if (P2HUD(MyHUD) != None)
        Super.SetupCatnipUseage(StartTime);
    else
        CatnipUseTime = StartTime;
}

function SetupDualWielding(float StartTime)
{
    if (Pawn != None && Pawn.Weapon != None)
        Super.SetupDualWielding(StartTime);
    else
        DualWieldUseTime = StartTime;
}

// Server-side remote controllers have no local InteractionMaster.
function SetupScreens()
{
    if (Player != None && Player.InteractionMaster != None)
        Super.SetupScreens();
}

function AddWeaponSelector()
{
    if (Player != None && Player.InteractionMaster != None)
        Super.AddWeaponSelector();
}

function AddInventorySelector()
{
    if (Player != None && Player.InteractionMaster != None)
        Super.AddInventorySelector();
}

event TravelPostAccept()
{
    // Engine network login handles possession and initial loadout. Do not
    // run SP travel code that assumes local screens and restores world state.
    if (Role == ROLE_Authority && LanCoopGameInfo(Level.Game) != None)
        LanCoopGameInfo(Level.Game).PostTravel(MyPawn);
}

// The singleplayer walking state otherwise enters a local-screen wait even
// when autosaving is disabled. Coop saving will have its own lifecycle.
function CheckPrepForSave()
{
}

defaultproperties
{
    InventorySelectorClassName="LanCoop.LanCoopInventorySelector"
    InventorySelectorName=LanCoopInventorySelector
    CustomInventorySelectorClassName=""
    CustomInventorySelectorName=""
}
