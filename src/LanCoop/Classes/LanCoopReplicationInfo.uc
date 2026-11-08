// Shared campaign view. Clients rebuild the errand list from the campaign
// class defaults, so only the day number and per-errand state travel here.
class LanCoopReplicationInfo extends GameReplicationInfo;

var int CampaignDay, CompletedTaskMask, TaskCount;
var int ActiveTaskMask, RevealedTaskMask, RevealedLocationMask;
var string CampaignMap;

replication
{
    reliable if (Role == ROLE_Authority && bNetDirty)
        CampaignDay, CompletedTaskMask, TaskCount, CampaignMap,
        ActiveTaskMask, RevealedTaskMask, RevealedLocationMask;
}
