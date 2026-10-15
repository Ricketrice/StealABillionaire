-- Studio location: ServerScriptService.RewardsService (ModuleScript)
-- RewardsService  (Milestone 029)
-- Server side of the V1 reasons to come back, all behind ReplicatedStorage.V1Flags:
--   REWARDS_ENABLED      daily streak (7 days), playtime gifts (minutes played today), offline earnings
--   INDEX_BONUS_ENABLED  index completion bonus (D15): claim a zone's tier, all income goes up
--   UI_V1_ENABLED        saved settings (music, sounds, low effects, low graphics) and favourite workers
-- Everything is decided here with server time (os.time); clients only ask (RewardsAction) and are
-- shown the result (RewardsState = their state, RewardsEvent = "Claimed" moments for the juice).
-- No amount ever comes from a client. Requests are rate limited per player.
--
-- Saved in the existing hub field (optional, with defaults; schema stays 3). Only written while the
-- matching switch is on, so with every switch off nothing is added to anyone's save:
--   hub.daily    = { streak = 1..7 (last day claimed), day = UTC day number of that claim }
--   hub.play     = { day = UTC day number, secs = seconds played that day, got = { ["1"] = true, ... } }
--   hub.seen     = os.time() when last seen (written every SEEN_INTERVAL and when leaving)
--   hub.offline  = offline cash waiting to be collected
--   hub.index    = { [zoneId] = highest tier claimed }
--   hub.settings = { music, sfx, lowfx, lowgfx } (booleans)
--   hub.favs     = { [workerUid] = true }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ParadeConfig = require(ReplicatedStorage:WaitForChild("ParadeConfig"))
local StealConfig = require(ReplicatedStorage:WaitForChild("StealConfig"))
local RewardsConfig = require(ReplicatedStorage:WaitForChild("RewardsConfig"))
local V1Flags = require(ReplicatedStorage:WaitForChild("V1Flags"))
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue"))
local HubBase = require(script.Parent:WaitForChild("HubBase"))
local ParadeService = require(script.Parent:WaitForChild("ParadeService"))
local PassiveIncome = require(script.Parent:WaitForChild("PassiveIncome"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local RewardsService = {}

local DAY = 86400
local FAVS_MAX = 100
local SETTINGS = { music = true, sfx = true, lowfx = false, lowgfx = false } -- defaults

local function getRemote(name: string): RemoteEvent
	local remote = ReplicatedStorage:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end
	return remote :: RemoteEvent
end
local actionEvent = getRemote("RewardsAction") -- client -> server: (action: string, arg: any?)
local stateEvent = getRemote("RewardsState") -- server -> client: the player's state (see stateOf)
local clientEvent = getRemote("RewardsEvent") -- server -> client: (kind: "Claimed", info)

-- Server clock (a test can move it).
local clock = os.time
local function now(): number
	return clock()
end
local function today(): number
	return math.floor(now() / DAY)
end

local flag = V1Flags.on
local function rewardsOn(): boolean
	return flag("REWARDS_ENABLED")
end

-- Per-player session bookkeeping (not saved).
local since: { [Player]: number } = {} -- os.time playtime was last folded into hub.play.secs
local lastSeenWrite: { [Player]: number } = {}
local budget: { [Player]: { tokens: number, at: number } } = {}

local function hubOf(player: Player): any?
	local data = PlayerData.get(player) :: any
	if not data then
		return nil
	end
	if type(data.hub) ~= "table" then
		data.hub = {}
	end
	return data.hub
end
local function section(hub: any, name: string): any
	if type(hub[name]) ~= "table" then
		hub[name] = {}
	end
	return hub[name]
end

-- Index ------------------------------------------------------------------------------------------------
-- Zone rosters from the catalogue (zone id -> worker ids), in the Index's page order.
local rosters: { [string]: { string } } = {}
local zoneOrder: { string } = {}
do
	local order = {}
	for _, page in ParadeConfig.BOOK_PAGES do
		table.insert(order, page.zone)
	end
	for zone in WorkerCatalogue.ZONES do
		if not table.find(order, zone) then
			table.insert(order, zone)
		end
	end
	for _, zone in order do
		local list = WorkerCatalogue.ZONES[zone]
		if list and #list > 0 then
			rosters[zone] = table.clone(list)
			table.insert(zoneOrder, zone)
		end
	end
end
RewardsService.rosters = rosters

-- Every worker id this player has collected: the book (028) plus everything they own now.
local function collected(player: Player): { [string]: boolean }
	local set = {}
	local data = PlayerData.get(player) :: any
	if not data then
		return set
	end
	local hub = data.hub
	if type(hub) == "table" and type(hub.book) == "table" then
		for id, v in hub.book do
			if v == true and type(id) == "string" then
				set[id] = true
			end
		end
	end
	for _, w in data.workers do
		if type(w.id) == "string" then
			set[w.id] = true
		end
	end
	return set
end

local function zoneProgress(player: Player, zone: string, have: { [string]: boolean }?): (number, number)
	local list = rosters[zone] or {}
	local set = have or collected(player)
	local n = 0
	for _, id in list do
		if set[id] then
			n += 1
		end
	end
	return n, #list
end

-- Highest tier this zone's progress reaches (0 = none).
local function tierReached(have: number, total: number): number
	local reached = 0
	if total > 0 then
		for i, tier in RewardsConfig.INDEX_TIERS do
			if have / total >= tier.share - 1e-9 then
				reached = i
			end
		end
	end
	return reached
end

-- Total claimed bonus (0.35 = +35%), from the saved claims. 0 while the switch is off.
function RewardsService.indexBonus(player: Player): number
	if not flag("INDEX_BONUS_ENABLED") then
		return 0
	end
	local hub = hubOf(player)
	local claims = hub and hub.index
	if type(claims) ~= "table" then
		return 0
	end
	local total = 0
	for zone, tier in claims do
		local def = type(tier) == "number" and RewardsConfig.INDEX_TIERS[tier]
		if def and rosters[zone] then
			total += def.bonus
		end
	end
	return total
end

-- Offline -----------------------------------------------------------------------------------------------
-- Income per second of the workers saved on stations (catalogue income), index bonus included.
local function stationIncome(player: Player, data: any): number
	local income = 0
	for _, w in data.workers do
		if w.loc == "station" then
			local worker = WorkerCatalogue.get(w.id)
			if worker then
				income += worker.income
			end
		end
	end
	return math.floor(income * (1 + RewardsService.indexBonus(player)) + 1e-9)
end

-- Runs once per load: what the workers earned since hub.seen (capped), added to anything uncollected.
local function settleOffline(player: Player, data: any)
	local hub = data.hub
	local seen = hub.seen
	local t = now()
	if type(seen) == "number" and seen < t then
		local away = t - seen
		local rate = stationIncome(player, data) * RewardsConfig.OFFLINE_RATE
		local cap = math.floor(rate * RewardsConfig.OFFLINE_CAP_SECONDS)
		if away >= RewardsConfig.OFFLINE_MIN_SECONDS and rate > 0 then
			local earned = math.floor(rate * math.min(away, RewardsConfig.OFFLINE_CAP_SECONDS))
			local pending = (if type(hub.offline) == "number" then hub.offline else 0) + earned
			hub.offline = math.min(pending, math.max(cap, 0))
			hub.offlineAway = math.min(away, RewardsConfig.OFFLINE_CAP_SECONDS)
		end
	end
	hub.seen = t
	lastSeenWrite[player] = t
end

-- Playtime -----------------------------------------------------------------------------------------------
-- hub.play for today (reset when the UTC day changes), with this session's time folded in.
local function playToday(player: Player): any?
	local hub = hubOf(player)
	if not hub then
		return nil
	end
	local play = section(hub, "play")
	local d, t = today(), now()
	if play.day ~= d then
		play.day, play.secs, play.got = d, 0, {}
		since[player] = math.max(since[player] or t, d * DAY) -- only today's part of the session counts
	end
	if type(play.got) ~= "table" then
		play.got = {}
	end
	play.secs = (if type(play.secs) == "number" then play.secs else 0) + math.max(0, t - (since[player] or t))
	since[player] = t
	return play
end

-- State ---------------------------------------------------------------------------------------------------
-- What a daily/playtime reward gives this player now (D20: cash from their current income, floored).
local function rewardFor(player: Player, def: any): any
	return {
		minutes = def.minutes,
		cash = RewardsConfig.cash(def, PassiveIncome.getIncome(player)),
		goldenCatches = def.goldenCatches,
		freeCatches = def.freeCatches,
	}
end
local function rewardList(player: Player, defs: { any }): { any }
	local list = {}
	for i, def in defs do
		list[i] = rewardFor(player, def)
	end
	return list
end

local function stateOf(player: Player): any
	local hub = hubOf(player) or {}
	local state: any = {
		now = now(),
		rewards = rewardsOn(),
		indexBonus = flag("INDEX_BONUS_ENABLED"),
		ui = flag("UI_V1_ENABLED"),
	}
	if state.rewards then
		local daily = section(hub, "daily")
		local d = today()
		local lastDay = if type(daily.day) == "number" then daily.day else nil
		local streak = if type(daily.streak) == "number" then daily.streak else 0
		local continues = lastDay ~= nil and lastDay == d - 1
		state.daily = {
			canClaim = lastDay == nil or lastDay < d,
			streak = streak, -- last day claimed (1..7), 0 = never
			claimedToday = lastDay == d,
			nextDay = if lastDay == d then streak elseif continues then (streak % 7) + 1 else 1,
			restarted = lastDay ~= nil and lastDay < d - 1 and streak > 0, -- missed a day: kind message
			rewards = rewardList(player, RewardsConfig.DAILY),
			nextAt = (d + 1) * DAY,
		}
		local play = playToday(player)
		state.play = {
			secs = play and play.secs or 0,
			got = play and play.got or {},
			gifts = rewardList(player, RewardsConfig.PLAYTIME),
			dayEndsAt = (today() + 1) * DAY,
		}
		state.offline = {
			pending = if type(hub.offline) == "number" then hub.offline else 0,
			away = if type(hub.offlineAway) == "number" then hub.offlineAway else 0,
		}
	end
	local have = collected(player)
	local claims = if type(hub.index) == "table" then hub.index else {}
	local zones = {}
	for _, zone in zoneOrder do
		local n, total = zoneProgress(player, zone, have)
		zones[zone] = { have = n, total = total, reached = tierReached(n, total), claimed = if type(claims[zone]) == "number" then claims[zone] else 0 }
	end
	state.index = { zones = zones, tiers = RewardsConfig.INDEX_TIERS, bonus = RewardsService.indexBonus(player), collected = have }
	if state.ui then
		local settings = table.clone(SETTINGS)
		if type(hub.settings) == "table" then
			for key in SETTINGS do
				if type(hub.settings[key]) == "boolean" then
					settings[key] = hub.settings[key]
				end
			end
		end
		state.settings = settings
		state.favs = if type(hub.favs) == "table" then hub.favs else {}
	end
	return state
end
RewardsService.stateOf = stateOf

function RewardsService.push(player: Player)
	if player.Parent and PlayerData.isLoaded(player) then
		stateEvent:FireClient(player, stateOf(player))
	end
end

local function refreshIncome(player: Player)
	local bonus = RewardsService.indexBonus(player)
	player:SetAttribute("IncomeBonus", if bonus > 0 then bonus else nil)
	PassiveIncome.refresh(player)
end

-- Claims ---------------------------------------------------------------------------------------------------
local function pay(player: Player, amount: number, kind: string, info: any)
	if amount > 0 then
		HubBase.giveCash(player, amount) -- (tracked so the "collect cash" quest doesn't count it)
	end
	info.kind, info.cash = kind, amount
	clientEvent:FireClient(player, "Claimed", info)
end
-- Pays a daily/playtime reward: its cash plus any free catches / Golden tickets.
local function payReward(player: Player, def: any, kind: string, info: any)
	local reward = rewardFor(player, def)
	if reward.freeCatches or reward.goldenCatches then
		ParadeService.grantCatches(player, reward.freeCatches, reward.goldenCatches)
		info.freeCatches, info.goldenCatches = reward.freeCatches, reward.goldenCatches
	end
	pay(player, reward.cash, kind, info)
end
local function saveSoon(player: Player)
	task.delay(1, function()
		if player.Parent and PlayerData.isLoaded(player) then
			PlayerData.save(player)
		end
	end)
end

-- Each returns (ok, message).
function RewardsService.claimDaily(player: Player): (boolean, string)
	if not rewardsOn() then
		return false, "off"
	end
	local hub = hubOf(player)
	if not hub then
		return false, "not loaded"
	end
	local state = stateOf(player).daily
	if not state.canClaim then
		return false, "Already collected today. Come back tomorrow!"
	end
	local day = state.nextDay
	local daily = section(hub, "daily")
	daily.streak, daily.day = day, today()
	payReward(player, RewardsConfig.DAILY[day], "daily", { day = day })
	return true, ("Day %d reward collected!"):format(day)
end

function RewardsService.claimPlaytime(player: Player, index: any): (boolean, string)
	if not rewardsOn() then
		return false, "off"
	end
	local gift = type(index) == "number" and index % 1 == 0 and RewardsConfig.PLAYTIME[index]
	if not gift then
		return false, "no such gift"
	end
	local play = playToday(player)
	if not play then
		return false, "not loaded"
	end
	local key = tostring(index)
	if play.got[key] then
		return false, "Already opened today."
	end
	if play.secs < gift.minutes * 60 then
		return false, "Not ready yet. Keep playing!"
	end
	play.got[key] = true
	payReward(player, gift, "playtime", { index = index })
	return true, "Gift opened!"
end

function RewardsService.claimOffline(player: Player): (boolean, string)
	if not rewardsOn() then
		return false, "off"
	end
	local hub = hubOf(player)
	local pending = hub and hub.offline
	if type(pending) ~= "number" or pending <= 0 then
		return false, "Nothing to collect."
	end
	hub.offline, hub.offlineAway = nil, nil -- before paying: a second request finds nothing
	pay(player, pending, "offline", {})
	return true, "Collected!"
end

function RewardsService.claimIndex(player: Player, zone: any): (boolean, string)
	if not flag("INDEX_BONUS_ENABLED") then
		return false, "off"
	end
	if type(zone) ~= "string" or not rosters[zone] then
		return false, "no such page"
	end
	local hub = hubOf(player)
	if not hub then
		return false, "not loaded"
	end
	local claims = section(hub, "index")
	local claimed = if type(claims[zone]) == "number" then claims[zone] else 0
	local n, total = zoneProgress(player, zone)
	local reached = tierReached(n, total)
	if reached <= claimed then
		return false, "Collect more creatures from this page first."
	end
	claims[zone] = reached
	refreshIncome(player)
	local tier = RewardsConfig.INDEX_TIERS[reached]
	clientEvent:FireClient(player, "Claimed", { kind = "index", zone = zone, tier = reached, bonus = tier.bonus, badge = tier.badge == true })
	return true, ("Index bonus claimed: +%d%% coins!"):format(math.floor(tier.bonus * 100 + 0.5))
end

function RewardsService.setSettings(player: Player, values: any): (boolean, string)
	if not flag("UI_V1_ENABLED") or type(values) ~= "table" then
		return false, "off"
	end
	local hub = hubOf(player)
	if not hub then
		return false, "not loaded"
	end
	local settings = section(hub, "settings")
	for key in SETTINGS do
		if type(values[key]) == "boolean" then
			settings[key] = values[key]
		end
	end
	return true, "saved"
end

function RewardsService.setFavourite(player: Player, uid: any, on: any): (boolean, string)
	if not flag("UI_V1_ENABLED") or type(uid) ~= "string" or #uid > 60 or type(on) ~= "boolean" then
		return false, "off"
	end
	local data = PlayerData.get(player) :: any
	if not data then
		return false, "not loaded"
	end
	local owned = false
	for _, w in data.workers do
		owned = owned or w.uid == uid
	end
	local favs = section(data.hub, "favs")
	if on then
		if not owned then
			return false, "not yours"
		end
		if StealConfig.on() then
			table.clear(favs) -- (033 fair stealing: one favourite, the one that can't be stolen; the star moves)
		end
		local count = 0
		for _ in favs do
			count += 1
		end
		if count >= FAVS_MAX then
			return false, "That's the most favourites you can have."
		end
		favs[uid] = true
	else
		favs[uid] = nil
	end
	local guard = script.Parent:FindFirstChild("StealGuard")
	if guard then
		local StealGuard = require(guard) :: any
		StealGuard.refresh(player) -- the shield over the placed favourite follows
	end
	return true, "saved"
end

-- Requests ---------------------------------------------------------------------------------------------------
local RATE = 4 -- requests per second (bucket size too)
local handlers = {
	State = function(_player)
		return true, nil
	end,
	ClaimDaily = RewardsService.claimDaily,
	ClaimPlaytime = RewardsService.claimPlaytime,
	ClaimOffline = RewardsService.claimOffline,
	ClaimIndex = RewardsService.claimIndex,
	Settings = RewardsService.setSettings,
	Favourite = RewardsService.setFavourite,
}
RewardsService.stats = { handled = 0, dropped = 0 }
function RewardsService.handle(player: Player, action: any, a: any, b: any)
	local t = os.clock()
	local bucket = budget[player]
	if not bucket then
		bucket = { tokens = RATE, at = t }
		budget[player] = bucket
	end
	bucket.tokens = math.min(RATE, bucket.tokens + (t - bucket.at) * RATE)
	bucket.at = t
	if bucket.tokens < 1 then
		RewardsService.stats.dropped += 1
		return
	end
	bucket.tokens -= 1
	local handler = type(action) == "string" and (handlers :: any)[action]
	if not (handler and PlayerData.isLoaded(player)) then
		return
	end
	RewardsService.stats.handled += 1
	local ok, message = handler(player, a, b)
	if ok and action ~= "State" and action ~= "Settings" and action ~= "Favourite" then
		HubBase.notify(player, true, message, "Rewards")
		saveSoon(player)
	elseif not ok and message and message ~= "off" and action ~= "Settings" and action ~= "Favourite" then
		HubBase.notify(player, false, message, "Rewards")
	elseif ok and (action == "Settings" or action == "Favourite") then
		saveSoon(player)
	end
	RewardsService.push(player)
end

-- Start ------------------------------------------------------------------------------------------------------
local started = false
function RewardsService.start()
	if started then
		return
	end
	started = true
	V1Flags.publish()
	for _, name in V1Flags.NAMES do
		ServerStorage:GetAttributeChangedSignal(V1Flags.STUDIO_ATTRIBUTES[name]):Connect(function()
			V1Flags.publish()
			for _, player in Players:GetPlayers() do
				refreshIncome(player)
				RewardsService.push(player)
			end
		end)
	end
	PassiveIncome.setMultiplier(function(player: Player): number
		return 1 + RewardsService.indexBonus(player)
	end)
	PlayerData.onLoaded(function(player, data: any)
		since[player] = now()
		if rewardsOn() then
			if type(data.hub) ~= "table" then
				data.hub = {}
			end
			settleOffline(player, data)
		end
		refreshIncome(player)
		task.delay(1, RewardsService.push, player)
	end)
	PlayerData.beforeFinalSave(function(player, data: any)
		if rewardsOn() and type(data.hub) == "table" then
			playToday(player)
			data.hub.seen = now()
		end
		since[player], lastSeenWrite[player], budget[player] = nil, nil, nil
	end)
	actionEvent.OnServerEvent:Connect(RewardsService.handle)
	-- Every 30 s: a new UTC day resets playtime; every SEEN_INTERVAL the last-seen time is written.
	task.spawn(function()
		local lastDay = today()
		while true do
			task.wait(30)
			local d = today()
			for _, player in Players:GetPlayers() do
				if not (rewardsOn() and PlayerData.isLoaded(player)) then
					continue
				end
				local hub = hubOf(player)
				if hub and now() - (lastSeenWrite[player] or 0) >= RewardsConfig.SEEN_INTERVAL then
					playToday(player)
					hub.seen = now()
					lastSeenWrite[player] = now()
				end
				if d ~= lastDay then
					RewardsService.push(player) -- new day: daily claim and playtime gifts are back
				end
			end
			lastDay = d
		end
	end)
end

-- Test seams (Studio test scripts only).
RewardsService._test = {
	setClock = function(fn: (() -> number)?)
		clock = fn or os.time
	end,
	settleOffline = settleOffline,
	playToday = playToday,
	collected = collected,
	tierReached = tierReached,
	stationIncome = stationIncome,
	setSince = function(player: Player, t: number)
		since[player] = t
	end,
}

return RewardsService
