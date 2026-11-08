// Uses stock map artwork, sprites, trail, reveal animation and screen fades.
// The day and its errands come from the campaign class defaults, which exist
// on both sides, so a client needs neither a single-player GameInfo nor any
// replicated artwork. Per-errand state arrives as bit masks and the local
// reveal bookkeeping replaces the single-player GameState lists.
class LanCoopMapScreen extends MapScreen;

var int CoopActiveMask;         // errands active for the shown day
var int CoopDoneMask;           // errands already crossed out
var int CoopRevealedMask;       // errand names written on this client
var int CoopLocationMask;       // errand locations written on this client
var bool bCoopBriefing;         // whether this showing writes the errands
var bool bCoopReadyForHome;     // replaces the server-only day-finished query

static function DayBase CoopCampaignDay(int Index)
{
    if (Index < 0 || Index >= class'LanCoopGameInfo'.Default.Days.Length)
        return None;
    return class'LanCoopGameInfo'.Default.Days[Index];
}

// Build the whole screen from the campaign defaults plus the replicated state.
// A briefing starts with nothing written so the stock animation can write it.
function bool BuildCoopDay(int DayNumber, int ActiveMask, int RevealedMask,
    int LocationMask, int DoneMask, bool bBriefing)
{
    Day = CoopCampaignDay(DayNumber);
    if (Day == None || Day.NumErrands() == 0)
        return false;
    BackgroundTex = Day.GetMapTexture();
    if (BackgroundTex == None)
        return false;
    DayIndex = DayNumber;
    CoopActiveMask = ActiveMask;
    CoopDoneMask = DoneMask;
    bCoopBriefing = bBriefing;
    if (bBriefing)
    {
        CoopRevealedMask = 0;
        CoopLocationMask = 0;
    }
    else
    {
        CoopRevealedMask = RevealedMask;
        CoopLocationMask = LocationMask;
    }
    BuildCoopSprites();
    return true;
}

// The stock SetupSprites reads the single-player GameState reveal lists and
// the live DayBase completion flags. Neither exists on a client, so lay the
// same sprites out from the masks instead.
function BuildCoopSprites()
{
    local int I, Count, Bit;
    local float X, Y;

    Count = Day.NumErrands();
    SpritesNextUnused = 0;
    ErrandNameBase = AllocateSprites(Count);
    ErrandLocBase = AllocateSprites(Count);
    ErrandLocCrossBase = AllocateSprites(Count);
    CrossoutBase = AllocateSprites(Count);
    for (I = 0; I < Count; I++)
    {
        Bit = 1 << I;
        // The shipped weekend days carry an empty errand entry.
        if (Day.Errands[I] == None)
            continue;

        Sprites[ErrandNameBase + I].tex = Day.GetErrandName(I);
        if (I < ErrandPositions.Length)
        {
            Sprites[ErrandNameBase + I].x = ErrandPositions[I].X;
            Sprites[ErrandNameBase + I].y = ErrandPositions[I].Y;
        }
        Sprites[ErrandNameBase + I].status = SS_Off;

        Sprites[ErrandLocBase + I].tex = Day.GetErrandLocation(I, X, Y);
        Sprites[ErrandLocBase + I].x = X;
        Sprites[ErrandLocBase + I].y = Y;
        Sprites[ErrandLocBase + I].status = SS_Off;

        Sprites[ErrandLocCrossBase + I].tex = Day.GetErrandLocationCrossout(I, X, Y);
        Sprites[ErrandLocCrossBase + I].x = X;
        Sprites[ErrandLocCrossBase + I].y = Y;
        Sprites[ErrandLocCrossBase + I].status = SS_Off;

        if (I < CrossoutTex.Length)
            Sprites[CrossoutBase + I].tex = CrossoutTex[I];
        if (I < ErrandPositions.Length)
        {
            Sprites[CrossoutBase + I].x = ErrandPositions[I].X;
            Sprites[CrossoutBase + I].y = ErrandPositions[I].Y;
        }
        Sprites[CrossoutBase + I].status = SS_Off;

        if ((CoopActiveMask & Bit) == 0)
            continue;
        if ((CoopRevealedMask & Bit) != 0 && Sprites[ErrandNameBase + I].tex != None)
            Sprites[ErrandNameBase + I].status = SS_On;
        if ((CoopLocationMask & Bit) != 0 && Sprites[ErrandLocBase + I].tex != None)
            Sprites[ErrandLocBase + I].status = SS_On;
        if ((CoopDoneMask & Bit) != 0)
        {
            if (Sprites[ErrandNameBase + I].tex != None)
                Sprites[CrossoutBase + I].status = SS_On;
            if (Sprites[ErrandLocCrossBase + I].tex != None)
                Sprites[ErrandLocCrossBase + I].status = SS_On;
        }
    }
}

// How many marks this day's errand state puts on the paper once everything
// is written. A briefing animates up to the same total.
function int CoopIconCount(int ActiveMask, int RevealedMask, int LocationMask, int DoneMask)
{
    local int I, Bit, Icons;
    if (Day == None)
        return 0;
    for (I = 0; I < Day.NumErrands(); I++)
    {
        Bit = 1 << I;
        if ((ActiveMask & Bit) == 0 || Day.Errands[I] == None)
            continue;
        if ((RevealedMask & Bit) != 0 && Sprites[ErrandNameBase + I].tex != None)
            Icons++;
        if ((LocationMask & Bit) != 0 && Sprites[ErrandLocBase + I].tex != None)
            Icons++;
        if ((DoneMask & Bit) != 0 && Sprites[CrossoutBase + I].tex != None)
            Icons++;
    }
    return Icons;
}

// The stock lookup reads the preference through a single-player GameInfo
// actor, which a client does not have. It is a config default on the class.
function CheckWidescreenPreference()
{
    bEnableWidescreenStretch = class'LanCoopGameInfo'.Default.bWidescreenStretch;
    bStretch = bEnableWidescreenStretch;
}

function SetupActors()
{
    if (ViewportOwner == None || ViewportOwner.Actor == None)
        return;
    if (HeadMarker == None)
    {
        HeadMarker = ViewportOwner.Actor.Spawn(class'RawActor', ViewportOwner.Actor);
        HeadMarker.SetStaticMesh(HeadMesh);
        HeadMarker.SetDrawType(DT_StaticMesh);
        HeadMarker.bUnlit = true;
    }
    if (TrailMarker == None)
    {
        TrailMarker = ViewportOwner.Actor.Spawn(class'RawActor', ViewportOwner.Actor);
        TrailMarker.SetStaticMesh(TrailMesh);
        TrailMarker.SetDrawType(DT_StaticMesh);
        TrailMarker.bUnlit = true;
    }
}

// Stock MapInit also asks a single-player GameInfo for the day and state.
// Those already came from the server, so only reset the presentation here.
function CoopMapInit()
{
    SetupActors();
    CheckWidescreenPreference();
    bGoFast = false;
    bNoFast = false;
    bFancyMapFade = false;
    bFadeScreenInOut = Default.bFadeScreenInOut;
    FadeInGameTime = Default.FadeInGameTime;
    FadeInScreenTime = Default.FadeInScreenTime;
    bFadeGameInOut = Default.bFadeGameInOut;
    SetupEndKeys();
    bWantInputEvents = true;
    PostRevealSendToURL = "";
    PreShowTrail();
}

function Show()
{
    if (BackgroundTex == None)
        return;
    CoopMapInit();
    ShowTrail();
    Mode = Mode_JustLooking;
    AfterFadeInScreen = 'JustLooking';
    Start();
}

// The single-player day start writes the errands on the paper one by one.
// Every coop player receives the same list, so each one gets that showing.
function ShowCoopErrands()
{
    if (BackgroundTex == None)
        return;
    if (FindUnrevealedErrand(-1) == -1)
    {
        Show();
        return;
    }
    CoopMapInit();
    Mode = Mode_RevealErrands;
    AfterFadeInScreen = 'RevealErrands';
    Start();
}

// Single player strikes the finished errand off the paper on the map of the
// player who finished it. In coop the day is shared, so everyone sees it.
function ShowCoopCrossOut(int Errand)
{
    if (BackgroundTex == None || Errand < 0 || Errand >= Day.NumErrands()
        || Day.Errands[Errand] == None)
        return;
    CoopMapInit();
    Mode = Mode_CrossOutErrand;
    CrossOutErrand = Errand;
    RevealErrand = -1;
    AfterFadeInScreen = 'CrossOut';
    Start();
}

function Start()
{
    bIsRunning = true;
    bEndNow = false;
    bPlayerWantsToEnd = false;
    bTraveling = false;
    bEnableRender = true;
    bTravelRenderMode = false;
    SongHandle = 0;
    bShowMsg = false;
    ViewportOwner.Actor.bWantsToSkip = 0;
    if (MyFont == None)
        MyFont = FontInfo(ViewportOwner.Actor.Spawn(class<Actor>(DynamicLoadObject(FontInfoClass, class'Class'))));
    GotoState('Startup');
}

// Stock reveal bookkeeping lives in the single-player GameState. Use the local
// masks instead; the shared campaign record stays with the server.
function int FindUnrevealedErrand(int ErrandIndex)
{
    local int Bit;
    if (Day == None)
        return -1;
    for (ErrandIndex++; ErrandIndex < Day.NumErrands(); ErrandIndex++)
    {
        Bit = 1 << ErrandIndex;
        if ((CoopActiveMask & Bit) == 0 || Day.Errands[ErrandIndex] == None)
            continue;
        if ((CoopRevealedMask & Bit) == 0 && Sprites[ErrandNameBase + ErrandIndex].tex != None)
            return ErrandIndex;
        if ((CoopLocationMask & Bit) == 0 && Day.IsLocationTexActive(ErrandIndex))
            return ErrandIndex;
    }
    return -1;
}

state RevealErrands2
{
    function BeginState()
    {
        local float Duration;

        if ((CoopRevealedMask & (1 << RevealErrand)) != 0)
            Duration = 0;
        else if (Sprites[ErrandNameBase + RevealErrand].tex != None)
        {
            Duration = ErrandNameFadeTime;
            SpriteFadeIn(ErrandNameBase + RevealErrand, Duration);
            PlayWritingSound();
            if (!bGoFast)
                Duration = PlayDudeComment(Day.GetErrandStartComment(RevealErrand), ErrandNameCommentPad, Duration);
        }
        else
            Duration = 0;
        DelayedGotoState(PreferredTime(Duration), 'RevealErrands3');
    }
}

state RevealErrands4
{
    function BeginState()
    {
        local float Duration;
        local Sound DudeComment;

        if (Day.IsLocationTexActive(RevealErrand))
        {
            Duration = ErrandLocFadeTime;
            if (Sprites[ErrandLocBase + RevealErrand].tex != None)
            {
                SpriteFadeIn(ErrandLocBase + RevealErrand, Duration);
                PlayWritingSound();
            }
            DudeComment = Day.GetErrandFoundComment(RevealErrand);
            if (!bGoFast && DudeComment != None)
                Duration = PlayDudeComment(DudeComment, ErrandLocCommentPad, Duration);
            CoopLocationMask = CoopLocationMask | (1 << RevealErrand);
        }
        DelayedGotoState(PreferredTime(Duration), 'RevealErrands5');
    }
}

state RevealErrands5
{
    function BeginState()
    {
        if (Sprites[ErrandLocBase + RevealErrand].tex != None
            && Day.IsLocationTexActive(RevealErrand))
            SpriteTurnOn(ErrandLocBase + RevealErrand);

        CoopRevealedMask = CoopRevealedMask | (1 << RevealErrand);
        RevealCount++;

        RevealErrand = FindUnrevealedErrand(RevealErrand);
        if (RevealErrand != -1)
            DelayedGotoState(PreferredTime(ErrandBetweenTime), 'RevealErrands2');
        else
            DelayedGotoState(0.2, 'RevealErrandsFinish');
    }
}

// The stock state ends by asking a single-player GameInfo whether the day is
// finished. That answer came with the crossout instead.
state CrossOut3
{
    function BeginState()
    {
        local float Duration;

        SpriteTurnOn(ErrandLocCrossBase + CrossOutErrand);
        Duration = BigHoldTime;
        RevealErrand = FindUnrevealedErrand(RevealErrand);
        if (RevealErrand != -1)
            DelayedGotoState(PreferredTime(ErrandBetweenTime), 'RevealErrands2');
        else
        {
            if (!bGoFast && bCoopReadyForHome)
                Duration += PlayDudeGoHomeComment();
            DelayedGotoState(PreferredTime(Duration), 'FadeOutScreen');
        }
    }
}

// Plain viewing never advances campaign scripts and never asks a
// single-player GameInfo whether the day is finished.
state JustLooking
{
    function BeginState()
    {
        ShowMsg();
        DelayedGotoState(0, 'HoldScreen');
    }
}

// The stock body asks the player controller for the errand reminder, which
// needs a single-player game. Keep the plain "press a key" prompt.
function RenderMsgBody(Canvas C)
{
    Super(P2Screen).RenderMsgBody(C);
}

defaultproperties
{
    bDontPauseGame=true
}
