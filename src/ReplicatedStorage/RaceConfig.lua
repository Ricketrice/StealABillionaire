-- Studio location: ReplicatedStorage.RaceConfig (ModuleScript)
-- RaceConfig  (Milestone 031, D21 Royale Race, numbers approved at Checkpoint 1 = D34): every number for the
-- race, shared by server and client.
-- Switch: RaceEnabled (RaceConfig.ENABLED). OFF = Zone 6 behaves exactly as before 031: nothing is added to
-- the world. In Studio, set the ServerStorage attribute StudioRace = true; the server publishes the
-- ReplicatedStorage attribute RaceOn for clients.
-- Course parts (pad, sign, podium board, checkpoints): ServerStorage.RaceCourse031, built by
-- tools/build031/B1_RaceCourse.lua. The server clones the visible parts into
-- Workspace.World.VelocityRoyale.RaceCourse while the race is on; the checkpoints stay on the server.

local ParadeConfig = require(script.Parent:WaitForChild("ParadeConfig"))
local WorkerCatalogue = require(script.Parent:WaitForChild("WorkerCatalogue"))

local RaceConfig = {}

RaceConfig.ENABLED = false
RaceConfig.STUDIO_ATTRIBUTE = "StudioRace"
RaceConfig.PUBLISHED = "RaceOn"
RaceConfig.TEMPLATE = "RaceCourse031" -- ServerStorage
RaceConfig.FOLDER = "RaceCourse" -- Workspace.World.VelocityRoyale

-- Timing (seconds)
RaceConfig.INTERVAL = 180 -- a race every 3 minutes if at least 1 player is on the pad
RaceConfig.COUNTDOWN = 5 -- big numbers + sound; stepping off the pad before GO = not in the race
RaceConfig.TIME_LIMIT = 64 -- from GO: 2x a measured 3-lap run (31.7 s, 2026-10-13; max 90); unfinished racers get nothing
RaceConfig.PODIUM_SECONDS = 20 -- top 3 names stay on the podium board
RaceConfig.LAPS = 3

-- Racing: everyone runs at the same fixed speed (D24), no collisions between racers.
RaceConfig.WALK_SPEED = 16
RaceConfig.COLLISION_GROUP = "Racers"
RaceConfig.TICK = 0.1 -- server checkpoint check
-- A racer who moves further than this in one tick (studs, flat) was teleported: that tick counts no
-- checkpoint, and WARP_LIMIT such ticks take them out of the race.
RaceConfig.WARP_STUDS = 10
RaceConfig.WARP_LIMIT = 3
RaceConfig.REVEAL_DELAY = 1.2 -- capsule pops at the finish, then the usual reveal card

-- Rewards. Gold for the top GOLD_PLACES finishers, Silver for everyone else who finishes.
-- Small races: with fewer than SMALL_RACE_MIN racers only 1st gets Gold (stops solo servers farming Gold).
RaceConfig.GOLD_PLACES = 3
RaceConfig.SMALL_RACE_MIN = 4
RaceConfig.SMALL_RACE_GOLD_PLACES = 1

-- Capsule odds (D34): Silver = normal parade odds (70/20/8/1.8/0.2), Gold = Golden Parade odds
-- (50/30/14.5/5/0.5). Capsules are free and solo players win Gold every race, so neither is better than
-- what the parade already gives. Rolled from the whole Zone 6 pool (BillionaireHills, 8 workers): inside a
-- rarity every worker is equally likely. Existing Zone 6 catch odds are untouched.
RaceConfig.ZONE = "BillionaireHills"
RaceConfig.PER_MILLE = {
	Silver = WorkerCatalogue.RARITY_PER_MILLE,
	Gold = ParadeConfig.GOLDEN_PER_MILLE,
}
RaceConfig.RARITIES = { "Common", "Rare", "Epic", "Legendary", "Secret" }

-- Gold places in a race that started with `racers` players.
function RaceConfig.goldPlaces(racers: number): number
	return if racers >= RaceConfig.SMALL_RACE_MIN then RaceConfig.GOLD_PLACES else RaceConfig.SMALL_RACE_GOLD_PLACES
end

-- "70/20/8/1.8/0.2" style text for the pad sign.
function RaceConfig.oddsText(capsule: string): string
	local parts = {}
	for _, rarity in RaceConfig.RARITIES do
		local pct = (RaceConfig.PER_MILLE[capsule][rarity] or 0) / 10
		table.insert(parts, ("%s %s%%"):format(rarity, if pct % 1 == 0 then tostring(math.floor(pct)) else tostring(pct)))
	end
	return table.concat(parts, " · ")
end

assert(RaceConfig.TIME_LIMIT <= 90, "race time limit is capped at 90 s")
assert(RaceConfig.PER_MILLE.Gold.Legendary > RaceConfig.PER_MILLE.Silver.Legendary, "Gold must beat Silver")

return RaceConfig
