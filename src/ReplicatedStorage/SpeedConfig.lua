-- Studio location: ReplicatedStorage.SpeedConfig (ModuleScript)
-- SpeedConfig  (Milestone 032, D24): the Speed stat and the cash-only speed trails, shared by server and
-- client. Prices and boosts are PROPOSED, waiting for the owner's approval (032 Checkpoint 1).
-- Switch: SpeedEnabled (SpeedConfig.ENABLED). OFF = everyone walks at the old speed, no Speed on the HUD,
-- no Trails tab. In Studio, set the ServerStorage attribute StudioSpeed = true; the server publishes the
-- ReplicatedStorage attribute SpeedOn for clients.
-- Save (optional field, schema stays 3): hub.speed = { owned = { trailId, ... }, on = trailId? }.

local SpeedConfig = {}

SpeedConfig.ENABLED = false
SpeedConfig.STUDIO_ATTRIBUTE = "StudioSpeed"
SpeedConfig.PUBLISHED = "SpeedOn"

SpeedConfig.BASE_WALK = 16 -- Roblox default; carrying = walk x 0.85 (NPCCarry)
SpeedConfig.MAX_BOOST = 0.30 -- PROPOSED cap on the total boost (+30%), keeps the heist and stealing fair
-- HUD number: 100 = normal speed, 130 = +30% (PROPOSED: kids read "130" easier than "20.8 studs/s")
SpeedConfig.HUD_BASE = 100

-- One trail equipped at a time. Effects are client-side; "Low effects" shows a thin plain trail instead.
-- PROPOSED prices (cash) and boosts.
SpeedConfig.TRAILS = {
	{ id = "bubble", name = "Bubble Trail", icon = "trail_bubble", boost = 0.05, price = 5000, colour = { 140, 210, 255 } },
	{ id = "leaf", name = "Leaf Trail", icon = "trail_leaf", boost = 0.10, price = 20000, colour = { 90, 210, 90 } },
	{ id = "star", name = "Star Trail", icon = "trail_star", boost = 0.15, price = 60000, colour = { 255, 220, 60 } },
	{ id = "comet", name = "Comet Trail", icon = "trail_comet", boost = 0.20, price = 150000, colour = { 255, 150, 40 } },
	{ id = "rainbow", name = "Rainbow Trail", icon = "trail_rainbow", boost = 0.25, price = 400000, colour = { 255, 120, 200 } },
	{ id = "gold", name = "Gold Rush Trail", icon = "trail_gold", boost = 0.30, price = 1000000, colour = { 255, 190, 30 } },
}

SpeedConfig.BY_ID = {}
for order, trail in SpeedConfig.TRAILS do
	(trail :: any).order = order
	SpeedConfig.BY_ID[trail.id] = trail
end

-- Boost for an equipped trail id (nil = none), capped.
function SpeedConfig.boost(trailId: string?): number
	local trail = trailId and SpeedConfig.BY_ID[trailId]
	return math.min(if trail then trail.boost else 0, SpeedConfig.MAX_BOOST)
end

-- Number shown on the HUD for a boost.
function SpeedConfig.hudNumber(boost: number): number
	return math.floor(SpeedConfig.HUD_BASE * (1 + boost) + 0.5)
end

do
	local last = 0
	for _, trail in SpeedConfig.TRAILS do
		assert(trail.boost > last and trail.boost <= SpeedConfig.MAX_BOOST, trail.id .. ": boosts must rise and stay under the cap")
		assert(trail.price > 0 and trail.price % 1 == 0, trail.id .. " has a bad price")
		last = trail.boost
	end
end

return SpeedConfig
