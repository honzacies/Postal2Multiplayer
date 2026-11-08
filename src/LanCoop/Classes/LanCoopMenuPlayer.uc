class LanCoopMenuPlayer extends MenuPlayer;

function CharacterChanged()
{
    Super.CharacterChanged();
    if (LanCoopPlayer(GetPlayerOwner()) != None)
        LanCoopPlayer(GetPlayerOwner()).ServerSetAppearance(CharacterCombo.GetValue2());
}

function SaveConfigs()
{
    Super.SaveConfigs();
    if (LanCoopPlayer(GetPlayerOwner()) != None)
        LanCoopPlayer(GetPlayerOwner()).ServerSetAppearance(GetPlayerOwner().GetDefaultURL("Class"));
}

defaultproperties
{
    CharacterChangeHelp="Change your appearance. Your character changes immediately; your inventory is kept."
}
