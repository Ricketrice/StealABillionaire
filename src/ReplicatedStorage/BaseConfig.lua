-- Studio location: ReplicatedStorage.BaseConfig (ModuleScript)
-- BaseConfig  (Milestone 033, D25/D28): living bases, worker levels and base pads 7-12. Shared by server and client.
-- !! PROPOSED NUMBERS (033 Checkpoint 1): level costs + boost, pad prices. Change them here only.
--
-- Three switches, all OFF = the game as before 033. In Studio set the ServerStorage attribute instead; the server
-- publishes a ReplicatedStorage attribute for clients:
--   LIVING_ENABLED  workers do a job at their pad (client-side code animation)   Studio StudioLiving  -> LivingOn
--   LEVELS_ENABLED  worker levels 1-10 bought with cash                           Studio StudioLevels  -> LevelsOn
--   PADS_ENABLED    pads 7-12 bought with cash at the base (new 4x3 pad layout)    Studio StudioPads    -> PadsOn
-- Save (optional fields, schema stays 3): the worker record's existing `level` (1..10); hub.pads = pads bought
-- beyond the first 6 (0..6); hub.intro = { levels = true, pads = true } once each NEW! hint was shown.

local BaseConfig = {}

BaseConfig.LIVING_ENABLED = false
BaseConfig.LEVELS_ENABLED = false
BaseConfig.PADS_ENABLED = false
BaseConfig.FLAGS = {
	LIVING_ENABLED = { studio = "StudioLiving", published = "LivingOn" },
	LEVELS_ENABLED = { studio = "StudioLevels", published = "LevelsOn" },
	PADS_ENABLED = { studio = "StudioPads", published = "PadsOn" },
}

-- Whether a switch is on. Server: the config value, or in Studio the ServerStorage attribute. Client: the attribute
-- the server publishes on ReplicatedStorage.
function BaseConfig.on(key: string): boolean
	local flag = BaseConfig.FLAGS[key]
	assert(flag, "unknown BaseConfig flag " .. tostring(key))
	local RunService = game:GetService("RunService")
	if RunService:IsServer() then
		return (BaseConfig :: any)[key] == true or (RunService:IsStudio() and game:GetService("ServerStorage"):GetAttribute(flag.studio) == true)
	end
	return game:GetService("ReplicatedStorage"):GetAttribute(flag.published) == true
end

-- Living bases (D25) -------------------------------------------------------------------------------------------
BaseConfig.Living = {
	RANGE = 80, -- studs from the camera: closer workers do their job loop, further ones stand still
	PROP_RANGE = 80, -- props (laptop, broom...) only exist this close
	COIN_EVERY = { 5, 8 }, -- seconds between a working worker's coin pop (only your own workers, random in range)
	-- Job loop per worker type (role in WorkerCatalogue). "Low effects" = a simple bob, no props.
	JOBS = { Earner = "laptop", Fighter = "pushups", Tank = "guard", ["All-rounder"] = "sweep" },
}

-- Worker levels ------------------------------------------------------------------------------------------------
BaseConfig.MAX_LEVEL = 10
BaseConfig.LEVEL_BOOST = 0.10 -- PROPOSED: +10% of the worker's base income per level above 1 (Level 10 = x1.9)
BaseConfig.LEVEL_COST_SECONDS = 30 -- PROPOSED: Level 1 -> 2 costs this many seconds of the worker's base income...
BaseConfig.LEVEL_COST_GROWTH = 1.4 -- PROPOSED: ...and each next level costs this much more
BaseConfig.LEVEL_COST_MIN = 50
BaseConfig.LEVEL_BADGE = 5 -- a star badge from this level
BaseConfig.LEVEL_GLOW = 10 -- a gold glow at this level
BaseConfig.REVEAL_LEVELS_AT = 3 -- Upgrade buttons appear once this many workers are on pads (D28)

-- Rounds to 2 significant digits ("1,234" -> "1,200"), so prices read easily.
local function nice(amount: number): number
	if amount < 100 then
		return math.floor(amount + 0.5)
	end
	local magnitude = 10 ^ (math.floor(math.log10(amount)) - 1)
	return math.floor(amount / magnitude + 0.5) * magnitude
end
BaseConfig.nice = nice

-- Income per second of a worker with `base` income (its Level 1 catalogue income) at `level`. Can have one decimal.
function BaseConfig.levelIncome(base: number, level: number): number
	local l = math.clamp(math.floor(level), 1, BaseConfig.MAX_LEVEL)
	return math.floor(base * (1 + BaseConfig.LEVEL_BOOST * (l - 1)) * 10 + 0.5) / 10
end

-- Cash price of going from `level` to level + 1 for a worker with `base` income, or nil at the top level.
function BaseConfig.levelCost(base: number, level: number): number?
	if level >= BaseConfig.MAX_LEVEL then
		return nil
	end
	local raw = base * BaseConfig.LEVEL_COST_SECONDS * BaseConfig.LEVEL_COST_GROWTH ^ (math.max(1, level) - 1)
	return math.max(BaseConfig.LEVEL_COST_MIN, nice(raw))
end

-- Pads ---------------------------------------------------------------------------------------------------------
BaseConfig.FIRST_PADS = 6 -- every base starts with these
BaseConfig.PAD_PRICES = { 5000, 12000, 30000, 75000, 180000, 450000 } -- PROPOSED: pads 7, 8, 9, 10, 11, 12 (in order)
BaseConfig.PASS_PADS = 2 -- pads 13-14 for the Extra Slots gamepass (ProductConfig), no cash price
-- Pad spots, lot-local (x, z); the lot's front (gate) is -z. While PADS_ENABLED the lot's own six pads move to the
-- inner columns and bought pads fill the outer ones: 4 columns x 3 rows, the gate path stays clear. The two pass
-- pads sit in the front corners. Pads are 6 studs wide: 2 studs between columns, 3 between rows.
BaseConfig.PAD_SPOTS = {
	{ -4, 12 },
	{ 4, 12 },
	{ -4, 3 },
	{ 4, 3 },
	{ -4, -6 },
	{ 4, -6 }, -- 1-6 (the lot's own pads, moved)
	{ -12, 12 },
	{ 12, 12 },
	{ -12, 3 },
	{ 12, 3 },
	{ -12, -6 },
	{ 12, -6 }, -- 7-12 (cash)
	{ -12, -14.4 },
	{ 12, -14.4 }, -- 13-14 (Extra Slots pass)
}
-- Decor spots (026 Lot & Decor) while the pad layout is on, clear of every pad.
BaseConfig.DECOR_SPOTS = { { -16, 16 }, { 16, 16 }, { -7.5, -15.5 }, { 7.5, -15.5 }, { 0, 16 } }

-- Price of the next pad for a player who has bought `bought` pads (0..5), or nil when all 6 are bought.
function BaseConfig.padPrice(bought: number): number?
	return BaseConfig.PAD_PRICES[bought + 1]
end

do
	assert(#BaseConfig.PAD_PRICES == 6, "pads 7-12: six prices")
	local last = 0
	for _, price in BaseConfig.PAD_PRICES do
		assert(price > last and price % 1 == 0, "pad prices must rise")
		last = price
	end
	assert(#BaseConfig.PAD_SPOTS == BaseConfig.FIRST_PADS + #BaseConfig.PAD_PRICES + BaseConfig.PASS_PADS, "one spot per pad")
end

return BaseConfig
