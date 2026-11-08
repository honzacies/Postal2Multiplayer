class LanCoopReplicationInfo extends GameReplicationInfo;

var int CampaignDay, CompletedTaskMask, TaskCount;
var string CampaignMap;

replication
{
    reliable if (Role == ROLE_Authority && bNetDirty)
        CampaignDay, CompletedTaskMask, TaskCount, CampaignMap;
}
