-- Studio location: ServerScriptService.DevTest_V1029 (Script)
-- DevTest_V1029  (Milestone 029) -- STUDIO-ONLY two-player test of the V1 rewards, index bonus, store,
-- settings/favourites and the V1 screens. Inert unless Studio started the session with
-- StudioTestService and one of these arguments (2 clients, in-memory save: ServerStorage
-- StudioMemoryStore = true or Studio API access off):
--   (036: V1 is live in code (D46): launch "v1029:off" with the ServerStorage attributes StudioUiV1/StudioStore/StudioRewards/StudioIndexBonus
--   set to FALSE (unset = the live value, on); put them back after the launch)
--   "v1029:off"  launched with every V1 switch OFF: old HUD, nothing new, no save changes; then the
--                switches are turned on at run time and the server logic is tested through the real
--                remotes (claims, double claims, streaks, playtime, offline, index bonus, spam)
--   "v1029:ui"   launched with every V1 switch ON (StudioUiV1/StudioStore/StudioRewards/
--                StudioIndexBonus): the V1 HUD and every screen open, show the right state, close
-- The server clock is moved with RewardsService._test.setClock (marked SIM). Results: "@@T029|".

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local StudioTestService = game:GetService("StudioTestService")
local okArgs, args = pcall(function()
	return StudioTestService:GetTestArgs()
end)
local mode: string? = nil
if okArgs and type(args) == "string" then
	if args == "v1029:off" then
		mode = "off"
	elseif args == "v1029:ui" then
		mode = "ui"
	end
end
if not mode then
	return
end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local lines, passed, failed, simulated = {}, 0, 0, 0
local section = "setup"
local function note(kind: string, name: string, detail: any?)
	local line = ("%s | %s %s: %s | %s"):format(kind, mode, section, name, tostring(detail or ""))
	table.insert(lines, line)
	print("@@T029|" .. line)
end
local function finish(state: string)
	local summary = ("%s mode=%s passed=%d failed=%d (of which simulated checks=%d)"):format(state, mode, passed, failed, simulated)
	print("@@T029|SUMMARY " .. summary)
	StudioTestService:EndTest(summary .. "\n" .. table.concat(lines, "\n"))
end
local function expect(name: string, condition: any, detail: any?, sim: boolean?)
	if sim then
		simulated += 1
	end
	if condition then
		passed += 1
	else
		failed += 1
		note(if sim then "FAIL(SIM)" else "FAIL", name, detail)
	end
end
local function waitUntil(seconds: number, check: () -> any): any
	local deadline = os.clock() + seconds
	repeat
		local value = check()
		if value then
			return value
		end
		task.wait(0.1)
	until os.clock() > deadline
	return nil
end
local function scenario(name: string, run: () -> ())
	section = name
	local ok, err = pcall(run)
	if not ok then
		failed += 1
		note("ERROR", "scenario stopped", err)
	end
	print("@@T029|done " .. name .. (" passed=%d failed=%d"):format(passed, failed))
end
local function mod(name: string)
	return require(ServerScriptService:WaitForChild(name)) :: any
end

if ServerStorage:GetAttribute("StudioMemoryStore") ~= true and mod("PlayerData").isPersistent() then
	finish("ABORTED: run on the in-memory save (ServerStorage StudioMemoryStore = true)")
	return
end

local CashService, PlayerData, PlotService, WorkerInventory = mod("CashService"), mod("PlayerData"), mod("PlotService"), mod("WorkerInventory")
local PassiveIncome, RewardsService = mod("PassiveIncome"), mod("RewardsService")
local NPCCarry, ParadeService = mod("NPCCarry"), mod("ParadeService")
local RewardsConfig = require(ReplicatedStorage:WaitForChild("RewardsConfig")) :: any
-- D20: what a daily/playtime reward pays this player now.
local function rewardCash(p: Player, def: any): number
	return RewardsConfig.cash(def, PassiveIncome.getIncome(p))
end
local V1Flags = require(ReplicatedStorage:WaitForChild("V1Flags")) :: any
local WorkerCatalogue = require(ReplicatedStorage:WaitForChild("WorkerCatalogue")) :: any

local function ready(p: Player): boolean
	local c = p.Character
	return p.Parent ~= nil and PlayerData.isLoaded(p) and PlotService.getPlot(p) ~= nil and c ~= nil and c:FindFirstChild("HumanoidRootPart") ~= nil and WorkerInventory.isReady(p)
end
waitUntil(240, function()
	local n = 0
	for _, p in Players:GetPlayers() do
		if ready(p) then
			n += 1
		end
	end
	return n >= 2
end)
task.wait(3)
local list = Players:GetPlayers()
table.sort(list, function(a, b)
	return a.UserId > b.UserId
end)
local A, B = list[1], list[2]
if not (A and B and ready(A) and ready(B)) then
	finish("ABORTED: needs two loaded players")
	return
end

-- Bridge to the client helpers.
local bridge = Instance.new("RemoteEvent")
bridge.Name = "Test029Bridge"
bridge.Parent = ReplicatedStorage
local replies: { [number]: any } = {}
local seq = 0
bridge.OnServerEvent:Connect(function(_p, kind, id, value)
	if kind == "reply" and type(id) == "number" then
		replies[id] = value
	end
end)
local function ask(p: Player, kind: string, arg: any?, timeout: number?): any
	seq += 1
	local id = seq
	bridge:FireClient(p, kind, id, arg)
	local value = waitUntil(timeout or 6, function()
		return replies[id]
	end)
	replies[id] = nil
	return value or { answered = false }
end
for _, p in { A, B } do
	local helper = script:WaitForChild("ClientHelper"):Clone()
	helper.Disabled = false
	helper.Parent = p:WaitForChild("PlayerGui")
end
waitUntil(10, function()
	return ask(A, "ping", nil, 1).answered and ask(B, "ping", nil, 1).answered
end)

local function setFlags(on: boolean?)
	for _, name in V1Flags.NAMES do
		ServerStorage:SetAttribute(V1Flags.STUDIO_ATTRIBUTES[name], on)
	end
	task.wait(0.5)
end
local function hub(p: Player): any
	return (PlayerData.get(p) :: any).hub
end
local NEW_FIELDS = { "daily", "play", "seen", "offline", "offlineAway", "index", "settings", "favs" }
local function newFields(p: Player): string
	local found = {}
	for _, key in NEW_FIELDS do
		if hub(p)[key] ~= nil then
			table.insert(found, key)
		end
	end
	return table.concat(found, ",")
end
-- Gives `p` a Level 1 worker record (inventory, or on `station`); returns its uid.
local function give(p: Player, id: string, station: number?): string
	local uid = HttpService:GenerateGUID(false)
	local rec = { uid = uid, id = id, zone = WorkerCatalogue.get(id).zone, level = 1, tier = "Normal", loc = if station then "station" else "inventory", station = station }
	assert(WorkerInventory.give(p, rec, true), "give failed")
	if station then
		assert(WorkerInventory.respawn(p, uid), "respawn failed")
	end
	return uid
end
local function act(p: Player, action: string, a: any?, b: any?)
	ask(p, "act", { action = action, a = a, b = b })
	task.wait(0.35)
end
local DAY = 86400
local base = os.time()
local offset = 0
local function setDay(days: number)
	offset = days * DAY
	RewardsService._test.setClock(function()
		return base + offset
	end)
end

-- "off": flags off, then the server logic -------------------------------------------------------------------
if mode == "off" then
	scenario("all switches off", function()
		setFlags(false) -- (036: an unset attribute now means the live value, which is ON: off must be false)
		for _, name in V1Flags.NAMES do
			expect(name .. " is not published", ReplicatedStorage:GetAttribute(V1Flags.PUBLISHED[name]) == nil)
		end
		expect("the server says the switches are published", ReplicatedStorage:GetAttribute(V1Flags.READY) == true)
		local cash = CashService.get(A)
		for _, action in { "ClaimDaily", "ClaimOffline" } do
			act(A, action)
		end
		act(A, "ClaimPlaytime", 1)
		act(A, "ClaimIndex", "MainStreet")
		act(A, "Settings", { music = false })
		expect("no claim pays anything", CashService.get(A) - cash <= (A:GetAttribute("Income") or 0) * 4, CashService.get(A) - cash)
		expect("nothing new in the save", newFields(A) == "", newFields(A))
		expect("no income bonus", A:GetAttribute("IncomeBonus") == nil)
		local probe = ask(A, "probe")
		expect("old HUD shown, no V1 HUD", probe.hud == true and probe.hudV1 == false, HttpService:JSONEncode(probe))
		expect("no 029 window opens", probe.openCount == 0, probe.openCount)
		ask(A, "open", { gui = "Rewards029", name = "Daily" })
		ask(A, "open", { gui = "Store029", name = "cash" })
		task.wait(0.5)
		probe = ask(A, "probe")
		expect("Daily and Store refuse to open while off", probe.open.Daily ~= true and probe.open.Store ~= true, HttpService:JSONEncode(probe.open))
		local data = PlayerData._sanitize and PlayerData._sanitize(HttpService:JSONDecode(HttpService:JSONEncode(PlayerData.get(A)))) or PlayerData.get(A)
		expect("save is still schema 3", (data :: any).schema == 3)
	end)

	setFlags(true)
	scenario("daily streak", function()
		setDay(0)
		local cash = CashService.get(A)
		act(A, "ClaimDaily")
		local got = CashService.get(A) - cash
		local want1 = rewardCash(A, RewardsConfig.DAILY[1])
		expect("day 1 pays " .. want1, got >= want1 and got < want1 + 200, got)
		expect("streak saved as day 1 today", hub(A).daily.streak == 1 and hub(A).daily.day == math.floor((base + offset) / DAY), HttpService:JSONEncode(hub(A).daily))
		cash = CashService.get(A)
		act(A, "ClaimDaily")
		expect("a second claim the same day pays nothing", CashService.get(A) - cash < 200, CashService.get(A) - cash)
		setDay(1)
		cash = CashService.get(A)
		act(A, "ClaimDaily")
		got = CashService.get(A) - cash
		local want2 = rewardCash(A, RewardsConfig.DAILY[2])
		expect("next day: day 2 pays " .. want2, got >= want2 and got < want2 + 200, got, true)
		setDay(3) -- missed day 3
		local state = RewardsService.stateOf(A).daily
		expect("a missed day starts again at day 1, said kindly", state.nextDay == 1 and state.restarted == true and state.canClaim == true, HttpService:JSONEncode(state), true)
		act(A, "ClaimDaily")
		expect("restart claim is day 1", hub(A).daily.streak == 1, hub(A).daily.streak, true)
		hub(A).daily.streak, hub(A).daily.day = 7, math.floor((base + offset) / DAY)
		setDay(4)
		expect("after day 7 the calendar starts again", RewardsService.stateOf(A).daily.nextDay == 1, nil, true)
	end)

	scenario("playtime gifts", function()
		setDay(10)
		-- A joins on this new day (a session running through midnight would count from midnight).
		RewardsService._test.setSince(A, base + offset)
		RewardsService._test.playToday(A) -- new day: resets
		RewardsService._test.setSince(A, base + offset - (RewardsConfig.PLAYTIME[1].minutes * 60 + 5))
		local cash = CashService.get(A)
		act(A, "ClaimPlaytime", 1)
		local got = CashService.get(A) - cash
		local wantGift = rewardCash(A, RewardsConfig.PLAYTIME[1])
		expect("gift 1 opens after its minutes", got >= wantGift and got < wantGift + 200, got, true)
		cash = CashService.get(A)
		act(A, "ClaimPlaytime", 1)
		expect("gift 1 can't be opened twice", CashService.get(A) - cash < 200)
		act(A, "ClaimPlaytime", 2)
		expect("gift 2 is not ready yet", hub(A).play.got["2"] == nil)
		for _, bad in { "1", 0, 99, 1.5 } do
			act(A, "ClaimPlaytime", bad)
		end
		expect("bad gift numbers are refused", hub(A).play.got["99"] == nil and hub(A).play.got["0"] == nil)
		setDay(11)
		RewardsService._test.setSince(A, base + offset) -- joined again on day 11
		RewardsService._test.playToday(A)
		expect("a new day resets the gifts", next(hub(A).play.got) == nil and hub(A).play.secs < 60, HttpService:JSONEncode(hub(A).play), true)
	end)

	scenario("offline earnings", function()
		setDay(12)
		local data = PlayerData.get(B) :: any
		give(B, "crypto_carl", 1) -- $35/s
		give(B, "security_sam", 2) -- $22/s
		local income = 0
		for _, w in data.workers do
			if w.loc == "station" then
				income += WorkerCatalogue.get(w.id).income
			end
		end
		hub(B).offline, hub(B).index = nil, nil
		hub(B).seen = base + offset - 3600
		RewardsService._test.settleOffline(B, data)
		local want = math.floor(income * RewardsConfig.OFFLINE_RATE * 3600)
		expect("1 hour away pays income x rate x time", hub(B).offline == want, ("%s vs %d"):format(tostring(hub(B).offline), want), true)
		local cash = CashService.get(B)
		act(B, "ClaimOffline")
		local got = CashService.get(B) - cash
		expect("collect pays it once", got >= want and got < want + income * 3, got)
		cash = CashService.get(B)
		act(B, "ClaimOffline")
		expect("collecting again pays nothing", CashService.get(B) - cash < income * 3, CashService.get(B) - cash)
		hub(B).seen = base + offset - 10 * 3600
		RewardsService._test.settleOffline(B, data)
		local cap = math.floor(income * RewardsConfig.OFFLINE_RATE * RewardsConfig.OFFLINE_CAP_SECONDS)
		expect("10 hours away is capped", hub(B).offline == cap, ("%s vs %d"):format(tostring(hub(B).offline), cap), true)
		hub(B).seen = base + offset - 60
		local before = hub(B).offline
		RewardsService._test.settleOffline(B, data)
		expect("a minute away adds nothing", hub(B).offline == before, nil, true)
		act(B, "ClaimOffline")
		expect("seen is updated on load", hub(B).seen == base + offset, nil, true)
	end)

	scenario("income-based rewards (D20)", function()
		setDay(20)
		local income = PassiveIncome.getIncome(B)
		expect("B earns from stations", income > 0, income)
		local want = rewardCash(B, RewardsConfig.DAILY[1])
		expect("day 1 = 2 minutes of income, above its floor", want == math.floor(income * 60 * 2) and want > RewardsConfig.DAILY[1].floor, want)
		local state = RewardsService.stateOf(B)
		expect("the screens get the same amounts", state.daily.rewards[1].cash == want and state.play.gifts[6].freeCatches == 1, HttpService:JSONEncode(state.daily.rewards[1]))
		local cash = CashService.get(B)
		act(B, "ClaimDaily")
		local got = CashService.get(B) - cash
		expect("B's day 1 pays 2 minutes of income", got >= want and got < want + income * 3, ("%d vs %d"):format(got, want))
		-- day 7: 30 minutes of income + a Golden ticket
		hub(B).daily.streak, hub(B).daily.day = 6, math.floor((base + offset) / DAY)
		setDay(21)
		local free0, golden0 = ParadeService.credits(B)
		want = rewardCash(B, RewardsConfig.DAILY[7])
		cash = CashService.get(B)
		act(B, "ClaimDaily")
		got = CashService.get(B) - cash
		local free1, golden1 = ParadeService.credits(B)
		expect("day 7 pays 30 minutes of income", got >= want and got < want + income * 3, ("%d vs %d"):format(got, want), true)
		expect("day 7 adds one Golden ticket", golden1 == golden0 + 1 and free1 == free0, ("%d -> %d"):format(golden0, golden1), true)
		-- the 60-minute gift: a free catch, no cash
		RewardsService._test.setSince(B, base + offset)
		RewardsService._test.playToday(B)
		RewardsService._test.setSince(B, base + offset - 3605)
		cash = CashService.get(B)
		act(B, "ClaimPlaytime", 6)
		local free2 = ParadeService.credits(B)
		expect("the 60-minute gift adds a free catch and no cash", free2 == free1 + 1 and CashService.get(B) - cash < income * 3, ("%d -> %d"):format(free1, free2), true)
		expect("the catches are kept in the save's hub", hub(B).freeCatches == free2 and hub(B).goldenCatches == golden1)
		local floorOnly = RewardsConfig.cash(RewardsConfig.PLAYTIME[1], 0)
		expect("no income: the floor is paid", floorOnly == RewardsConfig.PLAYTIME[1].floor, floorOnly)
		hub(B).freeCatches, hub(B).goldenCatches = nil, nil
	end)

	-- Lost and repeated store/place messages (029 review item 3). SIM: the server is told to ignore a
	-- message, as if it never arrived; the client re-sends on its own.
	local function carryNew(p: Player, id: string): string?
		local plot = PlotService.getPlot(p) :: Model
		local free = nil
		for _, station in (plot :: any).Stations:GetChildren() do
			local i = station:GetAttribute("StationIndex")
			if station:GetAttribute("Occupied") ~= true and type(i) == "number" and i <= 6 and (not free or i < free) then
				free = i
			end
		end
		if not free then
			return nil
		end
		local uid = give(p, id, free)
		local model = nil
		for _, m in (plot :: any).PlacedNPCs:GetChildren() do
			if m:GetAttribute("WorkerUid") == uid then
				model = m
			end
		end
		local rec = WorkerInventory.getRecord(p, uid) :: any
		rec.loc, rec.station = "carried", nil
		model.Parent = workspace
		for _, station in (plot :: any).Stations:GetChildren() do
			if station:GetAttribute("StationIndex") == free then
				station:SetAttribute("Occupied", false)
			end
		end
		NPCCarry.start(p, model)
		return if waitUntil(2, function()
				return NPCCarry.getCarried(p) == model
			end)
			then uid
			else nil
	end
	scenario("lost and repeated store/place messages", function()
		local uid = carryNew(A, "broke_bob")
		expect("A carries a worker", uid ~= nil)
		WorkerInventory._test.dropNext(A, 1)
		ask(A, "inv", { action = "StoreCarried" })
		task.wait(1)
		expect("the first Store message is lost: still carrying", NPCCarry.getCarried(A) ~= nil, nil, true)
		local stored = waitUntil(8, function()
			return NPCCarry.getCarried(A) == nil
		end)
		expect("the client sends it again: stored", stored and WorkerInventory.getRecord(A, uid :: string).loc == "inventory", nil, true)
		expect("the client has nothing left waiting", (ask(A, "inv", { action = "none" }).pending or -1) == 0)
		-- a late duplicate never runs twice
		task.wait(0.3) -- (past the 0.2 s request cooldown: a raw message is never re-sent)
		ask(A, "invRaw", { action = "Equip", uid = uid, id = 900001 })
		task.wait(0.6)
		local onStations, plotFree = 0, 0
		for _, w in (PlayerData.get(A) :: any).workers do
			if w.loc == "station" then
				onStations += 1
			end
		end
		for _, st in (PlotService.getPlot(A) :: any).Stations:GetChildren() do
			if st:GetAttribute("Occupied") ~= true then
				plotFree += 1
			end
		end
		expect(
			"Equip (id 900001) puts it on a station",
			WorkerInventory.getRecord(A, uid :: string).loc == "station",
			("loc %s, A's records on stations %d, free station parts %d"):format(tostring(WorkerInventory.getRecord(A, uid :: string).loc), onStations, plotFree)
		)
		ask(A, "invRaw", { action = "Store", uid = uid, id = 900002 })
		task.wait(0.6)
		expect("Store (id 900002) puts it back", WorkerInventory.getRecord(A, uid :: string).loc == "inventory")
		ask(A, "invRaw", { action = "Equip", uid = uid, id = 900001 })
		task.wait(0.6)
		expect("a late copy of 900001 is answered, not run again", WorkerInventory.getRecord(A, uid :: string).loc == "inventory")
		-- Place: the backup request, with its first message lost
		local uid2 = carryNew(A, "delivery_dave")
		expect("A carries another worker", uid2 ~= nil)
		local plot = PlotService.getPlot(A) :: any
		local target = nil
		for _, station in plot.Stations:GetChildren() do
			if station:GetAttribute("Occupied") ~= true and station:GetAttribute("StationIndex") == 1 then
				target = station
			end
		end
		if target then
			(A.Character :: Model):PivotTo(target.CFrame * CFrame.new(0, 3.5, 2))
			task.wait(0.3)
			WorkerInventory._test.dropNext(A, 1)
			ask(A, "inv", { action = "Place", uid = 1 })
			local placed = waitUntil(8, function()
				return NPCCarry.getCarried(A) == nil
			end)
			local rec = WorkerInventory.getRecord(A, uid2 :: string) :: any
			expect("Place: lost once, sent again, placed once on station 1", placed and rec and rec.loc == "station" and rec.station == 1, rec and rec.loc, true)
			ask(A, "inv", { action = "Place", uid = 1 })
			task.wait(1)
			local count = 0
			for _, m in plot.PlacedNPCs:GetChildren() do
				count += if m:GetAttribute("WorkerUid") == uid2 then 1 else 0
			end
			expect("another Place when not carrying changes nothing", count == 1 and rec.loc == "station", count)
		else
			expect("station 1 is free for the Place test", false)
		end
	end)

	scenario("index bonus", function()
		RewardsService._test.setClock(nil)
		local ids = WorkerCatalogue.ZONES.MainStreet
		local have = RewardsService._test.collected(B)
		local n = 0
		for _, id in ids do
			n += if have[id] then 1 else 0
		end
		for _, id in ids do -- make it exactly half of the page
			if n >= #ids / 2 then
				break
			end
			if not have[id] then
				give(B, id)
				n += 1
			end
		end
		local incomeBefore = PassiveIncome.getIncome(B)
		act(B, "ClaimIndex", "MainStreet")
		expect("half a page: tier 1 claimed", hub(B).index and hub(B).index.MainStreet == 1, HttpService:JSONEncode(hub(B).index or {}))
		expect("the HUD gets the bonus", B:GetAttribute("IncomeBonus") == RewardsConfig.INDEX_TIERS[1].bonus, B:GetAttribute("IncomeBonus"))
		local want = math.floor(incomeBefore * (1 + RewardsConfig.INDEX_TIERS[1].bonus) + 1e-9)
		expect(
			"income goes up by the bonus",
			PassiveIncome.getIncome(B) == want and B:GetAttribute("Income") == want,
			("%d -> %d (want %d)"):format(incomeBefore, PassiveIncome.getIncome(B), want)
		)
		local c0 = CashService.get(B)
		task.wait(3.05)
		local earned = CashService.get(B) - c0
		expect("cash actually arrives at the new rate", earned >= want * 2 and earned <= want * 4, ("%d in ~3 s at %d/s"):format(earned, want))
		act(B, "ClaimIndex", "MainStreet")
		expect("the same tier can't be claimed twice", hub(B).index.MainStreet == 1)
		for _, id in ids do
			if not RewardsService._test.collected(B)[id] then
				give(B, id)
			end
		end
		act(B, "ClaimIndex", "MainStreet")
		expect(
			"full page: tier 2, bonus is the tier's (not added to tier 1)",
			hub(B).index.MainStreet == 2 and B:GetAttribute("IncomeBonus") == RewardsConfig.INDEX_TIERS[2].bonus,
			B:GetAttribute("IncomeBonus")
		)
		act(A, "ClaimIndex", "MainStreet")
		expect("A (page not filled) can't claim", not (hub(A).index and hub(A).index.MainStreet))
		act(A, "ClaimIndex", "NoSuchZone")
		expect("unknown pages are refused", not (hub(A).index and hub(A).index.NoSuchZone))
		local snapshot = RewardsService.stateOf(B).offline
		expect(
			"offline earnings include the index bonus",
			RewardsService._test.stationIncome(B, PlayerData.get(B)) == math.floor((35 + 22) * (1 + RewardsConfig.INDEX_TIERS[2].bonus) + 1e-9),
			snapshot
		)
	end)

	scenario("settings and favourites", function()
		act(A, "Settings", { music = false, sfx = true, lowfx = true, lowgfx = false, junk = 5 })
		local s = hub(A).settings
		expect("settings saved", s and s.music == false and s.lowfx == true and s.junk == nil, HttpService:JSONEncode(s or {}))
		act(A, "Settings", "nonsense")
		expect("bad settings are ignored", hub(A).settings.music == false)
		local mine = (PlayerData.get(A) :: any).workers[1]
		if not mine then
			give(A, "broke_bob")
			mine = (PlayerData.get(A) :: any).workers[1]
		end
		act(A, "Favourite", mine.uid, true)
		expect("own worker favourited", hub(A).favs and hub(A).favs[mine.uid] == true)
		local theirs = (PlayerData.get(B) :: any).workers[1]
		act(A, "Favourite", theirs.uid, true)
		expect("someone else's worker can't be", hub(A).favs[theirs.uid] == nil)
		act(A, "Favourite", mine.uid, false)
		expect("unfavourite", hub(A).favs[mine.uid] == nil)
	end)

	scenario("spam", function()
		setDay(30)
		local cash = CashService.get(A)
		local dropped = RewardsService.stats.dropped
		ask(A, "spam", { action = "ClaimDaily", n = 60 })
		task.wait(1)
		local got = CashService.get(A) - cash
		local one = rewardCash(A, RewardsConfig.DAILY[1])
		expect("60 claims in a burst pay once", got >= one and got < one + rewardCash(A, RewardsConfig.DAILY[2]), got, true)
		expect("the burst is rate limited", RewardsService.stats.dropped > dropped, RewardsService.stats.dropped - dropped)
		RewardsService._test.setClock(nil)
	end)

	scenario("save", function()
		local json = HttpService:JSONEncode(PlayerData.get(A))
		local clean = PlayerData._sanitize and PlayerData._sanitize(HttpService:JSONDecode(json))
		expect(
			"hub keeps the new fields through sanitize",
			clean == nil or (clean.hub.daily and clean.hub.play and clean.hub.settings),
			clean and HttpService:JSONEncode(clean.hub)
		)
		expect("schema 3", (PlayerData.get(A) :: any).schema == 3)
	end)
	setFlags(nil)
	finish("COMPLETE")
	return
end

-- "ui": switches on at launch -------------------------------------------------------------------------------
scenario("V1 HUD", function()
	expect(
		"all four switches published",
		ReplicatedStorage:GetAttribute("UiV1On")
			and ReplicatedStorage:GetAttribute("StoreOn")
			and ReplicatedStorage:GetAttribute("RewardsOn")
			and ReplicatedStorage:GetAttribute("IndexBonusOn")
	)
	CashService.add(A, 1234)
	task.wait(1)
	local p = ask(A, "probe")
	expect("V1 HUD shown, old HUD not", p.hudV1 == true and p.hud == false, HttpService:JSONEncode(p))
	expect("cash pill shows the cash", p.cashText == require(ReplicatedStorage:WaitForChild("CashFormat")).format(CashService.get(A)), p.cashText)
	expect(
		"every HUD button is there",
		p.buttons and p.buttons.Store and p.buttons.Workers and p.buttons.Index and p.buttons.Daily and p.buttons.Gifts and p.buttons.Settings,
		HttpService:JSONEncode(p.buttons or {})
	)
	expect("daily badge: something to collect", p.badges and p.badges.Daily == true, HttpService:JSONEncode(p.badges or {}))
	expect("every HUD button is at least 44 px", (p.smallest or 0) >= 44, p.smallest)
end)

local function openAndCheck(p: Player, gui: string, name: string, arg: string?, window: string)
	ask(p, "open", { gui = gui, name = arg or name })
	task.wait(0.6)
	local probe = ask(p, "probe")
	expect(window .. " opens", probe.open[window] == true, HttpService:JSONEncode(probe.open))
	expect(window .. ": only one window open", probe.openCount == 1, probe.openCount)
	expect(window .. ": fits the screen", probe.fits[window] == true, probe.fitsDetail and probe.fitsDetail[window])
	expect(window .. ": buttons at least 44 px", (probe.windowSmallest[window] or 0) >= 44, probe.windowSmallest[window])
	return probe
end
scenario("screens", function()
	local probe = openAndCheck(A, "Rewards029", "Daily", nil, "Daily")
	expect("daily claim button says Claim Day 1", tostring(probe.texts.dailyButton):find("Claim") ~= nil, probe.texts.dailyButton)
	local cash = CashService.get(A)
	ask(A, "act", { action = "ClaimDaily" })
	task.wait(1)
	expect("claiming from the screen pays", CashService.get(A) - cash >= rewardCash(A, RewardsConfig.DAILY[1]))
	probe = ask(A, "probe")
	expect("coins fly to the cash pill", (probe.coins or 0) > 0 or probe.lastClaim == "daily", probe.coins)
	expect("button now shows the wait", tostring(probe.texts.dailyButton):find("Next") ~= nil, probe.texts.dailyButton)
	openAndCheck(A, "Rewards029", "Gifts", nil, "Gifts")
	openAndCheck(A, "Rewards029", "Settings", nil, "Settings")
	probe = openAndCheck(A, "Store029", "Store", "cash", "Store")
	expect("store: cash tab selected", probe.storeTab == "cash", probe.storeTab)
	expect(
		"store: every item is Coming soon and can't be pressed",
		probe.storeAvailable == 0 and (probe.storeItems or 0) >= 3,
		("%s/%s"):format(tostring(probe.storeAvailable), tostring(probe.storeItems))
	)
	probe = openAndCheck(A, "Index029", "Index", "MainStreet", "Index")
	expect("index shows the Main Street page", probe.indexPage == "MainStreet", probe.indexPage)
	ask(A, "open", { gui = "Rewards029", name = "" })
	task.wait(0.6)
	probe = ask(A, "probe")
	expect("closing leaves nothing open", probe.openCount == 0, probe.openCount)
end)

scenario("offline popup", function()
	give(B, "crypto_carl", 1)
	hub(B).seen = os.time() - 1800
	RewardsService._test.settleOffline(B, PlayerData.get(B))
	RewardsService.push(B)
	local probe = waitUntil(6, function()
		local p = ask(B, "probe")
		return p.open.Offline and p
	end)
	expect("the welcome-back popup opens with the amount", probe and tostring(probe.texts.offline):find("%$") ~= nil, probe and probe.texts.offline)
	local cash = CashService.get(B)
	ask(B, "act", { action = "ClaimOffline" })
	task.wait(1.5)
	expect("Collect pays and closes it", CashService.get(B) > cash and not ask(B, "probe").open.Offline)
end)

scenario("settings apply", function()
	ask(A, "act", { action = "Settings", a = { music = true, sfx = false, lowfx = true, lowgfx = true } })
	task.wait(0.6)
	-- the client applies what it sends itself; this checks the saved state round trip
	expect("saved on the server", hub(A).settings.sfx == false and hub(A).settings.lowgfx == true)
end)

scenario("inventory favourites", function()
	local uid = give(A, "broke_bob")
	task.wait(0.5)
	local p = ask(A, "inventory", { uid = uid })
	expect("cards have a favourite star", p.star == true, HttpService:JSONEncode(p))
	expect("a sort button", p.sort == true)
end)
finish("COMPLETE")
