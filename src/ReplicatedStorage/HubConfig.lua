-- Studio location: ReplicatedStorage.HubConfig (ModuleScript)
-- HubConfig  (Milestone 026)
-- Every switch, number and line of text for the hub gameplay: the worker battle arena, the three
-- shops, the City Guide, the Quest Board and the shopkeepers. Shared by server and clients.
--
-- All four flags are OFF by default; with them off the game behaves exactly as before Milestone 026.
-- To test in Studio without editing this file, set a ServerStorage attribute to true (ignored
-- outside Studio):  StudioArena / StudioShops / StudioNpcQuests / StudioUpgrades
--
-- !! PROPOSED VALUES, NOT APPROVED: every price and cash reward below (marked PROPOSED) affects the
-- economy and is waiting for the team's approval. Change them here; nothing else needs editing.

local CashFormat = require(script.Parent:WaitForChild("CashFormat"))

local HubConfig = {}

HubConfig.ARENA_ENABLED = false -- Battle Arena worker battles (plaza, by the Golden Vault)
HubConfig.SHOPS_ENABLED = false -- Bat Boutique and Lot & Decor (cosmetics, in-game cash only)
HubConfig.NPC_QUESTS_ENABLED = false -- City Guide (tutorial, story) and the Quest Board
HubConfig.UPGRADES_ENABLED = false -- Upgrade Office (needs SHOPS_ENABLED too); affects the economy

HubConfig.STUDIO_ATTRIBUTES = { ARENA_ENABLED = "StudioArena", SHOPS_ENABLED = "StudioShops", NPC_QUESTS_ENABLED = "StudioNpcQuests", UPGRADES_ENABLED = "StudioUpgrades" }
HubConfig.ACTION_RATE = 8 -- hub requests a client may send per second

-- Arena -------------------------------------------------------------------------------------------
-- A worker's battle stats are the catalogue's own (attack, speed, defence). Power = their sum.
HubConfig.Arena = {
	POWER_RANGE = 0.3, -- two workers can meet if the weaker has at least (1 - this) of the stronger's power
	HP_FACTOR = 3, -- health = this x (attack + defence)
	DEFENCE_FACTOR = 0.5, -- damage = max(1, attack - defence x this)
	HIT_INTERVAL = 0.55, -- seconds between hits (the faster worker hits first, then they take turns)
	MAX_HITS = 40, -- after this many hits the worker with more health left (as a share) wins
	INTRO_TIME = 2, -- seconds the two workers stand on the platforms before the first hit
	OUTRO_TIME = 3, -- seconds the result stays up
	COOLDOWN = 60, -- seconds before the same player can queue again
	PAD_REACH = 5, -- studs from a queue pad's centre that count as standing on it
	REWARD_INCOME_SECONDS = 60, -- PROPOSED: winner's cash = this many seconds of the beaten worker's income...
	REWARD_MIN = 300, -- PROPOSED: ...but at least this much
	PAIR_COOLDOWN = 600, -- seconds before beating the same player again pays cash (the trophy point is the same rule)
	TRAINING_BONUS = 0.1, -- battle stats gained per training level (Upgrade Office)
}

-- Shops -------------------------------------------------------------------------------------------
-- kind "skin": a bat look from the 022 locker.  "trail": the colour of the bat's swing trail.
-- "decor": a decoration for one of the lot's decor spots.  "upgrade": see the Upgrade Office.
HubConfig.DECOR_SPOTS = { { -15, -14 }, { 15, -14 }, { -15, 15 }, { 15, 15 }, { 0, 15.5 } } -- lot-local x, z (front = -z)
-- Where the pads of stations bought at the Upgrade Office stand (the lot's own six are at x = -8 and 8,
-- z = 12, 3, -6). Down the middle, between the rows: 9.2 studs from every pad (the six are 9 apart).
HubConfig.EXTRA_STATION_SPOTS = { { 0, 7.5 }, { 0, -1.5 } } -- lot-local x, z; one per level of "upgrade:stations"
HubConfig.Shops = {
	BatBoutique = {
		title = "BAT BOUTIQUE",
		keeper = "Slugger Sal",
		items = {
			{ id = "skin:Neon", name = "Neon Bat", note = "A glowing bat look", kind = "skin", value = "Neon", price = 15000 }, -- PROPOSED
			{ id = "skin:Golden", name = "Golden Bat", note = "A solid gold bat look", kind = "skin", value = "Golden", price = 75000 }, -- PROPOSED
			{ id = "trail:Sunset", name = "Sunset Trail", note = "Orange swing trail", kind = "trail", color = { 255, 140, 60 }, price = 5000 }, -- PROPOSED
			{ id = "trail:Mint", name = "Mint Trail", note = "Green swing trail", kind = "trail", color = { 110, 230, 160 }, price = 5000 }, -- PROPOSED
			{ id = "trail:Royal", name = "Royal Trail", note = "Purple swing trail", kind = "trail", color = { 170, 110, 240 }, price = 12000 }, -- PROPOSED
		},
	},
	LotAndDecor = {
		title = "LOT & DECOR",
		keeper = "Daisy Decor",
		items = {
			{ id = "decor:planter", name = "Flower Planter", note = "A stone bowl of flowers", kind = "decor", price = 2000 }, -- PROPOSED
			{ id = "decor:topiary", name = "Topiary", note = "A clipped ball tree", kind = "decor", price = 4000 }, -- PROPOSED
			{ id = "decor:lamp", name = "Street Lamp", note = "A warm lamp for your lot", kind = "decor", price = 6000 }, -- PROPOSED
			{ id = "decor:sign", name = "Neon Sign", note = "A glowing OPEN sign", kind = "decor", price = 12000 }, -- PROPOSED
			{ id = "decor:fountain", name = "Mini Fountain", note = "A small marble fountain", kind = "decor", price = 25000 }, -- PROPOSED
			{ id = "decor:statue", name = "Gold Statue", note = "A golden coin statue", kind = "decor", price = 40000 }, -- PROPOSED
		},
	},
	UpgradeOffice = {
		title = "UPGRADE OFFICE",
		keeper = "Mr. Ledger",
		flag = "UPGRADES_ENABLED",
		items = {
			-- levels = price of each level in turn. PROPOSED, and behind UPGRADES_ENABLED.
			{
				id = "upgrade:storage",
				name = "Storage Crate",
				note = "+5 creature storage slots per level",
				kind = "upgrade",
				key = "storage",
				levels = { 25000, 100000, 400000 },
				slots = 5,
			},
			{
				id = "upgrade:training",
				name = "Arena Training",
				note = "+10% battle stats for one creature per level",
				kind = "upgrade",
				levels = { 10000, 40000, 150000 },
				perWorker = true,
			},
			{
				id = "upgrade:stations",
				name = "Extra Station",
				note = "+1 creature station on your lot per level",
				kind = "upgrade",
				key = "stations",
				levels = { 150000, 750000 },
			},
		},
	},
}
HubConfig.SHOP_REACH = 40 -- studs from a shop's counter within which its shop can be used

-- Quest Board -------------------------------------------------------------------------------------
-- Three of these each day (UTC), the same three all day. `needs` = a flag the quest depends on.
HubConfig.Quests = {
	PER_DAY = 3,
	POOL = {
		{ id = "steal3", text = "Steal 3 creatures", event = "steal", goal = 3, reward = 1500 }, -- PROPOSED rewards
		{ id = "rare1", text = "Steal a Rare or better creature", event = "stealRare", goal = 1, reward = 2500 },
		{ id = "place2", text = "Put 2 creatures to work on your stations", event = "place", goal = 2, reward = 1000 },
		{ id = "earn5k", text = "Collect " .. CashFormat.format(5000), event = "earn", goal = 5000, reward = 2000 },
		{ id = "arena1", text = "Win a battle at the Battle Arena", event = "arenaWin", goal = 1, reward = 3000, needs = "ARENA_ENABLED" },
		{ id = "defend1", text = "Defend your base: knock a stolen creature loose", event = "defend", goal = 1, reward = 3000, needs = "PVP" },
	},
}

-- People and their lines (all dialogue lives here) ------------------------------------------------------
HubConfig.NPCs = {
	Guide = { name = "Mentor Mae", hello = { "Welcome to Hideout Camp! I'm Mae. Need a hand?", "Back again? Ask me anything!" } },
	QuestBoard = { name = "Quest Board", hello = { "Three new jobs every day. Finish them for coins!" } },
	BatBoutique = { name = "Slugger Sal", hello = { "Fresh bats! Looks only, kid: they all hit the same.", "A shiny bat says 'this base is defended'." } },
	LotAndDecor = { name = "Daisy Decor", hello = { "Let's make your lot the prettiest on the lane!", "A statue here, a planter there... perfect." } },
	UpgradeOffice = { name = "Mr. Ledger", hello = { "Paperwork, crates and training plans. How may I help?", "Good investments start at this desk." } },
}
HubConfig.Story = {
	"Every great boss thief started out right here in Hideout Camp.",
	"One day, the Trillionaire simply vanished.",
	"Legend says whoever builds the richest empire...",
	"...will be the one to open the Golden Vault in the plaza!",
}
HubConfig.Tips = {
	"Rarer creatures earn more. Keep your best six on your stations.",
	"Storage is safe. Creatures on stations can be stolen once PvP is on!",
	"Lock your base when you see the robbery alarm.",
	"Creatures of similar power are matched at the Battle Arena.",
	"Check the Quest Board every day for extra coins.",
}
-- Tutorial steps. `wait` = what the player has to do before the step ticks off by itself
-- ("carry", "place", "cash") or nil for a step that only needs reading.
HubConfig.Tutorial = {
	{
		title = "Steal",
		text = "Turn round and walk through the KNIGHT'S KEEP gate, then hold E on a creature to steal it.",
		paradeText = "Mystery creatures are walking down the red lane! Walk up to one and press E to catch it. Your first one is FREE!", -- shown while the Worker Parade (028) is on
		wait = "carry",
	},
	{ title = "Reveal", text = "The card shows who you caught and how rare they are.", wait = nil },
	{ title = "Carry", text = "Carry your creature to your own lot: follow the gold YOUR BASE beam.", wait = nil },
	{ title = "Place", text = "Stand by a round pad on your lot and press E to put the creature to work.", wait = "place" },
	{ title = "Collect", text = "Creatures on pads earn coins every second. Watch it grow!", wait = "cash" },
	{ title = "Defend", text = "Other players may try to steal placed creatures. Lock your base or use your bat!", wait = nil },
	{ title = "Arena", text = "The Battle Arena is in the plaza by the Golden Vault: step on a pad to battle a creature for coins.", wait = nil },
}

return HubConfig
