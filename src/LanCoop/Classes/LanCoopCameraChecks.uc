class LanCoopCameraChecks extends Object;

static function bool Run(Actor Context)
{
    local LanCoopCameraBuffer Buffer;
    local vector Position;
    local rotator Facing;
    local float FOV;
    Buffer = new(None) class'LanCoopCameraBuffer';
    Buffer.Push(vect(0,0,0), rot(0,65530,0), 80, 10, 100, 1, 1);
    Buffer.Push(vect(100,0,0), rot(0,10,0), 100, 10.1, 100.1, 1, 2);
    Buffer.Sample(100.125, Position, Facing, FOV);
    Facing = Normalize(Facing);
    if (Abs(Position.X - 50) > 0.1 || Abs(Facing.Yaw - 2) > 1 || Abs(FOV - 90) > 0.1)
        return false;
    Buffer.Push(vect(-500,0,0), rot(0,0,0), 40, 9, 100.13, 1, 1);
    if (Buffer.LastFrameId != 2 || Buffer.Frames.Length != 2)
        return false;
    Buffer.Push(vect(1000,0,0), rot(0,0,0), 70, 10.2, 100.2, 2, 3);
    Buffer.Sample(100.2, Position, Facing, FOV);
    if (Position.X != 1000 || FOV != 70 || Buffer.Frames.Length != 1)
        return false;
    Buffer.Push(vect(1100,0,0), rot(0,0,0), 75, 10.7, 100.7, 2, 4);
    Buffer.Sample(101, Position, Facing, FOV);
    if (Position.X != 1100 || FOV != 75 || Buffer.Frames.Length != 1)
        return false;
    class'LanCoopLog'.static.WriteEvent(Context, "CameraSmoothingCheckOk", "Interpolation ShortestRotation FOV LatePacketRejected CutAndGapSnap NoExtrapolation");
    return true;
}
