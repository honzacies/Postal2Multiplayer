// Keep the original newspaper animation/states, but receive day content from
// the server instead of reading the client's nonexistent Level.Game.
class LanCoopNewsScreen extends NewsScreen;

var Sound CoopComment;

function ShowCoop(Texture NewsTexture, Sound Comment, bool bForceWait)
{
    local vector PaperScale;
    if (NewsTexture == None || ViewportOwner == None || ViewportOwner.Actor == None)
        return;
    BackgroundTex = NewsTexture;
    CoopComment = Comment;
    if (Paper == None)
    {
        Paper = ViewportOwner.Actor.Spawn(class'RawActor', ViewportOwner.Actor);
        if (Paper == None)
            return;
        Paper.SetStaticMesh(PaperMesh);
        Paper.SetDrawType(DT_StaticMesh);
        Paper.bUnlit = true;
        Paper.Skins.Length = 1;
        PaperScale = vect(0.25,1,0.45);
        Paper.SetDrawScale3D(PaperScale);
    }
    Paper.Skins[0] = BackgroundTex;
    bMustWait = bForceWait;
    BufferCommentTime = Default.BufferCommentTime;
    if (bMustWait)
        BufferCommentTime *= 2;
    AfterFadeInScreen = 'Spinning';
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
    if (TileTex == None && TileName != 'None')
        TileTex = Texture(DynamicLoadObject(string(TileName), class'Texture'));
    if (MyFont == None)
        MyFont = FontInfo(ViewportOwner.Actor.Spawn(class<Actor>(DynamicLoadObject(FontInfoClass, class'Class'))));
    GotoState('Startup');
}

state DoneSpinning2
{
    function BeginState()
    {
        local float Duration;
        Duration = BufferCommentTime;
        if (CoopComment != None)
        {
            GetSoundActor().PlaySound(CoopComment, SLOT_Talk, 1.0);
            Duration += GetSoundDuration(CoopComment);
        }
        DelayedGotoState(Duration, 'HoldScreen');
    }
}

defaultproperties
{
    bDontPauseGame=true
}
