-- Studio location: ReplicatedStorage.ParadeConfig (ModuleScript)
-- ParadeConfig  (Milestone 028)
-- Every switch and number for the Worker Parade (D7), the juice effects (D8/D12), the one-goal HUD
-- and the collection book. Shared by the server and clients.
--
-- All four flags are OFF by default; with them off the game behaves exactly as before Milestone 028.
-- To test in Studio without editing this file, set a ServerStorage attribute to true (ignored
-- outside Studio):  StudioParade / StudioJuice / StudioGoalHud / StudioBook
-- The server publishes what is on as ReplicatedStorage attributes ParadeOn / JuiceOn / GoalHudOn /
-- BookOn, which is all clients read.
--
-- Numbers approved by the owner in D16 (GAME_DESIGN.md), with their changes: $75 catch, Golden odds
-- 50/30/14.5/5/0.5 (never worse than normal). Change them here; nothing else needs editing.
-- The normal parade uses the existing Main Street pool and odds (WorkerCatalogue), unchanged.

local WorkerCatalogue = require(script.Parent:WaitForChild("WorkerCatalogue"))

local ParadeConfig = {}

ParadeConfig.PARADE_ENABLED = true -- D46 live: mystery workers walking down the red lane, Golden Parade
ParadeConfig.JUICE_ENABLED = true -- D46 live: reveal/carry/place/cash/steal/idle effects (client only)
ParadeConfig.GOAL_HUD_ENABLED = true -- D46 live: one next goal with a progress bar
ParadeConfig.BOOK_ENABLED = true -- D46 live: collection book (records caught workers in the save's hub field)

ParadeConfig.STUDIO_ATTRIBUTES = { PARADE_ENABLED = "StudioParade", JUICE_ENABLED = "StudioJuice", GOAL_HUD_ENABLED = "StudioGoalHud", BOOK_ENABLED = "StudioBook" }
ParadeConfig.PUBLISHED = { PARADE_ENABLED = "ParadeOn", JUICE_ENABLED = "JuiceOn", GOAL_HUD_ENABLED = "GoalHudOn", BOOK_ENABLED = "BookOn" }

-- Parade ------------------------------------------------------------------------------------------
-- The lane is the part with the ParadeLane attribute (Workspace.World.SkyCity.Ground.ParadeLane.Lane).
-- Workers walk along its long axis from the spawn end (west, -X) to the plaza end (east, +X).
ParadeConfig.ZONE = "MainStreet" -- roster and odds the parade rolls from (existing pool, unchanged)
ParadeConfig.CATCH_PRICE = 75 -- cash per catch (D16)
ParadeConfig.FIRST_CATCH_FREE = true -- a player's first worker ever, caught at the parade, costs nothing
ParadeConfig.WALK_SPEED = 2.6 -- studs per second (D54: lane = the red band in front of the bases, 185 long, ~175 walked -> ~67 s, 7-8 on it;
-- was 4 on the old ~310-stud lane: on the shorter lane 4 left only ~3 walkers). Walking speed only: one new
-- walker every SPAWN_INTERVAL as before, so the number of creatures on offer per minute is unchanged.
ParadeConfig.SPAWN_INTERVAL = 9 -- seconds between new parade workers (lane time / max)
ParadeConfig.MAX_ON_LANE = 8 -- at most this many on the lane at once
ParadeConfig.START_INSET = 4 -- studs in from the lane's west end where workers appear
ParadeConfig.END_INSET = 6 -- studs in from the east end where they leave
ParadeConfig.LANE_SPREAD = 3.5 -- studs either side of the lane's centre line a worker may walk
ParadeConfig.PROMPT_DISTANCE = 10 -- studs
ParadeConfig.DISTANCE_TOLERANCE = 5 -- extra studs the server allows (latency, the worker moving)
ParadeConfig.CATCH_COOLDOWN = 1 -- seconds between one player's catch attempts
ParadeConfig.BOUNCE_HEIGHT = 0.45 -- studs (client only)
ParadeConfig.STEP_RATE = 2.2 -- bounces per second (client only)
ParadeConfig.ANIMATE_RANGE = 140 -- studs from the camera within which limbs are animated (client only)

-- Golden Parade: every GOLDEN_INTERVAL seconds, GOLDEN_LENGTH seconds of gold workers with better
-- odds for everyone (shown on the prompt and the lane sign). Gold workers still on the lane when it
-- ends leave in a sparkle, so it always ends cleanly.
ParadeConfig.GOLDEN_FIRST = 300 -- seconds after the server starts before the first one
ParadeConfig.GOLDEN_INTERVAL = 900 -- seconds from one start to the next (~15 min)
ParadeConfig.GOLDEN_LENGTH = 60 -- seconds
ParadeConfig.GOLDEN_SPAWN_INTERVAL = 3 -- seconds between gold workers while it runs
-- Odds during a Golden Parade, per mille (must total 1000; D16: Epic, Legendary and Secret never below
-- the normal parade's 700/200/80/18/2).
ParadeConfig.GOLDEN_PER_MILLE = { Common = 500, Rare = 300, Epic = 145, Legendary = 50, Secret = 5 }
ParadeConfig.GOLDEN_PRICE = 75 -- same as a normal catch, so the better odds are for everyone (D16)

-- Server-wide message when anyone catches one of these (parade or zone).
ParadeConfig.ANNOUNCE = { Legendary = true, Secret = true }

-- Juice ---------------------------------------------------------------------------------------------
ParadeConfig.Juice = {
	CASH_POP_EVERY = 2, -- seconds between "+$X" pops over each of your working workers (X = what it earned)
	CASH_POP_RANGE = 90, -- studs from the camera
	IDLE_RANGE = 90, -- studs: placed workers further away stand still
	AURA_RANGE = 45, -- studs: Epic+ aura only this close to the camera
	MOVE_EVERY = { 7, 12 }, -- seconds between a Rare+ worker's personality moves (random in range)
	SHAKE = { Epic = 0.25, Legendary = 0.45, Secret = 0.7 }, -- camera shake strength (studs)
	-- One personality move per Rare+ worker. Workers not listed get one from their id.
	MOVES = {
		street_hustler = "hop",
		business_betty = "wave",
		security_sam = "flex",
		crypto_carl = "spin",
		ceo_chad = "wave",
		mystery_millionaire = "dance",
	},
	MOVE_LIST = { "hop", "wave", "spin", "flex", "dance" },
}

-- One-goal HUD ----------------------------------------------------------------------------------------
-- The first goal in this list that isn't done yet is shown. kind: "catch" (workers caught, from the
-- book or owned), "pads" (workers working on stations), "zone" (district unlocked), "book" (book
-- entries in total). Zone goals show the cash progress towards the price.
ParadeConfig.GOALS = {
	{ kind = "catch", goal = 1, text = "Catch your first creature", icon = "🎁" },
	{ kind = "pads", goal = 1, text = "Put a creature on a pad", icon = "⭐" },
	{ kind = "catch", goal = 3, text = "Catch 3 creatures", icon = "🎁" },
	{ kind = "pads", goal = 6, text = "Fill 6 pads", icon = "⭐" },
	{ kind = "zone", zone = "SunkenKingdom", text = "Unlock the Sunken Kingdom", icon = "🔓" },
	{ kind = "zone", zone = "BillionaireHills", text = "Unlock Ember Academy", icon = "🔥" },
	{ kind = "book", text = "Complete the collection book", icon = "📖" }, -- goal = every catalogue worker
}

-- Collection book -----------------------------------------------------------------------------------
-- One page per zone, in lane order (034). A zone without workers in the catalogue shows "coming soon".
ParadeConfig.BOOK_PAGES = {
	{ zone = "MainStreet", title = "Knight's Keep" },
	{ zone = "SunkenKingdom", title = "Sunken Kingdom" },
	{ zone = "BillionaireHills", title = "Ember Academy" },
} -- (D48: the teammate zones' pages are gone with the zones)
ParadeConfig.BOOK_MAX = 200 -- most entries a save's book keeps

function ParadeConfig.validate()
	local total = 0
	for _, value in ParadeConfig.GOLDEN_PER_MILLE do
		assert(type(value) == "number" and value >= 0 and value % 1 == 0, "bad Golden Parade odds")
		total += value
	end
	assert(total == 1000, "Golden Parade odds must total 1000 per mille")
	local normal = WorkerCatalogue.RARITY_PER_MILLE
	for _, rarity in { "Epic", "Legendary", "Secret" } do
		assert(ParadeConfig.GOLDEN_PER_MILLE[rarity] >= normal[rarity], "Golden Parade odds worse than normal: " .. rarity)
	end
	assert(ParadeConfig.CATCH_PRICE >= 0 and ParadeConfig.CATCH_PRICE % 1 == 0, "bad catch price")
	assert(ParadeConfig.GOLDEN_PRICE >= 0 and ParadeConfig.GOLDEN_PRICE % 1 == 0, "bad golden price")
end
ParadeConfig.validate()

return ParadeConfig
