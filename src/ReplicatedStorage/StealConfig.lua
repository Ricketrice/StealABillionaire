-- Studio location: ReplicatedStorage.StealConfig (ModuleScript)
-- StealConfig  (Milestone 033): fair stealing, so kids don't lose everything (RETENTION_AND_JUICE: Tension, capped).
-- !! PROPOSED NUMBERS (033 Checkpoint 1).
-- Switch FAIR_ENABLED (Studio ServerStorage attribute StudioFairSteal; published ReplicatedStorage FairStealOn).
-- OFF = stealing works exactly as in 022 (favourites can be stolen, no limits).
--   * favourite: one starred worker per player (the star in Workers) can't be stolen; a small shield shows over it
--   * same base: a thief can steal from the same player at most once per SAME_BASE_COOLDOWN
--   * victim cap: a player loses at most VICTIM_MAX_LOSSES workers per VICTIM_WINDOW; then their base gets a safety
--     bubble for BUBBLE seconds (shown like new-player protection; it ends early if they start a steal themselves)
--   * no shop offer pops up for NO_OFFER_AFTER_LOSS seconds after being robbed or caught (RETENTION_AND_JUICE: Never)
-- All counters live on the server for as long as it runs (not saved).

local StealConfig = {}

StealConfig.FAIR_ENABLED = true -- D46: live
StealConfig.STUDIO_ATTRIBUTE = "StudioFairSteal"
StealConfig.PUBLISHED = "FairStealOn"

StealConfig.FAVOURITE_PROTECTED = true
StealConfig.FAVOURITES_MAX = 1 -- while fair stealing is on, starring a worker moves the star (one favourite)
StealConfig.SAME_BASE_COOLDOWN = 300 -- PROPOSED: 5 min between two steals by the same thief from the same player
StealConfig.VICTIM_MAX_LOSSES = 2 -- PROPOSED: at most 2 workers lost...
StealConfig.VICTIM_WINDOW = 600 -- PROPOSED: ...per 10 min, then
StealConfig.BUBBLE = 180 -- PROPOSED: a 3 min safety bubble on their base
StealConfig.NO_OFFER_AFTER_LOSS = 300 -- seconds without any shop offer after being robbed or caught

-- Whether fair stealing is on. Server: config or (Studio) the ServerStorage attribute. Client: the published attribute.
function StealConfig.on(): boolean
	local RunService = game:GetService("RunService")
	if RunService:IsServer() then
		return (require(script.Parent:WaitForChild("LaunchFlag")) :: any)(StealConfig.FAIR_ENABLED, StealConfig.STUDIO_ATTRIBUTE)
	end
	return game:GetService("ReplicatedStorage"):GetAttribute(StealConfig.PUBLISHED) == true
end

return StealConfig
