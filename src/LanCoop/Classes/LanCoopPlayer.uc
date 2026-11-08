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
var LanCoopCameraBuffer CoopCameraBuffer;
var float NextCoopInputLog;
var name LastCoopState;
var Pawn LastCoopPawn;
var float CoopArrivalGraceUntil;
var float CoopWantedPercent;
var Texture PendingCoopNewsTexture;
var Sound PendingCoopNewsComment;
var bool bPendingCoopNews, bPendingCoopNewsMustWait;
var bool bCoopNewsOffered, bCoopNewsReading;
var name CoopBeforeNewsState;
var LanCoopMapScreen CoopMapScreen;
var string CoopReconnectId;
var bool bCoopReconnectRestored;
var bool bCoopTravelLogin;
var Texture LastCoopMapTexture;
var int LastCoopMapIconCount;
var int CoopBriefedDay, CoopBriefedMask;
var int CoopBriefingSentDay, CoopBriefingSentMask;
var float CoopBriefingSentAt;
var LanCoopAttachmentGuard AttachmentGuard;
var bool bCoopAppearanceRefreshPending;
var Weapon CoopAppearanceWeapon;
var P2Weapon CoopAppearanceFoot, CoopAppearanceUrethra;

function ClientRefreshCoopAppearance(Weapon HeldWeapon, P2Weapon Foot, P2Weapon Urethra)
{
    CoopAppearanceWeapon = HeldWeapon;
    CoopAppearanceFoot = Foot;
    CoopAppearanceUrethra = Urethra;
    bCoopAppearanceRefreshPending = true;
}

function FinishCoopAppearanceRefresh()
{
    local LanCoopRootWindow R;
    local Inventory Item;
    local int Count;
    if (Pawn == None || Player == None || Player.InteractionMaster == None || bCoopScene)
        return;
    R = LanCoopRootWindow(Player.InteractionMaster.BaseMenu);
    if (R != None && (R.IsMenuShowing() || R.bCoopLoading))
        return;
    // Never rebuild or grant inventory as part of a cosmetic change.
    for (Item = Pawn.Inventory; Item != None && Count < 5000; Item = Item.Inventory)
        Count++;
    if (Item != None || Pawn.Inventory == None)
        return;
    MyPawn = P2MoCapPawn(Pawn);
    MyPawn.bPlayer = true;
    MyPawn.ClientPlayerStartingFinished();
    if (CoopAppearanceFoot != None && CoopAppearanceFoot.Owner == Pawn)
        MyPawn.ClientSetFoot(CoopAppearanceFoot);
    if (CoopAppearanceUrethra != None && CoopAppearanceUrethra.Owner == Pawn)
        MyPawn.ClientSetUrethra(CoopAppearanceUrethra);
    if (CoopAppearanceWeapon != None && CoopAppearanceWeapon.Owner == Pawn)
    {
        CoopAppearanceWeapon.Instigator = Pawn;
        if (Pawn.Weapon == None || Pawn.Weapon.bDeleteMe)
            CoopAppearanceWeapon.ClientWeaponSet(false);
        if (CoopAppearanceWeapon.IsInState('PendingClientWeaponSet'))
            CoopAppearanceWeapon.ClientWeaponSet(false);
    }
    AddWeaponSelector();
    AddInventorySelector();
    if (WeaponSelector != None)
        WeaponSelector.RefreshSelector();
    bCoopAppearanceRefreshPending = false;
    class'LanCoopLog'.static.WriteEvent(Self, "AppearanceControlsRefreshed", "Player=" $ PlayerReplicationInfo.PlayerName $ " State=" $ GetStateName() $ " Weapon=" $ Pawn.Weapon $ " Items=" $ Count);
}

static function string CoopSpeakerName(Actor Speaker)
{
    local int Depth;
    local Pawn P;
    for (Depth = 0; Speaker != None && Depth < 6; Depth++)
    {
        P = Pawn(Speaker);
        if (P != None && P.PlayerReplicationInfo != None)
            return P.PlayerReplicationInfo.PlayerName;
        if (LanCoopPlayer(Speaker) != None && LanCoopPlayer(Speaker).PlayerReplicationInfo != None)
            return LanCoopPlayer(Speaker).PlayerReplicationInfo.PlayerName;
        if (Speaker.Owner != None)
            Speaker = Speaker.Owner;
        else
            Speaker = Speaker.Base;
    }
    return "";
}

event CallSubtitle(Sound SpokenSound, int Index, int ActorIndex, Actor Speaker)
{
    local LanCoopHUD H;
    local string Previous;
    H = LanCoopHUD(MyHUD);
    if (H != None)
    {
        Previous = H.CoopSubtitleSpeaker;
        H.CoopSubtitleSpeaker = CoopSpeakerName(Speaker);
    }
    // Preserve the stock text, language, duration, priority and sound filtering.
    Super.CallSubtitle(SpokenSound, Index, ActorIndex, Speaker);
    if (H != None)
        H.CoopSubtitleSpeaker = Previous;
}

simulated event Destroyed()
{
    local LanCoopGameInfo G;
    if (Role == ROLE_Authority)
    {
        G = LanCoopGameInfo(Level.Game);
        if (G != None && G.ReconnectStore != None && !G.bTravelQueued && Pawn != None && Pawn.Health > 0)
        {
            G.ReconnectStore.Capture(G, Self);
            // Avoid a disconnect suicide dropping duplicate copies of saved gear.
            Pawn.Destroy();
            Pawn = None;
            MyPawn = None;
        }
    }
    Super.Destroyed();
}

exec function QuickUseMap()
{
    RequestMap();
}

function RequestMap()
{
    if (!bCoopScene)
        ServerRequestCoopMapScreen();
}

function ServerRequestCoopMapScreen()
{
    SendCoopMap(false);
}

// Only the day number and its per-errand state travel: the client rebuilds
// the paper, the writing and the icons from the campaign class defaults.
// A briefing is the coop stand-in for the original forced start-of-day map.
function bool SendCoopMap(bool bBriefing)
{
    local LanCoopGameInfo G;
    G = LanCoopGameInfo(Level.Game);
    if (G == None || Role < ROLE_Authority || !G.HasValidCampaignDay() || G.IsWeekend()
        || Pawn == None || bCoopScene || bCoopNewsReading || bCoopNewsOffered
        || Pawn.FindInventoryType(class'Inventory.MapInv') == None)
        return false;
    if (bBriefing && !bCoopClientReady)
        return false;
    G.RevealCampaignErrands();
    bCoopNewsOffered = true;
    ClientCoopMapShow(G.TheGameState.CurrentDay, G.CampaignErrandMask(0),
        G.CampaignErrandMask(1), G.CampaignErrandMask(2), G.CampaignErrandMask(3), bBriefing);
    class'LanCoopLog'.static.WriteEvent(Self, "MapRoutedToOwner", "Player=" $ PlayerReplicationInfo.PlayerName
        $ " Day=" $ G.TheGameState.CurrentDay $ " Briefing=" $ bBriefing
        $ " Active=" $ G.CampaignErrandMask(0) $ " Revealed=" $ G.CampaignErrandMask(1));
    return true;
}

// The crossout is shown with that errand still unmarked so the original
// animation can strike it through, exactly as the single-player map does.
function bool SendCoopMapCrossOut(int Errand)
{
    local LanCoopGameInfo G;
    local int Done, Bit;
    G = LanCoopGameInfo(Level.Game);
    if (G == None || Role < ROLE_Authority || !G.HasValidCampaignDay() || G.IsWeekend()
        || Pawn == None || bCoopScene || bCoopNewsReading || bCoopNewsOffered
        || Pawn.FindInventoryType(class'Inventory.MapInv') == None)
        return false;
    Bit = 1 << Errand;
    Done = G.CampaignErrandMask(3);
    Done = Done - (Done & Bit);
    bCoopNewsOffered = true;
    ClientCoopMapCrossOut(G.TheGameState.CurrentDay, G.CampaignErrandMask(0),
        G.CampaignErrandMask(1), G.CampaignErrandMask(2), Done, Errand, G.IsPlayerReadyForHome());
    class'LanCoopLog'.static.WriteEvent(Self, "ErrandCrossOutSent", "Player=" $ PlayerReplicationInfo.PlayerName
        $ " Day=" $ G.TheGameState.CurrentDay $ " Errand=" $ Errand);
    return true;
}

function ClientCoopMapCrossOut(int Day, int ActiveMask, int RevealedMask,
    int LocationMask, int DoneMask, int Errand, bool bReadyForHome)
{
    EnsureCoopMapScreen();
    if (CoopMapScreen == None || Pawn == None || bCoopScene
        || (CurrentScreen != None && CurrentScreen.IsRunning())
        || !CoopMapScreen.BuildCoopDay(Day, ActiveMask, RevealedMask, LocationMask, DoneMask, false))
    {
        ServerSetCoopNewsReading(false);
        return;
    }
    LastCoopMapTexture = CoopMapScreen.BackgroundTex;
    CoopMapScreen.bCoopReadyForHome = bReadyForHome;
    MyMapScreen = CoopMapScreen;
    CoopMapScreen.ShowCoopCrossOut(Errand);
    CurrentScreen = CoopMapScreen;
    MyOldState = GetStateName();
    ServerSetCoopNewsReading(true);
    GotoState('CoopReadNews');
}

function EnsureCoopMapScreen()
{
    local int I;
    if (Player == None || Player.InteractionMaster == None)
        return;
    if (CoopMapScreen != None)
        for (I = 0; I < Player.LocalInteractions.Length; I++)
            if (Player.LocalInteractions[I] == CoopMapScreen)
                return;
    CoopMapScreen = None;
    for (I = 0; I < Player.LocalInteractions.Length; I++)
        if (LanCoopMapScreen(Player.LocalInteractions[I]) != None)
        {
            CoopMapScreen = LanCoopMapScreen(Player.LocalInteractions[I]);
            return;
        }
    // The stock screen asks a single-player GameInfo for the day and would
    // answer the map key with an empty paper on a client.
    if (MyMapScreen != None)
        Player.InteractionMaster.RemoveInteraction(MyMapScreen);
    MyMapScreen = None;
    CoopMapScreen = LanCoopMapScreen(Player.InteractionMaster.AddInteraction("LanCoop.LanCoopMapScreen", Player));
}

function ClientCoopMapShow(int Day, int ActiveMask, int RevealedMask,
    int LocationMask, int DoneMask, bool bBriefing)
{
    local LanCoopMapScreen Built;

    LastCoopMapTexture = None;
    LastCoopMapIconCount = 0;
    // Record what the day's paper carries before touching the viewport, so a
    // server-side check without one can still read the routed contents.
    Built = new(None) class'LanCoopMapScreen';
    if (!Built.BuildCoopDay(Day, ActiveMask, RevealedMask, LocationMask, DoneMask, false))
    {
        ServerSetCoopNewsReading(false);
        return;
    }
    LastCoopMapTexture = Built.BackgroundTex;
    LastCoopMapIconCount = Built.CoopIconCount(ActiveMask, RevealedMask, LocationMask, DoneMask);
    EnsureCoopMapScreen();
    if (CoopMapScreen == None || Pawn == None || bCoopScene
        || (CurrentScreen != None && CurrentScreen.IsRunning())
        || !CoopMapScreen.BuildCoopDay(Day, ActiveMask, RevealedMask, LocationMask, DoneMask, bBriefing))
    {
        ServerSetCoopNewsReading(false);
        return;
    }
    MyMapScreen = CoopMapScreen;
    if (bBriefing)
        CoopMapScreen.ShowCoopErrands();
    else
        CoopMapScreen.Show();
    CurrentScreen = CoopMapScreen;
    MyOldState = GetStateName();
    ServerSetCoopNewsReading(true);
    GotoState('CoopReadNews');
    if (bBriefing)
        ServerConfirmCoopBriefing();
}

// A briefing counts as delivered only once the paper is actually on screen;
// a menu or a cutscene blocking it has to leave the day still to hand out.
function ServerConfirmCoopBriefing()
{
    CoopBriefedDay = CoopBriefingSentDay;
    CoopBriefedMask = CoopBriefingSentMask;
}

function HandlePickup(Pickup Pick)
{
    local Sound PickupAudio;
    Super.HandlePickup(Pick);
    if (Pick == None)
        return;
    PickupAudio = Pick.PickupSound;
    // Stock AnnouncePickup broadcasts Receiver.PlaySound after this hook.
    // Send it to the owner instead; inventory delivery itself is unchanged.
    Pick.PickupSound = None;
    if (PickupAudio != None && P2Pawn(Pawn) != None && !P2Pawn(Pawn).bPlayerStarting)
        ClientCoopPickupSound(PickupAudio);
    class'LanCoopLog'.static.WriteEvent(Self, "PickupOwned", "Player=" $ PlayerReplicationInfo.PlayerName $ " Item=" $ Pick.InventoryType);
}

function ClientCoopPickupSound(Sound Audio)
{
    if (Audio != None)
        ClientPlaySound(Audio);
}

function ServerSetCoopNewsReading(bool bReading)
{
    if (bReading)
    {
        if (!bCoopNewsOffered || bCoopNewsReading || Pawn == None)
            return;
        bCoopNewsReading = true;
        Pawn.Velocity = vect(0,0,0);
        Pawn.Acceleration = vect(0,0,0);
        if (NetConnection(Player) != None)
        {
            CoopBeforeNewsState = GetStateName();
            GotoState('CoopServerReadNews');
        }
    }
    else
    {
        bCoopNewsReading = false;
        bCoopNewsOffered = false;
        if (IsInState('CoopServerReadNews'))
            GotoState(CoopBeforeNewsState);
    }
}

state CoopServerReadNews
{
    ignores Fire, AltFire, DoKick, InventoryMenu, SwitchWeapon;
    function PlayerMove(float DeltaTime) {}
    function ProcessMove(float DeltaTime, vector NewAccel, eDoubleClickDir DoubleClickMove, rotator DeltaRot) {}
}

function EnsureCoopNewsScreen()
{
    local int I;
    if (Player == None || Player.InteractionMaster == None)
        return;
    if (LanCoopNewsScreen(MyNewsScreen) != None)
        return;
    for (I = 0; I < Player.LocalInteractions.Length; I++)
        if (LanCoopNewsScreen(Player.LocalInteractions[I]) != None)
        {
            MyNewsScreen = LanCoopNewsScreen(Player.LocalInteractions[I]);
            return;
        }
    if (MyNewsScreen != None)
        Player.InteractionMaster.RemoveInteraction(MyNewsScreen);
    MyNewsScreen = NewsScreen(Player.InteractionMaster.AddInteraction("LanCoop.LanCoopNewsScreen", Player));
}

function ServerRequestCoopNews()
{
    if (Pawn == None || Pawn.FindInventoryType(class'Inventory.NewspaperInv') == None)
        return;
    if (LanCoopGameInfo(Level.Game) != None && !LanCoopGameInfo(Level.Game).IsWeekend())
        DisplayNews();
}

function RequestNews()
{
    ServerRequestCoopNews();
}

function DisplayNews()
{
    local LanCoopGameInfo G;
    local Texture NewsTexture;
    if (Role < ROLE_Authority)
    {
        ServerRequestCoopNews();
        return;
    }
    G = LanCoopGameInfo(Level.Game);
    if (G == None || G.TheGameState == None)
        return;
    if (bCoopNewsOffered || bCoopNewsReading)
        return;
    NewsTexture = G.GetNewsTexture();
    if (NewsTexture == None)
        return;
    bCoopNewsOffered = true;
    ClientCoopNews(NewsTexture, G.GetDudeNewsComment(), G.TheGameState.bIsApocalypse);
    class'LanCoopLog'.static.WriteEvent(Self, "NewsRoutedToOwner", "Player=" $ PlayerReplicationInfo.PlayerName $ " Day=" $ G.TheGameState.CurrentDay);
}

function ClientCoopNews(Texture NewsTexture, Sound Comment, bool bForceWait)
{
    if (NewsTexture == None)
        return;
    PendingCoopNewsTexture = NewsTexture;
    PendingCoopNewsComment = Comment;
    bPendingCoopNewsMustWait = bForceWait;
    bPendingCoopNews = true;
    if (Pawn == None || MyPawn == None || Player == None || Player.InteractionMaster == None || bCoopScene)
        return;
    EnsureCoopNewsScreen();
    if (MyNewsScreen == None)
        return;
    if (MyNewsScreen.IsRunning())
    {
        bPendingCoopNews = false;
        return;
    }
    if (CurrentScreen != None && CurrentScreen.IsRunning())
        return;
    bPendingCoopNews = false;
    LanCoopNewsScreen(MyNewsScreen).ShowCoop(NewsTexture, Comment, bForceWait);
    if (!MyNewsScreen.IsRunning())
        return;
    CurrentScreen = MyNewsScreen;
    MyOldState = GetStateName();
    ServerSetCoopNewsReading(true);
    GotoState('CoopReadNews');
    class'LanCoopLog'.static.WriteEvent(Self, "NewsOpenedLocally", "Player=" $ PlayerReplicationInfo.PlayerName);
}

state CoopReadNews extends WaitScreen
{
    function BeginState()
    {
        if (MyPawn != None)
            MyPawn.StopAcc();
    }
    function EndState()
    {
        CurrentScreen = None;
        ServerSetCoopNewsReading(false);
    }
Begin:
    while (CurrentScreen != None && CurrentScreen.IsRunning())
        Sleep(0.05);
    GotoState(MyOldState);
}

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
        ServerSetAppearance, ServerCoopMap, ServerCoopReady, ServerCoopSceneSkip,
        ServerRequestCoopNews, ServerSetCoopNewsReading, ServerRequestCoopMapScreen,
        ServerConfirmCoopBriefing;
    reliable if (Role == ROLE_Authority)
        CoopWantedPercent;
    reliable if (Role == ROLE_Authority)
        ClientProbeInventory, ClientProbeCombat, ClientCoopMusic, ClientStopCoopMusic, ClientClearCoopMusic,
        ClientBeginCoopScene, ClientEndCoopScene, ClientPrepareCoopTravel,
        ClientConfirmCoopArrival, ClientCoopNews, ClientCoopPickupSound,
        ClientCoopMapShow, ClientCoopMapCrossOut, ClientRefreshCoopAppearance;
    unreliable if (Role == ROLE_Authority)
        ClientCoopSceneFrame;
}

function ClientPrepareCoopTravel(Texture Background, string Destination, string EntryPortal)
{
    local LanCoopRootWindow Root;
    if (Player == None || Player.InteractionMaster == None)
        return;
    bPendingCoopNews = false;
    if (CoopMapScreen != None)
    {
        if (CoopMapScreen.IsRunning())
            CoopMapScreen.GotoState('Shutdown');
        CoopMapScreen.PreTravel();
    }
    if (MyNewsScreen != None && MyNewsScreen.IsRunning())
    {
        MyNewsScreen.GotoState('Shutdown');
        MyNewsScreen.PreTravel();
    }
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
    if (IsInState('CoopReadNews'))
    {
        if (CurrentScreen != None)
            CurrentScreen.GotoState('Shutdown');
        GotoState(MyOldState);
    }
    if (Role == ROLE_Authority && bCoopNewsReading)
        ServerSetCoopNewsReading(false);
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

function ClientCoopSceneFrame(vector CameraLocation, rotator CameraRotation, float CameraFOV, bool bLetterbox,
    optional float SourceTime, optional int Epoch, optional int FrameId)
{
    if (!bCoopScene)
        return;
    if (CoopCameraBuffer == None)
        CoopCameraBuffer = new(None) class'LanCoopCameraBuffer';
    if (SourceTime == 0)
        SourceTime = Level.TimeSeconds;
    CoopCameraBuffer.Push(CameraLocation, CameraRotation, CameraFOV, SourceTime, Level.TimeSeconds, Epoch, FrameId);
    CoopSceneCameraLocation = CameraLocation;
    CoopSceneCameraRotation = CameraRotation;
    bCoopSceneHasFrame = true;
    FOVAngle = CameraFOV;
    if (MyHUD != None)
        MyHUD.bCinematicView = bLetterbox;
}

function ClientEndCoopScene()
{
    CoopCameraBuffer = None;
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
        if (CoopCameraBuffer != None)
            CoopCameraBuffer.Sample(Level.TimeSeconds, CoopSceneCameraLocation, CoopSceneCameraRotation, FOVAngle);
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
            if (LanCoopGameInfo(Level.Game).bExpectTravelState || bCoopReconnectRestored)
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
    if (bCoopAppearanceRefreshPending)
        FinishCoopAppearanceRefresh();
    if (Level.NetMode == NM_Client && Player != None && Player.InteractionMaster != None
        && (AttachmentGuard == None || AttachmentGuard.bDeleteMe))
        AttachmentGuard = Spawn(class'LanCoopAttachmentGuard');
    if (bPendingCoopNews && !bCoopScene && !IsInState('CoopReadNews'))
        ClientCoopNews(PendingCoopNewsTexture, PendingCoopNewsComment, bPendingCoopNewsMustWait);
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
    {
        LanCoopPawn(Pawn).SetCoopAppearance(Appearance);
        LanCoopPawn(Pawn).RestoreCombatReferences();
        ClientRefreshCoopAppearance(Pawn.Weapon, P2Pawn(Pawn).MyFoot, P2Weapon(P2Pawn(Pawn).MyUrethra));
        class'LanCoopLog'.static.WriteEvent(Self, "AppearanceCombatPreserved", "Player=" $ PlayerReplicationInfo.PlayerName $ " Weapon=" $ Pawn.Weapon $ " Inventory=" $ Pawn.Inventory);
    }
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
    CoopBriefedDay=-1
}
