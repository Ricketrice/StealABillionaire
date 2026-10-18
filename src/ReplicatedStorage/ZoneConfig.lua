-- Studio location: ReplicatedStorage.ZoneConfig (ModuleScript)
-- ZoneConfig
-- District progression, shared by the server (rules) and clients (gate UI). Zone 1 is free; the
-- others unlock one after another, in `number` order (= the Rising Lane's terrace order), with cash.
-- Unlocks are permanent.
--
-- 034 (Steal a Boss, D41/D43): the lane is Knight's Keep (MainStreet) -> Sunken Kingdom -> Ember Academy
-- (BillionaireHills). Internal ids never change (saves); only `number`, `name` and prices did.
-- D48 (owner): the four teammate zones (4-7) are removed from the game. They are kept in RETIRED below for the
-- record only: nothing reads it, so no gate, unlock, teleport, menu or book page reaches them.
--
--   id           the district's ZoneId (attribute on its Workspace.World.FutureZones folder)
--   folder       that folder's name (gate model, NPC area)
--   purchasable  the server accepts unlock purchases for it (only while it is also ready)
--   gate         its gate is wired up: per-player access on the client plus the server's
--                boundary check
--   ready        false = "Coming soon", locked for everyone (no purchase, no entry, even with an old unlock in the
--                save); set from READY. No zone uses it since D48.

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
	ready: boolean?, -- set from READY (teammate zones); nil = always ready (ours)
}

ZoneConfig.FREE_ZONE = "MainStreet"

-- "Coming soon" switches (D43). Empty since D48: the teammate zones that used them are retired.
ZoneConfig.READY = {} :: { [string]: boolean }

ZoneConfig.ZONES = {
	{ id = "MainStreet", number = 1, name = "Knight's Keep", price = 0, purchasable = false, gate = false },
	-- Ours (034): both are lane gates (Gate attribute LaneGate).
	{ id = "SunkenKingdom", number = 2, name = "Sunken Kingdom", price = 50000, folder = "Our_SunkenKingdom", purchasable = true, gate = true },
	{ id = "BillionaireHills", number = 3, name = "Ember Academy", price = 500000, folder = "Zone6_BillionaireHills", purchasable = true, gate = true },
} :: { Zone }

-- D48: removed teammate zones, kept for the record (ids stay valid in saves and the worker catalogue). Not read by any system;
-- their map pieces are parked in ServerStorage._ParkedZones4to7.
ZoneConfig.RETIRED = {
	{ id = "FoodCourt", number = 4, name = "Food Court", price = 2500000, folder = "Zone2_FoodCourt" },
	{ id = "BeachBoardwalk", number = 5, name = "Beach Boardwalk", price = 7500000, folder = "Zone3_BeachBoardwalk" },
	{ id = "ToyTown", number = 6, name = "Toy Town", price = 25000000, folder = "Zone4_ToyTown" },
	{ id = "NeonDowntown", number = 7, name = "Neon Downtown", price = 75000000, folder = "Zone5_NeonDowntown" },
}

-- Worker progression foundation. Each district names the WorkerCatalogue roster its NPCs roll from
-- (a key of WorkerCatalogue.ZONES; nil until that district's workers are designed) and a planning
-- target for how much its workers should earn compared with Main Street's. The multiplier is a
-- design target for future rosters only: it is not applied to any earnings. A district spawns NPCs
-- once it has a Workspace.Zones.<roster> folder (ZoneBoundary + SpawnPoints) and an NPCSpawner entry.
ZoneConfig.WORKERS = {
	MainStreet = { roster = "MainStreet", targetIncomeMultiplier = 1 },
	SunkenKingdom = { roster = "SunkenKingdom", targetIncomeMultiplier = 10 },
	FoodCourt = { roster = nil, targetIncomeMultiplier = 2.5 },
	BeachBoardwalk = { roster = nil, targetIncomeMultiplier = 6 },
	ToyTown = { roster = nil, targetIncomeMultiplier = 15 },
	NeonDowntown = { roster = nil, targetIncomeMultiplier = 40 },
	BillionaireHills = { roster = "BillionaireHills", targetIncomeMultiplier = 100 },
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

-- False while a teammate zone is "Coming soon" (READY): nobody can buy or enter it.
function ZoneConfig.isReady(zoneId: string): boolean
	local zone = byId[zoneId]
	return zone ~= nil and zone.ready ~= false
end

-- The server sells it right now: purchasable and ready.
function ZoneConfig.forSale(zone: Zone): boolean
	return zone.purchasable and zone.ready ~= false
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
		if ZoneConfig.READY[zone.id] ~= nil then
			zone.ready = ZoneConfig.READY[zone.id] == true
		end
		byId[zone.id] = zone
		byNumber[zone.number] = zone
	end
	local free = byId[ZoneConfig.FREE_ZONE]
	assert(free and free.number == 1 and free.price == 0, "the free zone must be Zone 1 at no cost")
end

ZoneConfig.validate()

return ZoneConfig
