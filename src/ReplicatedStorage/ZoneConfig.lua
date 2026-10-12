-- Studio location: ReplicatedStorage.ZoneConfig (ModuleScript)
-- ZoneConfig
-- District progression, shared by the server (rules) and clients (gate UI). Zone 1 is free; the
-- others unlock one after another, in `number` order, with cash. Unlocks are permanent.
--
-- Prices are PLACEHOLDERS approved for testing in Milestone 014, not final economy balance.
--
--   id           the district's ZoneId (attribute on its Workspace.World.FutureZones folder)
--   folder       that folder's name (gate model, NPC area)
--   purchasable  the server accepts unlock purchases for it
--   gate         its gate is wired up: per-player access on the client plus the server's
--                boundary check. Only wire a gate once its district is approved for integration.
--
-- Food Court (Zone 2) is teammate-owned: it is listed for the unlock order only, with no purchase
-- or gate wiring until that integration is approved. Beach Boardwalk's gate is reached through
-- the Food Court, so it waits for the same approval. Toy Town is the approved test gate.

local ZoneConfig = {}

export type Zone = {
	id: string,
	number: number,
	name: string,
	price: number,
	folder: string?,
	purchasable: boolean,
	gate: boolean,
	requires: string?, -- the zone that must be unlocked first (default: the one before it)
}

ZoneConfig.FREE_ZONE = "MainStreet"

ZoneConfig.ZONES = {
	{ id = "MainStreet", number = 1, name = "Main Street", price = 0, purchasable = false, gate = false },
	{ id = "FoodCourt", number = 2, name = "Food Court", price = 40000, folder = "Zone2_FoodCourt", purchasable = false, gate = false },
	{ id = "BeachBoardwalk", number = 3, name = "Beach Boardwalk", price = 150000, folder = "Zone3_BeachBoardwalk", purchasable = false, gate = false },
	{ id = "ToyTown", number = 4, name = "Toy Town", price = 500000, folder = "Zone4_ToyTown", purchasable = true, gate = true },
	{ id = "NeonDowntown", number = 5, name = "Neon Downtown", price = 1500000, folder = "Zone5_NeonDowntown", purchasable = false, gate = false },
	-- Zone 6 is ours: its gate is the top of the Rising Lane (030). PROPOSED launch price 500,000 while Zones 2-5 are
	-- closed (the old 5,000,000 ladder price returns once they open); it needs only Main Street.
	{
		id = "BillionaireHills",
		number = 6,
		name = "Billionaire Hills",
		price = 500000,
		folder = "Zone6_BillionaireHills",
		purchasable = true,
		gate = true,
		requires = "MainStreet",
	},
} :: { Zone }

-- Worker progression foundation. Each district names the WorkerCatalogue roster its NPCs roll from
-- (a key of WorkerCatalogue.ZONES; nil until that district's workers are designed) and a planning
-- target for how much its workers should earn compared with Main Street's. The multiplier is a
-- design target for future rosters only: it is not applied to any earnings. A district spawns NPCs
-- once it has a Workspace.Zones.<roster> folder (ZoneBoundary + SpawnPoints) and an NPCSpawner entry.
ZoneConfig.WORKERS = {
	MainStreet = { roster = "MainStreet", targetIncomeMultiplier = 1 },
	FoodCourt = { roster = nil, targetIncomeMultiplier = 2.5 },
	BeachBoardwalk = { roster = nil, targetIncomeMultiplier = 6 },
	ToyTown = { roster = nil, targetIncomeMultiplier = 15 },
	NeonDowntown = { roster = nil, targetIncomeMultiplier = 40 },
	BillionaireHills = { roster = nil, targetIncomeMultiplier = 100 },
} :: { [string]: { roster: string?, targetIncomeMultiplier: number } }

local byId: { [string]: Zone } = {}
local byNumber: { [number]: Zone } = {}

function ZoneConfig.get(zoneId: string): Zone?
	return byId[zoneId]
end

-- The district that must be unlocked before this one, or nil for Zone 1.
function ZoneConfig.previous(zoneId: string): Zone?
	local zone = byId[zoneId]
	return zone and byNumber[zone.number - 1]
end

-- The district that must be unlocked before this one: its `requires`, else the one before it (nil for Zone 1).
function ZoneConfig.prerequisite(zoneId: string): Zone?
	local zone = byId[zoneId]
	if zone and zone.requires then
		return byId[zone.requires]
	end
	return ZoneConfig.previous(zoneId)
end

-- Checks the configuration; errors describing the first problem found.
function ZoneConfig.validate()
	table.clear(byId)
	table.clear(byNumber)
	for index, zone in ZoneConfig.ZONES do
		assert(type(zone.id) == "string" and zone.id:match("^[%w_]+$"), "zone " .. index .. " needs a plain id")
		assert(not byId[zone.id], "zone id " .. zone.id .. " is listed twice")
		assert(zone.number == index, zone.id .. " must be zone number " .. index)
		assert(type(zone.price) == "number" and zone.price >= 0 and zone.price % 1 == 0, zone.id .. " has a bad price")
		assert(not zone.purchasable or zone.price > 0, zone.id .. " can't be bought for nothing")
		assert(not zone.gate or zone.folder, zone.id .. " needs a folder for its gate")
		assert(not zone.requires or zone.requires == ZoneConfig.FREE_ZONE or zone.requires ~= zone.id, zone.id .. " can't require itself")
		assert(ZoneConfig.WORKERS[zone.id], zone.id .. " needs a worker progression entry")
		byId[zone.id] = zone
		byNumber[zone.number] = zone
	end
	local free = byId[ZoneConfig.FREE_ZONE]
	assert(free and free.number == 1 and free.price == 0, "the free zone must be Zone 1 at no cost")
end

ZoneConfig.validate()

return ZoneConfig
