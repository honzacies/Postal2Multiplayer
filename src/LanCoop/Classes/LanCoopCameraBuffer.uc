// Interpolate timestamped camera samples, never mouse input or player movement.
class LanCoopCameraBuffer extends Object;

struct CameraSample
{
    var float Time, FOV;
    var vector Position;
    var rotator Facing;
};
var array<CameraSample> Frames;
var float ClockOffset;
var int LastFrameId, CurrentEpoch;

function Push(vector Position, rotator Facing, float FOV, float SourceTime, float ReceiveTime, int Epoch, int FrameId)
{
    local int N;
    local bool bReset;
    local rotator Delta;
    if (FrameId > 0 && LastFrameId > 0 && FrameId <= LastFrameId)
        return;
    N = Frames.Length;
    bReset = N == 0 || Epoch != CurrentEpoch;
    if (N > 0)
    {
        Delta = Normalize(Facing - Frames[N-1].Facing);
        bReset = bReset || SourceTime <= Frames[N-1].Time
            || SourceTime - Frames[N-1].Time > 0.3
            || VSize(Position - Frames[N-1].Position) > 2048
            || Abs(Delta.Yaw) > 16384 || Abs(Delta.Pitch) > 16384;
    }
    if (bReset)
    {
        Frames.Length = 0;
        ClockOffset = ReceiveTime - SourceTime;
    }
    LastFrameId = FrameId;
    CurrentEpoch = Epoch;
    N = Frames.Length;
    Frames.Length = N + 1;
    Frames[N].Time = SourceTime;
    Frames[N].Position = Position;
    Frames[N].Facing = Facing;
    Frames[N].FOV = FOV;
    if (Frames.Length > 12)
        Frames.Remove(0, Frames.Length - 12);
}

function Sample(float LocalTime, out vector Position, out rotator Facing, out float FOV)
{
    local float TargetTime, Alpha;
    local int N;
    local rotator Delta;
    N = Frames.Length;
    if (N == 0)
        return;
    TargetTime = LocalTime - ClockOffset - 0.075;
    while (Frames.Length > 2 && Frames[1].Time <= TargetTime)
        Frames.Remove(0, 1);
    if (Frames.Length == 1)
        Alpha = 0;
    else
        Alpha = FClamp((TargetTime - Frames[0].Time) / (Frames[1].Time - Frames[0].Time), 0, 1);
    Position = Frames[0].Position;
    Facing = Frames[0].Facing;
    FOV = Frames[0].FOV;
    if (Frames.Length > 1)
    {
        Position += Alpha * (Frames[1].Position - Position);
        Delta = Normalize(Frames[1].Facing - Facing);
        Facing.Pitch += int(Alpha * Delta.Pitch);
        Facing.Yaw += int(Alpha * Delta.Yaw);
        Facing.Roll += int(Alpha * Delta.Roll);
        FOV += Alpha * (Frames[1].FOV - FOV);
    }
}
