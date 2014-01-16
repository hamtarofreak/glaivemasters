function DispatchOnPostSpawn()
	print("Adding Thinker to Glaive")
	AddThinkToEnt( thisEntity, "GlaiveThink" )
end

GLAIVE_SPELL = "glaive_damage"
GLAIVE_DAMAGE = "glaivemasters_plus_damage"
GLAIVE_BOUNCES = "glaivemasters_plus_bounces"
GLAIVE_SPEED = "glaivemasters_plus_speed"
GLAIVE_RADIUS = "glaivemasters_plus_radius"
s_GlaiveThrowAbility = thisEntity:FindAbilityByName( GLAIVE_SPELL )
function GlaiveThink()
	print("Tick")
	if s_GlaiveThrowAbility == nil then
		error( string.format( "Cannot initialize ability %s", GLAIVE_SPELL ) )
		return 0.1
	end
	local unitsAround = FindUnitsInRadius( thisEntity:GetTeamNumber(), thisEntity:GetOrigin(), nil, 100.0, DOTA_UNIT_TARGET_TEAM_BOTH, DOTA_UNIT_TARGET_ALL , 0, 0, false )
	if #unitsAround == 0 then
		print("No units around?")
	else
		for i = 1, #unitsAround do
			local theUnit = unitsAround[i]
			if string.find( theUnit:GetUnitName(), "npc_dota_hero_silencer" ) then
				if s_GlaiveThrowAbility:IsFullyCastable() != false then
					print("Casting damage spell on unit")
					thisEntity:CastAbilityOnTarget( theUnit, s_GlaiveThrowAbility, 0 )
				end
			end
		end
		printTable(unitsAround, " ")
	end
	return 0.1
end

function printTable( t, indent )
	for k,v in pairs( t ) do
        if type( v ) == "table" then
        	if ( v ~= t ) then
				print( indent..tostring(k)..":\n"..indent.."{" )
        		printTable( v, indent.."  " )
				print( indent.."}" )
        	end
        else
        	print( indent..tostring(k)..":"..tostring(v) )
        end
    end
end