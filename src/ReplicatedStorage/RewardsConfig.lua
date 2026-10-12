-- Studio location: ReplicatedStorage.RewardsConfig (ModuleScript)
-- RewardsConfig  (Milestone 029)
-- Every reward amount in one place: daily streak, playtime gifts, offline earnings and the index
-- completion bonus (D15). The server pays from these numbers; clients only display them.
--
-- Cash rewards are INCOME-BASED (D20, owner 2026-10-12): "N minutes of income" = the player's income
-- per second right now (PassiveIncome.getIncome: placed workers, index bonus included) x 60 x N, and
-- never less than the floor (the 029 proposal). RewardsConfig.cash(def, income) does the sum; the
-- server pays it and sends the same numbers to the screens.
-- Scale: Zone 1 workers earn $5-$35/s (Legendary $100, Secret $500); one parade catch costs $75 (D16).
--
-- Times are server time (os.time, UTC). A "day" is a UTC calendar day.

local RewardsConfig = {}

-- Daily streak: claim once per day. Claiming on the next day moves the streak on; missing a whole day
-- starts it again from day 1 (said kindly, never as a loss). After day 7 it starts again at day 1.
-- incomeMinutes / floor = cash; goldenCatches = Golden catch tickets (a free catch with Golden Parade
-- odds, usable any time; see ParadeService).
RewardsConfig.DAILY = { -- D20
	{ incomeMinutes = 2, floor = 300 },
	{ incomeMinutes = 3, floor = 500 },
	{ incomeMinutes = 5, floor = 750 },
	{ incomeMinutes = 7, floor = 1000 },
	{ incomeMinutes = 10, floor = 1500 },
	{ incomeMinutes = 15, floor = 2000 },
	{ incomeMinutes = 30, floor = 5000, goldenCatches = 1 },
}

-- Playtime gifts: minutes played today (UTC day, kept across rejoins). Each gift can be claimed once
-- per day. freeCatches = free parade catches (no cash).
RewardsConfig.PLAYTIME = { -- D20
	{ minutes = 5, incomeMinutes = 1, floor = 150 },
	{ minutes = 10, incomeMinutes = 2, floor = 250 },
	{ minutes = 20, incomeMinutes = 3, floor = 400 },
	{ minutes = 30, incomeMinutes = 5, floor = 600 },
	{ minutes = 45, incomeMinutes = 8, floor = 900 },
	{ minutes = 60, freeCatches = 1 },
}

-- Offline earnings: while away, workers that were on stations earn this share of their normal income
-- (catalogue income x index bonus), for at most OFFLINE_CAP_SECONDS. Nothing if away less than
-- OFFLINE_MIN_SECONDS. Collected with the popup on the next join.
RewardsConfig.OFFLINE_RATE = 0.25 -- D20: 25% of normal income
RewardsConfig.OFFLINE_CAP_SECONDS = 3 * 60 * 60 -- D20: 3 hours
RewardsConfig.OFFLINE_MIN_SECONDS = 5 * 60 -- 5 minutes

-- Cash for a daily or playtime reward at this income per second (0 when the reward has no cash).
function RewardsConfig.cash(def: any, incomePerSecond: number): number
	if type(def.incomeMinutes) ~= "number" then
		return 0
	end
	return math.max(def.floor or 0, math.floor(math.max(incomePerSecond, 0) * 60 * def.incomeMinutes))
end

-- Index completion bonus (D15): per zone, collect a share of its workers, then claim the tier on the
-- Index page. Claimed bonuses add up across zones and multiply all income (placed workers + offline).
RewardsConfig.INDEX_TIERS = { -- D15 numbers, unchanged in D20
	{ share = 0.5, bonus = 0.10, label = "Half the page" },
	{ share = 1.0, bonus = 0.25, label = "Full page", badge = true },
}

-- How often the server writes "last seen" into the save while a player is online (the offline clock
-- starts from the last write, so a server crash can't give more than this much extra).
RewardsConfig.SEEN_INTERVAL = 300

function RewardsConfig.validate()
	local function reward(def: any, what: string)
		local cash = type(def.incomeMinutes) == "number"
		assert(not cash or (def.incomeMinutes > 0 and type(def.floor) == "number" and def.floor >= 0 and def.floor % 1 == 0), "bad cash for " .. what)
		for _, key in { "goldenCatches", "freeCatches" } do
			assert(def[key] == nil or (type(def[key]) == "number" and def[key] > 0 and def[key] % 1 == 0), "bad " .. key .. " for " .. what)
		end
		assert(cash or def.goldenCatches or def.freeCatches, what .. " gives nothing")
	end
	assert(#RewardsConfig.DAILY == 7, "the streak calendar shows 7 days")
	for day, def in RewardsConfig.DAILY do
		reward(def, "daily day " .. day)
	end
	local last = 0
	for i, gift in RewardsConfig.PLAYTIME do
		assert(type(gift.minutes) == "number" and gift.minutes > last, "bad playtime gift " .. i)
		reward(gift, "playtime gift " .. i)
		last = gift.minutes
	end
	assert(RewardsConfig.OFFLINE_RATE >= 0 and RewardsConfig.OFFLINE_RATE <= 1, "bad offline rate")
	assert(RewardsConfig.OFFLINE_CAP_SECONDS > RewardsConfig.OFFLINE_MIN_SECONDS, "bad offline cap")
	local share = 0
	for i, tier in RewardsConfig.INDEX_TIERS do
		assert(tier.share > share and tier.share <= 1 and tier.bonus > 0, "bad index tier " .. i)
		share = tier.share
	end
end
RewardsConfig.validate()

return RewardsConfig
