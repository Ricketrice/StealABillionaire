-- Studio location: ReplicatedStorage.HeistConfig (ModuleScript)
-- HeistConfig  (Milestone 032, D22/D24 Boss Heist): every number for the vault, the Boss Capsule and the
-- security robot, shared by server and client. Numbers marked PROPOSED wait for the owner's approval
-- (032 Checkpoint 1).
-- Switch: HeistEnabled (HeistConfig.ENABLED). OFF = Main Street exactly as before 032: nothing is added to
-- the world. In Studio, set the ServerStorage attribute StudioHeist = true; the server publishes the
-- ReplicatedStorage attribute HeistOn for clients.

local WorkerCatalogue = require(script.Parent:WaitForChild("WorkerCatalogue"))

local HeistConfig = {}

HeistConfig.ENABLED = false
HeistConfig.STUDIO_ATTRIBUTE = "StudioHeist"
HeistConfig.PUBLISHED = "HeistOn"

-- Timing (seconds)
HeistConfig.INTERVAL = 600 -- the vault opens every 10 minutes (D24)
HeistConfig.WINDOW = 60 -- and stays open this long; grabs only while open (D24)
HeistConfig.FIRST_OPEN = 180 -- PROPOSED: first opening this long after the server starts
HeistConfig.CARRY_LIMIT = 90 -- PROPOSED: a capsule not brought home in this time flies back (no hiding forever)

-- Boss Capsule: one per player per opening, rolled from this zone's roster (inside a rarity every worker
-- is equally likely). Guaranteed Epic or better (D24). PROPOSED: Epic 85% · Legendary 13% · Secret 2%.
HeistConfig.ZONE = "MainStreet"
HeistConfig.PER_MILLE = { Common = 0, Rare = 0, Epic = 850, Legendary = 130, Secret = 20 }
HeistConfig.RARITIES = { "Epic", "Legendary", "Secret" } -- shown on the vault sign

-- Security robot
HeistConfig.ROBOT_SPEED = 13.6 -- PROPOSED: = base carry speed (walk 16 x 0.85)
HeistConfig.HITS = 2 -- 1st hit pops the shield bubble, 2nd sends the capsule back to the vault (D22)
HeistConfig.HIT_GRACE = 2.0 -- PROPOSED: after a hit, that player can't be hit again for this long
HeistConfig.MIN_WARNING = 1.5 -- every attack shows its warning at least this long (D24); asserted below
HeistConfig.ATTACK_GAP = 2.5 -- PROPOSED: rest between two attacks
HeistConfig.ATTACKS = { -- PROPOSED
	-- searchlight: a circle follows the target, locks (turns red) and zaps that spot; walk out of it
	Searchlight = { warning = 2.0, range = 60, radius = 6 },
	-- laser: a red line appears on the ground across the lane, then the laser sweeps along it; step off it
	Laser = { warning = 1.8, range = 40, length = 36, width = 4 },
	-- stomp: the robot lifts a foot, a ring shows the reach, a shockwave rolls out along the ground; jump it
	Stomp = { warning = 1.6, range = 24, radius = 28, waveSpeed = 22, band = 2.5, jumpClear = 2.5 },
}

-- "Epic 85% · Legendary 13% · Secret 2%" for the vault sign.
function HeistConfig.oddsText(): string
	local parts = {}
	for _, rarity in HeistConfig.RARITIES do
		local pct = (HeistConfig.PER_MILLE[rarity] or 0) / 10
		table.insert(parts, ("%s %s%%"):format(rarity, if pct % 1 == 0 then tostring(math.floor(pct)) else tostring(pct)))
	end
	return table.concat(parts, " · ")
end

do
	local total = 0
	for _, rarity in WorkerCatalogue.RARITIES do
		total += HeistConfig.PER_MILLE[rarity] or 0
	end
	assert(total == 1000, "Boss Capsule odds must cover 100%")
	assert((HeistConfig.PER_MILLE.Common or 0) == 0 and (HeistConfig.PER_MILLE.Rare or 0) == 0, "Boss Capsule is Epic or better")
	for name, attack in HeistConfig.ATTACKS do
		assert(attack.warning >= HeistConfig.MIN_WARNING, name .. " warning is shorter than 1.5 s")
	end
	assert(HeistConfig.WINDOW < HeistConfig.INTERVAL, "the vault can't be open longer than its interval")
end

return HeistConfig
