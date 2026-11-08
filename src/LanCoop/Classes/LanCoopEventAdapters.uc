// Runtime adapters modify only this mod's level instances, never original .u files.
class LanCoopEventAdapters extends Object;

static function ScriptedAction Adapt(ScriptedSequence OwnerScript, ScriptedAction Original)
{
    local class<ScriptedAction> AdapterClass;
    local ScriptedAction Adapted;
    local string Properties, PropertyName, OriginalValue;
    local int Separator;
    if (Original == None)
        return None;
    if (Original.Class == class'MoreGame.ACTION_P2Screen')
    {
        AdapterClass = class'LanCoopActionScreen';
        Properties = "Screen,bMapRevealErrands,bMapRevealHaters";
    }
    if (Original.Class == class'MoreGame.ACTION_Errand')
    {
        AdapterClass = class'LanCoopActionErrand';
        Properties = "ErrandAction,UniqueName,UniqueTag,GoalMet_SendToURL";
    }
    if (Original.Class == class'MoreGame.ACTION_IfPlayerWeaponState')
    {
        AdapterClass = class'LanCoopActionWeaponCondition';
        Properties = "WeaponClass";
    }
    if (Original.Class == class'MoreGame.ACTION_StealPlayerInventory')
    {
        AdapterClass = class'LanCoopActionStealInventory';
        Properties = "ItemsToSteal,bStealEverything,bRemovePickupsFromVolume,VolumeTag";
    }
    if (Original.Class == class'MoreGame.ACTION_SendPlayer')
    {
        AdapterClass = class'LanCoopActionSendPlayer';
        Properties = "Where,URL,bNice,bTakeHisInventory,bQuit,LoadScreen";
    }
    if (Original.Class == class'MoreGame.ACTION_AtMyHouse')
    {
        AdapterClass = class'LanCoopActionAtHouse';
        Properties = "";
    }
    if (Original.Class == class'MoreGame.ACTION_EndOfGame')
    {
        AdapterClass = class'LanCoopActionEndGame';
        Properties = "";
    }
    if (Original.Class == class'AWPStuff.ACTION_GiveInventoryToPlayer')
    {
        AdapterClass = class'LanCoopActionGiveInventory';
        Properties = "InvType";
    }
    if (Original.Class == class'AWPStuff.ACTION_TakeInventoryFromPlayer')
    {
        AdapterClass = class'LanCoopActionTakeInventory';
        Properties = "InvType";
    }
    if (Original.Class == class'FPSGame.ACTION_TriggerEvent')
    {
        AdapterClass = class'LanCoopActionTrigger';
        Properties = "Event";
    }
    if (Original.Class == class'MoreGame.ACTION_AIDisturbance')
    {
        AdapterClass = class'LanCoopActionDisturbance';
        Properties = "DisturbanceMarker,bPlayerDidIt,NPCDidItTag,ThingDoneToTag";
    }
    if (AdapterClass == None)
        return Original;
    Adapted = new(OwnerScript) AdapterClass;
    if (Adapted == None)
        return Original;
    Properties = "bValidForTrigger,bRequiresValidGameInfo," $ Properties;
    while (Properties != "")
    {
        Separator = InStr(Properties, ",");
        if (Separator < 0)
        {
            PropertyName = Properties;
            Properties = "";
        }
        else
        {
            PropertyName = Left(Properties, Separator);
            Properties = Mid(Properties, Separator + 1);
        }
        if (PropertyName != "")
        {
            OriginalValue = Original.GetPropertyText(PropertyName);
            Adapted.SetPropertyText(PropertyName, OriginalValue);
            if (Adapted.GetPropertyText(PropertyName) != OriginalValue)
            {
                class'LanCoopLog'.static.WriteEvent(OwnerScript, "EventAdapterCopyFailed", "Action=" $ Original $ " Property=" $ PropertyName);
                return Original;
            }
        }
    }
    return Adapted;
}

static function InstallForLevel(LanCoopGameInfo G)
{
    local ScriptedSequence S;
    local ScriptedTrigger T;
    local LanCoopContextTrigger Proxy;
    local ScriptedAction Adapted;
    local int I, Actions, Triggers;
    foreach G.AllActors(class'ScriptedSequence', S)
        for (I = 0; I < S.Actions.Length; I++)
        {
            Adapted = Adapt(S, S.Actions[I]);
            if (Adapted != S.Actions[I])
            {
                S.Actions[I] = Adapted;
                Actions++;
            }
        }
    foreach G.AllActors(class'ScriptedTrigger', T)
        if (T.Class == class'FPSGame.ScriptedTrigger' && T.bWaitForTrigger)
        {
            Proxy = G.Spawn(class'LanCoopContextTrigger',,, T.Location, T.Rotation);
            if (Proxy == None)
                continue;
            Proxy.Tag = T.Tag;
            Proxy.Event = T.Event;
            Proxy.Actions = T.Actions;
            Proxy.bOneTimeOnly = T.bOneTimeOnly;
            Proxy.bRequiresValidGameInfo = T.bRequiresValidGameInfo;
            Proxy.bLoggingEnabled = T.bLoggingEnabled;
            // Keep the original object for map references, but route tagged
            // event delivery through the participant-aware proxy only.
            T.Tag = 'LanCoopOriginalTrigger';
            T.Disable('Trigger');
            Triggers++;
        }
    class'LanCoopLog'.static.WriteEvent(G, "EventAdaptersInstalled", "Actions=" $ Actions $ " TriggerProxies=" $ Triggers);
}
