// The original Matinee runs once on the server. Clients receive its camera,
// rather than independently advancing a second copy of the scene.
class LanCoopSceneRelay extends Info;

var LanCoopPlayer Source;
var SceneManager Scene;
var float LastRunningTime, NextFrameTime;
var int FrameNumber, CameraEpoch;
var SceneManager LastFrameScene;
var Actor LastFrameView;

function BeginScene(LanCoopPlayer Viewer, SceneManager SM)
{
    local LanCoopPlayer P;
    Source = Viewer;
    CameraEpoch++;
    Scene = SM;
    LastRunningTime = Level.TimeSeconds;
    foreach DynamicActors(class'LanCoopPlayer', P)
    {
        P.BeginCoopScene(P != Source);
        P.ClientBeginCoopScene(P == Source);
    }
    class'LanCoopLog'.static.WriteEvent(Self, "SceneBegin", "Scene=" $ SM $ " Viewer=" $ Source);
}

function EndScene()
{
    local LanCoopPlayer P;
    foreach DynamicActors(class'LanCoopPlayer', P)
    {
        P.EndCoopScene();
        P.ClientEndCoopScene();
    }
    class'LanCoopLog'.static.WriteEvent(Self, "SceneEnd", "Scene=" $ Scene);
    Source = None;
    Scene = None;
}

event Tick(float Delta)
{
    local LanCoopPlayer P;
    local SceneManager SM;
    local actor ViewActor;
    local vector CameraLocation;
    local rotator CameraRotation;
    if (Source == None)
        return;
    // Follow chained Matinees without restoring control between them.
    foreach AllActors(class'SceneManager', SM)
        if (SM.bIsRunning && SM.Affect == AFFECT_ViewportCamera
            && LanCoopPlayer(SM.Viewer) != None)
        {
            Source = LanCoopPlayer(SM.Viewer);
            Scene = SM;
            LastRunningTime = Level.TimeSeconds;
            break;
        }
    if (Source.bDeleteMe || Level.TimeSeconds - LastRunningTime > 0.15)
    {
        EndScene();
        return;
    }
    if (Scene == None || !Scene.bIsRunning || !Source.bInterpolating)
        return;
    if (Level.TimeSeconds < NextFrameTime)
        return;
    NextFrameTime = Level.TimeSeconds + 0.025;
    Source.GetOriginalSceneView(ViewActor, CameraLocation, CameraRotation);
    if (Scene != LastFrameScene || ViewActor != LastFrameView)
        CameraEpoch++;
    LastFrameScene = Scene;
    LastFrameView = ViewActor;
    FrameNumber++;
    foreach DynamicActors(class'LanCoopPlayer', P)
        P.ClientCoopSceneFrame(CameraLocation, CameraRotation, Source.FOVAngle, Scene.bCinematicView,
            Level.TimeSeconds, CameraEpoch, FrameNumber);
}

defaultproperties
{
    RemoteRole=ROLE_None
}
