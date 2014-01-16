function glaiveOnSpellStart(keys)
	print("Spell Started")
	keys.target_entities[1]:AddNewModifier( keys.caster, nil, "MODIFIER_STATE_NO_HEALTH_BAR", nil )
	keys.target_entities[1]:AddNewModifier( keys.caster, nil, "MODIFIER_STATE_UNSELECTABLE", nil )
	keys.target_entities[1]:SetForwardVector( keys.caster:GetForwardVector() )
	keys.target_entities[1]:SetInitialGoalEntity( keys.target_entities[0] )
	keys.target_entities[1]:SetMustReachEachGoalEntity( true )
end