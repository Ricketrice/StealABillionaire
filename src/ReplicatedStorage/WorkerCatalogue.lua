-- Studio location: ReplicatedStorage.WorkerCatalogue (ModuleScript)
-- WorkerCatalogue
-- Every worker that can be caught: stable ids, display info, rarity, role and Level 1 / Normal
-- tier base stats. Shared read-only data: the server rolls and pays from it; clients only display it.
--
-- Rolling a worker for a zone: first a rarity from RARITY_PER_MILLE (the same for every zone),
-- then a uniform pick among that zone's workers of that rarity. validate() requires every zone
-- roster to contain every rarity, so adding a zone can never change the rarity odds.
--
-- To add a zone: add its workers to WORKERS (with `zone` set) and a roster to ZONES, keyed by the
-- zone's folder name under Workspace.Zones (which is also its ZoneConfig id).
--
-- District progression (Milestone 015): every district roster mirrors Main Street's shape, so
-- each slot keeps its rarity and role and the same income ratios inside the zone:
--   2 Common (Earner, All-rounder), 2 Rare (Fighter, Earner), 2 Epic (Tank, Earner),
--   1 Legendary, 1 Secret
-- Income is Main Street's income for that slot times the district's ZoneConfig.WORKERS
-- targetIncomeMultiplier (Beach x6, Toy Town x15, Neon x40, Hills x100). Attack/speed/defence
-- get +4 per district step (capped at 100, the UI meter's maximum). Only the server pays from these.
--
-- Food Court (Zone 2) is teammate-owned: its roster is a placeholder (PENDING_ZONES) until the team
-- approves its workers. It has no catalogue entries, so nothing can roll or pay for it yet.

local WorkerCatalogue = {}

export type Worker = {
	id: string,
	name: string,
	zone: string,
	rarity: string,
	role: string,
	income: number, -- $/sec at Level 1, Normal tier
	attack: number,
	speed: number,
	defence: number,
}

-- Lowest to highest.
WorkerCatalogue.RARITIES = { "Common", "Rare", "Epic", "Legendary", "Secret" }

-- Chance of each rarity in tenths of a percent (per mille), so the odds are exact whole numbers:
-- Common 70%, Rare 20%, Epic 8%, Legendary 1.8%, Secret 0.2%.
WorkerCatalogue.RARITY_PER_MILLE = {
	Common = 700,
	Rare = 200,
	Epic = 80,
	Legendary = 18,
	Secret = 2,
}

WorkerCatalogue.LEVEL = 1 -- every caught worker starts here (levelling comes later)
WorkerCatalogue.TIER = "Normal" -- every caught worker starts here (merging comes later)

local CustomWorkers = require(script.Parent:WaitForChild("CustomWorkers"))

local WORKERS: { [string]: Worker } = {
	-- Main Street
	broke_bob = { name = "Broke Bob", zone = "MainStreet", rarity = "Common", role = "Earner", income = 5, attack = 10, speed = 15, defence = 10 },
	delivery_dave = { name = "Delivery Dave", zone = "MainStreet", rarity = "Common", role = "All-rounder", income = 6, attack = 16, speed = 22, defence = 15 },
	street_hustler = { name = "Street Hustler", zone = "MainStreet", rarity = "Rare", role = "Fighter", income = 9, attack = 32, speed = 30, defence = 12 },
	business_betty = { name = "Business Betty", zone = "MainStreet", rarity = "Rare", role = "Earner", income = 14, attack = 12, speed = 17, defence = 18 },
	security_sam = { name = "Security Sam", zone = "MainStreet", rarity = "Epic", role = "Tank", income = 22, attack = 28, speed = 15, defence = 55 },
	crypto_carl = { name = "Crypto Carl", zone = "MainStreet", rarity = "Epic", role = "Earner", income = 35, attack = 17, speed = 24, defence = 15 },
	ceo_chad = { name = "CEO Chad", zone = "MainStreet", rarity = "Legendary", role = "All-rounder", income = 100, attack = 65, speed = 55, defence = 60 },
	mystery_millionaire = { name = "Mystery Millionaire", zone = "MainStreet", rarity = "Secret", role = "All-rounder", income = 500, attack = 85, speed = 80, defence = 80 },

	-- Beach Boardwalk (Zone 3): x6
	surfer_sid = { name = "Surfer Sid", zone = "BeachBoardwalk", rarity = "Common", role = "Earner", income = 30, attack = 14, speed = 19, defence = 14 },
	lifeguard_lucy = { name = "Lifeguard Lucy", zone = "BeachBoardwalk", rarity = "Common", role = "All-rounder", income = 36, attack = 20, speed = 26, defence = 19 },
	volleyball_vic = { name = "Volleyball Vic", zone = "BeachBoardwalk", rarity = "Rare", role = "Fighter", income = 54, attack = 36, speed = 34, defence = 16 },
	ice_cream_ivy = { name = "Ice Cream Ivy", zone = "BeachBoardwalk", rarity = "Rare", role = "Earner", income = 84, attack = 16, speed = 21, defence = 22 },
	pier_bouncer_bruno = { name = "Pier Bouncer Bruno", zone = "BeachBoardwalk", rarity = "Epic", role = "Tank", income = 132, attack = 32, speed = 19, defence = 59 },
	yacht_broker_yara = { name = "Yacht Broker Yara", zone = "BeachBoardwalk", rarity = "Epic", role = "Earner", income = 210, attack = 21, speed = 28, defence = 19 },
	boardwalk_baron = { name = "Boardwalk Baron", zone = "BeachBoardwalk", rarity = "Legendary", role = "All-rounder", income = 600, attack = 69, speed = 59, defence = 64 },
	captain_goldbeard = { name = "Captain Goldbeard", zone = "BeachBoardwalk", rarity = "Secret", role = "All-rounder", income = 3000, attack = 89, speed = 84, defence = 84 },

	-- Toy Town (Zone 4): x15
	toy_soldier_tom = { name = "Toy Soldier Tom", zone = "ToyTown", rarity = "Common", role = "Earner", income = 75, attack = 18, speed = 23, defence = 18 },
	balloon_bella = { name = "Balloon Bella", zone = "ToyTown", rarity = "Common", role = "All-rounder", income = 90, attack = 24, speed = 30, defence = 23 },
	robo_rex = { name = "Robo Rex", zone = "ToyTown", rarity = "Rare", role = "Fighter", income = 135, attack = 40, speed = 38, defence = 20 },
	yoyo_yuki = { name = "Yo-Yo Yuki", zone = "ToyTown", rarity = "Rare", role = "Earner", income = 210, attack = 20, speed = 25, defence = 26 },
	nutcracker_ned = { name = "Nutcracker Ned", zone = "ToyTown", rarity = "Epic", role = "Tank", income = 330, attack = 36, speed = 23, defence = 63 },
	toymaker_tilly = { name = "Toymaker Tilly", zone = "ToyTown", rarity = "Epic", role = "Earner", income = 525, attack = 25, speed = 32, defence = 23 },
	toy_tycoon_theo = { name = "Toy Tycoon Theo", zone = "ToyTown", rarity = "Legendary", role = "All-rounder", income = 1500, attack = 73, speed = 63, defence = 68 },
	golden_teddy = { name = "The Golden Teddy", zone = "ToyTown", rarity = "Secret", role = "All-rounder", income = 7500, attack = 93, speed = 88, defence = 88 },

	-- Neon Downtown (Zone 5): x40
	night_courier_nia = { name = "Night Courier Nia", zone = "NeonDowntown", rarity = "Common", role = "Earner", income = 200, attack = 22, speed = 27, defence = 22 },
	arcade_andy = { name = "Arcade Andy", zone = "NeonDowntown", rarity = "Common", role = "All-rounder", income = 240, attack = 28, speed = 34, defence = 27 },
	dj_dynamo = { name = "DJ Dynamo", zone = "NeonDowntown", rarity = "Rare", role = "Fighter", income = 360, attack = 44, speed = 42, defence = 24 },
	neon_nate = { name = "Neon Nate", zone = "NeonDowntown", rarity = "Rare", role = "Earner", income = 560, attack = 24, speed = 29, defence = 30 },
	bouncer_blaze = { name = "Bouncer Blaze", zone = "NeonDowntown", rarity = "Epic", role = "Tank", income = 880, attack = 40, speed = 27, defence = 67 },
	hacker_hex = { name = "Hacker Hex", zone = "NeonDowntown", rarity = "Epic", role = "Earner", income = 1400, attack = 29, speed = 36, defence = 27 },
	neon_mogul_max = { name = "Neon Mogul Max", zone = "NeonDowntown", rarity = "Legendary", role = "All-rounder", income = 4000, attack = 77, speed = 67, defence = 72 },
	midnight_magnate = { name = "Midnight Magnate", zone = "NeonDowntown", rarity = "Secret", role = "All-rounder", income = 20000, attack = 97, speed = 92, defence = 92 },

	-- Billionaire Hills (Zone 6): x100
	butler_barnaby = { name = "Butler Barnaby", zone = "BillionaireHills", rarity = "Common", role = "Earner", income = 500, attack = 26, speed = 31, defence = 26 },
	caddie_gus = { name = "Caddie Gus", zone = "BillionaireHills", rarity = "Common", role = "All-rounder", income = 600, attack = 32, speed = 38, defence = 31 },
	polo_pro_penny = { name = "Polo Pro Penny", zone = "BillionaireHills", rarity = "Rare", role = "Fighter", income = 900, attack = 48, speed = 46, defence = 28 },
	chef_pierre = { name = "Chef Pierre", zone = "BillionaireHills", rarity = "Rare", role = "Earner", income = 1400, attack = 28, speed = 33, defence = 34 },
	bodyguard_boris = { name = "Bodyguard Boris", zone = "BillionaireHills", rarity = "Epic", role = "Tank", income = 2200, attack = 44, speed = 31, defence = 71 },
	hedge_fund_hank = { name = "Hedge Fund Hank", zone = "BillionaireHills", rarity = "Epic", role = "Earner", income = 3500, attack = 33, speed = 40, defence = 31 },
	oil_baron_oswald = { name = "Oil Baron Oswald", zone = "BillionaireHills", rarity = "Legendary", role = "All-rounder", income = 10000, attack = 81, speed = 71, defence = 76 },
	the_trillionaire = { name = "The Trillionaire", zone = "BillionaireHills", rarity = "Secret", role = "All-rounder", income = 50000, attack = 100, speed = 96, defence = 96 },
}
for id, worker in WORKERS do
	worker.id = id
end

-- Custom character models (Milestone 019) come with their own display names. Only `name` changes:
-- ids, zones, rarities and stats above are untouched, and switching a worker off in CustomWorkers
-- brings its original name back.
for id, worker in WORKERS do
	local custom = CustomWorkers.get(id)
	if custom then
		worker.name = custom.name
	end
end

-- Each zone's roster, keyed by zone id (the zone's folder name under Workspace.Zones).
local ZONES: { [string]: { string } } = {
	MainStreet = {
		"broke_bob",
		"delivery_dave",
		"street_hustler",
		"business_betty",
		"security_sam",
		"crypto_carl",
		"ceo_chad",
		"mystery_millionaire",
	},
	BeachBoardwalk = {
		"surfer_sid",
		"lifeguard_lucy",
		"volleyball_vic",
		"ice_cream_ivy",
		"pier_bouncer_bruno",
		"yacht_broker_yara",
		"boardwalk_baron",
		"captain_goldbeard",
	},
	ToyTown = {
		"toy_soldier_tom",
		"balloon_bella",
		"robo_rex",
		"yoyo_yuki",
		"nutcracker_ned",
		"toymaker_tilly",
		"toy_tycoon_theo",
		"golden_teddy",
	},
	NeonDowntown = {
		"night_courier_nia",
		"arcade_andy",
		"dj_dynamo",
		"neon_nate",
		"bouncer_blaze",
		"hacker_hex",
		"neon_mogul_max",
		"midnight_magnate",
	},
	BillionaireHills = {
		"butler_barnaby",
		"caddie_gus",
		"polo_pro_penny",
		"chef_pierre",
		"bodyguard_boris",
		"hedge_fund_hank",
		"oil_baron_oswald",
		"the_trillionaire",
	},
}

-- Districts whose roster is waiting on approval. Listed for documentation only: they have no
-- workers, so they can't be rolled from, and their zone has no spawner.
WorkerCatalogue.PENDING_ZONES = {
	FoodCourt = "Zone 2 is teammate-owned; its workers are pending team approval",
}

WorkerCatalogue.WORKERS = WORKERS
WorkerCatalogue.ZONES = ZONES

-- zone id -> rarity -> worker ids, built by validate().
local byZoneAndRarity: { [string]: { [string]: { string } } } = {}

function WorkerCatalogue.get(workerId: string): Worker?
	return WORKERS[workerId]
end

-- Stats for a worker at a level and tier. Only Level 1 / Normal exists for now, which is the
-- catalogue's base stats; levelling and merging will scale these here.
function WorkerCatalogue.getStats(workerId: string, level: number, tier: string): (number, number, number, number)
	local worker = WORKERS[workerId]
	assert(worker, "unknown worker " .. tostring(workerId))
	assert(level == WorkerCatalogue.LEVEL and tier == WorkerCatalogue.TIER, "only Level 1 Normal workers exist yet")
	return worker.income, worker.attack, worker.speed, worker.defence
end

-- `perMille` (optional) replaces the normal odds for one roll, e.g. the Golden Parade's (Milestone 028).
-- It must cover 1000 per mille; nil = the normal RARITY_PER_MILLE.
function WorkerCatalogue.rollRarity(rng: Random, perMille: { [string]: number }?): string
	local odds = perMille or WorkerCatalogue.RARITY_PER_MILLE
	local roll = rng:NextInteger(1, 1000)
	local cumulative = 0
	for _, rarity in WorkerCatalogue.RARITIES do
		cumulative += odds[rarity] or 0
		if roll <= cumulative then
			return rarity
		end
	end
	error("rarity odds don't cover 1000") -- unreachable once validate() has passed
end

-- Rolls a rarity, then picks uniformly among the zone's workers of that rarity.
function WorkerCatalogue.rollWorker(zoneId: string, rng: Random, perMille: { [string]: number }?): string
	local zone = byZoneAndRarity[zoneId]
	assert(zone, "no worker roster for zone " .. tostring(zoneId))
	local candidates = zone[WorkerCatalogue.rollRarity(rng, perMille)]
	return candidates[rng:NextInteger(1, #candidates)]
end

-- Checks the catalogue is consistent; errors describing the first problem found.
function WorkerCatalogue.validate()
	local total = 0
	for _, rarity in WorkerCatalogue.RARITIES do
		local perMille = WorkerCatalogue.RARITY_PER_MILLE[rarity]
		assert(type(perMille) == "number" and perMille > 0 and perMille % 1 == 0, "bad odds for rarity " .. rarity)
		total += perMille
	end
	assert(total == 1000, ("rarity odds total %.1f%%, not 100%%"):format(total / 10))

	for id, worker in WORKERS do
		assert(WorkerCatalogue.RARITY_PER_MILLE[worker.rarity], id .. " has unknown rarity " .. tostring(worker.rarity))
		assert(ZONES[worker.zone], id .. " belongs to unknown zone " .. tostring(worker.zone))
		for _, field in { "income", "attack", "speed", "defence" } do
			local value = worker[field]
			assert(type(value) == "number" and value >= 0 and value % 1 == 0, id .. " has a bad " .. field)
		end
		assert(type(worker.name) == "string" and type(worker.role) == "string", id .. " needs a name and role")
	end

	table.clear(byZoneAndRarity)
	local listed = {}
	for zoneId, roster in ZONES do
		local byRarity = {}
		local seen = {}
		for _, id in roster do
			local worker = WORKERS[id]
			assert(worker, ("zone %s lists unknown worker %s"):format(zoneId, tostring(id)))
			assert(worker.zone == zoneId, ("zone %s lists %s, which belongs to %s"):format(zoneId, id, worker.zone))
			assert(not seen[id], ("zone %s lists %s twice"):format(zoneId, id))
			seen[id] = true
			listed[id] = true
			byRarity[worker.rarity] = byRarity[worker.rarity] or {}
			table.insert(byRarity[worker.rarity], id)
		end
		for _, rarity in WorkerCatalogue.RARITIES do
			assert(byRarity[rarity], ("zone %s has no %s worker, which would change the rarity odds"):format(zoneId, rarity))
		end
		byZoneAndRarity[zoneId] = byRarity
	end
	for id in WORKERS do
		assert(listed[id], id .. " isn't in its zone's roster")
	end
end

WorkerCatalogue.validate()

return WorkerCatalogue
