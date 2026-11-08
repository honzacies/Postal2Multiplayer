// The campaign has to hand out a day's errands without any single-player map
// interaction, and a client has to be able to draw them from class defaults.
class LanCoopMapChecks extends Object;

static function bool Run(LanCoopGameInfo G)
{
    local LanCoopMapScreen Screen;
    local DayBase Day;
    local int I, First, Active, Revealed, Locations, Expected;
    local bool Passed;

    Day = G.GetCurrentDayBase();
    if (Day == None || Day.NumErrands() == 0)
        return false;

    // Day flags the original start-of-day scripts test.
    Passed = !G.TheGameState.bPreGameMode && G.TheGameState.bFirstLevelOfDay;

    // Handing the day out is the server's job and has to be repeatable.
    G.RevealCampaignErrands();
    Revealed = G.RevealCampaignErrands();
    Passed = Passed && Revealed == 0;

    Active = G.CampaignErrandMask(0);
    Revealed = G.CampaignErrandMask(1);
    Locations = G.CampaignErrandMask(2);
    Passed = Passed && Active != 0 && Revealed == Active;

    for (I = 0; I < Day.NumErrands(); I++)
        if (Day.IsErrandActive(I))
        {
            Expected++;
            if (First < 0 || Expected == 1)
                First = I;
        }
    Passed = Passed && Expected >= 3;

    // A client rebuilds the same paper with no GameInfo and no replicated art.
    Screen = new(None) class'LanCoopMapScreen';
    Passed = Passed && Screen.BuildCoopDay(G.TheGameState.CurrentDay, Active, Revealed, Locations, 0, false)
        && Screen.BackgroundTex == Day.GetMapTexture()
        && Screen.CoopIconCount(Active, Revealed, Locations, 0) >= 3;
    for (I = 0; I < Day.NumErrands(); I++)
        if (Day.IsErrandActive(I))
        {
            Passed = Passed && Screen.Sprites[Screen.ErrandNameBase + I].tex != None
                && Screen.Sprites[Screen.ErrandNameBase + I].status != 0;
            if (Day.IsLocationTexActive(I) && Screen.Sprites[Screen.ErrandLocBase + I].tex != None)
                Passed = Passed && Screen.Sprites[Screen.ErrandLocBase + I].status != 0;
        }

    // A completion crosses the line out for everyone.
    Passed = Passed && Screen.BuildCoopDay(G.TheGameState.CurrentDay, Active, Revealed, Locations, 1 << First, false)
        && Screen.Sprites[Screen.CrossoutBase + First].status != 0;

    // A briefing starts with an empty paper so the original writing plays.
    Passed = Passed && Screen.BuildCoopDay(G.TheGameState.CurrentDay, Active, Revealed, Locations, 0, true)
        && Screen.Sprites[Screen.ErrandNameBase + First].status == 0
        && Screen.FindUnrevealedErrand(-1) == First;

    if (Passed)
        class'LanCoopLog'.static.WriteEvent(G, "MapObjectivesCheckOk", "DayFlags ServerHandout Idempotent"
            @ "ClientRebuild Names Locations CompletionCrossout Briefing Active=" $ Expected);
    return Passed;
}
