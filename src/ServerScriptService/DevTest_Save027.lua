-- Studio location: ServerScriptService.DevTest_Save027 (Script)
-- DevTest_Save027  (Milestone 027) -- STUDIO-ONLY real-save test on the REAL Studio DataStore (Studio
-- API access on). Inert in live servers, and in Studio unless one of these starts it:
--   Solo Play with ServerStorage attribute StudioTest027 = "a", then (Stop, Play again = a rejoin) "b".
--     The player is the Studio user, so BEFORE "a" their saved record is backed up and replaced by a
--     schema-2 test record, and AFTER "b" the original is written back (both done in Edit mode).
--     a  migration 2 -> 3, shop purchases incl. two extra stations, a trophy (SIM: awarded directly;
--        the arena fight itself is covered by DevTest_Hub026), tutorial done, workers on stations 7/8.
--        What "b" must find goes to DataStore SAB_Test027, key "expect".
--     b  (StudioUpgrades OFF) everything above came back, the station 7/8 workers are in storage and
--        their pads are gone.
--   StudioTestService session "save027:steal" (2 clients, test players -1 / -2 seeded as schema 2):
--     a PvP steal delivered, then the thief's real final save and a real load of it (same server).
-- Results: "@@T027|" lines; the last one starts with "@@T027|SUMMARY".

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local ServerStorage = game:GetService("ServerStorage")
local StudioTestService = game:GetService("StudioTestService")
local okArgs, args = pcall(function()
	return StudioTestService:GetTestArgs()
end)
local multi = okArgs and type(args) == "string" and args == "save027:steal"
local phase = if multi then "steal" else ServerStorage:GetAttribute("StudioTest027")
if phase ~= "a" and phase ~= "b" and phase ~= "steal" then
	return
end

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local lines, passed, failed, simulated = {}, 0, 0, 0
local section = "setup"
local function note(kind: string, name: string, detail: any?)
	local line = ("%s | %s %s: %s | %s"):format(kind, phase, section, name, tostring(detail or ""))
	table.insert(lines, line)
	print("@@T027|" .. line)
end
local function finish(state: string)
	local summary = ("%s phase=%s passed=%d failed=%d (simulated checks=%d)"):format(state, phase, passed, failed, simulated)
	print("@@T027|SUMMARY " .. summary)
	workspace:SetAttribute("Test027Summary", summary)
	if multi then
		StudioTestService:EndTest(summary .. "\n" .. table.concat(lines, "\n"))
	end
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
	print("@@T027|done " .. name .. (" passed=%d failed=%d"):format(passed, failed))
end

local function mod(name: string)
	return require(ServerScriptService:WaitForChild(name)) :: any
end
local PlayerData, PlotService, WorkerInventory, CashService = mod("PlayerData"), mod("PlotService"), mod("WorkerInventory"), mod("CashService")
local HubBase, HubShops = mod("HubBase"), mod("HubShops")
local PvPSteal, PvPTransfer = mod("PvPSteal"), mod("PvPTransfer")
local testStore = DataStoreService:GetDataStore("SAB_Test027")

local function ready(p: Player): boolean
	local c = p.Character
	return p.Parent ~= nil and PlayerData.isLoaded(p) and PlotService.getPlot(p) ~= nil and c ~= nil and c:FindFirstChild("HumanoidRootPart") ~= nil and WorkerInventory.isReady(p)
end
local wanted = if multi then 2 else 1
waitUntil(240, function()
	local n = 0
	for _, p in Players:GetPlayers() do
		if ready(p) then
			n += 1
		end
	end
	return n >= wanted
end)
task.wait(2)
if not PlayerData.isPersistent() then
	finish("ABORTED: Studio API access is off; this test needs the real Studio DataStore")
	return
end

local function record(p: Player, uid: string): any
	for _, w in (PlayerData.get(p) :: any).workers do
		if w.uid == uid then
			return w
		end
	end
	return nil
end
local function placed(p: Player, uid: string): Model?
	for _, m in PlotService.getPlot(p).PlacedNPCs:GetChildren() do
		if m:GetAttribute("WorkerUid") == uid then
			return m
		end
	end
	return nil
end
local function moveTo(p: Player, position: Vector3)
	(p.Character :: Model):PivotTo(CFrame.new(position + Vector3.new(0, 3.5, 0)))
	task.wait(0.2)
end
local function pad(p: Player, index: number): Instance?
	return PlotService.getPlot(p).Stations:FindFirstChild("Station" .. index)
end
local function raw(userId: number): any
	local stored = PlayerData.store():GetAsync("player_" .. userId)
	return stored and stored.data
end
local venues = workspace:WaitForChild("Venues")

if phase == "a" then
	local U = Players:GetPlayers()[1]
	scenario("migration 2 -> 3", function()
		local before = raw(U.UserId)
		expect("the store holds the seeded schema-2 test record", before and before.schema == 2 and before.workers[1] and before.workers[1].uid == "t027-a1", before and before.schema)
		local data = PlayerData.get(U) :: any
		-- (the hub systems have filled in their defaults and today's quests by now)
		expect("loaded as schema 3 with a fresh hub field", data.schema == 3 and type(data.hub) == "table" and (data.hub.trophies or 0) == 0 and next(data.hub.owned or {}) == nil, HttpService:JSONEncode(data.hub))
		expect("the seeded workers came through", record(U, "t027-a1") and record(U, "t027-a2") and record(U, "t027-a3"))
		expect("a save writes schema 3", PlayerData.save(U) and raw(U.UserId).schema == 3, raw(U.UserId).schema)
	end)
	scenario("purchases", function()
		local shops = venues.Shops
		local before = CashService.get(U)
		moveTo(U, shops.BatBoutique.Counter.Position)
		local ok, message = HubShops.buy(U, "skin:Neon")
		expect("bought the Neon Bat", ok and HubBase.data(U).owned["skin:Neon"] == true, message)
		moveTo(U, shops.LotAndDecor.Counter.Position)
		ok, message = HubShops.buy(U, "decor:planter")
		expect("bought a planter", ok, message)
		ok, message = HubShops.use(U, "decor:planter", 1)
		expect("put it on decor spot 1", ok and HubBase.data(U).decor["1"] == "decor:planter", message)
		moveTo(U, shops.UpgradeOffice.Counter.Position)
		for level = 1, 2 do
			ok, message = HubShops.buy(U, "upgrade:stations")
			expect("bought extra station level " .. level, ok and HubBase.data(U).upgrades.stations == level, message)
		end
		expect("pads 7 and 8 were built", pad(U, 7) ~= nil and pad(U, 8) ~= nil)
		local spent = before - CashService.get(U)
		expect("charged 15K + 2K + 150K + 750K (give or take a few seconds of income)", spent >= 917000 - 2000 and spent <= 917000, spent)
	end)
	scenario("stations 7 and 8", function()
		for _, pair in { { "t027-a2", 7 }, { "t027-a3", 8 } } do
			local rec = WorkerInventory.take(U, pair[1])
			rec.loc, rec.station = "station", pair[2]
			expect("worker given to station " .. pair[2], WorkerInventory.give(U, rec) and WorkerInventory.respawn(U, pair[1]) ~= nil)
			expect("it stands on pad " .. pair[2], placed(U, pair[1]) ~= nil and (pad(U, pair[2]) :: any):GetAttribute("Occupied") == true)
		end
	end)
	scenario("trophy and tutorial", function()
		local hub = HubBase.data(U)
		hub.trophies += 1 -- SIM: what HubArena does for a won fight
		HubBase.changed(U)
		expect("trophy recorded", hub.trophies == 1, hub.trophies, true)
		HubBase.handleAction(U, "TutorialDone")
		expect("tutorial marked done", hub.tutorial == true)
	end)
	scenario("save", function()
		expect("saved", PlayerData.save(U))
		local stored = raw(U.UserId)
		expect("the store has stations 7/8, purchases, trophy and tutorial", stored.hub.trophies == 1 and stored.hub.tutorial == true and stored.hub.upgrades.stations == 2 and stored.hub.owned["skin:Neon"] == true, HttpService:JSONEncode(stored.hub))
		testStore:SetAsync("expect", { cash = stored.cash, userId = U.UserId })
	end)
	finish("COMPLETE")
	return
end

if phase == "b" then
	local U = Players:GetPlayers()[1]
	scenario("rejoin", function()
		local want = testStore:GetAsync("expect")
		expect("expectations from phase a found", type(want) == "table" and want.userId == U.UserId)
		local data = PlayerData.get(U) :: any
		local hub = data.hub
		expect("schema 3", data.schema == 3)
		expect("cash at least what phase a saved", CashService.get(U) >= want.cash and CashService.get(U) <= want.cash + 20000, ("%s vs %s"):format(CashService.get(U), want.cash))
		expect("purchases are back", hub.owned["skin:Neon"] == true and hub.owned["decor:planter"] == true and hub.decor["1"] == "decor:planter", HttpService:JSONEncode(hub))
		expect("upgrade level is back", hub.upgrades.stations == 2, HttpService:JSONEncode(hub.upgrades))
		expect("trophy is back", hub.trophies == 1, hub.trophies)
		expect("tutorial still done", hub.tutorial == true)
	end)
	scenario("upgrades off: stations 7/8", function()
		expect("UPGRADES flag is off", not HubBase.flag("UPGRADES_ENABLED"))
		expect("no pads 7 and 8", pad(U, 7) == nil and pad(U, 8) == nil)
		for _, uid in { "t027-a2", "t027-a3" } do
			local rec = record(U, uid)
			expect(uid .. " went to storage", rec and rec.loc == "inventory" and rec.station == nil, rec and HttpService:JSONEncode(rec))
		end
		expect("the station-1 worker is still placed", placed(U, "t027-a1") ~= nil)
	end)
	pcall(testStore.RemoveAsync, testStore, "expect")
	finish("COMPLETE")
	return
end

-- phase "steal": two test players
local A, B = Players:GetPlayerByUserId(-1), Players:GetPlayerByUserId(-2)
if not (A and B and ready(A) and ready(B)) then
	finish("ABORTED: needs the loaded test players -1 and -2")
	return
end
scenario("steal, save, load", function()
	local model = placed(B, "t027-b2")
	expect("B's worker stands on B's lot", model ~= nil)
	local root = (model :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
	;(A.Character :: Model):PivotTo(CFrame.new(root.Position + Vector3.new(0, 1, 4)))
	task.wait(0.3)
	local ok, message = PvPSteal.tryBegin(A, model :: Model)
	expect("steal begins", ok, message)
	PvPSteal._test.setTeleportCheck(false)
	;(A.Character :: Model):PivotTo(PlotService.getPlot(A).PrimaryPart.CFrame * CFrame.new(0, 3.5, 0))
	PvPSteal._test.check()
	PvPSteal._test.setTeleportCheck(true)
	expect("delivered: A owns it, B doesn't", waitUntil(10, function()
		return record(A, "t027-b2") ~= nil and record(B, "t027-b2") == nil
	end))
	expect("the transfer journal settles", waitUntil(30, function()
		return PvPTransfer.isClear(PlayerData.store(), -1) == true and PvPTransfer.isClear(PlayerData.store(), -2) == true
	end))
	-- Rejoin: A's real final save, then a real load from the store (same server).
	PlayerData._test.leave(A)
	PlayerData._test.leave(B)
	local storedA, storedB = raw(-1), raw(-2)
	local function has(data: any, uid: string): boolean
		for _, w in (data and data.workers or {}) do
			if w.uid == uid then
				return true
			end
		end
		return false
	end
	expect("in the store: A has it, B doesn't", has(storedA, "t027-b2") and not has(storedB, "t027-b2"))
	task.spawn(PlayerData._test.load, A)
	expect("A loads again from the store", waitUntil(30, function()
		return PlayerData.isLoaded(A) and PlayerData.get(A) ~= nil
	end))
	expect("after the rejoin A still owns the stolen worker", record(A, "t027-b2") ~= nil)
	PlayerData._test.leave(A)
end)
scenario("cleanup", function()
	local store = PlayerData.store()
	for _, id in { -1, -2 } do
		for _, k in { "player_", "zones_", "pvpx_" } do
			pcall(store.RemoveAsync, store, k .. id)
		end
	end
	expect("test keys removed", store:GetAsync("player_-1") == nil and store:GetAsync("player_-2") == nil)
end)
finish("COMPLETE")
