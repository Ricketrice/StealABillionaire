-- Studio location: ReplicatedStorage.RewardsConfig (ModuleScript)
-- RewardsConfig  (Milestone 029)
-- Every reward amount in one place: daily streak, playtime gifts, offline earnings and the index
-- completion bonus (D15). The server pays from these numbers; clients only display them.
--
-- !! PROPOSED VALUES, NOT APPROVED: every number marked PROPOSED waits for the owner's approval.
-- Scale: Zone 1 workers earn $5-$35/s (Legendary $100, Secret $500), so a new player earns roughly
-- $10-$60/s; one parade catch costs $75 (D16).
--
-- Times are server time (os.time, UTC). A "day" is a UTC calendar day.

local RewardsConfig = {}

-- Daily streak: claim once per day. Claiming on the next day moves the streak on; missing a whole day
-- starts it again from day 1 (said kindly, never as a loss). After day 7 it starts again at day 1.
RewardsConfig.DAILY = { -- PROPOSED: cash for day 1..7
	300,
	500,
	750,
	1000,
	1500,
	2000,
	5000,
}

-- Playtime gifts: minutes played today (UTC day, kept across rejoins) -> cash. Each gift can be
-- claimed once per day.
RewardsConfig.PLAYTIME = { -- PROPOSED
	{ minutes = 5, cash = 150 },
	{ minutes = 10, cash = 250 },
	{ minutes = 20, cash = 400 },
	{ minutes = 30, cash = 600 },
	{ minutes = 45, cash = 900 },
	{ minutes = 60, cash = 1500 },
}

-- Offline earnings: while away, workers on stations keep earning at OFFLINE_RATE of their normal
-- income (index bonus included), for at most OFFLINE_CAP_SECONDS. Nothing is offered for absences
-- shorter than OFFLINE_MIN_SECONDS. Unclaimed earnings wait for the next visit (still capped).
RewardsConfig.OFFLINE_RATE = 0.15 -- PROPOSED: 15% of normal income
RewardsConfig.OFFLINE_CAP_SECONDS = 2 * 60 * 60 -- PROPOSED: 2 hours
RewardsConfig.OFFLINE_MIN_SECONDS = 5 * 60 -- PROPOSED: 5 minutes

-- Index completion bonus (D15): per zone, collect a share of its workers, then claim the tier on the
-- Index page. Claimed bonuses add up across zones and multiply all income (placed workers + offline).
RewardsConfig.INDEX_TIERS = { -- PROPOSED (D15 numbers, marked tune)
	{ share = 0.5, bonus = 0.10, label = "Half the page" },
	{ share = 1.0, bonus = 0.25, label = "Full page", badge = true },
}

-- How often the server writes "last seen" into the save while a player is online (the offline clock
-- starts from the last write, so a server crash can't give more than this much extra).
RewardsConfig.SEEN_INTERVAL = 300

function RewardsConfig.validate()
	for day, cash in RewardsConfig.DAILY do
		assert(type(cash) == "number" and cash > 0 and cash % 1 == 0, "bad daily reward on day " .. day)
	end
	assert(#RewardsConfig.DAILY == 7, "the streak calendar shows 7 days")
	local last = 0
	for i, gift in RewardsConfig.PLAYTIME do
		assert(gift.minutes > last and gift.cash > 0 and gift.cash % 1 == 0, "bad playtime gift " .. i)
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
