-- Syntax copied mostly from frostivus example

-- Constants
MAX_PLAYERS = 10
STARTING_GOLD = 0

-- State control
STATE_INIT = 0      -- Waiting for players

-- Written like this to allow reloading
if GlaiveMastersGameMode == nil then
	GlaiveMastersGameMode = {}
	GlaiveMastersGameMode.szEntityClassName = "glaivemasters"
	GlaiveMastersGameMode.szNativeClassName = "dota_base_game_mode"
	GlaiveMastersGameMode.__index = GlaiveMastersGameMode
end

function GlaiveMastersGameMode:new (o)
	o = o or {}
	setmetatable(o, self)
	return o
end

function GlaiveMastersGameMode:InitGameMode()
    -- Setup rules
    GameRules:SetHeroRespawnEnabled( true )
    GameRules:SetUseUniversalShopMode( true )
    GameRules:SetSameHeroSelectionEnabled( true )
    GameRules:SetHeroSelectionTime( 0.0 )
    GameRules:SetPreGameTime( 60.0 )
    GameRules:SetPostGameTime( 60.0 )
    GameRules:SetTreeRegrowTime( 30.0 )
    GameRules:SetHeroMinimapIconSize( 400 )
    GameRules:SetCreepMinimapIconScale( 0.7 )
    GameRules:SetRuneMinimapIconScale( 0.7 )

    -- Hooks
    ListenToGameEvent('player_connect_full', Dynamic_Wrap(GlaiveMastersGameModeGameMode, 'AutoAssignPlayer'), self)
    ListenToGameEvent('player_disconnect', Dynamic_Wrap(GlaiveMastersGameModeGameMode, 'CleanupPlayer'), self)

    -- -- Mod Events
    -- self:ListenToEvent('dota_player_used_ability')
    -- self:ListenToEvent('dota_player_learned_ability')
    -- self:ListenToEvent('dota_player_gained_level')
    -- self:ListenToEvent('dota_item_purchased')
    -- self:ListenToEvent('dota_item_used')
    -- self:ListenToEvent('last_hit')
    -- self:ListenToEvent('dota_item_picked_up')
    -- self:ListenToEvent('dota_super_creep')
    -- self:ListenToEvent('dota_glyph_used')
    -- self:ListenToEvent('dota_courier_respawned')
    -- self:ListenToEvent('dota_courier_lost')

    -- userID map
    self.vUserIDMap = {}

    -- Active Hero Map
    self.vActiveHeroMap = {}

    -- Load initial Values
    self:_SetInitialValues()

	Convars:SetBool("dota_force_night", true )
    Convars:SetBool("dota_suppress_invalid_orders", true)

    -- Precache everything
    print('\n\nprecaching:')
    PrecacheUnit('npc_precache_everything')
    print('done precaching!\n\n')
end

function GlaiveMastersGameMode:_SetInitialValues()
    -- Change random seed
    local timeTxt = string.gsub(string.gsub(GetSystemTime(), ':', ''), '0','')
    math.randomseed(tonumber(timeTxt))

    -- Load ability List
    self:LoadAbilityList()

    -- Timers
    self.timers = {}
	
    -- Stores the current skill list for each hero
    self.currentSkillList = {}

    -- Reset Builds
    self:ResetBuilds()

    -- Options
    self.gamemodeOptions = {}

    -- Scores
    self.scoreDire = 0
    self.scoreRadiant = 0

    -- The state of the game
    self.currentState = STATE_INIT;
    self:ChangeStateData({});
end

function GlaiveMastersGameMode:AutoAssignPlayer(keys)
    -- Grab the entity index of this player
    local entIndex = keys.index+1
    local ply = EntIndexToHScript(entIndex)

    -- Find the team with the least players
    local teamSize = {
        [DOTA_TEAM_GOODGUYS] = 0,
        [DOTA_TEAM_BADGUYS] = 0
    }

    self:LoopOverPlayers(function(ply, playerID)
        if Players:GetPlayer(playerID) then
            local ply = Players:GetPlayer(playerID)
            if ply then
                -- Grab the players team
                local team = ply:GetTeam()

                -- Increase the number of players on this players team
                teamSize[team] = (teamSize[team] or 0) + 1
            end
        end
    end)

    if teamSize[DOTA_TEAM_GOODGUYS] > teamSize[DOTA_TEAM_BADGUYS] then
        ply:SetTeam(DOTA_TEAM_BADGUYS)
        ply:__KeyValueFromInt('teamnumber', DOTA_TEAM_BADGUYS)
    else
        ply:SetTeam(DOTA_TEAM_GOODGUYS)
        ply:__KeyValueFromInt('teamnumber', DOTA_TEAM_GOODGUYS)
    end

    --ply:__KeyValueFromInt('teamnumber', DOTA_TEAM_BADGUYS)

    --for i=0,4 do
    --    Players:UpdateTeamSlot(ply:GetPlayerID(), i)
    --end

    local playerID = ply:GetPlayerID()
    local hero = self:GetActiveHero(playerID)
    if IsValidEntity(hero) then
        hero:Remove()
    end

    -- Store into our map
    self.vUserIDMap[keys.userid] = ply

    self.selectedBuilds[playerID] = self:GetDefaultBuild()

    -- Autoassign player
    self:CreateTimer('assign_player_'..entIndex, {
        endTime = Time(),
        callback = function(glaivemasters, args)
            glaivemasters:SetActiveHero(CreateHeroForPlayer('npc_dota_hero_silencer_glaivemasters', ply))

            -- Check if we are in a game
            if self.currentState == STATE_PLAYING then
                -- Check if we need to assign a hero
                if IsValidEntity(self:GetActiveHero(playerID)) then
                    self:FireEvent('assignHero', ply)
                    self:FireEvent('onHeroSpawned', self:GetActiveHero(playerID))
                end
            end

            -- Fire new player event
            self:FireEvent('NewPlayer', ply)
        end
    })
end


-- Cleanup a player when they leave
function GlaiveMastersGameMode:CleanupPlayer(keys)
    -- Grab and validate the leaver
    local leavingPly = self.vUserIDMap[keys.userid];
    if not leavingPly then return end

    -- Fire event
    self:FireEvent('CleanupPlayer', leavingPly)

    -- Remove all Heroes owned by this player
    for k,v in pairs(Entities:FindAllByClassname('npc_dota_hero_*')) do
        if v:IsRealHero() then
            -- Grab the owning player
            local ply = Players:GetPlayer(v:GetPlayerID())

            -- Check if this is our leaver
            if ply and ply == leavingPly then
                -- Remove this hero
                v:Remove()
            end
        end
    end

    self:CreateTimer('cleanup_player_'..keys.userid, {
        endTime = Time() + 1,
        callback = function(glaivemasters, args)
            local foundSomeone = false

            -- Check if there are any players connected
            self:LoopOverPlayers(function(ply, playerID)
                foundSomeone = true
            end)

            if foundSomeone then
                return
            end

            -- No players are in, reset to initial vote
            self:_SetInitialValues()
        end
    })
end

-- Default settings for regular Dota
local minimapHeroScale = 600
local minimapCreepScale = 1